## 128（作者定）：不画暂存区 —— 格子外的整块屏幕就是「地上」，拖出背包放哪就在哪，每个节点各自一片地
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_ground_run.json"
const META := "user://test_ground_meta.json"
const SETTINGS := "user://test_ground_settings.json"
const SCREEN := Vector2(1600, 900)


static func _def(id: StringName, rows: Array) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	d.display_name = String(id)
	d.shape = ItemShape.from_ascii(rows)
	return d


static func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.001


## 铺满屏的地 + 一块棋盘 + 拖拽层（不进树：global == position）
static func _rig(stash: ItemStash, board: GridInventory) -> Dictionary:
	var ground := GroundLayer.new()
	ground.fills_screen = true
	ground.size = SCREEN
	ground.stash = stash
	ground._sync_norms()
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2.ZERO
	view.size = Vector2(board.size) * InventoryView.CELL
	var drag := DragLayer.new()
	drag.register_view(view)
	drag.register_view(ground)
	drag.stash = stash
	drag.drop_outside_to_stash = true
	return {"ground": ground, "view": view, "drag": drag}


static func _free(rig: Dictionary) -> void:
	for k in rig:
		(rig[k] as Node).free()


static func run_drop_at_release_point(t: TestCase) -> void:
	t.begin("128 · 拖出棋盘放手在 (0.3, 0.7)：落点就在那儿，存档来回不变")
	ItemInstance.reset_uid_counter()
	var gun := _def(&"t_gun", ["#"])
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var stash := ItemStash.new(2, 0)
	var rig := _rig(stash, board)
	var view: InventoryView = rig["view"]
	var drag: DragLayer = rig["drag"]
	var a := ItemInstance.create(gun)
	board.place(a, Vector2i(0, 0), 0)
	view.grab_requested.emit(view, a.uid, Vector2(24, 24))     # 抓在第 (0, 0) 格的正中
	t.check(drag.is_dragging(), "抓起来了")
	var release := Vector2(0.3, 0.7) * SCREEN + Vector2(0.5, 0.5) * InventoryView.CELL
	drag.update_preview(release)
	t.check(drag.drop_at(release), "放到棋盘外：算落下")
	t.check(stash.has_item(a.uid) and not board.has_item(a.uid), "到了地上")
	t.check(_near(stash.spot_of(a.uid), Vector2(0.3, 0.7)), "落点 = 放手点（%s）" % str(stash.spot_of(a.uid)))
	var back := ItemStash.from_dict(stash.to_dict(), _db_of([gun]))
	t.check(_near(back.spot_of(a.uid), Vector2(0.3, 0.7)), "存档来回：落点不变（%s）" % str(back.spot_of(a.uid)))
	_free(rig)


static func _db_of(defs: Array) -> ItemDatabase:
	var db := ItemDatabase.new()
	for d in defs:
		db.register(d)
	return db


static func run_auto_lay(t: TestCase) -> void:
	t.begin("128 · 没给落点的（程序塞进来的、旧档）自动铺：从左下角起，互不重叠、都在屏内")
	ItemInstance.reset_uid_counter()
	var small := _def(&"t_small", ["#"])
	var long := _def(&"t_long", ["###"])
	var block := _def(&"t_block", ["##", "##"])
	var stash := ItemStash.new(2, 0)
	stash.cell_norm = Vector2(InventoryView.CELL, InventoryView.CELL) / SCREEN
	var all: Array = []
	for i in 12:
		var inst := ItemInstance.create([small, long, block][i % 3])
		t.check(stash.admit(inst), "第 %d 件进地上" % i)
		all.append(inst)
	var overlap := 0
	var outside := 0
	for i in all.size():
		var r := stash.spot_rect(all[i])
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > 1.0001 or r.end.y > 1.0001:
			outside += 1
		for j in range(i + 1, all.size()):
			if r.intersects(stash.spot_rect(all[j])):
				overlap += 1
	t.eq(overlap, 0, "两两不重叠")
	t.eq(outside, 0, "都在屏内")
	t.check(stash.spot_of((all[0] as ItemInstance).uid).y > 0.8, "第一件铺在屏幕下沿（%s）" % str(stash.spot_of((all[0] as ItemInstance).uid)))
	# 躲开面板
	var stash2 := ItemStash.new(3, 0)
	stash2.cell_norm = stash.cell_norm
	stash2.avoid = [Rect2(0, 0.5, 0.5, 0.5)] as Array[Rect2]
	var x := ItemInstance.create(small)
	stash2.admit(x)
	t.check(not stash2.spot_rect(x).intersects(stash2.avoid[0]), "自动铺放躲开登记的面板（%s）" % str(stash2.spot_of(x.uid)))


