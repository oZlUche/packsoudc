## 乙 石刻小签（UI替换美术 kit，作者 18:27 选乙）：刻进石板的签，选中凹下去再加一道红线（`kit/chip_*`）。设置屏用：
## - 选项签（窗口 / 分辨率 / 底色 / 光标）：toggle_mode，一组里只有一个 on；宽 = 粗体字宽 + 38，底色签左边多 24 放色样（[member swatch]）；
## - 开关行（[member check] = true）：chip_normal 拉满整行，左头印 `kit/check_on` / `check_off`，字左对齐从 48 起；
## - 目录条（[method entry]，百科左栏）：`kit/entry_*` 高 36、字 17 左对齐从 14 起，正在看的那页 = entry_on（书签）。
## 字由这里画（普通态宋体、选中态粗体，按粗体留宽）；缺图退回平板按钮（[method UiTheme.make_button]）
class_name StoneChip
extends Button

const ART := "kit/chip_"
const CHECK_ART := "kit/check_"
const LAYOUT := "kit/layout"
const STATES := ["normal", "hover", "pressed", "disabled"]
const HEIGHT := 40.0
const FONT_SIZE := 18
## 底色签：色样 14 × 14，左 14、上 13；字往右让 24
const SWATCH := 14.0
const SWATCH_AT := Vector2(14, 13)
const SWATCH_ROOM := 24.0
const SWATCH_LINE := Color(0.937, 0.902, 0.824, 0.4)
## 开关行：印左 10、竖直居中；字从 48 起
const CHECK_X := 10.0
const CHECK_TEXT_X := 48.0
const PAD_X := 19.0
const ENTRY_ART := "kit/entry_"
const ENTRY_HEIGHT := 36.0
const ENTRY_FONT := 17
const ENTRY_TEXT_X := 14.0

## 开关行（左头印、字左对齐）
var check := false
## 目录条（entry 图、字左对齐）
var is_entry := false
## 底色签的色样（透明 = 没有）
var swatch := Color(0, 0, 0, 0):
	set(v):
		swatch = v
		_fit()
		queue_redraw()

var _colors := {}
var _boxes := {}


## 选项签：[param p_swatch] 给了就是底色签
static func make(text: String, handler: Callable, p_swatch: Color = Color(0, 0, 0, 0)) -> Button:
	if UiTheme.art_cached(ART + "normal") == null:
		var flat := UiTheme.make_button(text, handler, UiPalette.Tier.MINOR, 13)
		flat.toggle_mode = true
		return flat
	var b := StoneChip.new()
	b.text = text
	b.toggle_mode = true
	b._dress()
	b.swatch = p_swatch
	b.pressed.connect(handler)
	return b


## 开关行：拉满整行，左头印表示开 / 关
static func toggle(text: String, handler: Callable) -> Button:
	if UiTheme.art_cached(ART + "normal") == null:
		var flat := UiTheme.make_button(text, handler, UiPalette.Tier.MINOR, 14)
		flat.toggle_mode = true
		flat.alignment = HORIZONTAL_ALIGNMENT_LEFT
		return flat
	var b := StoneChip.new()
	b.check = true
	b.text = text
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b._dress()
	b.pressed.connect(handler)
	return b


## 目录条：拉满一栏，正在看的那页按下（[method set_pressed_no_signal]）= 书签
static func entry(text: String, handler: Callable) -> Button:
	if UiTheme.art_cached(ENTRY_ART + "normal") == null:
		var flat := UiTheme.make_button(text, handler, UiPalette.Tier.MINOR, 13)
		flat.toggle_mode = true
		flat.alignment = HORIZONTAL_ALIGNMENT_LEFT
		flat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return flat
	var b := StoneChip.new()
	b.is_entry = true
	b.text = text
	b.toggle_mode = true
	b.clip_text = true     # 长标题不撑宽左栏
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b._dress()
	b.pressed.connect(handler)
	return b


## 换某一态的字色（[param state]：normal / hover / pressed / disabled / on）—— 放在深底上的灰签要浅字（神坛石碑）
func set_state_ink(state: String, ink: Color) -> void:
	_colors[state] = ink
	queue_redraw()


