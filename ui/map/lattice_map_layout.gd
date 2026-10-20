## 格阵形态（沙漏、塔）的布局（8-2，报告 078）：层画成一行行（塔：出生那层在底、终点在顶）或一列列（横置的沙漏：出生在左、终点在右），
## 按图上的 orientation 定；格子的 col 是绝对列。边画直线，单向的路加箭头；衬底把每层的格子画成淡点，形状（蝴蝶结、三角）就看得出来。
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


static func is_horizontal(graph: MapGraph) -> bool:
	return String(graph.layout_meta.get("orientation", "vertical")) == "horizontal"


## 213：每个点在第几层 = 它的 row（入局转场一层层长出来按它）
func level_of(graph: MapGraph) -> Dictionary:
	var out := {}
	for id in graph.node_ids():
		out[id] = int(graph.get_node(id).layout.get("row", 0))
	return out


func layer_count(graph: MapGraph) -> int:
	return rows_of(graph) - 1


## 213：第 [param r] 层从最左到最右的格子（列号）[lo, hi]；这层没格子 = 空
static func row_span(graph: MapGraph, r: int) -> Array:
	var cells: Array = graph.layout_meta.get("cells", [])
	if r < 0 or r >= cells.size() or (cells[r] as Array).is_empty():
		return []
	return [int((cells[r] as Array).min()), int((cells[r] as Array).max())]


## 213：第 [param r] 层那根线的两端（画布坐标，两端各放 0.4 列）—— 局内衬底与开局预览的层线是同一根；这层没格子 = 空
func row_segment(graph: MapGraph, rect: Rect2, r: int) -> Array:
	var span := row_span(graph, r)
	if span.is_empty():
		return []
	var a := cell_pos(graph, rect, r, span[0])
	var b := cell_pos(graph, rect, r, span[1])
	var pad := (b - a).normalized() * COL_STEP * 0.4 if span[1] > span[0] else Vector2.ZERO
	return [a - pad, b + pad]


func canvas_size(graph: MapGraph) -> Vector2:
	var along := float(rows_of(graph) - 1) * ROW_STEP + 2.0 * MARGIN
	var across := float(cols_of(graph) - 1) * COL_STEP + 2.0 * MARGIN
	return Vector2(along, across) if is_horizontal(graph) else Vector2(across, along)


func cell_pos(graph: MapGraph, rect: Rect2, row: int, col: int) -> Vector2:
	if is_horizontal(graph):
		return rect.position + Vector2(MARGIN + float(row) * ROW_STEP, MARGIN + float(col) * COL_STEP)
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
	canvas: CanvasItem, _graph: MapGraph, edge: MapEdge, a: Vector2, b: Vector2,
	color: Color, width: float, _rect: Rect2 = Rect2()
) -> void:
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
		if not straight.has(r):
			var seg := row_segment(graph, rect, r)
			canvas.draw_line(seg[0], seg[1], UiPalette.LINE, 1.0, true)
		for c in cols:
			canvas.draw_circle(cell_pos(graph, rect, r, int(c)), 3.0, UiPalette.LINE)
