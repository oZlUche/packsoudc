## 拖拽状态机的逻辑测试。
##
## 视图不进场景树，直接设 position / size；鼠标位置由测试给定。
## 这样整条「抓取 → 预览 → 旋转 → 放手 / 取消」的链路都能自动验证，
## 不必靠手工拖拽去撞那些失败路径。
extends RefCounted

const CELL := 48.0


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


static func _view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


## 某格中心的全局坐标
static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func run(t: TestCase) -> void:
	t.begin("DragLayer")

	ItemInstance.reset_uid_counter()
	var bar := _def("bar", ["#", "#", "#"])
	var big := _def("big", ["##", "##"])
	var gun := _def("gun", ["#"], ["weapon"])

	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)

	# --- 命中测试 ---
	t.check(drag.view_at(Vector2(10, 10)) == view_a, "左侧坐标应命中 view_a")
	t.check(drag.view_at(Vector2(410, 10)) == view_b, "右侧坐标应命中 view_b")
	t.is_null(drag.view_at(Vector2(300, 10)), "两者之间的空白不应命中任何视图")

	# --- 抓取：物品立刻离开源容器 ---
	var a := ItemInstance.create(bar)
	src.place(a, Vector2i(0, 0), 0)
	t.check(not drag.is_dragging(), "初始不在拖拽中")
	view_a.grab_requested.emit(view_a, a.uid, Vector2(24, 24))  # 抓住 (0,0) 格
	t.check(drag.is_dragging(), "抓取后应进入拖拽态")
	t.eq(src.item_count(), 0, "抓取时物品即从源容器移除")
	t.eq(src.cell_uid(Vector2i(0, 1)), GridInventory.EMPTY_UID, "源占用表已清空")

	# --- 跨容器放手 ---
	t.check(drag.drop_at(_center(view_b, Vector2i(1, 0))), "放到 view_b 应成功")
	t.check(not drag.is_dragging(), "放手后退出拖拽态")
	t.eq(dst.item_count(), 1, "目标容器应有 1 件")
	t.eq(a.origin, Vector2i(1, 0), "落点应为抓取格所在位置")
	t.eq(a.container_id, 2, "container_id 应更新")

	# --- 抓取偏移：抓住长条中段，落点要相应前移 ---
	var b := ItemInstance.create(bar)
	src.place(b, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, b.uid, Vector2(24, 24 + CELL))  # 抓住 (0,1)，即中段
	drag.drop_at(_center(view_a, Vector2i(2, 2)))
	t.eq(b.origin, Vector2i(2, 1), "抓中段放到 (2,2)，物品原点应落在 (2,1)")

	# --- 放到容器外：退回源容器原位 ---
	var c := ItemInstance.create(big)
	src.place(c, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, c.uid, Vector2(24, 24))
	t.check(not drag.drop_at(Vector2(300, 300)), "放到空白处应判为未落入容器")
	t.check(src.has_item(c.uid), "应退回源容器")
	t.eq(c.origin, Vector2i(0, 0), "应退回原位")
	t.eq(c.rotation, 0, "应退回原朝向")

	# --- 放到非法位置：同样退回 ---
	view_a.grab_requested.emit(view_a, c.uid, Vector2(24, 24))
	t.check(not drag.drop_at(_center(view_a, Vector2i(3, 3))), "2x2 放在 (3,3) 会越界")
	t.check(src.has_item(c.uid), "越界后应退回源容器")
	t.eq(c.origin, Vector2i(0, 0), "越界后应退回原位")

	# --- 取消拖拽 ---
	view_a.grab_requested.emit(view_a, c.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "取消前处于拖拽态")
	drag.cancel()
	t.check(not drag.is_dragging(), "取消后退出拖拽态")
	t.check(src.has_item(c.uid), "取消后物品退回源容器")
	t.eq(c.origin, Vector2i(0, 0), "取消后回到原位")

	# --- 拖拽中旋转 ---
	var narrow := GridInventory.new(Vector2i(3, 1), 3)
	var view_c := _view(narrow, Vector2(0, 400))
	drag.register_view(view_c)

	var d := ItemInstance.create(bar)
	src.remove(c.uid)
	src.place(d, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, d.uid, Vector2(24, 24))
	t.check(not drag.drop_at(_center(view_c, Vector2i(0, 0))), "竖条直接放进 3x1 应失败")
	t.check(src.has_item(d.uid), "失败后退回源容器")

	view_a.grab_requested.emit(view_a, d.uid, Vector2(24, 24))
	drag.rotate_dragged()
	t.check(drag.drop_at(_center(view_c, Vector2i(0, 0))), "旋转后放进 3x1 应成功")
	t.eq(d.rotation, 1, "落地后朝向应为旋转后的值")
	t.eq(narrow.item_count(), 1, "3x1 容器应收下这件")

	# --- 标签过滤 ---
	var slot := GridInventory.new(Vector2i(1, 1), 4)
	slot.accept_tags = [&"weapon"] as Array[StringName]
	var view_d := _view(slot, Vector2(400, 400))
	drag.register_view(view_d)

	var e := ItemInstance.create(big)
	src.place(e, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, e.uid, Vector2(24, 24))
	t.check(not drag.drop_at(_center(view_d, Vector2i(0, 0))), "无标签物品放不进武器槽")
	t.check(src.has_item(e.uid), "被拒后退回源容器")

	var g := ItemInstance.create(gun)
	src.remove(e.uid)
	src.place(g, Vector2i(0, 0), 0)
	view_a.grab_requested.emit(view_a, g.uid, Vector2(24, 24))
	t.check(drag.drop_at(_center(view_d, Vector2i(0, 0))), "带 weapon 标签可放进武器槽")

	# --- 落点预览的合法性判定 ---
	var h := ItemInstance.create(big)
	src.place(h, Vector2i(0, 0), 0)
	var occupied := ItemInstance.create(big)
	dst.place(occupied, Vector2i(0, 0), 0)

	view_a.grab_requested.emit(view_a, h.uid, Vector2(24, 24))
	drag.update_preview(_center(view_b, Vector2i(2, 2)))
	t.check(view_b._preview_on, "光标所在视图应显示预览")
	t.check(view_b._preview_valid, "空位处预览应为合法")
	t.check(not view_a._preview_on, "非光标所在视图应清除预览")

	# 压着别人不再是「非法」，而是「会顶人」—— 预览必须把这两档分开，
	# 否则玩家要么以为这一下没生效，要么不知道自己挤走了什么
	drag.update_preview(_center(view_b, Vector2i(0, 0)))
	t.check(view_b._preview_valid, "压着一件的位置是合法落点（会顶掉它）")
	t.eq(view_b._preview_victims.size(), 1, "预览点名了会被顶掉的那一件")
	# 「点名的是谁」问容器，不写死 —— 前面的用例往 dst 里放过东西，
	# 写死某个实例只会测出上面那些用例的摆放顺序
	var named: int = view_b._preview_victims[0]
	var overlaps := false
	for pc in view_b._preview_cells:
		if dst.cell_uid(view_b._preview_origin + pc) == named:
			overlaps = true
	t.check(overlaps, "点名的那件确实压在落点上")

	# 2x2 摆在 4x4 的 (3,3)，右下角伸出界外。地形不允许，顶谁都没用
	drag.update_preview(_center(view_b, Vector2i(3, 3)))
	t.check(not view_b._preview_valid, "伸出界外的落点仍是非法")
	t.check(view_b._preview_victims.is_empty(), "非法落点不该点名任何受害者")

	drag.update_preview(_center(view_d, Vector2i(0, 0)))
	t.check(not view_d._preview_valid, "标签不符时预览应为非法")

	drag.update_preview(Vector2(300, 300))
	t.check(not view_b._preview_on, "光标离开视图后预览应清除")

	drag.cancel()
	t.check(not view_b._preview_on, "结束拖拽应清掉所有预览")

	# --- 拖拽期间不接受第二次抓取 ---
	var i := ItemInstance.create(gun)
	src.place(i, Vector2i(3, 3), 0)
	view_a.grab_requested.emit(view_a, h.uid, Vector2(24, 24))
	var dragging_uid := h.uid
	view_a.grab_requested.emit(view_a, i.uid, Vector2(24 + CELL * 3, 24 + CELL * 3))
	t.check(src.has_item(i.uid), "已在拖拽中时，第二件不应被抓起")
	drag.drop_at(_center(view_a, Vector2i(0, 0)))
	t.check(src.has_item(dragging_uid), "第一件正常落地")

	# 释放节点，避免无头进程退出时报泄漏
	for v in [view_a, view_b, view_c, view_d]:
		v.free()
	drag.free()