static func run_resize_keeps_on_screen(t: TestCase) -> void:
	t.begin("128 · 窗口尺寸变了：东西还在屏内（落点是归一化的，画的时候整块夹进屏）")
	ItemInstance.reset_uid_counter()
	var block := _def(&"t_block", ["###", "###"])
	var stash := ItemStash.new(2, 0)
	var ground := GroundLayer.new()
	ground.size = SCREEN
	ground.stash = stash
	var a := ItemInstance.create(block)
	var b := ItemInstance.create(block)
	stash.insert(a, -1, Vector2(0.98, 0.97))
	stash.insert(b, -1, Vector2(0.1, 0.2))
	for s in [SCREEN, Vector2(800, 450), Vector2(1280, 1024), Vector2(400, 300)]:
		ground.size = s
		var screen := Rect2(Vector2.ZERO, s)
		t.check(screen.encloses(ground.item_rect(a.uid)), "%s：贴右下角的那件在屏内（%s）" % [str(s), str(ground.item_rect(a.uid))])
		t.check(screen.encloses(ground.item_rect(b.uid)), "%s：另一件在屏内" % str(s))
	ground.size = Vector2(800, 450)
	t.check(ground.item_rect(b.uid).position.is_equal_approx(Vector2(80, 90)), "按比例落在同一处（%s）" % str(ground.item_rect(b.uid).position))
	ground.free()


static func run_pick_up_and_drop_again(t: TestCase) -> void:
	t.begin("128 · 从地上拿起又放回地上 = 改落点（列表里的位置不变、件数不变）；拿起放进棋盘就离开地上")
	ItemInstance.reset_uid_counter()
	var gun := _def(&"t_gun", ["#"])
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var stash := ItemStash.new(2, 0)
	var rig := _rig(stash, board)
	var ground: GroundLayer = rig["ground"]
	var drag: DragLayer = rig["drag"]
	var first := ItemInstance.create(gun)
	var second := ItemInstance.create(gun)
	stash.insert(first, -1, Vector2(0.5, 0.5))
	stash.insert(second, -1, Vector2(0.6, 0.5))
	var at := ground.item_rect(first.uid).position + Vector2(24, 24)
	t.eq(ground.uid_at_local(at), first.uid, "地上点得到那一件")
	ground.grab_requested.emit(ground, first.uid, at)
	t.check(drag.is_dragging() and not stash.has_item(first.uid), "拿起来了（离开地上）")
	var release := Vector2(0.4, 0.3) * SCREEN + Vector2(0.5, 0.5) * InventoryView.CELL
	drag.update_preview(release)
	t.check(drag.drop_at(release), "放回地上：算落下")
	t.check(_near(stash.spot_of(first.uid), Vector2(0.4, 0.3)), "落点改了（%s）" % str(stash.spot_of(first.uid)))
	t.eq(stash.index_of(first.uid), 0, "列表里还是第一件")
	t.eq(stash.item_count(), 2, "一件没多没少")
	# 取消 = 原处
	ground.grab_requested.emit(ground, second.uid, ground.item_rect(second.uid).position + Vector2(10, 10))
	drag.cancel()
	t.check(_near(stash.spot_of(second.uid), Vector2(0.6, 0.5)), "取消：回到原落点")
	# 拿到棋盘上
	ground.grab_requested.emit(ground, second.uid, ground.item_rect(second.uid).position + Vector2(24, 24))
	var on_board := Vector2(1.5, 1.5) * InventoryView.CELL
	drag.update_preview(on_board)
	t.check(drag.drop_at(on_board), "放进棋盘")
	t.check(board.has_item(second.uid) and not stash.has_item(second.uid), "上了棋盘、离开地上")
	t.check(not stash.spots.has(second.uid), "落点跟着删了")
	_free(rig)


