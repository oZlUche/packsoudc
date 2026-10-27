## 134（作者定）：东西落到地上有个落地动画（只是样子）；地上的东西双击直接进包并打开背包，放不下就只开背包
extends RefCounted
const Support := preload("res://tests/run/flow_support.gd")

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
	var gun := G._def(&"t_gun", ["1"])
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
	t.eq(ground.uid_at_local(target + Vector2.ONE * 10), -1, "落点上还没东西（它在上方 %.0f 像素）" % GroundLayer.LAND_DROP)
	t.eq(ground.uid_at_local((start["pos"] as Vector2) + Vector2.ONE * InventoryView.CELL * 0.5), a.uid, "162：半空中的照样接鼠标（按此刻画在哪）")
	var sec := ground.landing_sec(a.uid)
	ground.advance_landing(sec * 0.5)
	var mid := ground.landing_pose(a.uid)
	t.check((mid["pos"] as Vector2).y > (start["pos"] as Vector2).y and (mid["pos"] as Vector2).y <= target.y + 0.01, "半程：往下落了、还没过落点")
	ground.advance_landing(sec)
	t.check(not ground.is_landing(a.uid), "播完删掉（%.2f 秒）" % sec)
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
	ground.advance_landing(5.0)
	t.check(ground.landing_uids().is_empty(), "全部落稳")

	# 弹跳：最后四分之一高过落点再落回
	var e := ItemInstance.create(gun)
	stash.insert(e, -1, Vector2(0.4, 0.8))
	stash.landing_from[e.uid] = true
	ground._scan()
	ground.advance_landing(ground.landing_sec(e.uid) * 0.875)
	t.check((ground.landing_pose(e.uid)["pos"] as Vector2).y < ground.item_rect(e.uid).position.y - 1.0, "末尾弹起一下")

	# 换一片地：基线，不播
	var other := ItemStash.new(3, 0)
	other.insert(ItemInstance.create(gun), -1, Vector2(0.3, 0.3))
	ground.stash = other
	ground._scan()
	t.check(ground.landing_uids().is_empty(), "换一片地（回到另一个点）：不播")
	ground.free()


