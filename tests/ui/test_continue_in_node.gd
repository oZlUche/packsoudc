## 作者 2026-10-20：读档回来直接落在点上（战前准备、搜索……）时，叠层底下是地图，不是主菜单
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_continue_lands_on_map_base(t: TestCase, root: Window) -> void:
	t.begin("作者 10-20 · 停在点上存的档，主菜单「继续」回来：叠层照旧，底屏是局内地图")
	var c := NodeScreens._content()
	var kit := NodeScreens._kit(c)
	var found := NodeScreens._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = NodeScreens.SAVE
	game.meta_path = NodeScreens.META
	game.settings_path = NodeScreens.SETTINGS
	Support.cleanup("084")
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(c.chapter, kit, int(found["seed"]))
	var map = game.base()
	if map.rules_open():
		map.close_rules()
	map.pick_spawn(int(found["entry"]))
	t.check(map.step(int(found["next"])), "走上战斗点")
	t.check(game.overlay() != null and game.overlay().screen == GameFlow.Screen.PREBATTLE, "停在战前准备")
	t.check(flow.save(), "存档")
	flow.to_main_menu()
	t.eq(game.base().screen, GameFlow.Screen.MAIN_MENU, "回了主菜单")
	t.check(flow.continue_run(), "继续")
	t.check(game.overlay() != null and game.overlay().screen == GameFlow.Screen.PREBATTLE, "读回来还停在战前准备")
	t.eq(game.base().screen, GameFlow.Screen.MAP, "底下换成了局内地图，不是主菜单")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup("084")


static func frame_briefing_after_finished_run(t: TestCase, root: Window) -> void:
	t.begin("测试报告 10-21 第 1 条 · 打完一局后「再来一局」，开局屏上弹交代时 flow.run 还是上一局：开局屏不被换成地图，「知道了」之后真出发")
	Support.cleanup("setup1021")
	var p := Support.paths("setup1021")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	setup.show_page(2)
	setup.pick_spawn(setup.preview().entry_ids()[0])
	var stale := RunState.new()     # 上一局（打完了还没清掉）
	flow.run = stale
	t.check(setup.next_page(), "出发")
	var brief = game.overlay()
	t.check(brief != null and brief.screen == GameFlow.Screen.EVENT and brief.is_briefing(), "先弹交代")
	t.eq(game.base(), setup, "开局屏还在底下，没被换成地图")
	if brief != null and brief.screen == GameFlow.Screen.EVENT:
		t.check(brief.choose(0), "知道了")
	t.eq(game.base().screen, GameFlow.Screen.MAP, "真出发了：进了地图")
	t.check(flow.run != null and flow.run != stale and flow.run.phase == RunState.Phase.ON_MAP, "是新开的一局")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup("setup1021")


static func run_first_launch_no_profile(t: TestCase) -> void:
	t.begin("测试报告 10-21 第 3 条 · 第一次启动（存档位模式）：回主菜单不把空的第 1 位落地，「继续」「读取存档」不出现")
	var root := "user://test_first1021_slots"
	var slots := SaveSlots.new(root)
	for n in range(1, SaveSlots.COUNT + 1):
		slots.remove(n)
	var flow := GameFlow.new()
	flow.slots = slots
	flow.use_slot(1)
	flow.to_main_menu()
	t.check(not slots.exists(1), "第 1 位没落地")
	t.check(not slots.any(), "哪一位都没有")
	t.check(not flow.profile_exists(), "主菜单不出「继续」")
	flow.meta.funds += 5     # 真有东西要存的时候照样存
	t.check(flow.save_meta(), "save_meta 照常能写")
	flow.to_main_menu()
	t.check(slots.exists(1), "落地之后回主菜单照存")
	for n in range(1, SaveSlots.COUNT + 1):
		slots.remove(n)
