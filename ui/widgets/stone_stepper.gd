## 乙 石刻步进件（226 §1.5：读数并进步进件）：[−][读数牌][+] 三件一排、间隔 4。
## 两颗钮 36 × 36（`kit/step_minus_*` / `step_plus_*`，图四周多 6），读数牌 `kit/plate` 九宫格 14，字粗宋 18 墨色、由这里画。
## 设置屏的音效音量在用；缺图退回平板「−」「+」
class_name StoneStepper
extends HBoxContainer

const ART := "kit/step_"
const PLATE_ART := "kit/plate"
const STATES := ["normal", "hover", "pressed", "disabled"]
const BUTTON := 36.0
const FONT_SIZE := 18
const INK := Color("2e2219")
const PLATE_PAD_X := 16.0
const PLATE_MIN_W := 96.0

var minus: Button
var plus: Button
var plate: Plate


## 读数牌：九宫格石牌 + 居中的粗体墨字
class Plate extends Control:
	var text := "":
		set(v):
			text = v
			update_minimum_size()
			queue_redraw()
	var _box: StyleBoxTexture = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		var w := UiPalette.cjk_font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		return Vector2(maxf(PLATE_MIN_W, ceilf(w + 2.0 * PLATE_PAD_X)), BUTTON)

	func _draw() -> void:
		if _box == null:
			_box = UiTheme.art_box(PLATE_ART)
			if _box != null:
				_box.set_texture_margin_all(14.0)
				_box.set_expand_margin_all(6.0)
		if _box != null:
			draw_style_box(_box, Rect2(Vector2.ZERO, size))
		var f := UiPalette.cjk_font_bold()
		var y := size.y * 0.5 + (f.get_ascent(FONT_SIZE) - f.get_descent(FONT_SIZE)) * 0.5
		draw_string(f, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, INK)


func _init(on_minus: Callable = Callable(), on_plus: Callable = Callable()) -> void:
	add_theme_constant_override("separation", 4)
	minus = _key("minus", "−", on_minus)
	add_child(minus)
	plate = Plate.new()
	add_child(plate)
	plus = _key("plus", "+", on_plus)
	add_child(plus)


func set_text(t: String) -> void:
	plate.text = t


func _key(which: String, glyph: String, handler: Callable) -> Button:
	var b: Button
	if UiTheme.art_cached(ART + which + "_normal") == null:
		b = UiTheme.make_button(glyph, handler if handler.is_valid() else func(): pass, UiPalette.Tier.MINOR, 13)
	else:
		b = Button.new()
		b.custom_minimum_size = Vector2(BUTTON, BUTTON)
		b.focus_mode = Control.FOCUS_NONE
		for state in STATES:
			var box := StyleBoxTexture.new()
			box.texture = UiTheme.art_cached(ART + which + "_" + state)
			box.set_expand_margin_all(6.0)
			b.add_theme_stylebox_override(state, box)
		b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = glyph
		if handler.is_valid():
			b.pressed.connect(handler)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b
