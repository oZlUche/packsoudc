## 基地与开局页面的石牌、纸档与出征红漆。内边距跟随原控件，图案只占边角。
extends RefCounted

const ROOT := "campaign/"
const EDGE := [28, 23, 28, 23]
const INK := Color("382f27")
const CREAM := Color("fff2d1")


static func surface(name_: String, original: StyleBox) -> StyleBoxTexture:
	var p := [original.get_margin(SIDE_LEFT), original.get_margin(SIDE_TOP),
			original.get_margin(SIDE_RIGHT), original.get_margin(SIDE_BOTTOM)]
	return UiTheme.nine_box(UiTheme.art_cached(ROOT + name_), EDGE, p)


static func panel(control: PanelContainer) -> void:
	var original := control.get_theme_stylebox("panel") if control.has_theme_stylebox_override("panel") else UiTheme.current().get_stylebox("panel", control.theme_type_variation)
	control.add_theme_stylebox_override("panel", surface("dossier", original))


static func button(b: Button, primary: bool = false) -> void:
	var plain := surface("lacquer" if primary else "limestone", b.get_theme_stylebox("normal"))
	var active := surface("lacquer" if primary else "enamel", b.get_theme_stylebox("pressed"))
	var hover := plain.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.07, 1.06, 1.03)
	var disabled := surface("limestone", b.get_theme_stylebox("disabled"))
	disabled.modulate_color = Color("b9b3a7")
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", active)
	b.add_theme_stylebox_override("hover_pressed", active)
	b.add_theme_stylebox_override("disabled", disabled)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, CREAM if primary else INK)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, CREAM)
	b.add_theme_color_override("font_disabled_color", Color("514b43"))