static func run_old_save_without_spots(t: TestCase) -> void:
	t.begin("128 · 旧档（地上 / 按点存放都没有 spots）照样读得回来，东西自动铺开")
	ItemInstance.reset_uid_counter()
	var gun := _def(&"t_gun", ["#"])
	var db := _db_of([gun])
	var stash := ItemStash.new(2, 0)
	for i in 3:
		stash.admit(ItemInstance.create(gun))
	var d := stash.to_dict()
	d.erase("spots")
	var back := ItemStash.from_dict(d, db)
	t.eq(back.item_count(), 3, "三件都在")
	var ok := true
	for inst in back.items():
		ok = ok and ItemStash.has_spot_value(back.spot_of((inst as ItemInstance).uid))
	t.check(ok, "每件都有落点")
	var list := back.items()
	t.check(not back.spot_rect(list[0]).intersects(back.spot_rect(list[1])), "自动铺开不重叠")
	# 按点存放的旧档：只有 nodes
	var ns := NodeStorageModule.new()
	ns._load({"nodes": {"7": [ItemInstance.create(gun).to_dict()]}}, db)
	t.eq(ns.stored_at(7).size(), 1, "按点存放的旧档读得回来")
	t.check((ns.spots.get(7, {}) as Dictionary).is_empty(), "没有落点（回到那个点时自动铺）")


static func run_spots_follow_nodes(t: TestCase) -> void:
	t.begin("128 · 每个节点一片地：离开时落点跟着东西留在那个点，回来还在原处；存档带着")
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var kit: Array[StringName] = []
	var run: RunState = null
	var entry := -1
	var next := -1
	for seed in range(1, 60):
		run = RunState.start(chapter, seed, items, enemies, sets, kit)
		if run == null:
			continue
		for e in run.map.entry_ids:
			for nid in run.map.neighbors(e):
				if run.map.get_node(nid).type in [&"rest", &"search", &"empty"]:
					entry = e
					next = nid
		if entry >= 0:
			break
	if entry < 0:
		t.check(false, "找不到种子")
		return
	run.pick_spawn(entry)
	run.storage.clear()
	var ration := ItemInstance.create(items.get_def(&"ration"))
	run.storage.insert(ration, -1, Vector2(0.3, 0.7))
	# 存档：身上这片地的落点
	var saved := RunState.from_dict(run.to_dict(), chapter, items, enemies, sets)
	t.check(saved != null and _near(saved.storage.spot_of(ration.uid), Vector2(0.3, 0.7)), "存档来回：地上的落点不变")
	var ns := NodeStorageModule.of(run)
	run.leaving.emit(entry)
	t.eq(run.storage.item_count(), 0, "离开：地上空了")
	t.check(_near(ns.spots[entry][ration.uid], Vector2(0.3, 0.7)), "落点留在了那个点上")
	var saved2 := RunState.from_dict(run.to_dict(), chapter, items, enemies, sets)
	var ns2 := NodeStorageModule.of(saved2)
	t.check(ns2 != null and _near((ns2.spots.get(entry, {}) as Dictionary).get(ration.uid, Vector2(-1, -1)), Vector2(0.3, 0.7)), "按点存放的落点跟存档")
	run.arrived.emit(entry, false)
	t.check(run.storage.has_item(ration.uid), "回来：东西回到地上")
	t.check(_near(run.storage.spot_of(ration.uid), Vector2(0.3, 0.7)), "回来：还在原处（%s）" % str(run.storage.spot_of(ration.uid)))


