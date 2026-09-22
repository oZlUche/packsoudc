## 手绘地图（网格脚本）的布局：每一行画成一圈，角度由 [RingAngleSolver] 解 ——
## 作者画的 `|` 一律竖直（径向边两端同一个角度），列的先后只决定次序与插值。
##
## 行末占位 `0` 所在的列就是这一环的「一整圈」：作者画的时候行越靠下越短，
## 正好对应环越靠里越短。最后一行（核心）只有一个点，画在圆心。
class_name GridMapLayout
extends RingLayoutBase


static func rows_of(graph: MapGraph) -> int:
	return int(graph.layout_meta.get("rows", 1))


func level_count(graph: MapGraph) -> int:
	return maxi(1, rows_of(graph) - 1)


## 作者画的 `|` 就该竖直：不往列的位置拉
func anchor_weight() -> float:
	return 0.0


## 第 0 行最外；最后一行是圆心（层 0）
func levels_of(graph: MapGraph) -> Dictionary:
	var rows := rows_of(graph)
	var out := {}
	for id in graph.node_ids():
		out[id] = rows - 1 - int(graph.get_node(id).layout.get("row", 0))
	return out


## 圈上的位置：这一行第一个点到行末占位算一整圈，各行的正中都朝上 ——
## 作者是把各行居中对齐着画的，这样径向边大致还是径向的，求解器只需微调
func fractions_of(graph: MapGraph) -> Dictionary:
	var zero_cols: Array = graph.layout_meta.get("zero_cols", [])
	var starts := {}
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		var row := int(lay.get("row", 0))
		starts[row] = mini(int(starts.get(row, 1 << 20)), int(lay.get("col", 0)))
	var out := {}
	for id in graph.node_ids():
		var lay := graph.get_node(id).layout
		var row := int(lay.get("row", 0))
		var zero := int(zero_cols[row]) if row < zero_cols.size() else -1
		var start := int(starts.get(row, 0))
		if zero <= start:
			out[id] = 0.0
			continue
		var mid := float(start + zero) / 2.0
		out[id] = fposmod((float(int(lay.get("col", 0))) - mid) / float(zero - start), 1.0)
	return out
