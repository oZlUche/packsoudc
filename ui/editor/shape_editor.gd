## 形状画板：在同一张网格上画占格、增益格、受益格。
##
## 形状本来就是一张布尔矩阵，所以编辑它最自然的样子就是一张能点的网格 ——
## 让作者去数 `[[0,0],[1,0],[0,1]]` 是把人当解析器用。
##
## [b]标记格必须和形状画在同一张网格上[/b]，否则「弹匣加成的是上下相邻那一格」
## 这件事在界面上根本看不出来 —— 它是一条相对偏移，脱离形状就没有意义。
## 标记格在物品**轮廓之外**，偏移可以是负数，所以网格四周留了边距。
##
## 输出：形状是 0/1 数字串（[method ItemShape.to_bits]），标记格是相对原点的偏移，
## 与 [AdjacencyProfile] 用的是同一套坐标。
class_name ShapeEditor
extends Control

signal changed

enum Layer {
	SHAPE,    ## 占格
	GRANT,    ## 增益：我给站在这儿的邻居加成
	RECEIVE,  ## 受益：站在这儿的邻居给我加成
}

const MAX_SIDE := 8
## 四周至少留这么多格，好让负偏移的标记有地方画
const MIN_PAD := 2
const MAX_PAD := 4
const GAP := 2
const TARGET_PX := 280

var label_font: Font
var layer: Layer = Layer.SHAPE

var _w: int = 3
var _h: int = 3
var _pad: int = MIN_PAD
var _bits: Array = []  # _h 行，每行 _w 个 bool
## 相对物品原点的偏移 → true
var _grant: Dictionary = {}
var _receive: Dictionary = {}


func _ready() -> void:
	if _bits.is_empty():
		_resize(_w, _h)
	_refit()


#region 取值
func set_from(shape: ItemShape, adjacency: AdjacencyProfile) -> void:
	_grant.clear()
	_receive.clear()
	if adjacency != null:
		for c in adjacency.grant_cells:
			_grant[c] = true
		for c in adjacency.receive_cells:
			_receive[c] = true
	_set_shape(shape)
	_refit()
	queue_redraw()


func _set_shape(shape: ItemShape) -> void:
	if shape == null or not shape.is_valid():
		_resize(3, 3)
		return
	var rows := shape.to_bits().split("\n")
	var h := mini(MAX_SIDE, rows.size())
	var w := 1
	for r in rows:
		w = maxi(w, mini(MAX_SIDE, (r as String).length()))
	_resize(w, h)
	for y in _h:
		var row: String = rows[y]
		for x in mini(_w, row.length()):
			_bits[y][x] = row[x] == "1"


## 当前形状；一个格子都没点时返回 null（调用方据此报「形状为空」）
func to_shape() -> ItemShape:
	var text := to_bits()
	return ItemShape.from_bits(text) if text.contains("1") else null


func to_bits() -> String:
	var lines: Array[String] = []
	for y in _h:
		var line := ""
		for x in _w:
			line += "1" if _bits[y][x] else "0"
		lines.append(line)
	return "\n".join(lines)


func grant_cells() -> Array[Vector2i]:
	return _sorted(_grant)


func receive_cells() -> Array[Vector2i]:
	return _sorted(_receive)


