## 402：框选多件道具 —— 从空格拖框选中、按在选中的一件上整组拖、整组落地、放不下整组弹回、勾选模式下框 = 全勾。
## 视图不进场景树，鼠标位置由测试给定（同 test_drag_layer）
extends RefCounted

const CELL := InventoryView.CELL


static func _def(id: String, rows: Array) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.shape = ItemShape.from_ascii(rows)
	return d


static func _view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## 本地像素（格中心）
static func _local(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func run(t: TestCase) -> void:
	t.begin("402 框选多件道具")
	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["1"])
	var bar := _def("bar", ["11"])

	var src := GridInventory.new(Vector2i(5, 4), 1)
	var dst := GridInventory.new(Vector2i(5, 4), 2)
	var va := _view(src, Vector2.ZERO)
	var vb := _view(dst, Vector2(400, 0))
	t.check(not va.box_select, "没登记到拖拽层的棋盘不框选")
	var drag := DragLayer.new()
	var ground := ItemStash.new()
	drag.stash = ground
	drag.register_view(va)
	drag.register_view(vb)
	t.check(va.box_select and vb.box_select, "登记了就能框")

	var a := ItemInstance.create(dot)
	var b := ItemInstance.create(bar)
	var c := ItemInstance.create(dot)
	src.place(a, Vector2i(0, 0), 0)
	src.place(b, Vector2i(1, 1), 0)     # 占 (1,1)(2,1)
	src.place(c, Vector2i(4, 3), 0)

	# --- 框：压到一格就算 ---
	t.eq(va.items_in_box(_local(Vector2i(0, 0)), _local(Vector2i(1, 1))), [a.uid, b.uid] as Array[int], "框 (0,0)–(1,1)：a 整个、b 压到一格都算")
	t.eq(va.items_in_box(_local(Vector2i(2, 2)), _local(Vector2i(3, 2))), [] as Array[int], "框到空地 = 没有")
	t.eq(va.items_in_box(Vector2(-50, -50), Vector2(1000, 1000)).size(), 3, "框出界也夹回棋盘")

	# --- 按下 / 拖开 / 松手 ---
	va.box_press(_local(Vector2i(0, 0)))
	va.box_motion(_local(Vector2i(0, 0)) + Vector2(2, 2))
	t.check(not va.is_boxing(), "没拖开不算框")
	va.box_motion(_local(Vector2i(2, 1)))
	t.check(va.is_boxing(), "拖开了在框")
	va.box_release(_local(Vector2i(2, 1)))
	t.eq(va.selected_uids(), [a.uid, b.uid] as Array[int], "松手：选中 a、b")
	t.eq(va.group_for(a.uid), [a.uid, b.uid] as Array[int], "按在选中的一件上 = 整组")
	t.eq(va.group_for(c.uid), [] as Array[int], "按在没选中的一件上 = 单件")
	va.box_press(_local(Vector2i(3, 0)))
	va.box_release(_local(Vector2i(3, 0)))
	t.eq(va.selected_uids().size(), 0, "点一下空格 = 取消选中")

	# --- 整组拖到另一块棋盘：相对位置不变 ---
	va.select_box(_local(Vector2i(0, 0)), _local(Vector2i(2, 1)))
	va.grab_requested.emit(va, a.uid, _local(Vector2i(0, 0)))
	t.check(drag.is_group_drag(), "按在选中的一件上：整组拿起")
	t.eq(src.item_count(), 1, "两件都离开了源棋盘")
	drag.rotate_dragged()
	t.check(drag.drop_at(_center(vb, Vector2i(2, 2))), "放到另一块棋盘的空处")
	t.eq(a.origin, Vector2i(2, 2), "领头那件落在光标格")
	t.eq(b.origin, Vector2i(3, 3), "另一件相对位置不变（整组先不转）")
	t.eq(dst.item_count(), 2, "两件都进了目标棋盘")
	t.eq(vb.selected_uids(), [a.uid, b.uid] as Array[int], "选中跟着道具走")

	# --- 放不下：整组弹回原位 ---
	vb.grab_requested.emit(vb, b.uid, _local(Vector2i(3, 3)))
	t.check(not drag.drop_at(_center(vb, Vector2i(4, 3))), "b 领头放到 (4,3)：b 出界，整组放不下")
	t.eq(a.origin, Vector2i(2, 2), "弹回：a 原位")
	t.eq(b.origin, Vector2i(3, 3), "弹回：b 原位")
	t.eq(vb.selected_uids().size(), 2, "弹回之后还是选中的")

	# --- 压着别的道具：不顶替，整组弹回 ---
	var d := ItemInstance.create(dot)
	dst.place(d, Vector2i(0, 0), 0)
	vb.grab_requested.emit(vb, a.uid, _local(Vector2i(2, 2)))
	t.check(not drag.drop_at(_center(vb, Vector2i(0, 0))), "压着 d：整组不顶替")
	t.check(dst.has_item(d.uid) and d.origin == Vector2i(0, 0), "d 没被挤走")

	# --- 取消：整组原样放回 ---
	vb.grab_requested.emit(vb, a.uid, _local(Vector2i(2, 2)))
	drag.cancel()
	t.check(dst.has_item(a.uid) and dst.has_item(b.uid), "取消：整组放回")

	# --- 棋盘外 = 整组落地（开着 drop_outside_to_stash 时）---
	drag.drop_outside_to_stash = false
	vb.grab_requested.emit(vb, a.uid, _local(Vector2i(2, 2)))
	t.check(not drag.drop_at(Vector2(300, 600)), "不许落地的一屏：棋盘外 = 弹回")
	t.eq(dst.item_count(), 3, "都还在棋盘上")
	drag.drop_outside_to_stash = true
	vb.grab_requested.emit(vb, a.uid, _local(Vector2i(2, 2)))
	t.check(drag.drop_at(Vector2(300, 600)), "棋盘外松手 = 整组落地")
	t.check(ground.has_item(a.uid) and ground.has_item(b.uid), "两件都在地上")
	t.eq(dst.item_count(), 1, "棋盘上只剩 d")

	# --- drop_filter 拦住任意一件 = 整组不放 ---
	var e1 := ItemInstance.create(dot)
	var e2 := ItemInstance.create(dot)
	src.place(e1, Vector2i(0, 0), 0)
	src.place(e2, Vector2i(1, 0), 0)
	drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		return not (inst == e2 and target == dst)
	va.select_box(_local(Vector2i(0, 0)), _local(Vector2i(1, 0)))
	va.grab_requested.emit(va, e1.uid, _local(Vector2i(0, 0)))
	t.check(not drag.drop_at(_center(vb, Vector2i(2, 2))), "跟着的那件不许进：整组不放")
	t.check(src.has_item(e1.uid) and src.has_item(e2.uid), "整组回了源棋盘")
	drag.drop_filter = Callable()

	# --- 包、扎根的不框 ---
	var pack := GridInventory.new(Vector2i(4, 4), 3, true)
	var bag_def := _def("pouch", ["11", "11"])
	bag_def.is_bag = true
	var vp := _view(pack, Vector2(0, 400))
	if pack.acts_as_bag(bag_def):
		var bag := ItemInstance.create(bag_def)
		pack.place(bag, Vector2i(0, 0), 0)
		var inside := ItemInstance.create(dot)
		pack.place(inside, Vector2i(0, 0), 0)
		t.eq(vp.items_in_box(Vector2(-10, -10), Vector2(500, 500)), [inside.uid] as Array[int], "包不框，包里的道具框")
		t.check(not vp.box_starts_at(Vector2i(1, 1), false), "平时包的空处不起框（拿整个包）")
		t.check(vp.box_starts_at(Vector2i(1, 1), true), "按着框选键：包的空处起框")
		t.check(not vp.box_starts_at(Vector2i(0, 0), true), "按着框选键按在道具上：还是拖那件")
		t.check(not vp.box_starts_at(Vector2i(3, 3), true), "棋盘空格本来就能框，这条只管包的空处")
	t.eq(InputKeys.keys_of(InputKeys.BOX_SELECT), [KEY_SHIFT] as Array[Key], "框选键默认 Shift")

	# --- 勾选模式（快速出售）：框 = 把框到的都勾上 ---
	var picked: Array[int] = []
	va.select_mode = true
	va.selected = {e1.uid: true}
	va.item_picked.connect(func(_v: InventoryView, uid: int): picked.append(uid))
	var before := va.selected_uids()
	va.select_box(_local(Vector2i(0, 0)), _local(Vector2i(1, 0)))
	t.eq(picked, [e2.uid] as Array[int], "勾选模式：只勾没勾的那件")
	t.eq(va.selected_uids(), before, "勾选模式不动框选的选中")
	va.select_mode = false

	drag.unregister_view(va)
	t.check(not va.box_select, "撤登记就不能框")
	for v in [va, vb, vp]:
		v.free()
	drag.free()