static func run_gravity_profile(t: TestCase) -> void:
	t.begin("162 补充一 / 二 · 密度定末速度与弹：石以上「沉」（不封顶、按触地速度弹、不摆），其余「飘」（末速度封顶、包更慢、左右摆）；同一高度重的先触地")
	var bag := G._def(&"t_bag", ["11"])
	bag.is_bag = true
	var cloth := G._def(&"t_cloth", ["11"])
	var stone := G._def(&"t_stone", ["1"])
	stone.tags = [&"stone"] as Array[StringName]
	var metal := G._def(&"t_metal", ["11"])
	metal.tags = [&"metal"] as Array[StringName]
	t.check(not GroundLayer.land_profile(cloth)["sink"] and GroundLayer.land_profile(stone)["sink"] and GroundLayer.land_profile(metal)["sink"], "密度 ≥ %.0f 算沉（石起）" % GroundLayer.LAND_SINK_DENSITY)
	t.eq(float(GroundLayer.land_profile(cloth)["vmax"]), GroundLayer.LAND_VMAX, "飘的末速度 %.2f 屏高 / 秒" % GroundLayer.LAND_VMAX)
	t.eq(float(GroundLayer.land_profile(bag)["vmax"]), GroundLayer.LAND_VMAX_BAG, "包更慢")
	t.eq(GroundLayer.land_profile(metal)["vmax"], INF, "沉的不封顶")
	t.eq(float(GroundLayer.land_profile(bag)["sway"]), GroundLayer.LAND_SWAY_BAG, "包摆得最大")
	t.eq(float(GroundLayer.land_profile(metal)["sway"]), 0.0, "沉的不摆")

	ItemInstance.reset_uid_counter()
	var stash := ItemStash.new(2, 0)
	var ground := _ground(stash)
	var light := ItemInstance.create(cloth)
	stash.insert(light, -1, Vector2(0.2, 0.1))
	var hard := ItemInstance.create(metal)
	stash.insert(hard, -1, Vector2(0.6, 0.1))
	stash.landing_from[light.uid] = Vector2(300, 100)
	stash.landing_from[hard.uid] = Vector2(900, 100)
	ground._scan()
	ground.advance_landing(GroundLayer.LAND_STAGGER)     # 第二件出队，两件都在落
	t.check(ground.landing_sec(hard.uid) < ground.landing_sec(light.uid), "同一高度：金属先触地（%.2f 秒 < %.2f 秒）" % [ground.landing_sec(hard.uid), ground.landing_sec(light.uid)])
	var g := GroundLayer.LAND_G * G.SCREEN.y
	var last := -1.0
	var rising := true
	var a_hard: Dictionary = ground._landing[hard.uid]
	var a_light: Dictionary = ground._landing[light.uid]
	var capped := 0.0
	for i in 12:
		a_hard["t"] = float(a_hard["t_hit"]) * (i + 0.5) / 12.0
		var v := ground.landing_speed(hard.uid)
		rising = rising and v > last
		last = v
		a_light["t"] = float(a_light["t_hit"]) * (i + 0.5) / 12.0
		capped = maxf(capped, ground.landing_speed(light.uid))
	t.check(rising, "沉的越落越快（触地前速度一直涨到 %.0f 像素 / 秒）" % last)
	t.check(is_equal_approx(capped, GroundLayer.LAND_VMAX * G.SCREEN.y), "飘的封顶在末速度（%.0f 像素 / 秒）" % capped)
	t.check(is_equal_approx(float(a_hard["v_hit"]), sqrt(2.0 * g * ((a_hard["p1"] as Vector2).y - (a_hard["p0"] as Vector2).y))), "沉的触地速度 = √(2gh)")
	t.check(float(a_hard["amp"]) >= GroundLayer.LAND_IMPACT_MIN and float(a_hard["amp"]) <= GroundLayer.LAND_IMPACT_MAX, "沉的弹按触地速度（%.1f 像素，夹在 2 ～ 6）" % float(a_hard["amp"]))
	# 摆：落到四分之一（按落了几成）时飘的偏到一边，沉的不偏
	var quarter := func(a: Dictionary) -> void:
		for i in 400:
			a["t"] = float(a["t_hit"]) * i / 400.0
			if GroundLayer._fall_progress(a, float(a["t"])) >= 0.25:
				return
	quarter.call(a_light)
	quarter.call(a_hard)
	var dx_light := (ground.landing_pose(light.uid)["pivot"] as Vector2).x - (a_light["p0"] as Vector2).x
	var dx_hard := (ground.landing_pose(hard.uid)["pivot"] as Vector2).x - (a_hard["p0"] as Vector2).x
	t.check(absf(dx_light - GroundLayer.LAND_SWAY) < 0.2, "飘的落到四分之一摆到一边（%.1f 像素）" % dx_light)
	t.check(absf(dx_hard) < 0.01, "沉的不摆")
	a_hard["t"] = float(a_hard["t_hit"]) + GroundLayer.LAND_BOUNCE_SEC * 0.5
	t.check(((ground.landing_pose(hard.uid)["pivot"] as Vector2).y) < (a_hard["p1"] as Vector2).y - 1.0, "触地后弹起一下")
	ground.advance_landing(5.0)
	t.check(ground.landing_uids().is_empty(), "全部落稳")
	ground.free()


static func run_drag_writes_origin(t: TestCase) -> void:
	t.begin("162 补充二 · 拖出棋盘放到地上：从松手那一刻残影的位置竖直往下掉到屏幕底；取消拖拽放回地上原处：不播")
	ItemInstance.reset_uid_counter()
	var gun := G._def(&"t_gun", ["1"])
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
	var ghost := release - Vector2(0.5, 0.5) * InventoryView.CELL
	t.eq(stash.landing_from.get(a.uid, null), ghost, "拖拽层记下：起点 = 松手时残影的左上角（不是棋盘上原来那格）")
	ground._scan()
	t.check(ground.is_landing(a.uid), "播落地")
	t.eq(ground.landing_pose(a.uid)["pos"], ghost - ground.global_position, "从松手处起落")
	var r := ground.item_rect(a.uid)
	t.check(absf(r.position.x - ghost.x) < 0.01, "竖直落：x 不变")
	t.check(absf(r.end.y - G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN)) < 0.5, "落到屏幕底（%.1f）" % r.end.y)
	ground.advance_landing(5.0)
	# 从地上拿起、取消：放回原处不算落地
	ground.grab_requested.emit(ground, a.uid, ground.item_rect(a.uid).position + Vector2.ONE * 10)
	t.check(drag.is_dragging(), "从地上拿起")
	ground._scan()
	drag.cancel()
	t.check(stash.has_item(a.uid), "取消：回到地上")
	ground._scan()
	t.check(not ground.is_landing(a.uid), "放回原处：不播")
	G._free(rig)


