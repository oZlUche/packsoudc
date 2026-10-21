## 地上按点清空（3.4 / 058 第 3 条）：走出发生过事的点，地上的东西留在那里；出生点、只是路过的点不清；
## 提醒按设置档位；设置存读。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
## 与 Support.paths("storage") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_storage_run.json"
const META := "user://test_storage_meta.json"
const SETTINGS := "user://test_storage_settings.json"
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["loadouts"])


## 出生点旁边就有某类型点的种子：{seed, entry, next}
static func _seed_with(c: TestSupport.Content, type: StringName, kit: Array[StringName]) -> Dictionary:
	for seed in range(1, 80):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit)
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == type:
					return {"seed": seed, "entry": entry, "next": nid}
	return {}


static func _settle(f: GameFlow) -> void:
	var guard := 0
	while GameFlow.is_overlay(f.screen) and guard < 30:
		guard += 1
		match f.screen:
			GameFlow.Screen.PREBATTLE:
				f.start_battle()
			GameFlow.Screen.LOOT:
				f.take_all_loot()
			GameFlow.Screen.SEARCH:
				f.run.events.current_search.leave()
			GameFlow.Screen.SHOP:
				f.run.events.current_shop.leave()
			_:
				f.resume()


static func _kit(c: TestSupport.Content) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == &"standard":
			return l
	return c.loadouts[0]


