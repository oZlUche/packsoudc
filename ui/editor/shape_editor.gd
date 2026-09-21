## 形状画板：点格子切换 0 / 1。
##
## 形状本来就是一张布尔矩阵，所以编辑它最自然的样子就是一张能点的网格 ——
## 让作者去数 `[[0,0],[1,0],[0,1]]` 是把人当解析器用。
##
## 输出仍是 0/1 数字串（[method ItemShape.to_bits]），和 JSON、文档三方同一种记法。
class_name ShapeEditor
extends Control

signal changed

const CELL := 26
const GAP := 2
const MAX_SIDE := 8

var label_font: Font

var _w: int = 3
var _h: int = 3
var _bits: Array = []  # _h 行，每行 _w 个 bool


func _ready() -> void:
	if _bits.is_empty():
		_resize(_w, _h)
	custom_minimum_size = Vector2(MAX_SIDE * (CELL + GAP), MAX_SIDE * (CELL + GAP))


#region 取值
func set_shape(shape: ItemShape) -> void:
	if shape == null or not shape.is_valid():
		_resize(3, 3)
		queue_redraw()
		return
	var rows := shape.to_bits().split("\n")
	_h = mini(MAX_SIDE, rows.size())
	_w = 1
	for r in rows:
		_w = maxi(_w, mini(MAX_SIDE, (r as String).length()))
	_resize(_w, _h)
	for y in _h:
		var row: String = rows[y]
		for x in mini(_w, row.length()):
			_bits[y][x] = row[x] == "1"
	queue_redraw()


## 当前形状；一个格子都没点时返回 null（调用方据此报「形状为空」）
func to_shape() -> ItemShape:
	var text := to_bits()
	if not text.contains("1"):
		return null
	return ItemShape.from_bits(text)


func to_bits() -> String:
	var lines: Array[String] = []
	for y in _h:
		var line := ""
		for x in _w:
			line += "1" if _bits[y][x] else "0"
		lines.append(line)
	return "\n".join(lines)


func cell_count() -> int:
	var n := 0
	for y in _h:
		for x in _w:
			if _bits[y][x]:
				n += 1
	return n
#endregion


func _resize(w: int, h: int) -> void:
	_w = clampi(w, 1, MAX_SIDE)
	_h = clampi(h, 1, MAX_SIDE)
	var fresh: Array = []
	for y in _h:
		var row: Array = []
		for x in _w:
			var old: bool = false
			if y < _bits.size() and x < (_bits[y] as Array).size():
				old = _bits[y][x]
			row.append(old)
		fresh.append(row)
	_bits = fresh


func grow_to(w: int, h: int) -> void:
	_resize(w, h)
	queue_redraw()
	changed.emit()


func size_wh() -> Vector2i:
	return Vector2i(_w, _h)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var x := int(mb.position.x / (CELL + GAP))
	var y := int(mb.position.y / (CELL + GAP))
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return
	_bits[y][x] = mb.button_index == MOUSE_BUTTON_LEFT
	queue_redraw()
	changed.emit()
	accept_event()


func _draw() -> void:
	for y in _h:
		for x in _w:
			var r := Rect2(x * (CELL + GAP), y * (CELL + GAP), CELL, CELL)
			draw_rect(r, UiPalette.FG if _bits[y][x] else UiPalette.BG)
			draw_rect(r, UiPalette.LINE, false, 1.0)
	if label_font != null:
		draw_string(
			label_font, Vector2(0, _h * (CELL + GAP) + 14),
			"%dx%d　%d 格　左键填、右键清" % [_w, _h, cell_count()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.DIM
		)
