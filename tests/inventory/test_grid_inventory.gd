extends RefCounted


static func _def(id: String, rows: Array, tags: Array = []) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(rows)
	var t: Array[StringName] = []
	for tag in tags:
		t.append(StringName(tag))
	d.tags = t
	return d


static func run(t: TestCase) -> void:
	t.begin("GridInventory")

	ItemInstance.reset_uid_counter()
	var bar := _def("bar", ["#", "#", "#"])          # 竖 1x3
	var l_shape := _def("L", ["##", "#."])           # L 形三格
	var single := _def("dot", ["#"])
	var weapon := _def("sword", ["#", "#"], ["weapon"])

	# --- 初始状态 ---
	var inv := GridInventory.new(Vector2i(4, 4), 1)
	t.eq(inv.size, Vector2i(4, 4), "尺寸应为 4x4")
	t.eq(inv.free_cell_count(), 16, "空容器应有 16 个可用格")
	t.eq(inv.item_count(), 0, "空容器应无物品")
	t.eq(inv.cell_uid(Vector2i(0, 0)), GridInventory.EMPTY_UID, "空格 uid 为 0")
	t.check(not inv.in_bounds(Vector2i(4, 0)), "越界判定")
	t.check(not inv.in_bounds(Vector2i(-1, 0)), "负坐标越界")

	# --- 基本放置 ---
	var a := ItemInstance.create(bar)
	t.check(inv.place(a, Vector2i(0, 0), 0), "竖条放在左上应成功")
	t.eq(inv.item_count(), 1, "放入后应有 1 件")
	t.eq(inv.free_cell_count(), 13, "3 格被占，剩 13")
	t.eq(inv.cell_uid(Vector2i(0, 1)), a.uid, "占用表应记录 uid")
	t.eq(a.container_id, 1, "放置后应写入 container_id")
	t.eq(a.origin, Vector2i(0, 0), "放置后应写入 origin")

	# --- 重叠被拒 ---
	var b := ItemInstance.create(bar)
	t.check(not inv.place(b, Vector2i(0, 0), 0), "重叠放置应被拒绝")
	t.check(not inv.place(b, Vector2i(0, 2), 0), "部分重叠也应被拒绝")
	t.eq(inv.item_count(), 1, "被拒后不应改变容器内容")
	t.eq(b.container_id, 0, "被拒的实例应保持游离态")

	# --- 越界被拒 ---
	t.check(not inv.place(b, Vector2i(1, 2), 0), "竖条从 y=2 起会超出下边界")
	t.check(inv.place(b, Vector2i(1, 1), 0), "竖条从 y=1 起恰好放得下")
	t.eq(inv.item_count(), 2, "应有 2 件")

	# --- 同一实例不可重复放入 ---
	t.check(not inv.place(b, Vector2i(3, 0), 0), "已在容器中的实例不能再次 place")

	# --- 移除 ---
	var removed := inv.remove(b.uid)
	t.check(removed == b, "remove 应返回同一个实例")
	t.eq(inv.item_count(), 1, "移除后应剩 1 件")
	t.eq(inv.cell_uid(Vector2i(1, 1)), GridInventory.EMPTY_UID, "移除后占用表应清空")
	t.eq(b.container_id, 0, "移除后 container_id 归零")
	t.is_null(inv.remove(9999), "移除不存在的 uid 返回 null")

	# --- 旋转后占位改变 ---
	var inv2 := GridInventory.new(Vector2i(4, 4), 2)
	var r := ItemInstance.create(bar)
	inv2.place(r, Vector2i(0, 0), 0)
	t.eq(inv2.cell_uid(Vector2i(0, 2)), r.uid, "rot0 竖条占 (0,2)")
	inv2.remove(r.uid)
	t.check(inv2.place(r, Vector2i(0, 0), 1), "换个朝向放回去")
	t.eq(r.rotation, 1, "旋转后 rotation 为 1")
	t.eq(inv2.cell_uid(Vector2i(2, 0)), r.uid, "rot1 横条占 (2,0)")
	t.eq(inv2.cell_uid(Vector2i(0, 2)), GridInventory.EMPTY_UID, "旋转后旧格应释放")
	t.eq(inv2.free_cell_count(), 13, "旋转不改变占格总数")

	# --- 封禁格（非矩形容器）---
	var inv3 := GridInventory.new(Vector2i(3, 3), 3)
	t.check(inv3.set_blocked(Vector2i(2, 2), true), "封禁空格应成功")
	t.eq(inv3.free_cell_count(), 8, "封禁一格后剩 8")
	t.check(inv3.is_blocked(Vector2i(2, 2)), "该格应为封禁状态")
	var c := ItemInstance.create(single)
	t.check(not inv3.place(c, Vector2i(2, 2), 0), "不能放进封禁格")
	t.check(inv3.place(c, Vector2i(0, 0), 0), "非封禁格仍可放")
	t.check(not inv3.set_blocked(Vector2i(0, 0), true), "已占据的格子不能封禁")

	# --- 准入回调 ---
	var slot := GridInventory.new(Vector2i(1, 2), 4)
	slot.accept_filter = func(d: ItemDef) -> bool: return d.tags.has(&"weapon")
	var w := ItemInstance.create(weapon)
	var d := ItemInstance.create(single)
	t.check(slot.accepts(weapon), "带 weapon 标签的定义应被接受")
	t.check(not slot.accepts(single), "无标签的定义应被拒绝")
	t.check(slot.place(w, Vector2i(0, 0), 0), "武器可放入装备栏")
	t.check(not slot.place(d, Vector2i(0, 0), 0), "非武器不可放入装备栏")

	# --- can_place 的 ignore_uid ---
	var inv4 := GridInventory.new(Vector2i(4, 4), 5)
	var e := ItemInstance.create(bar)
	inv4.place(e, Vector2i(0, 0), 0)
	t.check(
		not inv4.can_place(bar.cells_rotated(0), Vector2i(0, 0)),
		"不忽略自身时应判为冲突"
	)
	t.check(
		inv4.can_place(bar.cells_rotated(0), Vector2i(0, 0), e.uid),
		"忽略自身 uid 时应判为可放"
	)

	# --- 自动装填 ---
	var inv5 := GridInventory.new(Vector2i(3, 3), 6)
	var fit := inv5.find_first_fit(l_shape)
	t.check(fit["found"], "空容器应找得到位置")
	t.eq(fit["origin"], Vector2i(0, 0), "应优先落在左上角")
	t.eq(fit["rotation"], 0, "应优先保持原朝向")

	var tall := GridInventory.new(Vector2i(3, 1), 7)
	var fit2 := tall.find_first_fit(bar, true)
	t.check(fit2["found"], "3x1 容器靠旋转应能放下 1x3 竖条")
	t.eq(fit2["rotation"], 1, "应旋转 90° 后放入")
	var fit3 := tall.find_first_fit(bar, false)
	t.check(not fit3["found"], "禁止旋转时 1x3 放不进 3x1")

	t.check(tall.try_add(ItemInstance.create(bar)), "try_add 应成功")
	t.eq(tall.free_cell_count(), 0, "3x1 容器被横条填满")
	t.check(not tall.try_add(ItemInstance.create(single)), "满容器 try_add 应失败")

	# --- clear ---
	var cl := GridInventory.new(Vector2i(2, 2), 10)
	var ci := ItemInstance.create(single)
	cl.place(ci, Vector2i(0, 0), 0)
	cl.clear()
	t.eq(cl.item_count(), 0, "clear 后无物品")
	t.eq(cl.free_cell_count(), 4, "clear 后格子全空")
	t.eq(ci.container_id, 0, "clear 后实例转为游离态")

	# --- changed 信号与批量合并 ---
	var sig := GridInventory.new(Vector2i(4, 4), 11)
	var counter := {"n": 0}
	sig.changed.connect(func(): counter["n"] += 1)
	sig.place(ItemInstance.create(single), Vector2i(0, 0), 0)
	t.eq(counter["n"], 1, "一次放置应发一次 changed")
	counter["n"] = 0
	sig.begin_batch()
	sig.place(ItemInstance.create(single), Vector2i(1, 0), 0)
	sig.place(ItemInstance.create(single), Vector2i(2, 0), 0)
	t.eq(counter["n"], 0, "批量期间不应发信号")
	sig.end_batch()
	t.eq(counter["n"], 1, "批量结束应合并成一次 changed")
	counter["n"] = 0
	sig.begin_batch()
	sig.end_batch()
	t.eq(counter["n"], 0, "空批量不应发信号")