static func run_click_then_double_click(t: TestCase) -> void:
	t.begin("反馈 · 地上一件单击一下（拿起、原地放下）之后紧跟的双击照样接得到：就地落下的不算半空")
	ItemInstance.reset_uid_counter()
	var gun := G._def(&"t_gun", ["1"])
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var stash := ItemStash.new(2, 0)
	var rig := G._rig(stash, board)
	var ground: GroundLayer = rig["ground"]
	var drag: DragLayer = rig["drag"]
	var a := ItemInstance.create(gun)
	stash.insert(a, -1, Vector2(0.4, 0.4))
	ground._scan()
	var at := ground.item_rect(a.uid).position + Vector2.ONE * InventoryView.CELL * 0.5
	# 双击的第一下：按下 = 拿起，松开 = 原地放下
	ground.grab_requested.emit(ground, a.uid, at)
	t.check(drag.is_dragging(), "第一下按下：拿起")
	ground._scan()
	t.check(drag.drop_at(ground.global_position + at), "第一下松开：放回地上")
	ground._scan()
	t.check(ground.is_landing(a.uid), "放回地上：就地落下（只缩放 + 弹跳）")
	t.eq(ground.uid_at_local(at), a.uid, "就地落下的那件照样接鼠标")
	var got: Array = []
	ground.item_double_clicked.connect(func(_v: ContainerView, uid: int): got.append(uid))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.double_click = true
	mb.position = at
	ground._gui_input(mb)
	t.eq(got, [a.uid], "第二下（双击）：发出双击，面板把它放进背包")
	G._free(rig)


static func frame_fall_onto_panels(t: TestCase, root: Window) -> void:
	t.begin("162 补充二 → 253 · 竖直掉到屏幕底（或别的东西顶上）：登记面板不再是桌面，掉过窗面；落在贴地面板底下的往两边推开；面板关了不再掉一次；没起点的从落点上方竖直落下")
	ItemInstance.reset_uid_counter()
	var gun := G._def(&"t_gun", ["1"])
	var stash := ItemStash.new(4, 0)
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
	var floor_y := G.SCREEN.y * (1.0 - ItemStash.SPOT_MARGIN)
	# 没起点：竖直落下
	var a := ItemInstance.create(gun)
	stash.insert(a, -1, Vector2(1100, 700) / G.SCREEN)
	ground._scan()
	var target := ground.item_rect(a.uid).position
	t.eq(ground.landing_pose(a.uid)["pos"], target - Vector2(0, GroundLayer.LAND_DROP), "没起点：从落点正上方 %.0f 像素落下" % GroundLayer.LAND_DROP)
	# 253：起点在面板正上方也竖直掉过窗面（面板不是桌面），落到屏幕底
	var b := ItemInstance.create(gun)
	stash.insert(b, -1, Vector2(0.1, 0.1))
	stash.landing_from[b.uid] = Vector2(700, 100)
	var c := ItemInstance.create(gun)
	stash.insert(c, -1, Vector2(0.1, 0.1))
	stash.landing_from[c.uid] = Vector2(100, 100)
	ground._scan()
	var rb := ground.item_rect(b.uid)
	t.check(absf(rb.position.x - 700.0) < 0.01 and absf(rb.end.y - floor_y) < 0.5, "253：面板正上方也掉过窗面、落到屏幕底（%s）" % rb)
	var rc := ground.item_rect(c.uid)
	t.check(absf(rc.position.x - 100.0) < 0.01 and absf(rc.end.y - floor_y) < 0.5, "旁边没面板：落到屏幕底（%s）" % rc)
	ground.advance_landing(5.0)
	ground.settle_bumps()
	panel.free()
	t.check(not ground.is_landing(b.uid) and not ground.is_landing(c.uid), "253：面板关了没有东西再掉一次")
	# 作者 10-27 两层：落点在一块贴地的面板底下 —— 照样落在原处的地上，盖在面板前面，不推开
	var low := Control.new()
	low.position = Vector2(1200, floor_y - 200)
	low.size = Vector2(300, 260)
	host.add_child(low)
	var d := ItemInstance.create(gun)
	stash.insert(d, -1, Vector2(0.1, 0.1))
	stash.landing_from[d.uid] = Vector2(1300, 100)
	ground._scan()
	ground.advance_landing(5.0)
	ground.settle_bumps()
	var rd := ground.item_rect(d.uid)
	t.check(absf(rd.position.x - 1300.0) < 0.5 and absf(rd.end.y - floor_y) < 0.5, "落在窗底下的原地落地、不推到窗侧（%s）" % rd)
	host.free()


