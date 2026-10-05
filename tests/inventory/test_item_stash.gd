## 地上：一个列表容器，以及它怎么接进拖拽层（架构文档 3.4）。
##
## 这一组要守住的核心不变式是：**地上没有空间语义**。
## 异形、旋转、占格、邻接，一样都不认 —— 3×1 的长条和 1×1 的钉子占一样的位置。
## 一旦哪天有人给它加了「摆不下」这类判断，下面的用例就会红。
extends RefCounted

const CELL := InventoryView.CELL


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


#region 容器层
static func run(t: TestCase) -> void:
	t.begin("地上 · 列表语义")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var long := _def("long", ["#", "#", "#", "#", "#"])
	var s := ItemStash.new(7)

	var a := ItemInstance.create(dot)
	var b := ItemInstance.create(long)
	t.check(s.insert(a, -1), "收下一件")
	t.check(s.insert(b, -1), "**五格的长条也只是一行** —— 列表里没有空间可言")
	t.eq(s.item_count(), 2, "两件都在")

	# --- 顺序就是玩家拖出来的顺序 ---
	t.eq(s.index_of(a.uid), 0, "先放的在前")
	t.eq(s.index_of(b.uid), 1, "后放的在后")

	var c := ItemInstance.create(dot)
	t.check(s.insert(c, 0), "插到最前面")
	t.eq(s.index_of(c.uid), 0, "它就在最前面")
	t.eq(s.index_of(a.uid), 1, "原来的都往后挪一位")

	# --- 越界的插入位置夹到两端，不判失败 ---
	var dd := ItemInstance.create(dot)
	t.check(s.insert(dd, 999), "拖到列表下方的空白处 = 放到最后，不该判失败")
	t.eq(s.index_of(dd.uid), s.item_count() - 1, "它在最后一行")

	# --- 挪位 ---
	t.check(s.move(dd.uid, 0), "挪到第一行")
	t.eq(s.index_of(dd.uid), 0, "挪到了")
	t.eq(s.item_count(), 4, "挪位不改变件数")

	# --- 取出 ---
	var taken := s.remove(a.uid)
	t.not_null(taken, "取得出来")
	t.eq(taken.uid, a.uid, "取出来的就是它")
	t.check(not s.has_item(a.uid), "不在表里了")
	t.eq(taken.container_id, 0, "取出来之后是游离态")
	t.is_null(s.remove(a.uid), "再取一次拿不到")

	# --- 同一件不能进两次 ---
	var again := ItemInstance.create(dot)
	s.insert(again, -1)
	t.check(not s.insert(again, -1), "同一个实例不能重复收下")


static func run_capacity(t: TestCase) -> void:
	t.begin("地上 · 上限")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])

	var unlimited := ItemStash.new(1)
	for i in 50:
		unlimited.insert(ItemInstance.create(dot), -1)
	t.eq(unlimited.item_count(), 50, "capacity 为 0 表示不限")
	t.check(not unlimited.is_full(), "不限的永远不满")

	var two := ItemStash.new(2, 2)
	t.check(two.insert(ItemInstance.create(dot), -1), "第一件收下")
	t.check(two.insert(ItemInstance.create(dot), -1), "第二件收下")
	t.check(two.is_full(), "满了")
	t.check(not two.insert(ItemInstance.create(dot), -1), "第三件收不下")
	t.eq(two.item_count(), 2, "收不下就是没收，件数不变")


static func run_tags(t: TestCase) -> void:
	t.begin("地上 · 准入标签")

	ItemInstance.reset_uid_counter()
	var gun := _def("gun", ["#"], ["weapon"])
	var food := _def("food", ["#"], ["remedy"])

	var s := ItemStash.new(4)
	s.accept_tags = [&"weapon"] as Array[StringName]
	t.check(s.can_admit(gun), "标签对得上，收")
	t.check(not s.can_admit(food), "对不上，不收")
	t.check(not s.insert(ItemInstance.create(food), -1), "硬塞也不收")
	t.eq(s.item_count(), 0, "一件都没进去")
