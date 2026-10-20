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
	GameFlow.Screen.EVENT: "res://ui/game/event_screen.gd",     # 196：营地事件换 [constant CAMP_SCRIPT]（[method script_for]）
	GameFlow.Screen.RESULT: "res://ui/game/result_screen.gd",
	GameFlow.Screen.META: "res://ui/game/meta_screen.gd",
	GameFlow.Screen.SETTINGS: "res://ui/game/settings_screen.gd",
	GameFlow.Screen.PREBATTLE: "res://ui/game/prebattle_screen.gd",
	GameFlow.Screen.SLOTS: "res://ui/game/slots_screen.gd",
	GameFlow.Screen.SAFE: "res://ui/game/safe_screen.gd",
	GameFlow.Screen.ALTAR: "res://ui/game/altar_screen.gd",
	GameFlow.Screen.ENCYCLOPEDIA: "res://ui/game/encyclopedia_screen.gd",
	GameFlow.Screen.CHEST: "res://ui/game/chest_screen.gd",     # 154：宝箱（叠层；不画地上 —— 开锁时只看箱子）
	GameFlow.Screen.FORGE: "res://ui/game/forge_screen.gd",     # 175：铸炉（叠层）
}
## 196：`scene = rest_camp` 的事件（休息点）演成夜晚营地
const CAMP_SCRIPT := "res://ui/game/rest_camp_screen.gd"
const LAUNCHER := "res://ui/launcher.tscn"
## 157：换屏淡入 —— 叠层、底屏各多久（设置里 [member GameSettings.ui_fades] 能关）
const OVERLAY_FADE := 0.15
## 作者 2026-10-13（点开节点后地图的悬浮窗浮在打开的界面上面）：层高跟着屏走 —— 叠层整屏比底屏高这么多，
## 屏里的悬浮窗（[HoverTip] 60）、拖拽残影（50）都是相对自己那一屏的；地上画在最上面那一屏 + [constant GROUND_Z] 。
## 于是地图的悬浮窗高于地图和地上、低于叠层；叠层里的悬浮窗高于叠层本身
const OVERLAY_Z := 100
const GROUND_Z := 40
const BASE_FADE := 0.2
## 157：测试与截图工具关掉淡入（几百个屏幕用例的时序不变、截图不截到半透明）；正式游戏看设置
static var fades_allowed := true

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
## 128：地上 —— 一个节点一层，导演持有唯一一份，盖在整个屏栈上面（只有道具本身接鼠标，各屏的面板登记了地方、东西会让开）
var ground: GroundLayer = null
## 地上在这些屏里画（一局里、在某个点上的界面）；战斗回放、结算、局外都不画
const GROUND_SCREENS := [
	GameFlow.Screen.MAP, GameFlow.Screen.LOOT, GameFlow.Screen.SEARCH, GameFlow.Screen.SHOP, GameFlow.Screen.EVENT,
	GameFlow.Screen.REST, GameFlow.Screen.PREBATTLE, GameFlow.Screen.SAFE, GameFlow.Screen.ALTAR, GameFlow.Screen.FORGE,
]


