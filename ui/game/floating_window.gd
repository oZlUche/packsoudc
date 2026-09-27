## 能拖着走的浮窗（084，作者：背包不要锁死在一个地方）。
##
## 一块带标题栏的面板：按住标题栏拖，整块跟着走，不出父控件的范围；关掉再开还在上次放的地方
## （按 [member key] 记，一局里换屏也记得）。内容由调用方往 [method body] 里加。
##
## 不用 Godot 的 Window：那是操作系统级的窗口，叠在地图上的东西只想是同一张画布里的一块面板。
class_name FloatingWindow
extends PanelContainer

## 上次放的位置（key → Vector2）。静态：换屏、重开都记得
static var _remembered: Dictionary = {}

var key: String = ""
var _body: VBoxContainer
var _header: HBoxContainer
var _title: Label
var _dragging: bool = false
var _grab: Vector2 = Vector2.ZERO
var _placed: bool = false


## [param on_close] 给了就在标题栏右边放一个「收起」按钮
func setup(p_key: String, title: String, font: Font, on_close: Callable = Callable(), close_text: String = "收起") -> void:
	key = p_key
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PANEL
	style.border_color = UiPalette.LINE
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 12)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_header.gui_input.connect(_on_header_input)
	col.add_child(_header)
	_title = Label.new()
	_title.text = title
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", UiPalette.FG)
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)
	var hint := Label.new()
	hint.text = "按住标题拖动"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UiPalette.DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_PASS
	_header.add_child(hint)
	if on_close.is_valid():
		var b := Button.new()
		b.text = close_text
		b.add_theme_font_override("font", font)
		UiPalette.style_button(b, UiPalette.Tier.MINOR, UiPalette.button_font_size(12, UiPalette.Tier.MINOR))     # 090
		b.pressed.connect(on_close)
		_header.add_child(b)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	col.add_child(_body)
	resized.connect(_clamp)


## 往这里加内容
func body() -> VBoxContainer:
	return _body


func _ready() -> void:
	# 尺寸要等内容排完才知道，居中放要晚一帧
	_place.call_deferred()


## 第一次摆：上次放的地方，没有就居中
func _place() -> void:
	if _placed or not is_inside_tree():
		return
	_placed = true
	if _remembered.has(key):
		position = _remembered[key]
	else:
		position = ((_area() - size) / 2.0).floor()
	_clamp()


## 挪到某处（不出父控件的范围）。测试与键盘都能调
func move_to(p: Vector2) -> void:
	position = p
	_placed = true
	_clamp()
	if key != "":
		_remembered[key] = position


func is_dragging() -> bool:
	return _dragging


func _on_header_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = true
			_grab = get_global_mouse_position() - global_position
		else:
			_dragging = false
		_header.accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _dragging:
		move_to(position + (get_global_mouse_position() - global_position - _grab))
		_header.accept_event()


func _area() -> Vector2:
	var parent := get_parent() as Control
	return parent.size if parent != null else get_viewport_rect().size


func _clamp() -> void:
	var area := _area()
	position = Vector2(
		clampf(position.x, 0.0, maxf(0.0, area.x - size.x)),
		clampf(position.y, 0.0, maxf(0.0, area.y - size.y)))