## 258：按字号档放大（签高不变，40 高放得下大档 23 号）
func _font_size() -> int:
	return UiTheme.sz(ENTRY_FONT if is_entry else FONT_SIZE)


func _dress() -> void:
	var spec: Dictionary = UiTheme.art_meta(LAYOUT).get("entry" if is_entry else "chip", {})
	var m: Array = spec.get("nine_slice_margin", [32, 18, 14, 18] if is_entry else [18, 18, 24, 18])
	var art_base := ENTRY_ART if is_entry else ART
	var cols: Dictionary = spec.get("label", {}).get("colors", {})
	for state in STATES + ["on"]:
		_colors[state] = Color(String(cols.get(state, "#2e2219")))
	custom_minimum_size.y = ENTRY_HEIGHT if is_entry else HEIGHT
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_NONE
	# 宽按粗体留：主题字体换成粗体，Button 自己按它量最小宽；字本身由 _draw 画（主题字色全透明）
	add_theme_font_override("font", UiPalette.cjk_font_bold())
	add_theme_font_size_override("font_size", _font_size())
	for state in STATES + ["on"]:
		var name: String = state
		if check and state == "on":
			name = "normal"     # 开关行：开不开看印，底一直是平的
		var box := StyleBoxTexture.new()
		box.texture = UiTheme.art_cached(art_base + name)
		if box.texture == null:
			box.texture = UiTheme.art_cached(art_base + "normal")
		box.texture_margin_left = float(m[0])
		box.texture_margin_top = float(m[1])
		box.texture_margin_right = float(m[2])
		box.texture_margin_bottom = float(m[3])
		box.set_expand_margin_all(6.0)
		box.content_margin_left = PAD_X
		box.content_margin_right = PAD_X
		box.content_margin_top = 0.0     # 高由 [constant HEIGHT] 定，不按图边撑
		box.content_margin_bottom = 0.0
		_boxes[state] = box
	add_theme_stylebox_override("normal", _boxes["normal"])
	add_theme_stylebox_override("hover", _boxes["hover"])
	add_theme_stylebox_override("pressed", _boxes["on"])
	add_theme_stylebox_override("hover_pressed", _boxes["on"])
	add_theme_stylebox_override("disabled", _boxes["disabled"])
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))
	_fit()


func _fit() -> void:
	if _boxes.is_empty():
		return
	var left := PAD_X + (SWATCH_ROOM if swatch.a > 0.0 else 0.0)
	if check:
		left = CHECK_TEXT_X
	elif is_entry:
		left = ENTRY_TEXT_X
	for state in _boxes:
		(_boxes[state] as StyleBoxTexture).content_margin_left = left
	update_minimum_size()


func _state() -> String:
	if disabled:
		return "disabled"
	if button_pressed and toggle_mode and not check:
		return "on"
	if get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED:
		return "pressed"
	if get_draw_mode() == DRAW_HOVER:
		return "hover"
	return "normal"


func _draw() -> void:
	if _boxes.is_empty():
		return
	var st := _state()
	var bold := st == "on"
	var f := UiPalette.cjk_font_bold() if bold else UiPalette.cjk_font()
	var box := get_theme_stylebox("normal")
	var left := box.get_margin(SIDE_LEFT)
	var fs := _font_size()
	var y := size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	if is_entry:
		draw_string(f, Vector2(left, y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - left - 8.0, fs, _colors[st])
		return
	if check:
		draw_string(f, Vector2(left, y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - left - PAD_X, fs, _colors[st])
		var tex := UiTheme.art_cached(CHECK_ART + ("on" if button_pressed else "off"))
		if tex != null:
			draw_texture(tex, Vector2(CHECK_X - 6.0, (size.y - tex.get_size().y) * 0.5))
		return
	var w := size.x - left - PAD_X
	draw_string(f, Vector2(left, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, _colors[st])
	if swatch.a > 0.0:
		var r := Rect2(SWATCH_AT, Vector2(SWATCH, SWATCH))
		draw_rect(r, swatch)
		draw_rect(r, Color(_colors["normal"], 0.6), false, 1.0)
		draw_rect(r.grow(-1.5), SWATCH_LINE, false, 1.0)     # 底色都深：里圈一道浅线，看得出是色块不是黑方块
