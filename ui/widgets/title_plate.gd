## 标题牌（226 §1.2，全游戏共用结算屏那块 `result/title_plate`）：白石板、两头各一枚朱红钉，字由代码写（标题字体、墨色、居中）。
## 图是 2 倍分辨率（796 × 172，四周各 14 透明边），按 1x 画：牌身高 [constant HEIGHT]，图比牌身四周各大 [constant BLEED]；
## 横向三段 —— 两头带钉的 [constant CAP] 不拉、中段横拉，所以宽 = max([constant MIN_W], 字宽 + 2 × [constant PAD])。点不着
class_name TitlePlate
extends Control

const ART := "result/title_plate"
const HEIGHT := 72.0
const MIN_W := 384.0
const PAD := 64.0
const FONT_SIZE := 34
const INK := Color("2e2219")
## 图比牌身四周各大多少（1x）
const BLEED := 7.0
## 两头不拉的那段（1x，含钉）
const CAP := 40.0
const TEX_SCALE := 2.0
## 牌心垫的石色（结算屏石板的浅灰白）
const BACKING := Color("e4e0d8")

## 选人页 B（作者 2026-10-31 11:56「左上角跟着更新」）：底换基地木框羊皮纸（[constant UiTheme.PANEL_HOME_PLAQUE] 九宫格），字照旧。只开局屏开
var wood := false:
	set(v):
		wood = v
		queue_redraw()

var text := "":
	set(v):
		text = v
		_fit()
		queue_redraw()
var font_size := FONT_SIZE:
	set(v):
		font_size = v
		_fit()
		queue_redraw()


func _init(p_text: String = "", p_size: int = FONT_SIZE) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font_size = p_size
	text = p_text


func _font() -> Font:
	return UiPalette.title_font()


## 258：画的字号按字号档放大（[member font_size] 记小档的）
func _px() -> int:
	return UiTheme.sz(font_size)


func _fit() -> void:
	var w := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _px()).x
	custom_minimum_size = Vector2(maxf(MIN_W, ceilf(w + 2.0 * PAD)), HEIGHT)
	size = custom_minimum_size


func _draw() -> void:
	var tex := UiTheme.art_cached(ART)
	var r := Rect2(Vector2(-BLEED, -BLEED), size + Vector2(BLEED, BLEED) * 2.0)
	if wood:
		draw_style_box(UiTheme.current().get_stylebox("panel", UiTheme.PANEL_HOME_PLAQUE), Rect2(Vector2.ZERO, size))
	elif tex != null:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), BACKING)     # 图的牌心是半透明的（结算屏是叠在石板上画的）：别的屏底下是画，先垫一层石色
		var ts := tex.get_size()
		var cap_t := CAP * TEX_SCALE
		draw_texture_rect_region(tex, Rect2(r.position, Vector2(CAP, r.size.y)), Rect2(0, 0, cap_t, ts.y))
		draw_texture_rect_region(tex, Rect2(r.position + Vector2(CAP, 0), Vector2(r.size.x - 2.0 * CAP, r.size.y)), Rect2(cap_t, 0, ts.x - 2.0 * cap_t, ts.y))
		draw_texture_rect_region(tex, Rect2(r.end.x - CAP, r.position.y, CAP, r.size.y), Rect2(ts.x - cap_t, 0, cap_t, ts.y))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("ece8e0"))
	var font := _font()
	var px := _px()
	var base := size.y * 0.5 + (font.get_ascent(px) - font.get_descent(px)) * 0.5
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2((size.x - tw) * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)
