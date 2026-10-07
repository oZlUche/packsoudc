## 134（作者定）：东西落到地上有个落地动画（只是样子）；地上的东西双击直接进包并打开背包，放不下就只开背包
extends RefCounted

const G := preload("res://tests/inventory/test_ground.gd")
const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_ground_landing_run.json"
const META := "user://test_ground_landing_meta.json"
const SETTINGS := "user://test_ground_landing_settings.json"


static func _ground(stash: ItemStash) -> GroundLayer:
	var ground := GroundLayer.new()
	ground.fills_screen = true
	ground.size = G.SCREEN
	ground.stash = stash
	ground._sync_norms()
	return ground


static func run_new_items_land(t: TestCase) -> void:
	t.begin("134 · 新落地的那件播落地动画、播完删掉；换一片地 / 本来就在的不播；起点不进存档；一串落下错开")
	ItemInstance.reset_uid_counter()
	var gun := G._def(&"t_gun", ["#"])
	var stash := ItemStash.new(2, 0)
	var old := ItemInstance.create(gun)
	stash.insert(old, -1, Vector2(0.5, 0.5))
	var ground := _ground(stash)
	t.check(ground.landing_uids().is_empty(), "接上一片地：已经在的不播")
	var a := ItemInstance.create(gun)
	stash.insert(a, -1, Vector2(0.2, 0.3))
	ground._scan()
	t.check(ground.is_landing(a.uid), "新来的那件在落")
	t.check(not ground.is_landing(old.uid), "原来就在的不播")
	var target := ground.item_rect(a.uid).position
	var start := ground.landing_pose(a.uid)
	t.check((start["pos"] as Vector2).distance_to(target - Vector2(0, GroundLayer.LAND_DROP)) < 0.01, "没起点、没面板：从落点上方 %.0f 像素落下" % GroundLayer.LAND_DROP)
	t.check(absf(float(start["scale"]) - GroundLayer.LAND_SCALE) < 0.001 and absf(float(start["alpha"]) - GroundLayer.LAND_ALPHA) < 0.001, "起手放大、半透明")
	t.eq(ground.uid_at_local(target + Vector2.ONE * 10), -1, "半空中的不接鼠标")
	ground.advance_landing(GroundLayer.LAND_SEC * 0.5)
	var mid := ground.landing_pose(a.uid)
	t.check((mid["pos"] as Vector2).y > (start["pos"] as Vector2).y and (mid["pos"] as Vector2).y <= target.y + 0.01, "半程：往下落了、还没过落点")
	ground.advance_landing(GroundLayer.LAND_SEC)
	t.check(not ground.is_landing(a.uid), "播完删掉（%.2f 秒）" % GroundLayer.LAND_SEC)
	t.eq(ground.uid_at_local(target + Vector2.ONE * 10), a.uid, "落稳了能抓")
	var pose := ground.landing_pose(a.uid)
	t.check((pose["pos"] as Vector2) == target and float(pose["scale"]) == 1.0, "落稳：在落点、原大小")

	# 起点：就地（拖拽放手）不位移；给了全局像素从那里落；false 不播
	var b := ItemInstance.create(gun)
	stash.insert(b, -1, Vector2(0.6, 0.6))
	stash.landing_from[b.uid] = true
	var c := ItemInstance.create(gun)
	stash.insert(c, -1, Vector2(0.7, 0.2))
	stash.landing_from[c.uid] = Vector2(100, 200)
	var d := ItemInstance.create(gun)
	stash.insert(d, -1, Vector2(0.1, 0.1))
	stash.landing_from[d.uid] = false
	t.check(not stash.to_dict().has("landing_from") and not JSON.stringify(stash.to_dict()).contains("landing"), "起点不进存档")
	ground._scan()
	t.check((ground.landing_pose(b.uid)["pos"] as Vector2) == ground.item_rect(b.uid).position, "就地落下：不位移，只缩放 + 弹跳")
	t.check(ground.is_landing(c.uid) and (ground.landing_pose(c.uid)["pos"] as Vector2) == Vector2(100, 200), "给了起点：从那里落过来")
	t.check(not ground.is_landing(d.uid), "标了本来就在：不播")
	t.check(stash.landing_from.is_empty(), "起点读完即删")
	t.check(ground.landing_pose(c.uid)["hidden"], "同一拍落下的第二件排在后面（错开 %.2f 秒）" % GroundLayer.LAND_STAGGER)
	ground.advance_landing(GroundLayer.LAND_SEC + 1.0)
	t.check(ground.landing_uids().is_empty(), "全部落稳")

	# 弹跳：最后四分之一高过落点再落回
	var e := ItemInstance.create(gun)
	stash.insert(e, -1, Vector2(0.4, 0.8))
	stash.landing_from[e.uid] = true
	ground._scan()
	ground.advance_landing(GroundLayer.LAND_SEC * 0.875)
	t.check((ground.landing_pose(e.uid)["pos"] as Vector2).y < ground.item_rect(e.uid).position.y - 1.0, "末尾弹起一下")

	# 换一片地：基线，不播
	var other := ItemStash.new(3, 0)
	other.insert(ItemInstance.create(gun), -1, Vector2(0.3, 0.3))
	ground.stash = other
	ground._scan()
	t.check(ground.landing_uids().is_empty(), "换一片地（回到另一个点）：不播")
	ground.free()


