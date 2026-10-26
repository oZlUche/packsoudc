## 255：「首次赠包」羊皮小签（美术 2026-10-26 11:54 定稿 `setup/charsel/tag_gift`：九宫格、墨字约 18 号、字从左边距起，字由代码写）；
## 没图退回羊皮纸面板
class_name GiftTag
extends PanelContainer

const ART := "setup/charsel/tag_gift"
const FONT := 18
const HEIGHT := 56.0

var label: Label


static func make(text: String) -> GiftTag:
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
	g.add_child(g.label)
	return g


## 用上了定稿图没有（测试看）
func has_art() -> bool:
	return get_theme_stylebox("panel") is StyleBoxTexture
