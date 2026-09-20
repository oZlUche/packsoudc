extends RefCounted


static func _make_def(id: String, rows: Array, can_rotate: bool = true) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(rows)
	d.can_rotate = can_rotate
	return d


static func run(t: TestCase) -> void:
	t.begin("ItemInstance / ItemDef / ItemDatabase")

	ItemInstance.reset_uid_counter()

	var bar := _make_def("bar", ["#", "#", "#"])
	var fixed := _make_def("fixed", ["##"], false)

	# --- 定义校验 ---
	t.check(bar.is_valid(), "完整定义应合法")
	var no_id := _make_def("", ["#"])
	t.check(not no_id.is_valid(), "缺 id 的定义非法")
	var no_shape := ItemDef.new()
	no_shape.id = &"x"
	t.check(not no_shape.is_valid(), "缺形状的定义非法")

	# --- uid 自增 ---
	var a := ItemInstance.create(bar)
	var b := ItemInstance.create(bar)
	t.eq(a.uid, 1, "首个实例 uid 为 1")
	t.eq(b.uid, 2, "第二个实例 uid 为 2")
	t.ne(a.uid, b.uid, "同一 def 的两个实例 uid 必须不同")
	t.check(a.def == b.def, "两个实例共享同一个 ItemDef 对象")

	# --- 不可旋转的物品被强制钉在 rot 0 ---
	var f := ItemInstance.create(fixed, 3)
	t.eq(f.rotation, 0, "can_rotate = false 时创建旋转应被归零")
	t.eq(f.rotated_step(1), 0, "can_rotate = false 时旋转一步仍为 0")
	t.eq(f.cells(), fixed.shape.cells_rotated(0), "不可旋转物品恒用 rot0 占格")

	# --- 可旋转物品 ---
	var r := ItemInstance.create(bar)
	t.eq(r.rotated_step(1), 1, "旋转一步为 1")
	r.rotation = 3
	t.eq(r.rotated_step(1), 0, "从 3 旋转一步回到 0")
	t.eq(r.size(), Vector2i(3, 1), "竖条 rot3（270°）包围盒为 3x1")
	r.rotation = 2
	t.eq(r.size(), Vector2i(1, 3), "竖条 rot2（180°）包围盒回到 1x3")
	r.rotation = 1
	t.eq(r.size(), Vector2i(3, 1), "竖条 rot1（90°）包围盒为 3x1")

	# --- 实例状态互不干扰 ---
	a.state["durability"] = 5
	t.check(not b.state.has("durability"), "实例状态不应串到另一个实例")
	t.check(not ("durability" in bar), "实例状态不应写回 ItemDef")

	# --- 数据库登记 ---
	var db := ItemDatabase.new()
	t.check(db.register(bar), "登记合法定义应成功")
	t.check(not db.register(bar), "重复 id 应被拒绝")
	t.check(not db.register(no_id), "无效定义应被拒绝")
	t.check(db.register(fixed), "登记第二个定义应成功")
	t.eq(db.size(), 2, "数据库应有 2 条定义")
	t.check(db.get_def(&"bar") == bar, "按 id 应取回同一个对象")
	t.is_null(db.get_def(&"nope"), "未知 id 应返回 null")

	# --- 序列化往返 ---
	var orig := ItemInstance.create(bar, 2)
	orig.origin = Vector2i(3, 4)
	orig.state = {"durability": 7, "mods": ["sharp"]}
	var round_trip := ItemInstance.from_dict(orig.to_dict(), db)
	t.not_null(round_trip, "往返后实例不应为 null")
	t.eq(round_trip.uid, orig.uid, "uid 应保留")
	t.check(round_trip.def == bar, "def 应按 id 还原成同一个对象")
	t.eq(round_trip.rotation, orig.rotation, "旋转应保留")
	t.eq(round_trip.origin, orig.origin, "锚点应保留")
	t.eq(round_trip.state, orig.state, "状态字典应保留")

	# --- 存的是 id 而不是资源路径 ---
	t.eq(orig.to_dict()["def"], "bar", "序列化写入的应是 def id 字符串")

	# --- 状态字典是深拷贝，不与原实例共享 ---
	round_trip.state["mods"].append("tainted")
	t.eq(orig.state["mods"].size(), 1, "往返后的状态修改不应影响原实例")

	# --- 未知 def 被安全丢弃 ---
	var orphan := {"uid": 99, "def": "ghost", "rot": 0, "origin": [0, 0], "state": {}}
	t.is_null(ItemInstance.from_dict(orphan, db), "def 已不存在时应返回 null 而非崩溃")

	# --- 读档后新建的 uid 不与存档撞号 ---
	ItemInstance.reset_uid_counter()
	var loaded := {"uid": 500, "def": "bar", "rot": 0, "origin": [0, 0], "state": {}}
	ItemInstance.from_dict(loaded, db)
	var after_load := ItemInstance.create(bar)
	t.check(after_load.uid > 500, "读档后新建实例的 uid 必须大于存档中的最大值")
