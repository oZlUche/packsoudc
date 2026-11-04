## 277 第 1 条：确认键（Enter / 空格）按每屏的主按钮 —— 战前 = 开战；回放 = 先跳到结尾、再按继续；事件屏数字键选项
extends RefCounted

const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "confirm277"


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


static func frame_confirm_through_battle(t: TestCase, root: Window) -> void:
	t.begin("277 · 确认键：战前 Enter = 开战；回放 Enter 先跳到结尾、再按 = 继续")
	var c := GF._content()
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是战斗点的种子")
		return
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.settings.ui_fades = false     # 不演开战过场
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(c.chapter, kit, int(found["seed"]), [] as Array[int], null)
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	t.check(not map.confirm_key(false), "地图不接确认键（空格照旧回正镜头）")
	map.step(int(found["next"]))
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备")
	game._shortcut_input(_key(KEY_ENTER))
	var screen = game.overlay()
	t.check(screen != null and screen.screen == GameFlow.Screen.BATTLE, "Enter：开战了")
	if screen == null or screen.screen != GameFlow.Screen.BATTLE:
		game.queue_free()
		Support.cleanup(PREFIX)
		return
	var view: BattleView = screen.view()
	if view.is_held():
		view.release()
	var was := view.is_playing()
	t.check(screen.confirm_key(true), "空格接住")
	t.check(view.is_playing() != was, "空格：播 / 停切了一下")
	t.check(screen.confirm_key(false), "Enter 接住")
	t.check(screen._seen_end, "Enter：没看完先跳到结尾")
	t.eq(game.overlay(), screen, "还在回放屏（不一下按过头）")
	screen.confirm_key(false)
	t.check(game.overlay() != screen, "再按 Enter：继续，离开回放屏")
	game.queue_free()
	Support.cleanup(PREFIX)
