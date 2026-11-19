## 对局记录的一行，第一行写本局结果，第二行列出时间、角色和收获。
class_name RecordRow
extends Button

const PAD := 10.0
const WEIGHTS := [0.17, 0.34, 0.26, 0.23]
const PRIMARY := [0, 2, 4, 5]
const SECONDARY := [1, 3, 7, 6]
const PAPER := Color("#e7dabe")
const INK := Color("#30261e")
const SECONDARY_INK := Color("#55483c")
const BRONZE := Color("#886640")

var columns: Array = []
var outcome_color := INK


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = maxf(62, UiTheme.sz(17) * 3.5)


func setup(p_columns: Array, p_outcome_color: Color) -> void:
	columns = p_columns
	outcome_color = p_outcome_color
	accessibility_name = " · ".join(columns)
	tooltip_text = accessibility_name
	queue_redraw()


func _draw() -> void:
	if columns.is_empty():
		return
	var sheet := Rect2(Vector2.ZERO, size)
	draw_rect(sheet, PAPER.lightened(0.12) if is_hovered() or has_focus() else PAPER)
	draw_rect(Rect2(0, 0, 3, size.y), outcome_color)
	draw_line(Vector2(3, size.y - 1), Vector2(size.x, size.y - 1), BRONZE)
	var x := 3.0
	for col in WEIGHTS.size():
		var width := (size.x - 3.0) * float(WEIGHTS[col])
		var main_index: int = PRIMARY[col]
		var ink := outcome_color if main_index == 4 else INK
		_line(String(columns[main_index]), x, width, size.y * 0.32, UiPalette.cjk_font_bold(), UiTheme.sz(16), ink)
		_line(String(columns[SECONDARY[col]]), x, width, size.y * 0.72, UiPalette.cjk_font(), UiTheme.sz(14), SECONDARY_INK)
		x += width
	if has_focus():
		draw_rect(sheet.grow(-2), BRONZE, false, 2)


func _line(value: String, x: float, width: float, center_y: float, face: Font, px: int, color: Color) -> void:
	var span := TextLine.new()
	span.add_string(value, face, px)
	span.width = maxf(1, width - PAD * 2)
	span.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	span.draw(get_canvas_item(), Vector2(x + PAD, center_y - span.get_size().y * 0.5), color)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT, NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_RESIZED]:
		queue_redraw()
