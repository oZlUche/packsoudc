## 255：「首次赠包」羊皮小签（美术 2026-10-26 11:54 定稿 `setup/charsel/tag_gift`：九宫格、墨字约 18 号、字从左边距起，字由代码写）；
## 没图退回羊皮纸面板
class_name GiftTag
extends PanelContainer

const ART := "setup/charsel/tag_gift"
const FONT := 18
const HEIGHT := 56.0

var label: Label


## [param max_w] > 0：签最宽多宽（258：字号放大后英文一句顶宽右栏 —— 字缩回小档为止）
static func make(text: String, max_w: float = 0.0) -> GiftTag:
	var g := GiftTag.new()
	g.name = "GiftTag"
	var box := UiTheme.art_box(ART)
	if box != null:
		g.add_theme_stylebox_override("panel", box)
		UiTheme.set_tone(g, UiTheme.art_tone(ART))
		g.custom_minimum_size.y = HEIGHT
	else:
		UiTheme.panel_margins(g, UiTheme.PANEL_PARCHMENT, 16, 10, 16, 10)
	g.label = UiTheme.make_label(text, FONT, UiTheme.INK)
	g.label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if max_w > 0.0:
		var pad := g.get_theme_stylebox("panel")
		TextFit.shrink_label(g.label, max_w - (pad.get_margin(SIDE_LEFT) + pad.get_margin(SIDE_RIGHT) if pad != null else 0.0), UiTheme.sz(FONT), FONT)
	g.add_child(g.label)
	return g


## 用上了定稿图没有（测试看）
func has_art() -> bool:
	return get_theme_stylebox("panel") is StyleBoxTexture