static func run_rest_rotation(t: TestCase) -> void:
	t.begin("162 补充二 · 重心：占格中心的平均；落稳朝向 = 重心离底边最近的（长条躺平、L 长边朝下、T 横杠朝下、方块不转）")
	var bar := ItemShape.from_ascii(["1", "1", "1"])
	t.eq(bar.center_of_mass(0), Vector2(0.5, 1.5), "竖条的重心在正中")
	t.eq(bar.size_rotated(bar.rest_rotation(0)), Vector2i(3, 1), "竖条躺平")
	t.eq(bar.rest_rotation(1), 1, "已经躺平的不转")
	var ell := ItemShape.from_ascii(["1.", "1.", "11"])
	var r_ell := ell.rest_rotation(0)
	t.eq(ell.size_rotated(r_ell), Vector2i(3, 2), "L 长边横过来")
	var bottom_row := 0
	for cell in ell.cells_rotated(r_ell):
		if cell.y == 1:
			bottom_row += 1
	t.eq(bottom_row, 3, "长边在下")
	var tee := ItemShape.from_ascii(["111", ".1.", ".1."])
	var r_tee := tee.rest_rotation(0)
	var tee_bottom := 0
	for cell in tee.cells_rotated(r_tee):
		if cell.y == tee.size_rotated(r_tee).y - 1:
			tee_bottom += 1
	t.eq(tee_bottom, 3, "T 横杠朝下")
	var sq := ItemShape.from_ascii(["11", "11"])
	t.eq(sq.rest_rotation(2), 2, "方块不转")
	t.eq(ItemShape.from_ascii(["111"]).center_of_mass(0), Vector2(1.5, 0.5), "横条重心")


static func run_fall_turns_to_rest(t: TestCase) -> void:
	t.begin("162 补充二 · 竖着拖出去的长条：落点与朝向立刻是躺平的终态；途中绕重心转（越落转得越快），触地正好转到位；半空中照样能抓")
	ItemInstance.reset_uid_counter()
	var stick := G._def(&"t_stick", ["1", "1", "1"])
	var stash := ItemStash.new(2, 0)
	var ground := _ground(stash)
	var a := ItemInstance.create(stick)
	stash.insert(a, -1, Vector2(0.1, 0.1))
	stash.landing_from[a.uid] = Vector2(400, 100)
	ground._scan()
	t.eq(a.def.shape.size_rotated(a.rotation), Vector2i(3, 1), "朝向立刻是躺平的（存档里也是）")
	var r := ground.item_rect(a.uid)
	var com_x := 400.0 + 0.5 * InventoryView.CELL
	t.check(absf(r.get_center().x - com_x) < 0.01, "重心 x 不变（%.1f）" % r.get_center().x)
	var land: Dictionary = ground._landing[a.uid]
	t.eq(absf(float(land["turn"])), PI * 0.5, "转四分之一圈（走短的一边）")
	t.eq(ground.landing_pose(a.uid)["angle"], 0.0, "起手不转")
	land["t"] = float(land["t_hit"]) * 0.5
	var mid := ground.landing_pose(a.uid)
	var s := GroundLayer._fall_progress(land, float(land["t"]))
	t.check(absf(float(mid["angle"])) > 0.0 and absf(float(mid["angle"])) < absf(float(land["turn"])) * s, "半程：转了一点，比落了几成还少（缓入：%.2f 弧度）" % float(mid["angle"]))
	t.eq(ground.uid_at_local(mid["pivot"]), a.uid, "半空中按重心命中")
	t.eq(ground.grab_cell_at(a.uid, mid["pivot"]), Vector2i(1, 0), "抓在中间那格（换算到躺平的朝向）")
	land["t"] = float(land["t_hit"])
	t.check(is_equal_approx(float(ground.landing_pose(a.uid)["angle"]), float(land["turn"])), "触地：正好转到位")
	ground.advance_landing(5.0)
	var rest := ground.landing_pose(a.uid)
	t.check(rest["angle"] == 0.0 and int(rest["rot"]) == a.rotation and (rest["pos"] as Vector2) == r.position, "落稳：画的就是躺平的那个朝向")
	ground.free()


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
	t.check(Support.depart(setup), "出发")
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
	var huge := G._def(&"t_huge", ["1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111"])
	var big := ItemInstance.create(huge)
	run.storage.insert(big, -1, Vector2(0.2, 0.85))
	ground.item_double_clicked.emit(ground, big.uid)
	t.check(map.bag_open(), "放不下：背包照样打开")
	t.check(run.storage.has_item(big.uid) and not run.board.has_item(big.uid), "东西还在地上")
	var p2 := _find_panel(map)
	t.check(p2 != null and String(p2.last_hint).contains("背包里没有空间"), "提示放不下：%s" % (p2.last_hint if p2 != null else ""))
	t.check(map.notice_widget() == null or map.notice_widget().current_text().contains("背包里没有空间"), "188：地图屏走提示行")
	map.toggle_bag()
	# 没有背包按钮的屏不接（默认钩子）
	var plain := GameScreen.new()
	t.check(not plain.ground_double_clicked(big.uid), "没有背包的屏：不接")
	plain.free()
	game.queue_free()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