static func frame_push_out_of_panels(t: TestCase, root: Window) -> void:
	t.begin("128 · 放到面板上也算地上，但落点推到面板外最近的空处；面板后开的，压着的东西让开")
	ItemInstance.reset_uid_counter()
	var gun := _def(&"t_gun", ["#"])
	var stash := ItemStash.new(2, 0)
	var host := Control.new()
	host.size = SCREEN
	root.add_child(host)
	var ground := GroundLayer.new()
	ground.fills_screen = true
	ground.position = Vector2.ZERO
	ground.size = SCREEN
	ground.stash = stash
	host.add_child(ground)
	var panel := Control.new()
	panel.position = Vector2(600, 300)
	panel.size = Vector2(400, 300)
	host.add_child(panel)
	ground.reserve(panel)
	var a := ItemInstance.create(gun)
	var spot := ground.spot_for_drop(Vector2(620, 420), a, 0)
	var px := spot * SCREEN
	t.check(not Rect2(panel.position, panel.size).intersects(Rect2(px, Vector2.ONE * InventoryView.CELL)), "落点推到面板外（%s）" % str(px))
	t.check(absf(px.x - (600 - InventoryView.CELL - GroundLayer.PUSH_GAP)) < 1.0 and absf(px.y - 420) < 1.0, "推到最近的那一边（左边）")
	# 先放在那儿，再开一块面板压上去：settle 推开
	stash.insert(a, -1, Vector2(1220, 120) / SCREEN)
	var panel2 := Control.new()
	panel2.position = Vector2(1200, 100)
	panel2.size = Vector2(200, 100)
	host.add_child(panel2)
	ground.reserve(panel2)
	ground.settle()
	t.check(not Rect2(panel2.position, panel2.size).intersects(ground.item_rect(a.uid)), "压着的东西让开了（%s）" % str(ground.item_rect(a.uid)))
	panel2.free()
	t.eq(ground.reserved_rects().size(), 1, "面板关了：自动撤销")
	t.eq(ground.uid_at_local(Vector2(5, 5)), -1, "空地上点不到东西（点击穿给下面的屏）")
	t.check(not ground._has_point(Vector2(5, 5)), "铺满屏的那层：空地不接鼠标")
	host.free()


static func frame_director_ground(t: TestCase, root: Window) -> void:
	t.begin("128 · 导演持有唯一一层地：在点上的各屏都画同一片地、盖在屏栈上；背包面板接上它，双击地上的东西进棋盘")
	var items := ItemDatabase.new()
	items.load_dir()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	var ground: GroundLayer = game.ground
	t.not_null(ground, "导演有一层地")
	t.check(GroundLayer.current() == ground, "各屏找得到它")
	t.check(not ground.visible, "主菜单：不画")
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	for inst in flow.meta.warehouse.items().duplicate():
		setup.carry_in((inst as ItemInstance).uid)
	t.check(setup.depart(), "出发")
	var map = game.base()
	var run: RunState = flow.run
	map.pick_spawn(run.map.entry_ids[0])
	t.check(ground.visible and ground.stash == run.storage, "地图上：画的是这一局身上的地")
	t.eq(game.get_child(game.get_child_count() - 1), ground, "地盖在屏栈上面")
	var ration := ItemInstance.create(items.get_def(&"ration"))
	run.storage.insert(ration, -1, Vector2(0.05, 0.8))
	map.toggle_bag()
	var panel: Node = null
	var stack: Array[Node] = [map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() == preload("res://ui/game/inventory_panel.gd"):
			panel = n
			break
		stack.append_array(n.get_children())
	t.not_null(panel, "背包面板开了")
	if panel != null:
		t.check(panel.ground == ground, "背包面板接上了导演那层地")
		var room: bool = run.board.free_cell_count() > 0
		ground.item_double_clicked.emit(ground, ration.uid)
		if room:
			t.check(run.board.has_item(ration.uid) and not run.storage.has_item(ration.uid), "双击地上的口粮：进了棋盘")
	map.toggle_bag()
	game.queue_free()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
