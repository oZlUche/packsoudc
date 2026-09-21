## 顶替式放置：把东西压在别人身上放手，挡路的被挤出来（架构文档 3.2）。
##
## 这一组分两层测：
##
## - **容器层**（[method GridInventory.place_displacing]）：谁会被顶、顶不动时
##   容器有没有原样留住。这层只管腾地方，不管腾出来的东西归谁。
## - **拖拽层**（[DragLayer]）：顶出来一件就接着上手，多于一件全进暂存区，
##   没地方安置就整件事作废。
##
## [b]重点在失败路径。[/b] 顶替这类操作，成功时一眼就能看出对不对，
## 出问题的永远是中途放弃的那条路 —— 半数物品被摘下、另一半不知去向，
## 而界面上只是「这一下好像没反应」。所以每条失败路径都得断言容器毫发无损。
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


static func _bag_def(id: String, rows: Array) -> ItemDef:
	var d := _def(id, rows)
	d.is_bag = true
	return d


#region 容器层
static func run(t: TestCase) -> void:
	t.begin("顶替 · 容器层")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var wide := _def("wide", ["##"])
	var inv := GridInventory.new(Vector2i(4, 4), 1)

	# --- 地形与占用是两件事 ---
	var sitting := ItemInstance.create(dot)
	inv.place(sitting, Vector2i(1, 1), 0)

	t.check(inv.terrain_allows(dot, Vector2i(1, 1), 0),
		"被占着的格子，**地形**上仍然是允许的 —— 这正是能顶的前提")
	t.check(not inv.can_place_def(dot, Vector2i(1, 1), 0),
		"但直接放进去不行")
	t.check(not inv.terrain_allows(dot, Vector2i(9, 9), 0), "出界的地形不允许")
	t.check(not inv.terrain_allows(wide, Vector2i(3, 0), 0), "伸出界外的也不允许")

	# --- 顶掉一件 ---
	var comer := ItemInstance.create(dot)
	var victims = inv.place_displacing(comer, Vector2i(1, 1), 0)
	t.not_null(victims, "压在一件上面，顶得动")
	t.eq(victims.size(), 1, "顶出来一件")
	t.eq(victims[0].uid, sitting.uid, "顶出来的就是原来坐在那儿的")
	t.check(inv.has_item(comer.uid), "新来的进去了")
	t.check(not inv.has_item(sitting.uid), "被顶的离开了容器")
	t.eq(inv.cell_uid(Vector2i(1, 1)), comer.uid, "那一格改姓了")

	# --- 顶掉两件，且同一件只算一次 ---
	inv.clear()
	var a := ItemInstance.create(dot)
	var b := ItemInstance.create(dot)
	var c := ItemInstance.create(wide)   # 两格宽，会和横跨它的落点重叠两次
	inv.place(a, Vector2i(0, 0), 0)
	inv.place(b, Vector2i(3, 0), 0)
	inv.place(c, Vector2i(1, 0), 0)

	var row := _def("row", ["####"])
	t.eq(inv.displaced_by(row, Vector2i(0, 0), 0).size(), 3,
		"横跨一整行压住三件；两格宽的那件被压了两格，仍只算一件")

	var bar := ItemInstance.create(row)
	var many = inv.place_displacing(bar, Vector2i(0, 0), 0)
	t.not_null(many, "一次顶三件也顶得动")
	t.eq(many.size(), 3, "三件都交还给了调用方")
	t.eq(inv.item_count(), 1, "容器里只剩新来的这一件")

	# --- 顶不动：地形不允许时原样不动 ---
	inv.clear()
	var keeper := ItemInstance.create(dot)
	inv.place(keeper, Vector2i(3, 3), 0)
	var reject := ItemInstance.create(wide)
	t.is_null(inv.place_displacing(reject, Vector2i(3, 3), 0),
		"伸出界外，顶谁都没用")
	t.check(inv.has_item(keeper.uid), "**失败后原来那件还在原位**")
	t.eq(inv.cell_uid(Vector2i(3, 3)), keeper.uid, "占用表也没被动过")
	t.eq(inv.item_count(), 1, "没有半途留下的残迹")