## 排序让输出稳定 —— 不稳定的话，什么都没改也会在 git diff 里抖
func _sorted(marks: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in marks:
		out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


func cell_count() -> int:
	var n := 0
	for y in _h:
		for x in _w:
			if _bits[y][x]:
				n += 1
	return n


func size_wh() -> Vector2i:
	return Vector2i(_w, _h)


func grow_to(w: int, h: int) -> void:
	_resize(w, h)
	_refit()
	queue_redraw()
	changed.emit()
#endregion


#region 网格几何
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


## 边距要装得下所有已有标记，否则加载一件老道具会看不见它的标记格 ——
## 看不见比画错更糟，作者会以为没配。
func _refit() -> void:
	var need := MIN_PAD
	for marks in [_grant, _receive]:
		for c in marks:
			var v := c as Vector2i
			need = maxi(need, maxi(-v.x, -v.y))
			need = maxi(need, maxi(v.x - _w + 1, v.y - _h + 1))
	_pad = clampi(need, MIN_PAD, MAX_PAD)
	custom_minimum_size = Vector2(_cols() * _step(), _rows() * _step() + 34)


func _cols() -> int:
	return _w + _pad * 2


func _rows() -> int:
	return _h + _pad * 2


## 格子随网格变大而缩小，免得撑破右栏
func _cell() -> int:
	return clampi(int(TARGET_PX / float(maxi(_cols(), _rows()))) - GAP, 12, 26)


func _step() -> int:
	return _cell() + GAP


## 网格坐标 → 相对物品原点的偏移
func _to_offset(gx: int, gy: int) -> Vector2i:
	return Vector2i(gx - _pad, gy - _pad)


func _in_shape_area(o: Vector2i) -> bool:
	return o.x >= 0 and o.y >= 0 and o.x < _w and o.y < _h


func _is_filled(o: Vector2i) -> bool:
	return _in_shape_area(o) and _bits[o.y][o.x]
#endregion


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	var add := mb.button_index == MOUSE_BUTTON_LEFT
	if not add and mb.button_index != MOUSE_BUTTON_RIGHT:
		return

	var gx := int(mb.position.x / _step())
	var gy := int(mb.position.y / _step())
	if gx < 0 or gy < 0 or gx >= _cols() or gy >= _rows():
		return
	var o := _to_offset(gx, gy)

	match layer:
		Layer.SHAPE:
			if not _in_shape_area(o):
				return  # 形状只能画在包围盒里；要更大就先调画板尺寸
			_bits[o.y][o.x] = add
			if not add:
				pass
		_:
			# 标记格在【轮廓之外】—— 画在自己身上没有意义，直接忽略
			if _is_filled(o):
				return
			var marks: Dictionary = _grant if layer == Layer.GRANT else _receive
			if add:
				marks[o] = true
			else:
				marks.erase(o)

	queue_redraw()
	changed.emit()
	accept_event()


func _draw() -> void:
	var step := _step()
	var cell := _cell()

	for gy in _rows():
		for gx in _cols():
			var o := _to_offset(gx, gy)
			var r := Rect2(gx * step, gy * step, cell, cell)
			var inside := _in_shape_area(o)

			# 底：包围盒内比边距亮一点，好看出物品自己占多大
			draw_rect(r, UiPalette.BG if inside else UiPalette.PANEL)
			if _is_filled(o):
				draw_rect(r, UiPalette.FG)
			if _grant.has(o):
				_draw_mark(r, UiPalette.GRANT)
			if _receive.has(o):
				_draw_mark(r, UiPalette.RECEIVE)
			draw_rect(r, UiPalette.LINE, false, 1.0)

	if label_font == null:
		return
	var y := _rows() * step + 13
	draw_string(
		label_font, Vector2(0, y),
		"%dx%d　%d 格　增益 %d　受益 %d" % [
			_w, _h, cell_count(), _grant.size(), _receive.size()
		],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.DIM
	)
	draw_string(
		label_font, Vector2(0, y + 15), "左键填、右键清　当前画：" + _layer_name(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _layer_color()
	)


## 标记画成内缩的方块而不是铺满，这样它压在占格上时两者都还看得见
## （虽然点不上去，但从别的道具导入的数据可能就是那样）
func _draw_mark(r: Rect2, color: Color) -> void:
	var inset := r.size.x * 0.22
	draw_rect(Rect2(r.position + Vector2(inset, inset), r.size - Vector2(inset, inset) * 2), color)


func _layer_name() -> String:
	match layer:
		Layer.GRANT:
			return "增益格"
		Layer.RECEIVE:
			return "受益格"
		_:
			return "占格"


func _layer_color() -> Color:
	match layer:
		Layer.GRANT:
			return UiPalette.GRANT
		Layer.RECEIVE:
			return UiPalette.RECEIVE
		_:
			return UiPalette.DIM
