## 383（作者 2026-11-23）：出征第一屏食物横条头上的小牌 —— 一条效果（浅石底）、【食材不足】（朱红底白字）、
## 「食物尚未确认」（琥珀底）、空锅（淡）。占位配色照 UI设计 的 v2 样张（s383-departure/v2-1）
class_name MealChip
extends PanelContainer

const EFFECT := &"effect"
const SHORT := &"short"
const PENDING := &"pending"
const EMPTY := &"empty"

const LOOK := {
	EFFECT: [Color("d9c9a3"), Color("8a7350"), Color("3a2c1e"), 2],
	SHORT: [Color("b8432f"), Color("b8432f"), Color("fff6ea"), 10],
	PENDING: [Color("c98a1c"), Color("c98a1c"), Color("fff6ea"), 10],
	EMPTY: [Color("d9c9a3"), Color("b8a684"), Color("a8957a"), 2],
}

var label: Label = null


static func make(text: String, kind: StringName = EFFECT, font_size: int = 15) -> MealChip:
	var c := MealChip.new()
	c.name = "Chip_" + String(kind)
	var look: Array = LOOK.get(kind, LOOK[EFFECT])
	var box := StyleBoxFlat.new()
	box.bg_color = look[0]
	box.border_color = look[1]
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(look[3]))
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	c.add_theme_stylebox_override("panel", box)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.label = UiTheme.make_label(text, font_size, look[2])
	c.add_child(c.label)
	return c
