## 基地值勤牌、出征军令和装订账册。在控件现有内容边距内绘制，以免挤占仓库格子。
extends RefCounted

const ART := "home/station/"
const INK := Color("352c24")
const IVORY := Color("fff1ce")


static func book(panel: PanelContainer, supply: bool = false) -> void:
	var tex := UiTheme.art_cached(ART + ("stores" if supply else "manifest"))
	if tex == null:
		return
	var old := UiTheme.current().get_stylebox("panel", panel.theme_type_variation)
	var margins := [old.get_margin(SIDE_LEFT), old.get_margin(SIDE_TOP),
			old.get_margin(SIDE_RIGHT), old.get_margin(SIDE_BOTTOM)]
	panel.add_theme_stylebox_override("panel", UiTheme.nine_box(tex, [26, 19, 55, 18], margins))


static func button(b: Button, primary: bool = false) -> void:
	var off := UiTheme.art_cached(ART + ("march" if primary else "index"))
	var on := UiTheme.art_cached(ART + ("march" if primary else "selected"))
	if off == null or on == null:
		return
	var base := UiTheme.nine_box(off, [25, 16, 25, 16], [12, 4, 12, 4])
	var hover := base.duplicate() as StyleBoxTexture
	base.modulate_color = Color("e5ded3")
	var active := UiTheme.nine_box(on, [25, 16, 25, 16], [12, 6, 12, 2])
	var disabled := base.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color("b0a79a")
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", active)
	b.add_theme_stylebox_override("hover_pressed", active)
	b.add_theme_stylebox_override("disabled", disabled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("ffeab0")
	focus.set_border_width_all(3)
	focus.set_expand_margin_all(2)
	b.add_theme_stylebox_override("focus", focus)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, IVORY if primary else INK)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, IVORY)
	b.add_theme_color_override("font_disabled_color", Color("5b5144"))