static func run_bags_are_not_displaced(t: TestCase) -> void:
	t.begin("顶替 · 包是地基，不参与顶替")

	ItemInstance.reset_uid_counter()
	var bag := _bag_def("bag4", ["##", "##"])
	var dot := _def("dot", ["#"])
	var board := GridInventory.new(Vector2i(6, 6), 1, true)

	var b := ItemInstance.create(bag)
	board.place(b, Vector2i(0, 0), 0)

	# 往包上丢东西：该落进包里，而不是把包掀掉
	var item := ItemInstance.create(dot)
	t.check(board.place(item, Vector2i(0, 0), 0), "包覆盖的空格直接放得进去")
	t.check(board.has_item(b.uid), "包还在")

	# 再丢一件压在它上面：顶掉的只能是普通物品
	var second := ItemInstance.create(dot)
	var victims = board.place_displacing(second, Vector2i(0, 0), 0)
	t.not_null(victims, "压在包里的物品上，顶得动")
	t.eq(victims.size(), 1, "只顶出来那件普通物品")
	t.eq(victims[0].uid, item.uid, "顶的是物品，不是包")
	t.check(board.has_item(b.uid), "**包纹丝不动**")

	# 拖一个包去顶别人：拒绝
	var other := ItemInstance.create(bag)
	t.is_null(board.place_displacing(other, Vector2i(0, 0), 0),
		"包自己也不能靠顶替落地 —— 一整袋内容物没有着落")
	t.eq(board.bags().size(), 1, "棋盘上仍然只有一个包")

	# 包外的格子：地形就不允许，谈不上顶
	t.check(not board.terrain_allows(dot, Vector2i(4, 4), 0),
		"没有包覆盖的格子，地形不允许")
#endregion


#region 拖拽层
static func _view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func run_drag_single(t: TestCase) -> void:
	t.begin("顶替 · 顶出一件就接着上手")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)

	var sitting := ItemInstance.create(dot)
	dst.place(sitting, Vector2i(1, 1), 0)
	var comer := ItemInstance.create(dot)
	src.place(comer, Vector2i(0, 0), 0)

	# lambda 按值捕获局部变量，直接往捕获来的变量里写是写不出去的；
	# 拿一个数组当信箱，捕获到的是同一个引用
	var mail := {"instances": [], "grabbed": false}
	drag.items_displaced.connect(
		func(instances: Array, grabbed: bool) -> void:
			mail["instances"] = instances
			mail["grabbed"] = grabbed
	)

	view_a.grab_requested.emit(view_a, comer.uid, Vector2(24, 24))
	t.check(drag.drop_at(_center(view_b, Vector2i(1, 1))), "压着放手，算落地成功")
	t.check(dst.has_item(comer.uid), "新来的占住了那一格")
	t.check(not dst.has_item(sitting.uid), "被顶的离开了棋盘")

	t.eq((mail["instances"] as Array).size(), 1, "上报了一件")
	t.check(mail["grabbed"], "上报说它已经拿在手上")
	t.check(drag.is_dragging(), "**放完手反而还在拖 —— 被顶出来的那件自动上手**")
	t.eq(drag._inst.uid, sitting.uid, "手上拿的就是被顶出来的那件")

	# 接着把它放到别处，链路要走得通
	t.check(drag.drop_at(_center(view_a, Vector2i(2, 2))), "它能正常落到别处")
	t.check(src.has_item(sitting.uid), "落到了源容器")
	t.check(not drag.is_dragging(), "这下才真的结束")

	for v in [view_a, view_b]:
		v.free()
	drag.free()


static func run_drag_many(t: TestCase) -> void:
	t.begin("顶替 · 顶出多件全进暂存区")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var row := _def("row", ["###"])
	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	var stash := GridInventory.new(Vector2i(4, 4), 3)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)
	drag.stash = stash

	var v1 := ItemInstance.create(dot)
	var v2 := ItemInstance.create(dot)
	dst.place(v1, Vector2i(0, 0), 0)
	dst.place(v2, Vector2i(2, 0), 0)
	var comer := ItemInstance.create(row)
	src.place(comer, Vector2i(0, 0), 0)

	var mail := {"grabbed": true}
	drag.items_displaced.connect(
		func(_instances: Array, grabbed: bool) -> void: mail["grabbed"] = grabbed
	)

	view_a.grab_requested.emit(view_a, comer.uid, Vector2(24, 24))
	t.check(drag.drop_at(_center(view_b, Vector2i(0, 0))), "压着两件放手，落地成功")
	t.check(dst.has_item(comer.uid), "新来的进去了")
	t.check(stash.has_item(v1.uid) and stash.has_item(v2.uid),
		"**两件都进了暂存区**，一件都不能丢")
	t.check(not drag.is_dragging(), "多于一件时不自动上手 —— 手只有一只")
	t.check(not mail["grabbed"], "上报说的是「都进暂存区了」")

	for v in [view_a, view_b]:
		v.free()
	drag.free()


