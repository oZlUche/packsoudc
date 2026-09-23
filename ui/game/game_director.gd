## 场景流的导演（架构文档 8 节，M6）：`ui/game/game.tscn` 的根，正式游戏的入口。
##
## 它持有 [GameFlow]（纯逻辑的状态机）与内容库，听 [signal GameFlow.screen_changed] 换屏。
## **屏的切换用 add_child / queue_free 手动管，不用 change_scene_to_file**：战斗回放、战利品、搜索、商店、事件、休息
## 都是叠在地图上的一层，地图和镜头都留着；底屏（主菜单、开局、地图、结算、局外）才互相替换。
##
## 不是 autoload：核心逻辑层没有全局状态（1 节），一局的状态在 flow.run 里，导演只是一个场景的根。
## 开发期的启动选择器（launcher）与 F1 返回（DevNav）照旧可用。
class_name GameDirector
extends Control

const SCREEN_SCRIPTS := {
	GameFlow.Screen.MAIN_MENU: "res://ui/game/main_menu.gd",
	GameFlow.Screen.SETUP: "res://ui/game/setup_screen.gd",
	GameFlow.Screen.MAP: "res://ui/game/map_screen.gd",
	GameFlow.Screen.BATTLE: "res://ui/game/battle_screen.gd",
	GameFlow.Screen.LOOT: "res://ui/game/container_screen.gd",
	GameFlow.Screen.SEARCH: "res://ui/game/container_screen.gd",
	GameFlow.Screen.SHOP: "res://ui/game/shop_screen.gd",
	GameFlow.Screen.EVENT: "res://ui/game/event_screen.gd",
	GameFlow.Screen.REST: "res://ui/game/rest_screen.gd",
	GameFlow.Screen.RESULT: "res://ui/game/result_screen.gd",
	GameFlow.Screen.META: "res://ui/game/meta_screen.gd",
	GameFlow.Screen.SETTINGS: "res://ui/game/settings_screen.gd",
}
const LAUNCHER := "res://ui/launcher.tscn"

## 存档路径。测试在加进树之前改它，别碰玩家真正的存档
var save_path: String = RunSave.DEFAULT_PATH
var meta_path: String = MetaSave.DEFAULT_PATH
var settings_path: String = GameSettings.DEFAULT_PATH

var flow: GameFlow = null
var _font: Font
var _base: GameScreen = null
var _overlay: GameScreen = null


func _ready() -> void:
	_font = UiPalette.cjk_font()
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var rules := GameFlow.load_meta_rules()
	var meta := MetaSave.read(items, meta_path, rules)
	if meta == null:
		meta = MetaState.new(rules)
	flow = GameFlow.new(items, enemies, sets, meta)
	flow.meta_rules = rules
	flow.buff_defs = GameFlow.load_run_buffs()
	flow.event_defs = GameFlow.load_events()
	flow.chapters = GameFlow.load_chapters()
	flow.loadouts = GameFlow.load_loadouts()
	flow.save_path = save_path
	flow.meta_path = meta_path
	flow.settings_path = settings_path
	flow.settings = GameSettings.load_from(settings_path)
	# 占位：与沙盒一致的玩家基线，等角色系统
	flow.player_baseline = CombatantBaseline.with_hp(60.0)
	flow.screen_changed.connect(_on_screen_changed)
	flow.to_main_menu()


## 现在显示的底屏 / 叠层（测试看）
func base() -> GameScreen:
	return _base


func overlay() -> GameScreen:
	return _overlay


func _on_screen_changed(screen: int, payload: Dictionary) -> void:
	if GameFlow.is_overlay(screen):
		_drop_overlay()
		_overlay = _make(screen)
		add_child(_overlay)
		_overlay.open(payload)
		return
	_drop_overlay()
	if _base != null and _base.screen == screen:
		_base.refresh()
		return
	if _base != null:
		_base.queue_free()
		_base = null
	_base = _make(screen)
	add_child(_base)
	_base.open(payload)
	if _base.has_signal("dev_tools_requested"):
		_base.connect("dev_tools_requested", _to_launcher)


func _drop_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _make(screen: int) -> GameScreen:
	var script := load(String(SCREEN_SCRIPTS[screen])) as GDScript
	var s: GameScreen = script.new()
	s.screen = screen
	s.flow = flow
	s.font = _font
	return s


func _to_launcher() -> void:
	if get_tree().change_scene_to_file(LAUNCHER) != OK:
		push_error("GameDirector: 回不去启动选择器")


