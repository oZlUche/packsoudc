## 段头签（226 §1.3，作者 17:25 定甲 小石牌 `notice/header_stone`）：左头一枚朱红圆点的小石牌，墨字由代码写。
## 宽 = 字宽 + [constant LEFT] + [constant RIGHT]，高 [constant HEIGHT]；缺图画一块浅石色圆角底。点不着
class_name HeaderTag
extends Control

const ART := "notice/header_stone"
const HEIGHT := 32.0
## 字的左沿（圆点那侧 22 + 往右让 5 + 字前留白）与右沿留白
const LEFT := 34.0
const RIGHT := 14.0
const FONT_SIZE := 16
const INK := Color("2e2219")

var text := "":
	set(v):
		text = v
		_fit()
		queue_redraw()


func _init(p_text: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = p_text


func _fit() -> void:
	var w := UiPalette.cjk_font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	custom_minimum_size = Vector2(ceilf(w + LEFT + RIGHT), HEIGHT)
	size = custom_minimum_size


## 几枚并排时拉到同一宽度；字在圆点右边那段里居中
func widen(w: float) -> void:
	custom_minimum_size.x = maxf(custom_minimum_size.x, ceilf(w))
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var tex := UiTheme.art_cached(ART)
	if tex != null:
		var m: Array = UiTheme.art_meta(ART).get("margin", [22, 8, 12, 8])
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.texture_margin_left = float(m[0])
		box.texture_margin_top = float(m[1])
		box.texture_margin_right = float(m[2])
		box.texture_margin_bottom = float(m[3])
		draw_style_box(box, r)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("e4ded2")
		flat.set_corner_radius_all(4)
		draw_style_box(flat, r)
	var font := UiPalette.cjk_font_bold()
	var base := (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
	var room := size.x - LEFT - RIGHT
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(LEFT + maxf(0.0, (room - tw) * 0.5), base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