static func run_drag_no_stash(t: TestCase) -> void:
	t.begin("顶替 · 没地方安置就整件事作废")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var row := _def("row", ["###"])
	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)
	# 故意不给暂存区

	var v1 := ItemInstance.create(dot)
	var v2 := ItemInstance.create(dot)
	dst.place(v1, Vector2i(0, 0), 0)
	dst.place(v2, Vector2i(2, 0), 0)
	var comer := ItemInstance.create(row)
	src.place(comer, Vector2i(0, 0), 0)

	# 预览就该先说清楚做不到，而不是等放手才失败
	view_a.grab_requested.emit(view_a, comer.uid, Vector2(24, 24))
	drag.update_preview(_center(view_b, Vector2i(0, 0)))
	t.check(not view_b._preview_valid,
		"没有暂存区时，会顶出多件的落点直接判非法 —— 不给做不到的承诺")

	t.check(not drag.drop_at(_center(view_b, Vector2i(0, 0))), "放手也不成立")
	t.check(src.has_item(comer.uid), "拖着的那件退回了源容器")
	t.check(dst.has_item(v1.uid) and dst.has_item(v2.uid),
		"**原来的两件还在原位**，没有被摘下来之后无处可去")
	t.eq(dst.cell_uid(Vector2i(0, 0)), v1.uid, "占用表也复原了")
	t.eq(dst.cell_uid(Vector2i(2, 0)), v2.uid, "两格都复原了")

	# 单件仍然可以顶：没有暂存区只挡住「多件」这一种情况
	drag.cancel()
	var single := ItemInstance.create(dot)
	src.place(single, Vector2i(3, 3), 0)
	view_a.grab_requested.emit(view_a, single.uid, Vector2(24 + CELL * 3, 24 + CELL * 3))
	t.check(drag.drop_at(_center(view_b, Vector2i(0, 0))),
		"顶一件不需要暂存区，它直接上手")
	t.check(drag.is_dragging(), "确实上手了")
	drag.cancel()

	for v in [view_a, view_b]:
		v.free()
	drag.free()


static func run_drag_full_stash(t: TestCase) -> void:
	t.begin("顶替 · 暂存区塞不下就整批退回")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var row := _def("row", ["###"])
	var src := GridInventory.new(Vector2i(4, 4), 1)
	var dst := GridInventory.new(Vector2i(4, 4), 2)
	# 只有一格的暂存区：装得下第一件，装不下第二件
	var stash := GridInventory.new(Vector2i(1, 1), 3)
	var view_a := _view(src, Vector2.ZERO)
	var view_b := _view(dst, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(view_a)
	drag.register_view(view_b)
	drag.stash = stash

	var v1 := ItemInstance.create(dot)
	var v2 := ItemInstance.create(dot)
	dst.place(v1, Vector2i(0, 0), 0)
	dst.place(v2, Vector2i(2, 0), 0)
	var comer := ItemInstance.create(row)
	src.place(comer, Vector2i(0, 0), 0)

	view_a.grab_requested.emit(view_a, comer.uid, Vector2(24, 24))
	t.check(not drag.drop_at(_center(view_b, Vector2i(0, 0))), "塞不下，这一下不成立")
	t.eq(stash.item_count(), 0,
		"**暂存区一件都没留下** —— 进了一半是比不生效更糟的结果")
	t.check(dst.has_item(v1.uid) and dst.has_item(v2.uid), "棋盘上的两件都回到了原位")
	t.check(src.has_item(comer.uid), "拖着的那件退回了源容器")

	for v in [view_a, view_b]:
		v.free()
	drag.free()
#endregion
