## 一条线的布局（083 序章）：节点按 `layout.col` 从左到右排成一横行，没有 col 的按 id 顺序排。
## 只管画在哪，不管形态的规矩 —— 序章的教程图就是一条路，同心环的角度求解在这里没有意义。
class_name LineMapLayout
extends MapLayout

const STEP := 150.0
const MARGIN := 90.0
const HEIGHT := 360.0


func canvas_size(graph: MapGraph) -> Vector2:
	var n := graph.node_count() if graph != null else 0
	return Vector2(MARGIN * 2.0 + STEP * maxf(0.0, float(n - 1)), HEIGHT)


func positions(graph: MapGraph, rect: Rect2) -> Dictionary:
	var out := {}
	if graph == null:
		return out
	var ids := graph.node_ids()
	var cols := {}
	var next := 0
	for id in ids:
		var lay := graph.get_node(id).layout
		cols[id] = int(lay.get("col", next))
		next = int(cols[id]) + 1
	var y := rect.position.y + rect.size.y / 2.0
	for id in ids:
		out[id] = Vector2(rect.position.x + MARGIN + STEP * float(cols[id]), y)
	return out