#endregion


#region 搬运
static func run_transfer(t: TestCase) -> void:
	t.begin("地上 · 从网格搬进列表")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var loot := GridInventory.new(Vector2i(3, 3), 1)
	var s := ItemStash.new(2)

	for i in 5:
		loot.try_add(ItemInstance.create(dot))
	t.eq(loot.item_count(), 5, "战利品里五件")

	var moved := InventoryService.transfer_all(loot, s)
	t.eq(moved, 5, "全部搬进了列表 —— 列表不限容量，不存在「装不下」")
	t.eq(loot.item_count(), 0, "战利品空了")
	t.eq(s.item_count(), 5, "地上五件")

	# --- 目标收不下时，源容器一个字都不能动 ---
	var full := ItemStash.new(3, 0)
	full.capacity = 1
	full.insert(ItemInstance.create(dot), -1)
	var src := GridInventory.new(Vector2i(2, 2), 4)
	var stuck := ItemInstance.create(dot)
	src.place(stuck, Vector2i(1, 1), 0)

	t.check(not InventoryService.transfer_auto(src, stuck.uid, full), "满了，搬不过去")
	t.check(src.has_item(stuck.uid), "**源容器原样不动**")
	t.eq(src.cell_uid(Vector2i(1, 1)), stuck.uid, "连位置都没变")
	t.eq(full.item_count(), 1, "目标也没多出东西")
#endregion


#region 拖拽层
static func _grid_view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


## 128：一块地（不铺满屏的 [GroundLayer]），放进这块就落在放手点
static func _stash_view(s: ItemStash, at: Vector2) -> GroundLayer:
	var v := GroundLayer.new()
	v.stash = s
	v.position = at
	v.size = Vector2(400, 400)
	return v


## 这块地里的一个点（全局坐标）
static func _row_center(view: GroundLayer, row: int) -> Vector2:
	return view.position + Vector2(100 + row * 60, 100)


