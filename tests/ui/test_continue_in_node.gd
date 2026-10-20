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
