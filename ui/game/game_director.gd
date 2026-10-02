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
	GameFlow.Screen.PREBATTLE: "res://ui/game/prebattle_screen.gd",
	GameFlow.Screen.SLOTS: "res://ui/game/slots_screen.gd",
	GameFlow.Screen.SAFE: "res://ui/game/safe_screen.gd",
	GameFlow.Screen.ALTAR: "res://ui/game/altar_screen.gd",
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
## 084：最小化的叠层（作者定：收起不是关掉，是藏起来 —— 揭示进度、日志、拖到一半的状态都留着，「回到这个点」原样放回）
var _minimized: GameScreen = null


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
	flow.characters = GameFlow.load_characters()
	flow.difficulties = GameFlow.load_difficulties()
	flow.hunter_defs = GameFlow.load_hunters()
	flow.faith_defs = GameFlow.load_faiths()
	flow.recipes = GameFlow.load_recipes()
	flow.achievement_defs = GameFlow.load_achievements()     # 091
	# 校准记录（073）：正式游戏每走一步记一份玩家配置到 user://calibration/，木桩工具吃它
	flow.recorder = CalibrationRecorder.new()
	flow.save_path = save_path
	flow.meta_path = meta_path
	flow.settings_path = settings_path
	flow.settings = GameSettings.load_from(settings_path)
	UiText.apply(flow.settings)
	UiPalette.apply(flow.settings)     # 091：背景底色
	# 089：存档位 —— 用默认路径（正式游戏）时按位存：老的单文件存档先搬进第 1 位，再切到设置里记的那一位。
	# 测试 / 演示改了路径的走单文件模式
	if save_path == RunSave.DEFAULT_PATH and meta_path == MetaSave.DEFAULT_PATH:
		flow.slots = SaveSlots.new()
		flow.slots.migrate_legacy()
		flow.use_slot(flow.settings.save_slot)
	# 没有角色定义时的兜底基线（角色路上基线来自 CharacterDef，067）
	flow.player_baseline = CombatantBaseline.with_hp(60.0)
	flow.screen_changed.connect(_on_screen_changed)
	flow.check_achievements()     # 091：读档后补算（老存档、新加的成就）
	flow.apply_item_locks()
	flow.to_main_menu()


## 现在显示的底屏 / 叠层（测试看）
func base() -> GameScreen:
	return _base


func overlay() -> GameScreen:
	return _overlay


func _on_screen_changed(screen: int, payload: Dictionary) -> void:
	if GameFlow.is_overlay(screen):
		_drop_overlay()
		if bool(payload.get("restore", false)) and _minimized != null and _minimized.screen == screen:
			# 084：恢复最小化的那一屏，不重造
			_overlay = _minimized
			_minimized = null
			_overlay.visible = true
			_overlay.process_mode = Node.PROCESS_MODE_INHERIT
			return
		_drop_minimized()
		_overlay = _make(screen)
		add_child(_overlay)
		_overlay.open(payload)
		return
	if bool(payload.get("minimized", false)) and _overlay != null:
		# 084：收起 = 最小化：藏起来、停掉它的计时（揭示动画不在背后偷跑），流程与会话都还在
		_drop_minimized()
		_minimized = _overlay
		_overlay = null
		_minimized.visible = false
		_minimized.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_drop_overlay()
		_drop_minimized()     # 换了屏（走了一步、结算……）：藏着的那一屏也过期了
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


func _drop_minimized() -> void:
	if _minimized != null:
		_minimized.queue_free()
		_minimized = null


## 084：现在藏着的那一屏（测试看）；没有就 null
func minimized() -> GameScreen:
	return _minimized


## 090（作者定）：Esc 是通用「返回」—— 叠层在上面就问叠层（搜索 / 商店 / 战利品收起回地图，事件屏关背包……），
## 没叠层问底屏（地图关对话框 / 背包；开局、基地、设置、读取存档回主菜单）。谁都不接就不管（拖拽层自己先吃掉拖着时的 Esc）
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	if escape():
		get_viewport().set_input_as_handled()


## 按一次 Esc 该做的事；返回有没有人接（测试直接调）
func escape() -> bool:
	if _overlay != null:
		return _overlay.escape()
	return _base != null and _base.escape()


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


## 截图工具的钩子（tools/capture_scene.gd）：环境变量 `DEMO_SCREEN` 定把流程推到哪一屏。
## 101 第 6 刀：那段推流程的演示代码（200 行，造假难度、走到撤离点、把叠层看完）搬进了 `tools/demo_fill.gd` ——
## 它只在设了环境变量时才 `load`，所以正式游戏里一行都不跑，导演也不必带着它
func demo_fill() -> void:
	if OS.get_environment("DEMO_SCREEN") == "" or flow.chapters.is_empty():
		return
	var script: GDScript = load("res://tools/demo_fill.gd")
	if script == null:
		push_warning("GameDirector: 找不到 tools/demo_fill.gd")
		return
	script.new().fill(self, flow)