func _ready() -> void:
	_font = UiPalette.cjk_font()
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var rules := GameFlow.load_meta_rules()
	var techs := GameFlow.load_techs()     # 120：读档先按科技算仓库容量，再装仓库
	var meta := MetaSave.read(items, meta_path, rules, techs)
	if meta == null:
		meta = MetaState.new(rules)
	flow = GameFlow.new(items, enemies, sets, meta)
	flow.meta_rules = rules
	flow.buff_defs = RunBuffs.load_all()
	flow.event_defs = EventPlacer.load_all()
	flow.chapters = GameFlow.load_chapters()
	flow.loadouts = GameFlow.load_loadouts()
	flow.characters = GameFlow.load_characters()
	flow.difficulties = GameFlow.load_difficulties()
	flow.hunter_defs = HunterSystem.load_all()
	flow.faith_defs = FaithDef.load_all()
	flow.recipes = RecipeDef.load_all()
	flow.achievement_defs = GameFlow.load_achievements()     # 091
	flow.tech_defs = techs     # 110
	flow.help_pages = GameFlow.load_help_pages()     # 114：百科
	# 校准记录（073）：正式游戏每走一步记一份玩家配置到 user://calibration/，木桩工具吃它
	flow.recorder = CalibrationRecorder.new()
	flow.save_path = save_path
	flow.meta_path = meta_path
	flow.settings_path = settings_path
	flow.settings = GameSettings.load_from(settings_path)
	UiText.apply(flow.settings)
	AudioHub.apply(flow.settings)     # 204：音效 / 音乐音量
	UiPalette.apply(flow.settings)     # 091：背景底色
	InputKeys.apply(flow.settings)     # 154 补充一：改过的键盖到默认上
	UiTheme.install()     # 121：界面主题挂在窗口上
	UiCursor.apply(flow.settings.cursor_skin)     # 157：美术给的光标（设置里选的那套材质；没图用系统的）
	InventoryView.apply_grid_setting(flow.settings)     # 187：棋盘格线
	if WindowSetup.apply(flow.settings, get_window()):     # 172：窗口模式与分辨率；第一次启动按屏幕挑了档就存下
		flow.save_settings()
	ground = GroundLayer.new()
	ground.fills_screen = true
	ground.label_font = _font
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.visible = false
	add_child(ground)
	GroundLayer.set_current(ground)
	ground.item_double_clicked.connect(_on_ground_double)     # 134
	# 089：存档位 —— 用默认路径（正式游戏）时按位存：老的单文件存档先搬进第 1 位，再切到设置里记的那一位。
	# 测试 / 演示改了路径的走单文件模式
	if save_path == RunSave.DEFAULT_PATH and meta_path == MetaSave.DEFAULT_PATH:
		flow.slots = SaveSlots.new()
		flow.slots.migrate_legacy()
		flow.use_slot(flow.settings.save_slot)
	# 没有角色定义时的兜底基线（角色路上基线来自 CharacterDef，067）
	flow.player_baseline = CombatantBaseline.with_hp(60.0)
	flow.screen_changed.connect(_on_screen_changed)
	flow.run_changed.connect(_on_run_changed)     # 101 第 5 刀：只属于一局的 UI 接线（信仰探针）
	flow.derive_techs()     # 110 / 120：新档也按进度表推算科技派生值
	flow.check_achievements()     # 091：读档后补算（老存档、新加的成就）
	flow.apply_item_locks()
	flow.to_main_menu()


## 现在显示的底屏 / 叠层（测试看）
func base() -> GameScreen:
	return _base


func overlay() -> GameScreen:
	return _overlay


## 096：道具悬浮窗按局里的信仰状态给信仰加成上色（生效白 / 没生效灰）；回了主菜单（`null`）摘掉探针。
##
## 101 第 5 刀：接线在这边 —— [GameFlow] 只发 [signal GameFlow.run_changed] 并提供 [method GameFlow.faith_status]，不认识 ui
func _on_run_changed(state: RunState) -> void:
	ItemTooltip.faith_probe = Callable() if state == null else flow.faith_status


func _on_screen_changed(screen: int, payload: Dictionary) -> void:
	# 128：先把地接到这一局的 storage 上（各屏开面板时要找它），换完屏再决定画不画、挪到最上面
	ground.stash = flow.run.storage if flow.run != null else null
	_switch_screen(screen, payload)
	_sync_ground()


## 128：地上画不画（最上面那一屏是一局里某个点上的界面才画），并保持在屏栈之上
func _sync_ground() -> void:
	var top := _overlay if _overlay != null else _base
	ground.visible = flow.run != null and not flow.run.is_over() and top != null and GROUND_SCREENS.has(top.screen)     # 218：撤出来之后的收尾事件屏不画
	move_child(ground, -1)
	ground.z_index = (top.z_index if top != null else 0) + GROUND_Z
	if _overlay != null and _base != null:
		for tip in _base.find_children("*", "HoverTip", true, false):
			(tip as HoverTip).hide_tip()     # 底屏被盖住了：它的悬浮窗收起来
	if ground.visible:
		ground.settle.call_deferred()


## 134（作者定）：地上的一件被双击了。有面板接地上（容器屏、战前、开着的背包浮窗……）就是它的事；
## 没有就转给最上面那一屏：地图 / 事件屏「进包 + 打开背包」（放不下只开背包），没有背包按钮的屏不接
func _on_ground_double(_view: ContainerView, uid: int) -> void:
	if ground.top_drag() != null:
		return
	var top := _overlay if _overlay != null else _base
	if top != null:
		top.ground_double_clicked(uid)


func _exit_tree() -> void:
	if GroundLayer.current() == ground:
		GroundLayer.set_current(null)