static func run_drag_writes_origin(t: TestCase) -> void:
	t.begin("134 · 拖出棋盘放到地上：就地落下（不位移）；取消拖拽放回地上原处：不播")
	ItemInstance.reset_uid_counter()
	var gun := G._def(&"t_gun", ["#"])
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var stash := ItemStash.new(2, 0)
	var rig := G._rig(stash, board)
	var ground: GroundLayer = rig["ground"]
	var view: InventoryView = rig["view"]
	var drag: DragLayer = rig["drag"]
	var a := ItemInstance.create(gun)
	board.place(a, Vector2i(0, 0), 0)
	view.grab_requested.emit(view, a.uid, Vector2(24, 24))
	var release := Vector2(0.3, 0.7) * G.SCREEN + Vector2(0.5, 0.5) * InventoryView.CELL
	drag.update_preview(release)
	t.check(drag.drop_at(release), "放到地上")
	t.eq(stash.landing_from.get(a.uid, null), true, "拖拽层记下：就地落下")
	ground._scan()
	t.check(ground.is_landing(a.uid), "播落地")
	t.eq(ground.landing_pose(a.uid)["pos"], ground.item_rect(a.uid).position, "起点就是落点")
	ground.advance_landing(1.0)
	# 从地上拿起、取消：放回原处不算落地
	ground.grab_requested.emit(ground, a.uid, ground.item_rect(a.uid).position + Vector2.ONE * 10)
	t.check(drag.is_dragging(), "从地上拿起")
	ground._scan()
	drag.cancel()
	t.check(stash.has_item(a.uid), "取消：回到地上")
	ground._scan()
	t.check(not ground.is_landing(a.uid), "放回原处：不播")
	G._free(rig)


static func frame_landing_from_panel_edge(t: TestCase, root: Window) -> void:
	t.begin("134 · 程序放到地上的（战利品放不下之类）：从离落点最近的面板边缘落出来")
	ItemInstance.reset_uid_counter()
	var gun := G._def(&"t_gun", ["#"])
	var stash := ItemStash.new(2, 0)
	var host := Control.new()
	host.size = G.SCREEN
	root.add_child(host)
	var ground := GroundLayer.new()
	ground.fills_screen = true
	ground.size = G.SCREEN
	ground.stash = stash
	host.add_child(ground)
	var panel := Control.new()
	panel.position = Vector2(600, 300)
	panel.size = Vector2(400, 300)
	host.add_child(panel)
	ground.reserve(panel)
	var a := ItemInstance.create(gun)
	stash.insert(a, -1, Vector2(1100, 400) / G.SCREEN)
	ground._scan()
	var start: Vector2 = ground.landing_pose(a.uid)["pos"]
	var center := start + Vector2.ONE * InventoryView.CELL * 0.5
	t.check(absf(center.x - 1000.0) < 0.5, "从面板右边（最近那条边）出来：起点中心 x = %.1f" % center.x)
	t.check(center.y >= 300.0 and center.y <= 600.0, "高度在面板范围里（%.1f）" % center.y)
	host.free()


static func _find_panel(from: Node) -> Node:
	var stack: Array[Node] = [from]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() == preload("res://ui/game/inventory_panel.gd"):
			return n
		stack.append_array(n.get_children())
	return null


static func frame_double_click_opens_bag(t: TestCase, root: Window) -> void:
	t.begin("134 · 地图上没开背包：双击地上的东西 → 进包并打开背包；放不下 → 只开背包、面板提示；背包开着时地图不抢")
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
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.check(setup.depart(), "出发")
	var map = game.base()
	var run: RunState = flow.run
	map.pick_spawn(run.map.entry_ids[0])
	if map._rules != null:
		map.close_rules()     # 开局的本图规则卡（091）
	t.check(not map.bag_open(), "背包没开")
	var ration := ItemInstance.create(items.get_def(&"ration"))
	run.storage.insert(ration, -1, Vector2(0.05, 0.85))
	var room: bool = run.board.free_cell_count() > 0
	ground.item_double_clicked.emit(ground, ration.uid)
	t.check(map.bag_open(), "双击：背包打开了")
	if room:
		t.check(run.board.has_item(ration.uid) and not run.storage.has_item(ration.uid), "放得下：进了包")
	# 背包开着：交给背包面板（地图不再开关背包）
	var panel := _find_panel(map)
	t.not_null(panel, "背包面板在")
	var r2 := ItemInstance.create(items.get_def(&"ration"))
	run.storage.insert(r2, -1, Vector2(0.1, 0.85))
	ground.item_double_clicked.emit(ground, r2.uid)
	t.check(map.bag_open(), "背包开着时双击：背包还开着（面板接，地图不抢）")
	map.toggle_bag()
	# 放不下：一件比棋盘还大的东西
	var huge := G._def(&"t_huge", ["##########", "##########", "##########", "##########", "##########", "##########", "##########", "##########", "##########", "##########"])
	var big := ItemInstance.create(huge)
	run.storage.insert(big, -1, Vector2(0.2, 0.85))
	ground.item_double_clicked.emit(ground, big.uid)
	t.check(map.bag_open(), "放不下：背包照样打开")
	t.check(run.storage.has_item(big.uid) and not run.board.has_item(big.uid), "东西还在地上")
	var p2 := _find_panel(map)
	t.check(p2 != null and String(p2._hint.text).contains("背包里没有空间"), "面板里提示放不下：%s" % (p2._hint.text if p2 != null else ""))
	map.toggle_bag()
	# 没有背包按钮的屏不接（默认钩子）
	var plain := GameScreen.new()
	t.check(not plain.ground_double_clicked(big.uid), "没有背包的屏：不接")
	plain.free()
	game.queue_free()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
