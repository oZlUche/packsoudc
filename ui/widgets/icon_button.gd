## 166（作者定）：顶端栏里的图标按钮 —— 背包、放大镜、主动技能。
##
## 一张图标（`assets/ui/hud/icon_<id>.png`，[member icon_id]；缺图就写 [member fallback] 那几个字）+ 悬浮窗（名字、快捷键、一句说明）
## + 右上角可选的快捷键小字（B / N）+ 右下角可选的数字角标（技能还能用几次；-1 不画）。48 × 48，底与按下态走主题变体
## [constant UiTheme.BUTTON_ICON]，自己不挂主题覆盖。
##
## 167：另一种是**整颗按钮就是图**（[method make_art]：`<目录><id>.png` / `_hover` / `_pressed` 三态，战斗回放的符石键），
## 变体 [constant UiTheme.BUTTON_ART]（各态没有底），大小按图；缺图同样写字、走 BUTTON_ICON
class_name IconButton
extends Button

const SIZE := 48.0
const ICON_DIR := "res://assets/ui/hud/"
## 快捷键小字与角标的字号、角标圆的直径
const HINT_SIZE := 11
const BADGE := 18.0

## 图标文件名里的那段（`icon_<id>.png`）
var icon_id: String = ""
## 缺图时按钮上写的字
var fallback: String = ""
## 右上角的快捷键（空 = 不画）
var hotkey: String = ""
## 右下角的数字（-1 = 不画）
var badge: int = -1:
	set(v):
		badge = v
		queue_redraw()

var _tex: Texture2D = null
## 167：整图按钮的目录（空 = 普通图标按钮）与三态图（"" / "_hover" / "_pressed"）
var art_dir: String = ""
var _states: Dictionary = {}
var _hover := false
var _down := false
## 开战战旗：可点的只有旗面（按图里的像素，空 = 整张图都能点）
var hit_rect := Rect2()
## 图上不带字的整图按钮（铜面板「全部拾取」）：字由这里写 —— 字心在图里的位置、字号、颜色；空 = 不写
var art_label := ""
var art_label_center := Vector2.ZERO
var art_label_size := 16
var art_label_color := Color.WHITE
## 248：字摆进图里的一块（图的像素；有面积就居中在这块里、放不下逐号缩小，代替 [member art_label_center]）
var art_label_rect := Rect2()
## 按下时字往下挪几像素
var art_label_drop := 2.0
## 灰着时的字色（透明 = 跟平常一样）
var art_label_disabled_color := Color.TRANSPARENT
## 251 补充二：字的描边色（铁匠铺打造键：热铁上深红描边；透明 = 不描）
var art_label_outline := Color.TRANSPARENT
const ART_LABEL_OUTLINE := 4


## [param name] 写进悬浮窗第一行；[param hint] 是那一句说明
static func make(p_icon_id: String, p_fallback: String, name: String, hint: String, on_press: Callable, p_hotkey: String = "") -> IconButton:
	var b := IconButton.new()
	b.icon_id = p_icon_id
	b.fallback = p_fallback
	b.hotkey = p_hotkey
	b.tooltip_text = name + (UiText.t("ui.hotkey") % p_hotkey if p_hotkey != "" else "") + ("\n" + hint if hint != "" else "")
	if on_press.is_valid():
		b.pressed.connect(on_press)
	b._load()
	return b


## 167：整颗按钮就是图的那种（三态）；[method set_art] 换图（播放 → 暂停 → 重播、倍速档）
static func make_art(dir: String, p_icon_id: String, p_fallback: String, tooltip: String, on_press: Callable) -> IconButton:
	var b := IconButton.new()
	b.art_dir = dir
	if on_press.is_valid():
		b.pressed.connect(on_press)
	b.mouse_entered.connect(b._set_hover.bind(true))
	b.mouse_exited.connect(b._set_hover.bind(false))
	b.button_down.connect(b._set_down.bind(true))
	b.button_up.connect(b._set_down.bind(false))
	b.set_art(p_icon_id, p_fallback, tooltip)
	return b


## 换一套图（同一个按钮换状态）；缺图写 [param p_fallback]
func set_art(p_icon_id: String, p_fallback: String, tooltip: String) -> void:
	icon_id = p_icon_id
	fallback = p_fallback
	tooltip_text = tooltip
	_states.clear()
	for st in ["", "_hover", "_pressed", "_disabled"]:
		var path: String = art_dir + p_icon_id + st + ".png"
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			_states[st] = EventImage.load_texture(path)
	_tex = _states.get("", null)
	theme_type_variation = UiTheme.BUTTON_ART if _tex != null else UiTheme.BUTTON_ICON
	custom_minimum_size = _tex.get_size() if _tex != null else Vector2(SIZE, SIZE)
	text = "" if _tex != null else fallback
	_sync_state()


## 整图按钮现在该贴哪一态
func state() -> String:
	return "_pressed" if _down else ("_hover" if _hover else "")


func _set_hover(on: bool) -> void:
	_hover = on
	_sync_state()


func _set_down(on: bool) -> void:
	_down = on
	_sync_state()


func _sync_state() -> void:
	if _tex == null:
		icon = null
		return
	icon = _states.get("_disabled" if disabled and _states.has("_disabled") else state(), _tex)


## 改了 disabled 之后叫一下，换成那一态的图
func sync_art() -> void:
	_sync_state()


func _has_point(point: Vector2) -> bool:
	if not hit_rect.has_area():
		return Rect2(Vector2.ZERO, size).has_point(point)
	return hit_rect.has_point(point)


func _init() -> void:
	theme_type_variation = UiTheme.BUTTON_ICON
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_NONE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _load() -> void:
	var path := ICON_DIR + "icon_%s.png" % icon_id
	_tex = EventImage.load_texture(path) if icon_id != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)) else null
	icon = _tex
	text = "" if _tex != null else fallback


## 有没有图（测试看缺图退回文字）
func has_art() -> bool:
	return _tex != null


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var col := get_theme_color("font_color")
	if art_label != "" and _tex != null:
		var lf := UiPalette.cjk_font_bold()
		var fs := art_label_font_size()
		var ls := lf.get_string_size(art_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var center := art_label_rect.get_center() if art_label_rect.has_area() else art_label_center
		var at := center * (size / _tex.get_size()) + Vector2(-ls.x * 0.5, lf.get_ascent(fs) - ls.y * 0.5)
		if _down:
			at.y += art_label_drop
		var lc := art_label_disabled_color if disabled and art_label_disabled_color.a > 0.0 else art_label_color
		if art_label_outline.a > 0.0 and not disabled:
			draw_string_outline(lf, at.floor(), art_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ART_LABEL_OUTLINE, art_label_outline)
		draw_string(lf, at.floor(), art_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
	if hotkey != "":
		draw_string(font, Vector2(size.x - 12, HINT_SIZE + 1), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE, Color(col, 0.75))
	if badge >= 0:
		var c := size - Vector2(BADGE, BADGE) * 0.5
		draw_circle(c, BADGE * 0.5, UiPalette.BTN_PRIMARY)
		var t := str(badge)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE).x
		draw_string(font, c + Vector2(-w * 0.5, HINT_SIZE * 0.4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE, UiPalette.BTN_PRIMARY_TEXT)


## 248：图上那行字实际用几号 —— 有 [member art_label_rect] 时放不下就逐号缩（英文长，最小 10）
func art_label_font_size() -> int:
	var fs := art_label_size
	if not art_label_rect.has_area():
		return fs
	var lf := UiPalette.cjk_font_bold()
	while fs > 10 and lf.get_string_size(art_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > art_label_rect.size.x:
		fs -= 1
	return fs