## 截图工具的钩子（tools/capture_scene.gd）：环境变量 DEMO_SCREEN = setup / map / bag / battle / loot / search / result / meta，
## 把流程推到那一屏，好让截图里有东西可看。不设就停在主菜单
func demo_fill() -> void:
	var want := OS.get_environment("DEMO_SCREEN")
	if want == "" or flow.chapters.is_empty():
		return
	# 演示不碰玩家真正的存档
	flow.save_path = "user://demo_run.json"
	flow.meta_path = "user://demo_meta.json"
	if want == "setup":
		# 先撤离一局攒个仓库，开局屏才有东西可带
		var warm := flow.begin(flow.chapters[0], flow.loadouts[0] if not flow.loadouts.is_empty() else null, 1)
		if warm != null:
			warm.phase = RunState.Phase.EXTRACTED
			warm.end_reason = &"extract"
			flow.resume()
			flow.finish_result()
		flow.new_run()
		var setup := _base
		if setup != null and flow.meta.warehouse.item_count() > 0:
			setup.call("toggle_warehouse", (flow.meta.warehouse.items()[0] as ItemInstance).uid)
		return
	flow.new_run()
	var next_type: StringName = &"search" if want in ["search", "event"] else &"battle"
	var found := {}
	for seed in range(1, 60):
		var state := RunState.start(flow.chapters[0], seed, flow.items, flow.enemies, flow.sets)
		if state == null:
			continue
		for entry in state.map.entry_ids:
			for nid in state.map.neighbors(entry):
				if state.map.get_node(nid).type == next_type:
					found = {"seed": seed, "entry": entry, "next": nid}
					break
			if not found.is_empty():
				break
		if not found.is_empty():
			break
	if found.is_empty():
		return
	var run := flow.begin(flow.chapters[0], flow.loadouts[0] if not flow.loadouts.is_empty() else null, int(found["seed"]))
	if run == null:
		return
	flow.pick_spawn(int(found["entry"]))
	if want == "map":
		return
	if want == "bag":
		_base.call("toggle_bag")
		return
	if want == "confirm":
		_demo_walk_to_extract(run)
		_base.call("extract")
		return
	flow.step_to(int(found["next"]))
	if want == "battle":
		return
	if want == "event":
		return
	if want == "search":
		if _overlay != null and _overlay.screen == GameFlow.Screen.EVENT:
			_overlay.call("choose", 0)     # 搜索点的事件：「搜索」
		if _overlay != null and _overlay.screen == GameFlow.Screen.SEARCH:
			_overlay.call("search")
			_overlay.call("skip_reveal")
		return
	if want == "loot":
		if flow.screen == GameFlow.Screen.BATTLE:
			flow.resume()
		return
	_demo_settle()
	run.phase = RunState.Phase.EXTRACTED
	run.end_reason = &"extract"
	flow.resume()
	if want == "result":
		return
	flow.finish_result()


## 演示：把叠层都看完（战利品全拿、会话离开）
func _demo_settle() -> void:
	var guard := 0
	while GameFlow.is_overlay(flow.screen) and guard < 30:
		guard += 1
		match flow.screen:
			GameFlow.Screen.LOOT:
				flow.take_all_loot()
			GameFlow.Screen.SEARCH:
				flow.run.events.current_search.leave()
			GameFlow.Screen.SHOP:
				flow.run.events.current_shop.leave()
			GameFlow.Screen.EVENT:
				if flow.run.events.pending_event() != null:
					flow.choose_event(_first_open_option())
				else:
					flow.resume()
			_:
				flow.resume()


func _first_open_option() -> int:
	var def := flow.run.events.pending_event()
	for i in def.options.size():
		if bool(flow.run.events.option_state(i)["ok"]):
			return i
	return 0


## 演示：一路走到最近的免费撤离点
func _demo_walk_to_extract(run: RunState) -> void:
	var from := run.travel.current_id
	var dist := MapNavigator.distance_map(run.map, from)
	var target := -1
	var best := 999
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if n.type == &"extract" and PaidExtracts.fee_of(n) == 0 and dist.has(id) and int(dist[id]) < best:
			best = int(dist[id])
			target = id
	if target < 0:
		return
	var to_target := MapNavigator.distance_map(run.map, target)
	var guard := 0
	while run.travel.current_id != target and not run.is_over() and guard < 60:
		guard += 1
		var next := -1
		for id in run.travel.available_moves():
			if to_target.has(id) and (next < 0 or int(to_target[id]) < int(to_target[next])):
				next = id
		if next < 0 or not flow.step_to(next):
			return
		_demo_settle()
