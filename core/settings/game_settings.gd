## 玩家的设置：怎么看、怎么玩的偏好，不是玩到哪（进度在 [MetaState]）。跨局、跨存档位。
##
## 加设置项就是加字段；存 `user://settings.json`，带版本号，读不到就用默认值（没有设置文件不是错）。
## 109（作者定）：原来的「离开点时地上提醒档位」随提示一起删了 —— 旧文件里的那几个键 `from_dict` 不读，不用升版本
class_name GameSettings
extends RefCounted

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://settings.json"

## 109：战斗回放能选的倍速（[BattleView] 的切速按钮在这几档里转）
const BATTLE_SPEEDS: Array[float] = [1.0, 2.0, 4.0]

## 084（作者定）：拿走战利品 / 容器里最后一件之后要不要自动关那一屏。默认不关，手动关
var loot_auto_close: bool = false
## 084：节点浮窗预览 —— 不管章节开没开（`ChapterDef.node_tooltips`，第二章才开）都显示。给作者与开发期看效果用，默认关
var node_tooltips_preview: bool = false
## 085：界面语言 "zh" / "en"。主菜单点一下切，[UiText] 跟着读；不认识的值回落中文
var language: String = "zh"
## 089：当前用的存档位（1～3）
var save_slot: int = 1
## 091（作者定 10.2 第 4 条）：老手的「全部解锁」—— 章节 / 难度 / 道具不看解锁；代价是成就不计
var unlock_all: bool = false
## 091（作者定）：背景底色的 id。
##
## 101 第 5 刀：设置层只管「是个非空字符串」—— **哪些 id 存在是界面的事**（`UiPalette.BG_THEMES`），
## 认不出来的 id 由界面兜底成它的默认底色（`UiPalette.apply` / `UiPalette.bg`）。空串 = 用界面的默认
var bg_theme: String = ""
## 109（作者定）：战斗倍速跨局继承 —— 在战斗里切一次，下一场（下一局、重开游戏）照这个速度开场。只认 [constant BATTLE_SPEEDS] 里的值
var battle_speed: float = 1.0
## 117（作者定）：战斗的内部日志与回放存档（user://battle_logs）。非导出包默认开、导出包默认关（[method BattleArchive.default_on]）
var battle_trace: bool = BattleArchive.default_on()
## 150 补 2（作者定）：调试模式 —— 开着时地图屏摆出只给开发看的组件（事件日志等，布局里 `debug_only` 的那几件）。
## 现在默认开；发布版把这里的默认改成关（一处改）
var debug_mode: bool = DEBUG_MODE_DEFAULT
const DEBUG_MODE_DEFAULT := true
## 154 补充一：改过的键 —— 动作名 → 键码数组（文件里也可以写键名，如 "Enter"）。空 = 全用 `project.godot` 的默认。
## 设置层只存；哪些动作能改、怎么盖到 InputMap 上是界面的事
var key_bindings: Dictionary = {}
## 157：换屏淡入（叠层 0.15 秒、底屏 0.2 秒）。设置屏一个开关
var ui_fades: bool = true
## 157 补：光标材质 "mithril" / "iron" / "leather"（铠甲手套三套，作者定秘银默认）。设置层只存非空字符串，认不认得由界面管
var cursor_skin: String = "mithril"
## 反馈：地图缩放全局沿用 —— 玩家上次滚轮定下的缩放，下次进图（任何一张）照用；0 = 没定过，进图自动按点距定。F 键看全图时清回 0
var map_zoom: float = 0.0
## 172：窗口模式 "windowed" / "fullscreen"（认不出的回窗口）；首次启动默认窗口（待定 3 A）
var window_mode: String = "windowed"
## 172：窗口分辨率，[constant RESOLUTIONS] 里的一档；ZERO = 没定过，启动时按屏幕挑（界面层套到窗口上）
var resolution: Vector2i = Vector2i.ZERO

## 172：认得的窗口模式；全屏 = 无边框铺满桌面（待定 4 A）
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen"]
## 172：分辨率档位 —— 市面主流的 16:9 五档、16:10 三档，组内从小到大；超宽屏不列专档（待定 1 A）。
## 表放设置层（读档要校验），哪档放得进屏幕、怎么套到窗口归界面层
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
	Vector2i(1280, 800), Vector2i(1920, 1200), Vector2i(2560, 1600),
]


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"loot_auto_close": loot_auto_close,
		"node_tooltips_preview": node_tooltips_preview,
		"language": language,
		"save_slot": save_slot,
		"unlock_all": unlock_all,
		"bg_theme": bg_theme,
		"battle_speed": battle_speed,
		"battle_trace": battle_trace,
		"debug_mode": debug_mode,
		"key_bindings": key_bindings.duplicate(true),
		"ui_fades": ui_fades,
		"cursor_skin": cursor_skin,
		"map_zoom": map_zoom,
		"window_mode": window_mode,
		"resolution": [resolution.x, resolution.y],
	}