static func run_drag_to_and_from(t: TestCase) -> void:
	t.begin("地上 · 与棋盘之间来回拖")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var s := ItemStash.new(2)
	var bv := _grid_view(board, Vector2.ZERO)
	var sv := _stash_view(s, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(bv)
	drag.register_view(sv)
	drag.stash = s

	# --- 棋盘 → 列表 ---
	var item := ItemInstance.create(dot)
	board.place(item, Vector2i(1, 1), 0)
	bv.grab_requested.emit(bv, item.uid, Vector2(CELL * 1.5, CELL * 1.5))
	t.check(drag.drop_at(_row_center(sv, 0)), "拖到地上")
	t.check(s.has_item(item.uid), "它在列表里")
	t.check(not board.has_item(item.uid), "不在棋盘上了")
	t.eq(board.cell_uid(Vector2i(1, 1)), GridInventory.EMPTY_UID, "棋盘那一格空了")

	# --- 列表 → 棋盘 ---
	sv.grab_requested.emit(sv, item.uid, sv.item_rect(item.uid).position + Vector2(10, 10))
	t.check(drag.is_dragging(), "从列表里也抓得起来")
	t.check(drag.drop_at(bv.position + Vector2(CELL * 2.5, CELL * 2.5)), "拖回棋盘")
	t.check(board.has_item(item.uid), "回到棋盘")
	t.eq(item.origin, Vector2i(2, 2), "落在指定的格子上")
	t.eq(s.item_count(), 0, "列表空了")

	for v in [bv, sv]:
		v.free()
	drag.free()


static func run_drag_reorder(t: TestCase) -> void:
	t.begin("地上 · 地上挪位置（128）：只改落点，列表顺序不变")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var s := ItemStash.new(2)
	var sv := _stash_view(s, Vector2.ZERO)

	var drag := DragLayer.new()
	drag.register_view(sv)
	drag.stash = s

	var a := ItemInstance.create(dot)
	var b := ItemInstance.create(dot)
	var c := ItemInstance.create(dot)
	for inst in [a, b, c]:
		s.insert(inst, -1)

	var before := s.spot_of(c.uid)
	sv.grab_requested.emit(sv, c.uid, sv.item_rect(c.uid).position + Vector2(10, 10))
	t.check(drag.is_dragging(), "抓起来了")
	t.eq(s.item_count(), 2, "抓取期间它不在列表里")
	t.check(drag.drop_at(sv.position + Vector2(200, 60)), "放到这块地的另一处")
	t.eq(s.index_of(c.uid), 2, "列表里还是最后一件")
	t.check(not s.spot_of(c.uid).is_equal_approx(before), "落点改了")
	t.eq(s.item_count(), 3, "件数不变")

	sv.free()
	drag.free()


static func run_drag_cancel(t: TestCase) -> void:
	t.begin("地上 · 取消拖拽回到原行")

	ItemInstance.reset_uid_counter()
	var dot := _def("dot", ["#"])
	var s := ItemStash.new(2)
	var sv := _stash_view(s, Vector2.ZERO)

	var drag := DragLayer.new()
	drag.register_view(sv)

	var a := ItemInstance.create(dot)
	var b := ItemInstance.create(dot)
	var c := ItemInstance.create(dot)
	for inst in [a, b, c]:
		s.insert(inst, -1)

	var spot_b := s.spot_of(b.uid)
	sv.grab_requested.emit(sv, b.uid, Vector2(20, 15))
	drag.cancel()
	t.check(s.spot_of(b.uid).is_equal_approx(spot_b), "落点也回到原处（128）")
	t.eq(s.item_count(), 3, "取消后件数复原")
	t.eq(s.index_of(b.uid), 1, "**回到原来那一行**，而不是被追加到末尾")

	sv.free()
	drag.free()


static func run_bag_with_contents_rejected(t: TestCase) -> void:
	t.begin("地上 · 带东西的包收得进来（087 作者定）：包一行、内容物打散各一行")

	ItemInstance.reset_uid_counter()
	var bag_def := _def("bag4", ["##", "##"])
	bag_def.is_bag = true
	var dot := _def("dot", ["#"])

	var board := GridInventory.new(Vector2i(6, 6), 1, true)
	var s := ItemStash.new(2)
	var bv := _grid_view(board, Vector2.ZERO)
	var sv := _stash_view(s, Vector2(400, 0))

	var drag := DragLayer.new()
	drag.register_view(bv)
	drag.register_view(sv)

	var bag := ItemInstance.create(bag_def)
	board.place(bag, Vector2i(0, 0), 0)
	var inside := ItemInstance.create(dot)
	board.place(inside, Vector2i(0, 0), 0)

	bv.grab_requested.emit(bv, bag.uid, Vector2(CELL * 1.5, CELL * 0.5))
	t.check(drag.is_dragging(), "连内容物一起抓起来了")
	t.check(drag.drop_at(_row_center(sv, 0)), "放进列表：成（087：包能到地上，内容物打散）")
	t.eq(s.item_count(), 2, "列表里两行：包 + 内容物")
	t.check(s.has_item(bag.uid) and s.has_item(inside.uid), "包和里面的东西都在列表里")
	t.eq(board.item_count(), 0, "棋盘空了")

	# 空包照旧
	s.remove(inside.uid)
	sv.grab_requested.emit(sv, bag.uid, Vector2(10, 10))
	t.check(drag.drop_at(bv.position + Vector2(CELL * 0.5, CELL * 0.5)), "空包放回棋盘")
	bv.grab_requested.emit(bv, bag.uid, Vector2(CELL * 1.5, CELL * 0.5))
	t.check(drag.drop_at(_row_center(sv, 0)), "空包也收得进去")
	t.check(s.has_item(bag.uid), "空包在列表里")

	for v in [bv, sv]:
		v.free()
	drag.free()
#endregion
