## 手绘地图（网格脚本）的布局：每一行画成一圈，列的先后决定角度。
##
## 行末占位 `0` 所在的列就是这一环的「一整圈」—— 作者画的时候行越靠下越短，
## 正好对应环越靠里越短。没有占位的行（核心那一行）只有一个点，画在圆心。
##
## 同样是朴素版：列位置直接换算成角度。5.4.1 说过列位置不代表距离，
## 按连接关系把径向边对齐到同一个角度上是 M3-6 的布局求解要做的。
class_name GridMapLayout
extends MapLayout

const MARGIN := 44.0


func positions(graph: MapGraph, rect: Rect2) -> Dictionary:
	var rows := int(graph.layout_meta.get("rows", 1))
	var zero_cols: Array = graph.layout_meta.get("zero_cols", [])
	var outer := maxf(10.0, minf(rect.size.x, rect.size.y) / 2.0 - MARGIN)
	# 每一行从哪一列开始。作者画的时候越靠里的行越往右缩（像个倒梯形），
	# 所以一圈 = 这一行第一个点到行末占位，而不是从第 0 列算
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
			out[id] = rect.get_center()
			continue
		# 最外一行在最外圈；最后一行（核心）在圆心。
		# 每一行的【正中】都朝上：作者是把各行居中对齐着画的，这样径向边大致还是径向的
		var radius := outer * float(rows - 1 - row) / float(maxi(1, rows - 1))
		var mid := float(start + zero) / 2.0
		var angle := TAU * (float(int(lay.get("col", 0))) - mid) / float(zero - start) - PI / 2.0
		out[id] = rect.get_center() + Vector2.from_angle(angle) * radius
	return out


func edge_kind(graph: MapGraph, a: int, b: int) -> StringName:
	var same: bool = graph.get_node(a).layout.get("row", -1) == graph.get_node(b).layout.get("row", -2)
	return &"tangential" if same else &"radial"


func draw_backdrop(canvas: CanvasItem, graph: MapGraph, rect: Rect2) -> void:
	var rows := int(graph.layout_meta.get("rows", 1))
	var outer := maxf(10.0, minf(rect.size.x, rect.size.y) / 2.0 - MARGIN)
	for row in rows - 1:
		canvas.draw_arc(rect.get_center(), outer * float(rows - 1 - row) / float(maxi(1, rows - 1)),
			0.0, TAU, 96, UiPalette.LINE, 1.0, true)
