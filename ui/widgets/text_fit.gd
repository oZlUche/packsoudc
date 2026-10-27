## 255 补充一：定宽按钮里的字放不下就缩字号（英文比中文长）—— 按钮宽不变，旁边的面板不用让
class_name TextFit
extends RefCounted

const BASE_META := &"text_fit_base"


## [param b] 的字按它的 [member Control.custom_minimum_size] 宽（扣掉皮的左右边）缩到放得下，最小 [param floor_size]；
## 起点是第一次叫时的字号（记在 meta 上，换了字再叫会先回到它）；几行字按最宽那行算
static func shrink_button(b: Button, floor_size: int = 14) -> void:
	if b == null or b.custom_minimum_size.x <= 0.0:
		return
	var base: int = b.get_meta(BASE_META, b.get_theme_font_size("font_size"))
	b.set_meta(BASE_META, base)
	var font := b.get_theme_font("font")
	var box := b.get_theme_stylebox("normal")
	var room := b.custom_minimum_size.x - (box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT) if box != null else 0.0)
	var px := base
	while px > floor_size and font != null and font.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > room:
		px -= 1
	b.add_theme_font_size_override("font_size", px)


## 258：定宽美术字区里的一行字（纸卷上的挑战行）—— 从 [param base] 号缩到一行放得下 [param width]，最小 [param floor_size]（小档字号）
static func shrink_label(l: Label, width: float, base: int, floor_size: int) -> void:
	if l == null:
		return
	var font := l.get_theme_font("font")
	var px := base
	while px > floor_size and font != null and font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	l.add_theme_font_size_override("font_size", px)


## 258：定高卡里放不下时一号一号往回缩 —— [param l] 比 [param floor_size]（小档字号）大就小一号，返回缩了没有
static func step_down(l: Label, floor_size: int) -> bool:
	if l == null or l.get_theme_font_size("font_size") <= floor_size:
		return false
	var px := l.get_theme_font_size("font_size")
	l.add_theme_font_size_override("font_size", px - 1)
	return true


## 258：定高美术字区里的一行字（结算页标题木牌）—— 一行高过 [param height] 就小一号，最小 [param floor_size]（小档字号）
static func shrink_label_height(l: Label, height: float, floor_size: int) -> void:
	var font := l.get_theme_font("font")
	var px := l.get_theme_font_size("font_size")
	var base := px
	while px > floor_size and font != null and font.get_height(px) > height:
		px -= 1
	if px != base:
		l.add_theme_font_size_override("font_size", px)


## 260 测试反馈：定高板上的折行字（铸炉说明板）—— 先回到 [param base] 号，几行加起来高过 [param height] 就一号一号缩，最小 [param floor_size]
static func fit_wrapped_height(l: Label, height: float, base: int, floor_size: int) -> void:
	if l == null:
		return
	l.add_theme_font_size_override("font_size", base)
	while l.get_minimum_size().y > height and step_down(l, floor_size):
		pass