static func from_dict(d: Dictionary) -> GameSettings:
	var s := GameSettings.new()
	if int(d.get("version", -1)) != SAVE_VERSION:
		return s
	s.loot_auto_close = bool(d.get("loot_auto_close", false))
	s.node_tooltips_preview = bool(d.get("node_tooltips_preview", false))
	var lang := String(d.get("language", "zh"))
	s.language = lang if UiText.LANGS.has(lang) else "zh"
	s.save_slot = clampi(int(d.get("save_slot", 1)), 1, SaveSlots.COUNT)
	s.unlock_all = bool(d.get("unlock_all", false))
	s.bg_theme = String(d.get("bg_theme", ""))     # 认不认得由界面管（101 第 5 刀）
	s.battle_speed = normalize_speed(float(d.get("battle_speed", 1.0)))
	s.battle_trace = bool(d.get("battle_trace", BattleArchive.default_on()))
	s.debug_mode = bool(d.get("debug_mode", DEBUG_MODE_DEFAULT))
	s.key_bindings = read_bindings(d.get("key_bindings", {}))
	s.ui_fades = bool(d.get("ui_fades", true))
	var skin := String(d.get("cursor_skin", "mithril"))
	s.cursor_skin = skin if skin != "" else "mithril"
	s.map_zoom = normalize_zoom(float(d.get("map_zoom", 0.0)))
	var mode := String(d.get("window_mode", "windowed"))
	s.window_mode = mode if WINDOW_MODES.has(mode) else "windowed"
	s.resolution = normalize_resolution(d.get("resolution", []))
	return s


## 172：文件里的 `[宽, 高]` → 档位；不是两个数、不在 [constant RESOLUTIONS] 里的回 ZERO（启动时重挑）
static func normalize_resolution(raw: Variant) -> Vector2i:
	if not (raw is Array) or (raw as Array).size() != 2:
		return Vector2i.ZERO
	var r := Vector2i(int(raw[0]), int(raw[1]))
	return r if RESOLUTIONS.has(r) else Vector2i.ZERO


## 地图缩放：非正数 = 没定过（0）；其余夹到 0.3～2.5（和地图视图的上下限一致）
static func normalize_zoom(z: float) -> float:
	return 0.0 if not (z > 0.0) else clampf(z, 0.3, 2.5)


## 154 补充一：读改键表 —— 不是字典、动作名空、键表不是数组的都扔掉；键名换成键码，认不出来的键扔掉，一个都不剩的动作扔掉
static func read_bindings(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for action in raw:
		var keys = (raw as Dictionary)[action]
		if String(action) == "" or not (keys is Array):
			continue
		var codes: Array[int] = []
		for k in keys:
			var code := keycode_of(k)
			if code > 0 and not codes.has(code):
				codes.append(code)
		if not codes.is_empty():
			out[String(action)] = codes
	return out


## 设置文件里的一个键：键码数字，或键名（`"Enter"`、`"Space"`、`"F"`）。认不出来返回 0
static func keycode_of(v: Variant) -> int:
	if v is int or v is float:
		return int(v)
	if v is String:
		return int(OS.find_keycode_from_string(String(v)))
	return 0


## 109：不在 [constant BATTLE_SPEEDS] 里的倍速（旧文件、手改过的怪数）回 1×，别让回放被拖成 0× 或 3×
static func normalize_speed(v: float) -> float:
	for sp in BATTLE_SPEEDS:
		if is_equal_approx(v, sp):
			return sp
	return 1.0


## 读设置；没有文件、文件坏了、版本不对都返回默认值
## 173：读不出来先试上一份（`.prev`），再不行用默认
static func load_from(path: String = DEFAULT_PATH) -> GameSettings:
	for p in [path, AtomicFile.prev_path(path)]:
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary:
				return from_dict(parsed)
	return GameSettings.new()


## 173：原子写（[AtomicFile]）
func save_to(path: String = DEFAULT_PATH) -> Error:
	return AtomicFile.write(path, JSON.stringify(to_dict(), "  ", false) + "\n")


static func remove(path: String = DEFAULT_PATH) -> void:
	AtomicFile.remove(path)


## 作者 2026-10-17（内部文字不给玩家看）：是不是开发环境 —— 正式导出包（release / debug 模板）都不是。
## 开发入口、调参读数只在这里显示；不用 `OS.is_debug_build()`（debug 导出包里它也是真）
static func dev_build() -> bool:
	return not OS.has_feature("template")
