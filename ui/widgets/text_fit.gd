## 255 补充一：定宽按钮里的字放不下就缩字号（英文比中文长）—— 按钮宽不变，旁边的面板不用让
class_name TextFit
extends RefCounted

const BASE_META := &"text_fit_base"


## [param b] 的字按它的 [member Control.custom_minimum_size] 宽（扣掉皮的左右边）缩到放得下，最小 [param floor_size]；
## 起点是第一次叫时的字号（记在 meta 上，换了字再叫会先回到它）
static func shrink_button(b: Button, floor_size: int = 14) -> void:
	if b == null or b.custom_minimum_size.x <= 0.0:
		return
	var base: int = b.get_meta(BASE_META, b.get_theme_font_size("font_size"))
	b.set_meta(BASE_META, base)
	var font := b.get_theme_font("font")
	var box := b.get_theme_stylebox("normal")
	var room := b.custom_minimum_size.x - (box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT) if box != null else 0.0)
	var px := base
	while px > floor_size and font != null and font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 1
	b.add_theme_font_size_override("font_size", px)