static func run_clear_on_leave(t: TestCase) -> void:
	t.begin("地上 · 只是节点内的临时区（作者 2026-09-24 改）：离开任何点都清、进入头一回踩上的点也清（在那个点的事之前）；空的不发信号；走不成不清；存档带着")

	var c := _content()
	var kit := _kit(c)
	var found := _seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := Support.flow(c, "storage")
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	var entry := int(found["entry"])
	var next := int(found["next"])
	f.pick_spawn(entry)
	var def := c.items.get_def(&"ration")
	run.storage.clear()
	t.check(not run.will_clear_storage(), "地上空：走了没什么可清")
	run.storage.admit(ItemInstance.create(def))
	t.check(run.will_clear_storage(), "出生点上没发生过事，地上有东西也清（不再看发没发生过事）")
	var ns := NodeStorageModule.of(run)     # 101：按点暂存是一局的模块
	t.not_null(ns, "默认清单里有按点暂存")
	var dropped: Array = []
	ns.dropped.connect(func(id: int, items: Array): dropped.append([id, items.size()]))

	t.check(f.step_to(next), "走上战斗点")
	t.eq(run.storage.item_count(), 0, "离开出生点：清了")
	t.check(dropped.size() >= 1 and int(dropped[0][0]) == entry and int(dropped[0][1]) == 1, "发了 storage_dropped，点是离开的那个、件数对（%s）" % str(dropped))
	var n_leave := dropped.size()
	_settle(f)
	t.eq(run.events.last_handled_id, next, "战斗点是「发生过事的点」")
	t.eq(dropped.size(), n_leave, "进入时地上是空的：不再发信号")
	# 打完之后地上可能有战利品：走之前不收进棋盘就没了
	run.storage.clear()
	run.storage.admit(ItemInstance.create(def))
	t.check(run.will_clear_storage(), "地上有东西：走了会留在这里")
	var restored: Array = []
	ns.restored.connect(func(id: int, items: Array): restored.append([id, items.size()]))
	t.check(f.step_to(entry), "走回出生点")
	_settle(f)
	t.eq(ns.stored_at(next).size(), 1, "087：离开战斗点，那件留在了战斗点上")
	t.eq(run.storage.item_count(), 1, "087：回到出生点，先前留在这儿的口粮回到了地上")
	t.check(restored.size() == 1 and int(restored[0][0]) == entry, "发了 storage_restored")
	t.eq(run.events.last_handled_id, -1, "离开之后不再算发生过事的点")

	# 穿行：用过的点上放东西，走一步就留在那里；回到有东西的点又拿回来
	run.storage.admit(ItemInstance.create(def))
	t.check(f.step_to(next), "穿行到用过的战斗点")
	t.eq(run.storage.item_count(), 1, "087：出生点的两件留在出生点，战斗点留的那件回到地上")
	t.eq(ns.stored_at(entry).size(), 2, "出生点上留着两件")
	# 反馈：悬停看每个点的地上 —— 留在出生点的 2 件、站着的这个点身上地上的 1 件，各看各的
	var tip_entry := NodeTooltip.stash_text(run, run.map.get_node(entry))
	t.check(tip_entry.contains("2 件") and tip_entry.contains(Names.of(def)), "出生点浮窗：留着 2 件（%s）" % tip_entry)
	var tip_here := NodeTooltip.stash_text(run, run.map.get_node(next))
	t.check(tip_here.contains("1 件"), "站着的点：身上地上的 1 件（%s）" % tip_here)
	run.storage.clear()
	t.eq(NodeTooltip.stash_text(run, run.map.get_node(next)), "", "空了：没有这一行")
	run.storage.admit(ItemInstance.create(def))
	# 存档带着各点留的东西
	var save_back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(save_back != null and NodeStorageModule.of(save_back).stored_at(entry).size() == 2, "按点存着的东西跟存档（modules.node_storage）")
	run.storage.clear()

	# 走不成不清
	run.storage.admit(ItemInstance.create(def))
	t.check(not f.step_to(99999), "走不到的走不了")
	t.eq(run.storage.item_count(), 1, "走不成不清")

	# 进入头一回踩上的点：地上的东西照样在（087：不再进入时清），那个点的事照常发生
	run.storage.clear()
	var fresh_id := -1
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if not n.is_visited() and n.type == &"rest":
			fresh_id = id
			break
	if fresh_id >= 0:
		run.storage.admit(ItemInstance.create(def))
		var before_vit := run.vitality.current
		run.vitality.spend(1, &"test")
		dropped.clear()
		run.travel.on_node_event.call(run.map.get_node(fresh_id))
		t.eq(run.storage.item_count(), 1, "进入头一回踩上的点：地上的东西还在（087）")
		t.check(dropped.is_empty(), "进入不发 storage_dropped")
		t.check(run.events.pending_event() != null or run.vitality.current >= before_vit, "那个点的事照常发生（休息点：先过事件屏或回体力）")
		run.events.pending = {}
	else:
		t.check(true, "这张图没有没用过的休息点，跳过进入检查的用例")
	run.storage.clear()

	# 存档带着「发生过事的点」：走到另一个没用过的点，存、读，读回来的也知道走了要清
	var fresh := -1
	for id in run.travel.available_moves():
		var n := run.map.get_node(id)
		if not n.is_visited() and n.type in [&"battle", &"search", &"shop", &"rest", &"event"]:
			fresh = id
			break
	if fresh >= 0:
		t.check(f.step_to(fresh), "走到一个没用过的点 %d" % fresh)
		_settle(f)
		if run.storage.item_count() == 0:
			run.storage.admit(ItemInstance.create(def))
		var before := run.will_clear_storage()
		t.check(before, "在发生过事的点上、地上有东西")
		t.eq(RunSave.write(run, SAVE), OK, "存")
		var back := RunSave.read(c.items, c.enemies, c.sets, SAVE)
		t.not_null(back, "读回来")
		t.eq(back.events.last_handled_id, run.events.last_handled_id, "「发生过事的点」跟着存档")
		t.eq(back.will_clear_storage(), before, "读回来的也知道走了要清")
	Support.cleanup("storage")


static func run_left_behind_line(t: TestCase) -> void:
	t.begin("地上 · 离开时留下的那句日志（109：提醒档位删了，只留描述）")

	var c := _content()
	var items: Array = []
	for id in c.items.ids():
		var d := c.items.get_def(id)
		if not d.is_bag and items.size() < 3:
			items.append(ItemInstance.create(d))
	t.check(StorageWarning.describe(items).contains("%d 件" % items.size()), "一句话里有件数")
	t.check(StorageWarning.describe([]).begins_with("0 件"), "空的也能写")
	t.check(GameSettings.new().get("storage_warn_mode") == null, "提醒档位的设置字段删了")


