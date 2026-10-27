## 255：选角色屏的一块面板方块（蜡板）—— 上面一行小字是哪一项（生命 / 耐力 / 耐力回复 / 体力 / 角色改过的别的面板项），下面一个粗体大数。
## 一行横排、每块 ≤ [constant MAX_W] 宽；底是背包窗角色卡那块蜡板（`stats_panel/card_wax` 九宫格，没图退回深棕底）。只自绘，不加主题覆盖。
## 258：蜡板定高 64，字不跟字号档（中、大档小字会压到数字上 —— 游戏测试 v4.58）
class_name StatPlaque
extends Control

const ART := "stats_panel/card_wax"
const MAX_W := 100.0
const HEIGHT := 64.0
const LABEL_SIZE := 13
const VALUE_SIZE := 24
const LABEL_COLOR := Color("e8dcc4")
const VALUE_COLOR := Color("f6ecd6")

var caption := ""
var value := ""


func setup(p_caption: String, p_value: String, tip: String = "") -> StatPlaque:
	caption = p_caption
	value = p_value
	tooltip_text = tip
	mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MAX_W, HEIGHT)
	UiTheme.set_tone(self, UiTheme.TONE_DARK)
	queue_redraw()
	return self


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := UiTheme.art_cached(ART)
	if bg != null:
		var sb := StyleBoxTexture.new()
		sb.texture = bg
		sb.set_texture_margin_all(16)
		draw_style_box(sb, r)
	else:
		draw_rect(r, Color("3a2a1c"))
	var regular := UiPalette.cjk_font()
	var bold := UiPalette.cjk_font_bold()
	var px := font_sizes()
	draw_string(regular, Vector2(0, 8.0 + regular.get_ascent(px[0])), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, px[0], LABEL_COLOR)
	var fs := px[1]
	while fs > 12 and bold.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 12.0:
		fs -= 1     # 「5/秒」这类长一点的缩字，不出框
	draw_string(bold, Vector2(0, size.y - 10.0 - bold.get_descent(fs)), value, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, VALUE_COLOR)


## 小字、数字各多大（258：不跟字号档，三档都是小档那套；测试看）
static func font_sizes() -> Array[int]:
	return [LABEL_SIZE, VALUE_SIZE]
