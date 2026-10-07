## 一条线的布局（083 序章）：节点按 `layout.col` 从左到右排成一横行，没有 col 的按 id 顺序排。
## 084：也认 `layout.row`（默认 0）—— 岔路画成上下几行，同一列的点上下错开；行居中对齐。
## 只管画在哪，不管形态的规矩 —— 教程图就是一条路带几个岔，同心环的角度求解在这里没有意义。
class_name LineMapLayout
extends MapLayout

const STEP := 150.0
const ROW_STEP := 130.0
const MARGIN := 90.0
const HEIGHT := 360.0


func canvas_size(graph: MapGraph) -> Vector2:
	if graph == null:
		return Vector2(MARGIN * 2.0, HEIGHT)
	var g := _grid_of(graph)
	var rows := int(g["max_row"]) + 1
	return Vector2(MARGIN * 2.0 + STEP * float(int(g["max_col"])), maxf(HEIGHT, ROW_STEP * float(rows) + MARGIN * 2.0))


func positions(graph: MapGraph, rect: Rect2) -> Dictionary:
	var out := {}
	if graph == null:
		return out
	var g := _grid_of(graph)
	var cols: Dictionary = g["cols"]
	var rows: Dictionary = g["rows"]
	var mid := float(int(g["max_row"])) / 2.0
	var y0 := rect.position.y + rect.size.y / 2.0
	for id in graph.node_ids():
		out[id] = Vector2(rect.position.x + MARGIN + STEP * float(cols[id]), y0 + ROW_STEP * (float(rows[id]) - mid))
	return out


## 每个点在第几列 / 第几行（没写 col 的接着上一个排，没写 row 的在第 0 行），以及最大的列号 / 行号：
## `{cols: {id: col}, rows: {id: row}, max_col, max_row}`
func _grid_of(graph: MapGraph) -> Dictionary:
	var cols := {}
	var rows := {}
	var next := 0
	var max_col := 0
	var max_row := 0
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		var col := int(lay.get("col", next))
		next = col + 1
		cols[id] = col
		rows[id] = int(lay.get("row", 0))
		max_col = maxi(max_col, col)
		max_row = maxi(max_row, int(rows[id]))
	return {"cols": cols, "rows": rows, "max_col": max_col, "max_row": max_row}