static func run_settings_round_trip(t: TestCase) -> void:
	t.begin("设置 · 默认值、往返、坏值回默认、文件读写")

	var s := GameSettings.new()
	t.eq(s.battle_speed, 1.0, "倍速默认 1×")
	s.battle_speed = 4.0
	s.loot_auto_close = true
	var back := GameSettings.from_dict(s.to_dict())
	t.eq([back.battle_speed, back.loot_auto_close], [4.0, true], "往返")
	t.eq(GameSettings.from_dict({"version": 1, "battle_speed": 3.0}).battle_speed, 1.0, "不在表里的倍速回 1×")
	t.eq(GameSettings.from_dict({"version": 1, "battle_speed": 0.0}).battle_speed, 1.0, "0× 也回 1×")
	t.eq(GameSettings.from_dict({"version": 99, "battle_speed": 2.0}).battle_speed, 1.0, "版本不对回默认")
	t.eq(GameSettings.from_dict({"version": 1, "storage_warn_mode": "never", "battle_speed": 2.0}).battle_speed, 2.0,
		"旧文件里多出来的提醒档位键不碍事（不用升版本）")
	t.check(not s.to_dict().has("storage_warn_mode"), "提醒档位不再写进文件")
	GameSettings.remove(SETTINGS)
	t.eq(GameSettings.load_from(SETTINGS).battle_speed, 1.0, "没有文件就是默认")
	t.eq(s.save_to(SETTINGS), OK, "写文件")
	t.eq(GameSettings.load_from(SETTINGS).battle_speed, 4.0, "读回来")
	GameSettings.remove(SETTINGS)


static func frame_map_prompt(t: TestCase, root: Window) -> void:
	t.begin("地图屏 · 离开发生过事的点直接走，不再弹地上提示（109）")

	var c := _content()
	var kit := _kit(c)
	var found := _seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	Support.cleanup("storage")
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	# 083：这些测试要的是第一章（环形图）；序章通关才列它 —— 先把章节许诺的解锁都给上，再挑第一章
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	# 067：开局屏按角色开；把第一套（发进仓库的）全带上
	for inst in flow.meta.warehouse.items().duplicate():
		setup.carry_in((inst as ItemInstance).uid)
	setup.choose_scale(&"")     # 180：种子是按章节默认配置找的（开局屏默认第一档规模）
	setup.set_run_seed(int(found["seed"]))
	t.check(Support.depart(setup), "出发")
	var map = game.base()
	var run: RunState = flow.run
	map.pick_spawn(int(found["entry"]))
	t.check(map.step(int(found["next"])), "走上战斗点")
	var guard := 0
	while game.overlay() != null and guard < 10:
		guard += 1
		var ov = game.overlay()
		match ov.screen:
			GameFlow.Screen.PREBATTLE:
				ov.start_battle()
			GameFlow.Screen.LOOT:
				ov.take_all()
				ov.to_map()     # 084：拿完不自动关，手动关
			_:
				ov.proceed()
	if run.storage.item_count() == 0:
		run.storage.admit(ItemInstance.create(c.items.get_def(&"ration")))
	t.check(run.will_clear_storage(), "在战斗点上、地上有东西")
	var to: int = run.travel.available_moves()[0]
	t.check(map.step(to), "按走")
	t.eq(run.travel.current_id, to, "走了")
	t.eq(run.storage.item_count(), 0, "地上清了")
	guard = 0
	while game.overlay() != null and guard < 10:
		guard += 1
		var ov2 = game.overlay()
		match ov2.screen:
			GameFlow.Screen.PREBATTLE:
				ov2.start_battle()
			GameFlow.Screen.LOOT:
				ov2.take_all()
				ov2.to_map()     # 084：拿完不自动关，手动关
			GameFlow.Screen.SEARCH, GameFlow.Screen.SHOP:
				ov2.leave()
			_:
				ov2.proceed()
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup("storage")
