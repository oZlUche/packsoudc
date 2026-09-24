## 格阵形态（沙漏、塔）的布局（8-2，报告 078）：层画成一行行，出生那层在底下、终点那层在顶上；列是绝对列。
## 边画直线，单向的路加箭头；衬底把每层的格子画成淡点，形状（长方形、三角）就看得出来。
class_name LatticeMapLayout
extends MapLayout

const MARGIN := 70.0
const COL_STEP := 96.0
## 和同心环的环距一样宽：猎手的绝对距离度量按它换算，两种形态一把尺
const ROW_STEP := 110.0


static func rows_of(graph: MapGraph) -> int:
	return maxi(1, int(graph.layout_meta.get("rows", 1)))


static func cols_of(graph: MapGraph) -> int:
	return maxi(1, int(graph.layout_meta.get("cols", 1)))


func canvas_size(graph: MapGraph) -> Vector2:
	return Vector2(float(cols_of(graph) - 1) * COL_STEP + 2.0 * MARGIN, float(rows_of(graph) - 1) * ROW_STEP + 2.0 * MARGIN)


func cell_pos(graph: MapGraph, rect: Rect2, row: int, col: int) -> Vector2:
	var rows := rows_of(graph)
	return rect.position + Vector2(MARGIN + float(col) * COL_STEP, MARGIN + float(rows - 1 - row) * ROW_STEP)


func positions(graph: MapGraph, rect: Rect2) -> Dictionary:
	var out := {}
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		out[id] = cell_pos(graph, rect, int(lay.get("row", 0)), int(lay.get("col", 0)))
	return out


## 空着的格子：编辑器往上加点
func free_slots(graph: MapGraph, rect: Rect2) -> Array[Dictionary]:
	var taken := {}
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		taken["%d:%d" % [int(lay.get("row", 0)), int(lay.get("col", 0))]] = true
	var cells: Array = graph.layout_meta.get("cells", [])
	var rows := rows_of(graph)
	var reversed := bool(graph.layout_meta.get("erosion_reversed", false))
	var out: Array[Dictionary] = []
	for r in cells.size():
		for c in cells[r]:
			if taken.has("%d:%d" % [r, int(c)]):
				continue
			out.append({
				"pos": cell_pos(graph, rect, r, int(c)),
				"layout": {"row": r, "col": int(c)},
				"tier": r,
				"erosion_band": (rows - 1 - r) if reversed else r,
			})
	return out


func edge_kind(graph: MapGraph, a: int, b: int) -> StringName:
	var ra := int(graph.get_node(a).layout.get("row", -1))
	var rb := int(graph.get_node(b).layout.get("row", -2))
	return &"lateral" if ra == rb else &"forward"


func draw_edge(
	canvas: CanvasItem, graph: MapGraph, edge: MapEdge, a: Vector2, b: Vector2,
	color: Color, width: float, _rect: Rect2 = Rect2()
) -> void:
	if edge.is_portal():
		MapLayout.draw_portal(canvas, a, b, width)
		return
	canvas.draw_line(a, b, color, width, true)
	if edge.directed:
		# 箭头画在离终点一个节点半径的地方，指向 to（MapView 传的 a / b 就是 from / to 的位置）
		var dir := (b - a).normalized()
		var tip := b - dir * 18.0
		var left := tip - dir * 10.0 + dir.orthogonal() * 6.0
		var right := tip - dir * 10.0 - dir.orthogonal() * 6.0
		canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), color)


func draw_backdrop(canvas: CanvasItem, graph: MapGraph, rect: Rect2) -> void:
	var cells: Array = graph.layout_meta.get("cells", [])
	var straight: Array = graph.layout_meta.get("straight_rows", [])
	for r in cells.size():
		var cols: Array = cells[r]
		if cols.is_empty():
			continue
		var lo := int(cols.min())
		var hi := int(cols.max())
		var y := cell_pos(graph, rect, r, 0).y
		if not straight.has(r):
			canvas.draw_line(Vector2(cell_pos(graph, rect, r, lo).x - COL_STEP * 0.4, y),
				Vector2(cell_pos(graph, rect, r, hi).x + COL_STEP * 0.4, y), UiPalette.LINE, 1.0, true)
		for c in cols:
			canvas.draw_circle(cell_pos(graph, rect, r, int(c)), 3.0, UiPalette.LINE)
