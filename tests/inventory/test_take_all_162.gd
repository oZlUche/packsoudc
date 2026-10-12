## 162（作者定）：「全部拾取」先塞包再塞件；放不下落地的从它在棋盘上的那格起飞；落着的也能抓
extends RefCounted

const G := preload("res://tests/inventory/test_ground.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _ids(c: ItemContainer) -> Array:
	var out: Array = []
	for inst in c.items():
		out.append(String((inst as ItemInstance).def.id))
	out.sort()
	return out


static func run_bags_first(t: TestCase) -> void:
	var db := _db()
	var ration := db.get_def(&"ration")
	var bag := db.get_def(&"bag_leather")

	t.begin("162 · 先包后件：棋盘上还没有包，包先进、件再进刚放下的包")
	ItemInstance.reset_uid_counter()
	var loot := GridInventory.new(Vector2i(6, 6), 1)
	t.check(loot.try_add(ItemInstance.create(ration)), "战利品里一份口粮")
	t.check(loot.try_add(ItemInstance.create(ration)), "再一份")
	t.check(loot.try_add(ItemInstance.create(bag)), "一个皮革包")
	var board := GridInventory.new(Vector2i(5, 5), 2, true)     # 要包的棋盘，空的
	var storage := ItemStash.new(3)
	var got := InventoryService.transfer_all_prefer(loot, board, storage)
	t.eq(got, {"board": 3, "storage": 0}, "三件全进棋盘（旧顺序：件先试、没包放不下全落地）")
	t.eq(board.bags().size(), 1, "包在棋盘上")
	t.eq(storage.item_count(), 0, "地上空")

	t.begin("162 · 包放不下：包抛到地上，件各自再试棋盘")
	ItemInstance.reset_uid_counter()
	loot = GridInventory.new(Vector2i(6, 6), 1)
	loot.try_add(ItemInstance.create(ration))
	loot.try_add(ItemInstance.create(bag))
	board = GridInventory.new(Vector2i(2, 2), 2)     # 2×2：3×3 的包进不去，口粮进得去
	storage = ItemStash.new(3)
	got = InventoryService.transfer_all_prefer(loot, board, storage)
	t.eq(got, {"board": 1, "storage": 1}, "一件进棋盘、包到地上")
	t.eq(_ids(storage), ["bag_leather"], "地上的是包")
	t.eq(_ids(board), ["ration"], "棋盘上是口粮")

	t.begin("162 · 带东西的包：空包先进棋盘，包上的东西再按件塞（落回它）")
	ItemInstance.reset_uid_counter()
	loot = GridInventory.new(Vector2i(6, 6), 1, true)
	var b := ItemInstance.create(bag)
	t.check(loot.try_add(b), "包摆进战利品")
	t.check(loot.try_add(ItemInstance.create(ration)), "包上摆一件")
	t.check(loot.is_bag_with_contents(b.uid), "包上有东西")
	board = GridInventory.new(Vector2i(5, 5), 2, true)
	storage = ItemStash.new(3)
	got = InventoryService.transfer_all_prefer(loot, board, storage)
	t.eq(got, {"board": 2, "storage": 0}, "包和口粮都进了棋盘（包、件各算一件）")
	t.eq(board.contents_of(b.uid).size(), 1, "口粮在刚放下的包里")
	t.eq(loot.item_count(), 0, "战利品空了")

	t.begin("162 · 带东西的包整个搬（transfer_auto）：目标是要包的空棋盘也搬得进（包先进）")
	ItemInstance.reset_uid_counter()
	loot = GridInventory.new(Vector2i(6, 6), 1, true)
	b = ItemInstance.create(bag)
	loot.try_add(b)
	loot.try_add(ItemInstance.create(ration))
	board = GridInventory.new(Vector2i(5, 5), 2, true)
	t.check(InventoryService.transfer_auto(loot, b.uid, board), "搬进去了")
	t.eq(board.item_count(), 2, "包和口粮都在")
	t.eq(loot.item_count(), 0, "源空了")

	t.begin("162 · 带东西的包两边都进不去：整个放回原处，一件不少")
	ItemInstance.reset_uid_counter()
	loot = GridInventory.new(Vector2i(6, 6), 1, true)
	b = ItemInstance.create(bag)
	loot.try_add(b)
	loot.try_add(ItemInstance.create(ration))
	board = GridInventory.new(Vector2i(1, 1), 2, true)
	var full := GridInventory.new(Vector2i(1, 1), 3)
	full.try_add(ItemInstance.create(ration))
	got = InventoryService.transfer_all_prefer(loot, board, full)
	t.eq(got, {"board": 0, "storage": 0}, "一件没走")
	t.eq(loot.item_count(), 2, "包和口粮都还在")
	t.check(loot.is_bag_with_contents(b.uid), "口粮还在包上")


static func run_grab_mid_air(t: TestCase) -> void:
	t.begin("162 · 落着的也能抓：按此刻画在哪接鼠标；抓走动画停、拖拽层接手；排队还没出现的不接")
	ItemInstance.reset_uid_counter()
	var gun := G._def(&"t_gun", ["11"])
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var stash := ItemStash.new(2, 0)
	var rig := G._rig(stash, board)
	var ground: GroundLayer = rig["ground"]
	var drag: DragLayer = rig["drag"]
	var a := ItemInstance.create(gun)
	stash.insert(a, -1, Vector2(0.6, 0.6))
	stash.landing_from[a.uid] = Vector2(100, 200)
	var q := ItemInstance.create(gun)
	stash.insert(q, -1, Vector2(0.2, 0.2))
	stash.landing_from[q.uid] = Vector2(900, 200)
	ground._scan()
	t.check(ground.landing_pose(q.uid)["hidden"], "第二件还在排队")
	t.eq(ground.uid_at_local(Vector2(900, 200) + Vector2.ONE * 5), -1, "排队的不接")
	ground.advance_landing(GroundLayer.LAND_SEC * 0.1)
	var pose := ground.landing_pose(a.uid)
	var r := ground.item_rect(a.uid)
	t.check(ground.is_landing(a.uid) and (pose["pos"] as Vector2).distance_to(r.position) > 20.0, "还在半空（离落点 %.0f 像素）" % (pose["pos"] as Vector2).distance_to(r.position))
	# 第二格（右边那格）的中心：绕包围盒中心按此刻缩放
	var k := float(pose["scale"])
	var center := (pose["pos"] as Vector2) + r.size * 0.5
	var at := center + Vector2(InventoryView.CELL * 0.5, 0) * k
	t.eq(ground.uid_at_local(at), a.uid, "半空中按它此刻的位置命中")
	t.eq(ground.grab_cell_at(a.uid, at), Vector2i(1, 0), "抓在右边那格")
	t.eq(ground.uid_at_local(r.position + Vector2.ONE * 5), -1, "落点上还没东西")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = at
	ground._gui_input(mb)
	t.check(drag.is_dragging() and drag.source() == stash, "抓起来了")
	t.check(not ground.is_landing(a.uid), "动画停了")
	drag.cancel()
	G._free(rig)


static func frame_take_all_lands_from_cell(t: TestCase, root: Window) -> void:
	t.begin("162 · 全部拾取：放不下落地的那件起点 = 它在战利品棋盘上的那格；进了背包的不留起点")
	var db := _db()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var f := GameFlow.new(db, enemies, sets, MetaState.new())
	f.chapters = [chapter] as Array[ChapterDef]
	var run: RunState = null
	var seed := 1
	while run == null and seed < 30:
		run = RunState.start(chapter, seed, db, enemies, sets, [&"bag_leather"] as Array[StringName])
		seed += 1
	t.not_null(run, "开得了局")
	if run == null:
		return
	f.run = run
	var box := GridInventory.new(Vector2i(8, 8), 99)
	var huge := ItemInstance.create(G._def(&"t_huge_162", ["1111111", "1111111", "1111111", "1111111", "1111111", "1111111", "1111111"]))
	t.check(box.place(huge, Vector2i(1, 1), 0), "一件 7×7 的（背包放不下）")
	var small := ItemInstance.create(db.get_def(&"ration"))
	t.check(box.place(small, Vector2i(0, 0), 0), "一份口粮（放得下）")
	t.check(run.board.can_admit(small.def), "背包有地方放口粮")
	var screen = load("res://ui/game/container_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.LOOT
	root.add_child(screen)
	screen.open({"container": box})
	var view: LootView = screen.loot_view()
	var expect := view.global_position + view.cell_origin_px(Vector2i(1, 1))
	run.storage.landing_from.clear()
	screen.take_all()
	t.check(run.storage.has_item(huge.uid), "大件落地")
	t.check(run.board.has_item(small.uid), "口粮进了背包")
	t.eq(run.storage.landing_from.get(huge.uid, null), expect, "落地起点 = 它在战利品棋盘上的那格")
	t.check(not run.storage.landing_from.has(small.uid), "进了背包的不留起点")
	screen.queue_free()
