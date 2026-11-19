## 顶栏状态读数按分配的槽宽选取简写。悬停与查询保留完整读数，拖出顶栏恢复原排版。
extends HudWidget

var _room := INF
var _full_text := ""
var _short_text := ""


func _paint() -> void:
	_full_text = _text.text
	_short_text = _summary() if run != null and not _full_text.is_empty() and not editing else _full_text
	tooltip_text = _full_text if in_bar and not editing else ""
	_fit()


func fit_bar_width(room: float) -> void:
	_room = room
	_fit()


func _fit() -> void:
	var visible_text := _full_text
	if in_bar and run != null and not editing and not _full_text.is_empty() and _width(_full_text) > _room:
		visible_text = _short_text
	if visible_text != _text.text:
		_text.text = visible_text


func _width(value: String) -> float:
	var font := _text.get_theme_font("font")
	var px := _text.get_theme_font_size("font_size")
	return ceilf(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + get_theme_stylebox("panel").get_minimum_size().x)


func _summary() -> String:
	return _full_text


func bar_reserve_width() -> float:
	return _width(_short_text) if not _short_text.is_empty() else 0.0


func _bar_changed() -> void:
	_room = INF
	mouse_filter = Control.MOUSE_FILTER_STOP if editing else _idle_mouse_filter()
	refresh()


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_PASS if in_bar else Control.MOUSE_FILTER_IGNORE


func text() -> String:
	return _full_text