func _switch_screen(screen: int, payload: Dictionary) -> void:
	if GameFlow.is_overlay(screen):
		_ensure_map_base()
		_drop_overlay(true)     # 204：叠层换叠层只响「开」
		AudioHub.play(&"ui.open")
		if bool(payload.get("restore", false)) and _minimized != null and _minimized.screen == screen:
			# 084：恢复最小化的那一屏，不重造
			_overlay = _minimized
			_minimized = null
			_overlay.visible = true
			_overlay.process_mode = Node.PROCESS_MODE_INHERIT
			return
		_drop_minimized()
		_overlay = _make(screen, payload)
		_overlay.z_index = OVERLAY_Z
		add_child(_overlay)
		_overlay.open(payload)
		_fade_in(_overlay, OVERLAY_FADE)     # 157：撤叠层直接撤，不等
		return
	if bool(payload.get("minimized", false)) and _overlay != null:
		# 084：收起 = 最小化：藏起来、停掉它的计时（揭示动画不在背后偷跑），流程与会话都还在
		_drop_minimized()
		_minimized = _overlay
		_overlay = null
		AudioHub.play(&"ui.close")
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
	_base = _make(screen, payload)
	add_child(_base)
	_base.open(payload)
	if not payload.has("reveal"):
		_fade_in(_base, BASE_FADE)     # 180：入局转场自己从第三页接过来，不再叠一层淡入
	if _base.has_signal("dev_tools_requested"):
		_base.connect("dev_tools_requested", _to_launcher)


## 作者 10-20：一局里的叠层底下得是地图。读档回来直接落在点上（搜索、事件……）时，底屏还是主菜单 / 读取存档屏 ——
## 先把底屏换成地图，再叠上去（不淡入：叠层自己会淡入）
func _ensure_map_base() -> void:
	if flow.run == null or (_base != null and _base.screen == GameFlow.Screen.MAP):
		return
	if _base != null:
		_base.queue_free()
		_base = null
	_base = _make(GameFlow.Screen.MAP, {})
	add_child(_base)
	_base.open({})


## 157：新上来的一屏从透明淡到不透明（墨水扫过那种 shader 等美术方案）。关着就什么也不造；返回造的那个 Tween（测试看）
func _fade_in(s: Control, seconds: float) -> Tween:
	if not fades_allowed or flow.settings == null or not flow.settings.ui_fades:
		return null
	s.modulate.a = 0.0
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 1.0, seconds)
	return tw


## [param silent]：不响「关」（204：马上又要开一个叠层）
func _drop_overlay(silent: bool = false) -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		if not silent:
			AudioHub.play(&"ui.close")


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
	if key == null or not key.pressed or key.echo:
		return
	if key.is_action_pressed(InputKeys.TOGGLE_FULLSCREEN):     # 172：F11（可改键）切窗口 / 全屏，记进设置
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE and escape():
		get_viewport().set_input_as_handled()


## 172：窗口 ↔ 全屏，当场套用并存盘；开着的设置屏跟着刷新
func toggle_fullscreen() -> void:
	WindowSetup.toggle_mode(flow.settings)
	WindowSetup.apply(flow.settings, get_window())
	flow.save_settings()
	get_tree().call_group(DISPLAY_GROUP, "refresh_display")     # 设置屏开着（独立一屏或嵌在暂停菜单里）就跟着刷新


## 172：开着的设置屏挂在这一组里（F11 切了模式要刷新它的「显示」一节）
const DISPLAY_GROUP := &"display_settings"


## 按一次 Esc 该做的事；返回有没有人接（测试直接调）
func escape() -> bool:
	if _overlay != null:
		return _overlay.escape()
	return _base != null and _base.escape()


## 196：这一屏用哪个脚本 —— 事件屏看事件的 [member EventDef.scene]（营地歇完、两份用完的那一屏载荷带 `camp`）
static func script_for(screen: int, payload: Dictionary = {}) -> String:
	if screen == GameFlow.Screen.EVENT:
		var def = payload.get("def", payload.get("camp", null))
		if def is EventDef and (def as EventDef).scene == EventDef.SCENE_REST_CAMP:
			return CAMP_SCRIPT
	return String(SCREEN_SCRIPTS[screen])


func _make(screen: int, payload: Dictionary = {}) -> GameScreen:
	var script := load(script_for(screen, payload)) as GDScript
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