## 某格中心在视图内的局部坐标，用于模拟「点在这一格上」
static func _grab(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func _bag_def(id: String, rows: Array) -> ItemDef:
	var d := _def(id, rows)
	d.is_bag = true
	return d


static func run_bag_drag(t: TestCase) -> void:
	t.begin("DragLayer · 拖包")

	ItemInstance.reset_uid_counter()
	var bag_def := _bag_def("bag6", ["##", "##", "##"])   # 2 宽 3 高
	var dot := _def("dot", ["#"])

	var board_a := GridInventory.new(Vector2i(6, 6), 1, true)
	var board_b := GridInventory.new(Vector2i(6, 6), 2, true)
	var view_a := _view(board_a, Vector2.ZERO)
	var view_b := _view(board_b, Vector2(500, 0))
	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)

	var bag := ItemInstance.create(bag_def)
	board_a.place(bag, Vector2i(0, 0), 0)
	var a := ItemInstance.create(dot)
	var b := ItemInstance.create(dot)
	board_a.place(a, Vector2i(0, 0), 0)
	board_a.place(b, Vector2i(1, 2), 0)

	# --- 点物品格抓物品 ---
	view_a.grab_requested.emit(view_a, a.uid, _grab(Vector2i(0, 0)))
	t.check(drag.is_dragging(), "点物品格应抓起该物品")
	t.check(board_a.has_item(bag.uid), "抓物品不应把包一起带走")
	drag.cancel()
	t.eq(board_a.item_count(), 3, "取消后恢复")

	# --- 包内的空格确实归包所有 ---
	var empty_cell := Vector2i(0, 1)
	t.eq(board_a.cell_uid(empty_cell), GridInventory.EMPTY_UID, "该格没有物品")
	t.eq(board_a.bag_at(empty_cell), bag.uid, "该格被包覆盖")

	# --- 抓起包，内容物一起离开 ---
	view_a.grab_requested.emit(view_a, bag.uid, _grab(empty_cell))
	t.check(drag.is_dragging(), "点包的空白处应抓起包")
	t.eq(board_a.item_count(), 0, "包与内容物一起离开棋盘")
	t.eq(board_a.usable_cell_count(), 0, "包走了，可用格归零")

	# 抓的是包的 (0,1) 格，落到 (2,2) 则包的原点在 (2,1)
	t.check(drag.drop_at(_center(view_b, Vector2i(2, 2))), "放到另一块棋盘应成功")
	t.eq(bag.rotation, 0, "没按 R，朝向保持 0")

	# --- 内容物保持相对位置 ---
	t.eq(board_b.item_count(), 3, "目标棋盘收到包与两件内容物")
	t.eq(bag.origin, Vector2i(2, 1), "包的原点按抓取偏移落位")
	t.eq(a.origin, Vector2i(2, 1), "内容物相对偏移 (0,0) 保持")
	t.eq(b.origin, Vector2i(3, 3), "内容物相对偏移 (1,2) 保持")
	t.eq(board_b.bag_of(a.uid), bag.uid, "容纳关系保持")
	t.eq(board_b.usable_cell_count(), 6, "包在新棋盘上照常提供 6 格")

	# --- 放到放不下的位置：整体退回 ---
	var blocker := ItemInstance.create(bag_def)
	board_a.place(blocker, Vector2i(0, 0), 0)
	view_b.grab_requested.emit(view_b, bag.uid, _grab(Vector2i(2, 1)))  # 抓包的左上角
	t.check(not drag.drop_at(_center(view_a, Vector2i(0, 0))), "目标已被别的包占据，应失败")
	t.eq(board_b.item_count(), 3, "失败后包与内容物全部退回原棋盘")
	t.eq(bag.origin, Vector2i(2, 1), "退回原位")
	t.eq(a.origin, Vector2i(2, 1), "内容物也退回原位")
	t.eq(board_a.item_count(), 1, "目标棋盘只剩它自己的包，无残留")

	# --- 落点预览 ---
	view_b.grab_requested.emit(view_b, bag.uid, _grab(Vector2i(2, 1)))
	drag.update_preview(_center(view_a, Vector2i(3, 0)))
	t.check(view_a._preview_on, "光标所在棋盘显示预览")
	t.check(view_a._preview_valid, "空处应判为合法")
	drag.update_preview(_center(view_a, Vector2i(0, 0)))
	t.check(not view_a._preview_valid, "与已有包重叠应判为非法")
	drag.cancel()
	t.eq(board_b.item_count(), 3, "取消后整体退回")
	t.check(not view_a._preview_on, "结束拖拽清掉预览")

	for v in [view_a, view_b]:
		v.free()
	drag.free()
