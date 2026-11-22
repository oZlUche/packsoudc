## 报告 383（作者 2026-11-22 23:49）：出征第一屏的折叠横条 —— 一块木牌头，折叠时只显示大致信息（角色名、这一锅的效果、所奉的神），
## 点一下展开下面的详细内容（可以查看、编辑、切换），再点一下收起。头上的大致信息由调用方摆进 [member summary]。
## 占位排版，等 UI设计 的样张（「只有角色一条」「三条都折叠」「展开其中一条」）。
class_name FoldBar
extends MarginContainer

signal toggled(open: bool)

const HEAD_H := 64.0
const ARROW := 22.0
## 木牌头与展开内容之间
const BODY_GAP := 6

var id: StringName = &""
var head: PanelContainer = null
## 头上的大致信息（调用方往里摆，换内容前自己清）
var summary: HBoxContainer = null
## 展开以后的内容
var body: Control = null
var open := false
var _arrow: Chevron = null


func setup(p_id: StringName, p_body: Control) -> FoldBar:
	id = p_id
	name = "Bar_" + String(p_id)
	var col := UiTheme.vbox(BODY_GAP)
	add_child(col)
	head = UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_HOME_PLAQUE_SMALL, 18, 8, 18, 8)
	head.name = "Head"
	head.custom_minimum_size.y = HEAD_H
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head.gui_input.connect(_on_head_input)
	col.add_child(head)
	var row := UiTheme.hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(row)
	summary = UiTheme.hbox(14)
	summary.name = "Summary"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(summary)
	_arrow = Chevron.new()
	_arrow.custom_minimum_size = Vector2.ONE * ARROW
	_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_arrow)
	body = p_body
	body.visible = false
	col.add_child(body)
	return self


func _on_head_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		press()
		accept_event()


## 点一下木牌头：折叠 ⇄ 展开
func press() -> void:
	set_open(not open)


func set_open(v: bool) -> void:
	if v == open:
		return
	open = v
	body.visible = v
	_arrow.open = v
	_arrow.queue_redraw()
	toggled.emit(v)


## 头右端的小三角：折叠朝右、展开朝下（画出来的，不是字）
class Chevron extends Control:
	var open := false

	func _draw() -> void:
		var s := size
		var ink := Color("5a4433")
		var pts: PackedVector2Array
		if open:
			pts = PackedVector2Array([Vector2(s.x * 0.15, s.y * 0.3), Vector2(s.x * 0.85, s.y * 0.3), Vector2(s.x * 0.5, s.y * 0.75)])
		else:
			pts = PackedVector2Array([Vector2(s.x * 0.3, s.y * 0.15), Vector2(s.x * 0.75, s.y * 0.5), Vector2(s.x * 0.3, s.y * 0.85)])
		draw_colored_polygon(pts, ink)
