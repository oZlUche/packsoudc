## 作者 10-27（带入现金）：乙 石刻拖条 —— 横向滚动条那道石槽（kit `sb_groove_h`）+ 把手（`sb_grab_<态>_h`），槽里已拖过的一段铺一层金。
## 按住把手或槽上任一处拖，值按左右比例走（[member Range.min_value] … [member Range.max_value]）；缺图画平色槽与把手
class_name StoneSlider
extends Range

const HEIGHT := 36.0
const GROOVE_H := 14.0
const GRAB_W := 30.0
const GRAB_H := 24.0
const FILL := Color(0.86, 0.66, 0.24, 0.55)
const FLAT_GROOVE := Color("8a7a64")
const FLAT_GRAB := Color("d8cbb0")

## 关着：不响应拖、整条压灰（仓库没钱时）
var enabled := true:
	set(v):
		enabled = v
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW
		queue_redraw()
var _dragging := false
var _hover := false
var _boxes := {}


func _init() -> void:
	step = 1.0
	custom_minimum_size = Vector2(120.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())
	changed.connect(queue_redraw)
	value_changed.connect(func(_v: float) -> void: queue_redraw())


## 把手中心能走的左右两端（把手不出槽）
func _track() -> Vector2:
	return Vector2(GRAB_W * 0.5, maxf(GRAB_W * 0.5, size.x - GRAB_W * 0.5))


## 槽上横坐标 [param x] 对应的值（夹在两端）
func value_at(x: float) -> float:
	var tr := _track()
	var k := clampf((x - tr.x) / maxf(1.0, tr.y - tr.x), 0.0, 1.0)
	return min_value + k * (max_value - min_value)


func _grab_x() -> float:
	var tr := _track()
	return tr.x if max_value <= min_value else lerpf(tr.x, tr.y, ratio)     # 没得选（仓库 0）时把手停在最左


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		_dragging = false
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		if mb.pressed:
			value = value_at(mb.position.x)
		queue_redraw()
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _dragging:
		value = value_at(mm.position.x)
		accept_event()


func _box(name: String, along: float) -> StyleBoxTexture:
	if _boxes.has(name):
		return _boxes[name]
	var tex := UiTheme.art_cached(name)
	var s: StyleBoxTexture = null
	if tex != null:
		s = StyleBoxTexture.new()
		s.texture = tex
		s.texture_margin_left = along
		s.texture_margin_right = along
		s.texture_margin_top = 12.0
		s.texture_margin_bottom = 12.0
		s.set_expand_margin_all(6.0)
	_boxes[name] = s
	return s


func _draw() -> void:
	var y := (size.y - GROOVE_H) * 0.5
	var groove := Rect2(0.0, y, size.x, GROOVE_H)
	var gb := _box("kit/sb_groove_h", 14.0)
	if gb != null:
		draw_style_box(gb, groove)
	else:
		draw_rect(groove, FLAT_GROOVE)
	var gx := _grab_x()
	if gx > 0.0:
		draw_rect(Rect2(2.0, y + 3.0, gx - 2.0, GROOVE_H - 6.0), FILL)
	var state := "pressed" if _dragging else ("hover" if _hover else "normal")
	if not enabled:
		state = "normal"
	var grab := Rect2(gx - GRAB_W * 0.5, (size.y - GRAB_H) * 0.5, GRAB_W, GRAB_H)
	var kb := _box("kit/sb_grab_%s_h" % state, 12.0)
	if kb != null:
		draw_style_box(kb, grab)
	else:
		draw_rect(grab, FLAT_GRAB)
	if not enabled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.5, 0.5, 0.25))
