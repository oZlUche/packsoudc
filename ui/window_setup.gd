## 172（作者定：「给游戏设计固定分辨率大小，市面主流的几种，可以在主菜单的设置和 esc 菜单设置里面调整」）：
## 窗口尺寸与窗口 / 全屏。设计视口仍是 1600×1000、`canvas_items + expand`，换档只换**窗口**大小，界面按高度等比缩放；
## 窗口不可拖改（`project.godot` 的 `resizable = false`）。设置里只存模式与档位（[member GameSettings.window_mode] /
## [member GameSettings.resolution]），哪档能选、怎么套到窗口上在这里。headless（测试、导入）不碰窗口
class_name WindowSetup
extends RefCounted

const WINDOWED := "windowed"
## 无边框铺满桌面（`Window.MODE_FULLSCREEN`），不用独占全屏：Alt-Tab 不黑屏（待定 4 A）
const FULLSCREEN := "fullscreen"
const MODES := GameSettings.WINDOW_MODES
## 市面主流的两种宽高比，组内从小到大；超宽屏不列专档（待定 1 A）。表在设置层（读档校验要用）
const PRESETS := GameSettings.RESOLUTIONS
## 首次启动挑档：宽高都不超过屏幕的这一成（留出标题栏与任务栏）
const DEFAULT_FIT := 0.9
## 量不到屏幕（headless）时当成这么大 —— 设置屏照样列全部档位
const FALLBACK_SCREEN := Vector2i(3840, 2160)


## 套到窗口上；返回设置有没有被补上（第一次启动按屏幕挑了一档 —— 调用方存盘）
static func apply(settings: GameSettings, window: Window) -> bool:
	if settings == null or window == null or DisplayServer.get_name() == "headless":
		return false
	var filled := false
	var screen := screen_size(window)
	if settings.resolution == Vector2i.ZERO:
		settings.resolution = pick_default(screen)
		filled = true
	if settings.window_mode == FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
		return filled
	window.mode = Window.MODE_WINDOWED
	window.unresizable = true
	# 存的那档比现在的屏幕大（换了显示器）：这次按屏幕挑，不改设置
	var size := settings.resolution if fits(settings.resolution, screen) else pick_default(screen)
	window.size = size
	window.position = DisplayServer.screen_get_position(window.current_screen) + (screen - size) / 2
	return filled


## 窗口 ↔ 全屏（F11、设置屏都走这里）；切回窗口时用上次选的档
static func toggle_mode(settings: GameSettings) -> void:
	settings.window_mode = WINDOWED if settings.window_mode == FULLSCREEN else FULLSCREEN


## 窗口所在屏的尺寸；量不到（headless）用 [constant FALLBACK_SCREEN]
static func screen_size(window: Window = null) -> Vector2i:
	var s := DisplayServer.screen_get_size(window.current_screen if window != null else DisplayServer.SCREEN_OF_MAIN_WINDOW)
	return s if s.x > 0 and s.y > 0 else FALLBACK_SCREEN


## 这一档放得进屏幕吗（宽高都不超）
static func fits(preset: Vector2i, screen: Vector2i) -> bool:
	return preset.x > 0 and preset.y > 0 and preset.x <= screen.x and preset.y <= screen.y


## 设置屏列出的档位：放得进屏幕的那些，顺序同 [constant PRESETS]
static func available(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in PRESETS:
		if fits(p, screen):
			out.append(p)
	return out


## 首次启动的默认档：宽高都 ≤ 屏幕九成里面积最大的那档；九成里一档都放不下（1366×768 这类小屏）就放宽到整屏再挑；
## 整屏也放不下（屏幕比 1280×720 还小）就用屏幕本身
static func pick_default(screen: Vector2i) -> Vector2i:
	var best := _largest_within(Vector2i(int(screen.x * DEFAULT_FIT), int(screen.y * DEFAULT_FIT)))
	if best == Vector2i.ZERO:
		best = _largest_within(screen)
	return best if best != Vector2i.ZERO else screen


static func _largest_within(room: Vector2i) -> Vector2i:
	var best := Vector2i.ZERO
	for p in PRESETS:
		if fits(p, room) and p.x * p.y > best.x * best.y:
			best = p
	return best


## 「16:9」/「16:10」（设置屏的行首小字）
static func aspect_name(p: Vector2i) -> String:
	if p.x * 9 == p.y * 16:
		return "16:9"
	if p.x * 10 == p.y * 16:
		return "16:10"
	return "%d:%d" % [p.x, p.y]


## 按钮上的字：「1920×1080」（分辨率是行业写法，照写阿拉伯数字）
static func label(p: Vector2i) -> String:
	return "%d×%d" % [p.x, p.y]
