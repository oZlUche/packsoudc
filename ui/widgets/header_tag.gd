## 段头签（226 §1.3，作者 17:25 定甲 小石牌 `notice/header_stone`）：左头一枚朱红圆点的小石牌，墨字由代码写。
## 宽 = 字宽 + [constant LEFT] + [constant RIGHT]，高 [constant HEIGHT]；缺图画一块浅石色圆角底。点不着。
## 225 包架：挂绳版（[method hanging]，`notice/header_stone_hang` 160 × 46，牌身在挂绳下面，字大一号）
class_name HeaderTag
extends Control

const ART := "notice/header_stone"
const HEIGHT := 32.0
## 字的左沿（圆点那侧 22 + 往右让 5 + 字前留白）与右沿留白
const LEFT := 34.0
const RIGHT := 14.0
const FONT_SIZE := 16
const INK := Color("2e2219")
## 挂绳版（美术设计 18:36）：宽 = 字宽 + 58（字在牌身上居中、往右让 5），牌身中线 y 30
const HANG_ART := "notice/header_stone_hang"
const HANG_HEIGHT := 46.0
const HANG_LEFT := 34.0
const HANG_RIGHT := 24.0
const HANG_FONT_SIZE := 18
const HANG_MID := 30.0

var text := "":
	set(v):
		text = v
		_fit()
		queue_redraw()
## 挂绳版
var hang := false


func _init(p_text: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = p_text


## 挂绳版（包架的「包架」挂牌）
static func hanging(p_text: String) -> HeaderTag:
	var tag := HeaderTag.new()
	tag.hang = true
	tag.text = p_text
	return tag


func _left() -> float:
	return HANG_LEFT if hang else LEFT


func _right() -> float:
	return HANG_RIGHT if hang else RIGHT


func _font_size() -> int:
	return HANG_FONT_SIZE if hang else FONT_SIZE


func _fit() -> void:
	var w := UiPalette.cjk_font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x
	custom_minimum_size = Vector2(ceilf(w + _left() + _right()), HANG_HEIGHT if hang else HEIGHT)
	size = custom_minimum_size


## 几枚并排时拉到同一宽度；字在圆点右边那段里居中
func widen(w: float) -> void:
	custom_minimum_size.x = maxf(custom_minimum_size.x, ceilf(w))
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var art := HANG_ART if hang else ART
	var tex := UiTheme.art_cached(art)
	if tex != null:
		var m: Array = UiTheme.art_meta(art).get("margin", [24, 22, 24, 8] if hang else [22, 8, 12, 8])
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
		draw_style_box(flat, Rect2(0, HANG_HEIGHT - HEIGHT, size.x, HEIGHT) if hang else r)
	var font := UiPalette.cjk_font_bold()
	var px := _font_size()
	var mid := HANG_MID if hang else size.y * 0.5
	var base := mid + (font.get_ascent(px) - font.get_descent(px)) * 0.5
	var room := size.x - _left() - _right()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2(_left() + maxf(0.0, (room - tw) * 0.5), base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)
