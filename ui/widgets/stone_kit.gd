## 作者 2026-11-23 18:02 选 B：基地各页换石刻（照 UI设计 基地例图 1、2；规则见报告 385）。
## 几样常用的小件：浅石框、浅石小签、深石板卡、深石板里的段头（黄铜小字 + 一道细线）与一行「左字 …… 右数」
class_name StoneKit
extends RefCounted

## 深石板上的字：正文浅字、次要灰字、段头黄铜、数字金色
const TEXT := Color("efe6d2")
const DIM := Color("b8ab90")
const BRASS := Color("c9a04e")
const GOLD := Color("ffc928")
const RED := Color("b8432f")
const RULE := Color(0.788, 0.627, 0.306, 0.45)
const TAG_FONT := 18
const HEAD_FONT := 15
const ROW_FONT := 16


## 浅石框（窗、页的外框）；内边距 [param content]，-1 = 按图边
static func frame(content: int = -1) -> StonePanel:
	var p := StonePanel.new()
	UiTheme.stone(p, UiTheme.ART_STONE_FRAME, content)
	return p


## 深石板卡（数据区）
static func slate(content: int = 18) -> StonePanel:
	var p := StonePanel.new()
	UiTheme.stone(p, UiTheme.ART_STONE_SLATE, content)
	return p


## 一条浅石（列表里的一行）；内边距 [param pad] = [左, 上, 右, 下]
static func strip(pad: Array) -> StonePanel:
	var p := StonePanel.new()
	var box := UiTheme.art_box(UiTheme.ART_STONE_TAB)
	if box != null:
		box.content_margin_left = pad[0]
		box.content_margin_top = pad[1]
		box.content_margin_right = pad[2]
		box.content_margin_bottom = pad[3]
		p.add_theme_stylebox_override("panel", box)
	UiTheme.set_tone(p, UiTheme.TONE_LIGHT)
	return p


## 浅石小签：一行墨字（「上回出征」「食材仓库」「锅」）
static func tag(text: String, font_size: int = TAG_FONT) -> StonePanel:
	var p := strip([22, 6, 22, 6])
	p.name = "StoneTag"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := UiTheme.make_label(text, font_size, UiTheme.STONE_INK)
	l.name = "Text"
	p.add_child(l)
	return p


## 深石板里的段头：黄铜小字，下面一道细线
static func head(text: String) -> VBoxContainer:
	var col := UiTheme.vbox(4)
	col.name = "Head"
	col.add_child(UiTheme.make_label(text, HEAD_FONT, BRASS))
	var line := ColorRect.new()
	line.color = RULE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	return col


## 深石板里的一行：左边浅字，右边数（默认金色）
static func row(left: String, right: String, right_color: Color = GOLD, font_size: int = ROW_FONT) -> HBoxContainer:
	var r := UiTheme.hbox(12)
	var a := UiTheme.make_label(left, font_size, TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	var b := UiTheme.make_label(right, font_size, right_color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(b)
	return r
