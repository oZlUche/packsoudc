## 123（作者定）：【全部拾取】先往背包棋盘放（自动找位、可旋转），放不下的才到地上
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 第一件形状正好 n 格、不是包、没有地形要求的道具
static func _of_cells(db: ItemDatabase, n: int) -> ItemDef:
	var ids := db.ids()
	Ids.sort(ids)
	for id in ids:
		var d := db.get_def(StringName(id))
		if d != null and not d.is_bag and d.shape.cell_count() == n:
			return d
	return null


static func run(t: TestCase) -> void:
	var db := _db()
	var one := db.get_def(&"ration")
	var four := _of_cells(db, 4)
	t.not_null(four, "库里有一件 4 格的道具")

	t.begin("123 · 棋盘放得下：三件全进棋盘，地上空")
	ItemInstance.reset_uid_counter()
	var loot := GridInventory.new(Vector2i(6, 6), 1)
	for i in 3:
		loot.try_add(ItemInstance.create(one))
	var board := GridInventory.new(Vector2i(4, 4), 2)
	var storage := ItemStash.new(3)
	var got := InventoryService.transfer_all_prefer(loot, board, storage)
	t.eq(got, {"board": 3, "storage": 0}, "三件进棋盘")
	t.eq(board.item_count(), 3, "棋盘三件")
	t.eq(storage.item_count(), 0, "地上空")
	t.eq(loot.item_count(), 0, "战利品空了")

	t.begin("123 · 棋盘只剩一格：1 格的进棋盘，4 格的到地上")
	loot = GridInventory.new(Vector2i(6, 6), 1)
	loot.try_add(ItemInstance.create(one))
	loot.try_add(ItemInstance.create(four))
	board = GridInventory.new(Vector2i(1, 1), 2)
	storage = ItemStash.new(3)
	got = InventoryService.transfer_all_prefer(loot, board, storage)
	t.eq(got, {"board": 1, "storage": 1}, "一件进棋盘、一件到地上")
	t.eq((board.items()[0] as ItemInstance).def.id, one.id, "棋盘上的是 1 格那件")
	t.eq((storage.items()[0] as ItemInstance).def.id, four.id, "地上的是 4 格那件")

	t.begin("123 · 带东西的包：棋盘放不下包就到地上，包里的东西跟着包走")
	var bag := db.get_def(&"bag_leather")
	loot = GridInventory.new(Vector2i(6, 6), 1, true)
	t.check(loot.try_add(ItemInstance.create(bag)), "包摆进战利品")
	t.check(loot.try_add(ItemInstance.create(one)), "包上摆一件")
	board = GridInventory.new(Vector2i(1, 1), 2)
	storage = ItemStash.new(3)
	got = InventoryService.transfer_all_prefer(loot, board, storage)
	t.eq(int(got["board"]) + int(got["storage"]), 2, "两件都拿走了")
	t.eq(loot.item_count(), 0, "战利品空了")
	var bag_in_storage := false
	for inst in storage.items():
		if (inst as ItemInstance).def.id == bag.id:
			bag_in_storage = true
	t.check(bag_in_storage, "包到了地上")

	t.begin("123 · 顺序稳定：同样的战利品两次结果一样")
	var runs: Array = []
	for k in 2:
		ItemInstance.reset_uid_counter()
		loot = GridInventory.new(Vector2i(6, 6), 1)
		for d in [one, four, one, four, one]:
			loot.try_add(ItemInstance.create(d))
		board = GridInventory.new(Vector2i(3, 2), 2)
		storage = ItemStash.new(3)
		got = InventoryService.transfer_all_prefer(loot, board, storage)
		var placed: Array = []
		for inst in board.items():
			placed.append([String((inst as ItemInstance).def.id), (inst as ItemInstance).origin])
		placed.sort()
		runs.append([got, placed])
	t.eq(runs[0], runs[1], "两次一样：%s" % [runs[0][0]])

	t.begin("123 · 一局里：take_all_loot 先进背包，战利品清空、发 loot_cleared")
	var c_items := db
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var kit: Array[StringName] = [&"bag_leather", &"bag_leather"]
	var s := RunState.start(chapter, 7, c_items, enemies, sets, kit)
	var cleared := [0]
	s.loot_cleared.connect(func() -> void: cleared[0] += 1)
	var before_board := s.board.item_count()
	var before_storage := s.storage.item_count()
	s.pending_loot = GridInventory.new(Vector2i(4, 4), 9)
	s.pending_loot.try_add(ItemInstance.create(one))
	t.check(s.board.can_admit(one), "背包有空位")
	t.eq(s.take_all_loot(), 1, "拿了一件")
	t.eq(s.board.item_count(), before_board + 1, "进了背包")
	t.eq(s.storage.item_count(), before_storage, "地上没多")
	t.eq(cleared[0], 1, "发了 loot_cleared")
	t.check(s.pending_loot == null, "待拾取清空")
