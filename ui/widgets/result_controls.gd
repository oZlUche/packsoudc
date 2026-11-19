## 结算专属控件。标题按结局着墨，仓库操作有独立的状态图与配色。
extends RefCounted

const BUTTON_SIZE := Vector2(252, 77)
const BUTTON_BLEED := 7.0
const TEXT_STATES := ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]


static func outcome_heading(extracted: bool, font_size: int, height: float) -> Label:
	var title := UiTheme.make_title_label(UiText.t("result.extracted") if extracted else UiText.t("result.defeat"), font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("3d4837") if extracted else Color("703c32"))
	TextFit.shrink_label_height(title, height, font_size)
	title.set_meta(&"exempt_bare_text", "TitlePlate")     # 226 守门：字摆在同位置那块标题牌图上
	return title


## 224：「继续」图按钮（字由代码写）；228：第一页石键、第二页琥珀木牌（同尺寸、同字心）
static func continue_button(handler: Callable, art: String) -> Button:
	var en := UiText.lang == "en"
	var button := UiTheme.make_art_text_button(UiText.t("menu.continue"), handler, art, BUTTON_SIZE,
		Vector2(100, 38) if en else Vector2(110, 38), 28 if en else 34, BUTTON_BLEED)
	for state in TEXT_STATES:
		button.add_theme_color_override(state, Color("fff2cf"))
	button.add_theme_color_override("font_disabled_color", Color("4e483e"))
	button.add_theme_color_override("font_outline_color", Color("713d30"))
	button.add_theme_constant_override("outline_size", 2)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


## 只换结算页的置入和整理键，入库用绿漆，整理用浅木。
static func dress_store_button(button: Button, art: String) -> void:
	var tex := UiTheme.art_cached("result/" + art)
	if tex == null:
		return
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var pressed: bool = state in ["pressed", "hover_pressed"]
		var box := UiTheme.nine_box(tex, [17, 12, 17, 12], [12, 5 if pressed else 3, 12, 1 if pressed else 3])
		if state == "disabled":
			box.modulate_color = Color("aa9d89")
		elif pressed:
			box.modulate_color = Color("d1bb98")
		elif state == "normal":
			box.modulate_color = Color("efe5d2")
		button.add_theme_stylebox_override(state, box)
	for state in TEXT_STATES:
		button.add_theme_color_override(state, Color("3b3025"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
