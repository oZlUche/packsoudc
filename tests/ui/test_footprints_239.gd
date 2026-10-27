## 239：拿起道具时，每块棋盘把每件道具的占格逐格铺出来（作者 10-27：不描框，整格一层淡的稀有度色，白档偏灰；包铺更淡的包灰）；
## 手里那件在残影上也逐格描；放下 / 取消就全部收起
extends RefCounted

const Drag := preload("res://tests/inventory/test_drag_layer.gd")
const CELL := InventoryView.CELL


static func run_footprint_cells(t: TestCase) -> void:
	t.begin("239 · 占格：L 形三格各一块、整格铺满（作者 10-27 不留缝）；白档偏灰；包铺更淡的包灰")
	var ell := Drag._def("ell", ["10", "11"])
	var rects := InventoryView.footprint_cells(ell.cells_rotated(0), Vector2(100, 50), CELL)
	t.eq(rects.size(), 3, "L 形三格：三块")
	var inset := InventoryView.FOOTPRINT_INSET
	t.eq(rects[0], Rect2(Vector2(100, 50) + Vector2.ONE * inset, Vector2.ONE * (CELL - 2.0 * inset)), "左上那格：按锚点、整格")
	var corner := false
	for r in rects:
		corner = corner or r.position == Vector2(100, 50) + Vector2(CELL, CELL) + Vector2.ONE * inset
	t.check(corner, "拐角那格 (1,1) 也描到")
	t.eq(InventoryView.footprint_cells(ell.cells_rotated(1), Vector2.ZERO, 30.0).size(), 3, "转了照样三格，按格宽缩放")
	var bag := Drag._def("pouch", ["11", "11"])
	bag.is_bag = true
	t.check(InventoryView.footprint_hollow(bag), "包：铺更淡的包灰（内容物压在上面要看得见）")
	t.check(not InventoryView.footprint_hollow(ell), "道具：淡的稀有度色")
	t.eq(InventoryView.FOOTPRINT_INSET, 0.0, "不留缝")
	t.eq(InventoryView.footprint_color(ell, 0), InventoryView.FOOTPRINT_WHITE, "白档换成偏灰的白")
	t.eq(InventoryView.footprint_color(ell, 3), ItemPainter.rarity_color(ell, 3), "别的档照稀有度色")


static func frame_footprints_follow_drag(t: TestCase, root: Window) -> void:
	t.begin("239 · 拿起时所有棋盘描出占格（含没登记到拖拽层的视图），放下 / 取消收起")
	ItemInstance.reset_uid_counter()
	var bar := Drag._def("bar", ["1", "1"])
	var src := GridInventory.new(Vector2i(4, 4), 1)
	var other := GridInventory.new(Vector2i(3, 3), 2)
	var view_a := Drag._view(src, Vector2.ZERO)
	var view_b := Drag._view(other, Vector2(400, 0))     # 不登记到拖拽层（像战前的敌人棋盘）
	var drag := DragLayer.new()
	root.add_child(view_a)
	root.add_child(view_b)
	root.add_child(drag)
	drag.register_view(view_a)
	var a := ItemInstance.create(bar)
	src.place(a, Vector2i(0, 0), 0)
	var b := ItemInstance.create(bar)
	src.place(b, Vector2i(2, 0), 0)
	t.check(not view_a.footprints and not view_b.footprints, "没在拖：不描")
	view_a.grab_requested.emit(view_a, a.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "拿起来了")
	t.check(view_a.footprints and view_b.footprints, "拿起：每块棋盘都描（没登记的也算）")
	t.check(drag.drop_at(Drag._center(view_a, Vector2i(1, 2))), "放下")
	t.check(not view_a.footprints and not view_b.footprints, "放下：收起")
	view_a.grab_requested.emit(view_a, b.uid, Vector2(24, 24))
	t.check(view_a.footprints, "再拿起：又描")
	drag.cancel()
	t.check(not view_a.footprints and not view_b.footprints, "取消：收起")
	drag.grab_free(ItemInstance.create(bar), src, Vector2i(3, 0), 0, Vector2i.ZERO)
	t.check(view_a.footprints and view_b.footprints, "游离的一件直接上手（顶替挤出来的）：也描")
	drag.cancel()
	t.check(not view_b.footprints, "取消：收起")
	root.remove_child(drag)
	root.remove_child(view_a)
	root.remove_child(view_b)
	drag.free()
	view_a.free()
	view_b.free()