static func run_serialization(t: TestCase) -> void:
	t.begin("GridInventory 序列化")

	ItemInstance.reset_uid_counter()
	var bar := _def("bar", ["#", "#", "#"])
	var l_shape := _def("L", ["##", "#."])
	var db := ItemDatabase.new()
	db.register(bar)
	db.register(l_shape)

	var inv := GridInventory.new(Vector2i(5, 5), 42)
	inv.set_blocked(Vector2i(4, 4), true)
	var i1 := ItemInstance.create(bar)
	i1.state = {"durability": 3}
	var i2 := ItemInstance.create(l_shape)
	inv.place(i1, Vector2i(0, 0), 0)
	inv.place(i2, Vector2i(2, 0), 1)

	var dict := inv.to_dict()
	var back := GridInventory.from_dict(dict, db)

	t.eq(back.id, inv.id, "id 应保留")
	t.eq(back.size, inv.size, "尺寸应保留")
	t.check(not dict.has("accept_tags"), "140：不再写容器级准入标签")
	t.check(back.is_blocked(Vector2i(4, 4)), "封禁格应保留")
	t.eq(back.item_count(), 2, "物品数应保留")
	t.eq(back.free_cell_count(), inv.free_cell_count(), "可用格数应一致")

	var b1 := back.get_item(i1.uid)
	t.not_null(b1, "按 uid 应能取回物品")
	t.eq(b1.origin, i1.origin, "锚点应保留")
	t.eq(b1.rotation, i1.rotation, "旋转应保留")
	t.eq(b1.state, i1.state, "状态应保留")
	t.check(b1.def == bar, "def 应还原成同一对象")
	t.eq(back.get_item(i2.uid).rotation, 1, "非零旋转应保留")

	# --- 往返两次得到完全相同的字典 ---
	t.eq(back.to_dict(), dict, "二次序列化应与首次完全一致")

	# --- JSON 往返 ---
	var json_text := JSON.stringify(dict)
	var parsed = JSON.parse_string(json_text)
	t.not_null(parsed, "序列化结果应可被 JSON 解析")
	var from_json := GridInventory.from_dict(parsed, db)
	t.eq(from_json.item_count(), 2, "经 JSON 往返后物品数不变")
	t.eq(from_json.get_item(i1.uid).origin, i1.origin, "经 JSON 往返后锚点不变")
	t.eq(from_json.get_item(i1.uid).state["durability"], 3, "经 JSON 往返后状态不变")

	# --- 定义缺失时安全降级 ---
	var thin_db := ItemDatabase.new()
	thin_db.register(bar)  # 故意不登记 L
	var degraded := GridInventory.from_dict(dict, thin_db)
	t.eq(degraded.item_count(), 1, "定义缺失的物品被丢弃，其余正常加载")
	t.not_null(degraded.get_item(i1.uid), "仍在的定义应正常还原")
