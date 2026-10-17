## 同心环这一族布局的公共部分：固定环距、角度求解、切向弧、缓存。
##
## 子类只回答两件事：每个点在第几层（0 = 圆心）、在圈上的什么位置（0～1）。
## 角度由 [RingAngleSolver] 解，按 [member MapGraph.version] 缓存 —— 图没变就不重解，
## 命中测试每次鼠标动一下都要问位置，不能每次都解一遍。
@abstract
class_name RingLayoutBase
extends MapLayout

const MARGIN := 60.0
## 相邻两层之间隔多远（像素）。**固定的**：不管几环，环与环之间就是这么宽 ——
## 六环的图画布就比四环大一圈，而不是六环挤在四环的地方
const RING_STEP := 110.0
## 切向弧每多少弧度采一个点
const ARC_STEP := 0.05

var _cache_graph: MapGraph = null
var _cache_version: int = -1
var _angles: Dictionary = {}
var _warnings: Array[String] = []


## 每个点在第几层：id → int，0 = 圆心
@abstract func levels_of(graph: MapGraph) -> Dictionary
## 每个点在圈上的位置：id → float（0～1）
@abstract func fractions_of(graph: MapGraph) -> Dictionary
## 一共几层（圆心不算）
@abstract func level_count(graph: MapGraph) -> int


## 每个点往自己名义位置拉多少（见 RingAngleSolver.anchor）。随机生成的图默认留三成半：
## 它每个点向内连一两条斜边是本意，只把径向边往竖直方向带一带，不把点挤成一团。
## 手绘图覆盖成 0：作者画的 `|` 就该竖直
func anchor_weight() -> float:
	return 0.35


func canvas_size(graph: MapGraph) -> Vector2:
	var side := 2.0 * (float(level_count(graph)) * RING_STEP + MARGIN)
	return Vector2(side, side)


func positions(graph: MapGraph, rect: Rect2) -> Dictionary:
	_ensure_solved(graph)
	var levels := levels_of(graph)
	var out := {}
	for id in graph.node_ids():
		out[id] = polar(rect, int(levels.get(id, 0)), float(_angles.get(id, -PI / 2.0)))
	return out


func warnings(graph: MapGraph) -> Array[String]:
	_ensure_solved(graph)
	return _warnings.duplicate()


## 解出来的角度（画弧、测试用）。
func angles(graph: MapGraph) -> Dictionary:
	_ensure_solved(graph)
	return _angles


func edge_kind(graph: MapGraph, a: int, b: int) -> StringName:
	var levels := levels_of(graph)
	return &"tangential" if int(levels.get(a, -1)) == int(levels.get(b, -2)) else &"radial"


## 同层的边沿圆弧走短的那一边；跨层的直线（求解之后它本来就是径向的）。
##
## 圆心就是画布中心（[param rect] 的中心，所有环都以它为圆心）。第一版从两端与半径反推圆心，
## 两个候选里挑「离原点近的」—— 画布坐标的原点在左上角，不是圆心，下半张图的弧全都反着凸
func draw_edge(
	canvas: CanvasItem, graph: MapGraph, edge: MapEdge, a: Vector2, b: Vector2,
	color: Color, width: float, rect: Rect2 = Rect2()
) -> void:
	var levels := levels_of(graph)
	var la := int(levels.get(edge.from_id, -1))
	if la != int(levels.get(edge.to_id, -2)) or la <= 0:
		canvas.draw_line(a, b, color, width, true)
		return
	var center := rect.get_center() if rect.has_area() else canvas_size(graph) / 2.0
	canvas.draw_polyline(arc_points(a, b, center, RING_STEP * float(la)), color, width, true)


## 184：同层的边是那段圆弧上的点，跨层的直线（和 [method draw_edge] 一样）
func edge_points(graph: MapGraph, edge: MapEdge, a: Vector2, b: Vector2, rect: Rect2 = Rect2()) -> PackedVector2Array:
	var levels := levels_of(graph)
	var la := int(levels.get(edge.from_id, -1))
	if la != int(levels.get(edge.to_id, -2)) or la <= 0:
		return PackedVector2Array([a, b])
	var center := rect.get_center() if rect.has_area() else canvas_size(graph) / 2.0
	return arc_points(a, b, center, RING_STEP * float(la))


func draw_backdrop(canvas: CanvasItem, graph: MapGraph, rect: Rect2) -> void:
	for lv in range(1, level_count(graph) + 1):
		canvas.draw_arc(rect.get_center(), RING_STEP * float(lv), 0.0, TAU, 96, UiPalette.LINE, 1.0, true)


func polar(rect: Rect2, level: int, angle: float) -> Vector2:
	if level <= 0:
		return rect.get_center()
	return rect.get_center() + Vector2.from_angle(angle) * RING_STEP * float(level)


func _ensure_solved(graph: MapGraph) -> void:
	if graph == _cache_graph and graph.version == _cache_version:
		return
	var radial: Array = []
	var levels := levels_of(graph)
	for e in graph.edges:
		if e.is_portal():
			continue     # 传送点不参与角度求解：它本来就跨很远
		if int(levels.get(e.from_id, -1)) != int(levels.get(e.to_id, -1)):
			radial.append([e.from_id, e.to_id])
	var solver := RingAngleSolver.new()
	solver.anchor = anchor_weight()
	_angles = solver.solve(levels, fractions_of(graph), radial)
	_warnings = solver.warnings
	_cache_graph = graph
	_cache_version = graph.version


## 以 [param center] 为圆心、[param radius] 为半径，从 a 沿短的那一边扫到 b 的弧上的采样点。
## 两端按各自的角度取，所以 a、b 稍微不在圆上也画得顺
static func arc_points(a: Vector2, b: Vector2, center: Vector2, radius: float) -> PackedVector2Array:
	var a0 := (a - center).angle()
	var a1 := (b - center).angle()
	var sweep := RingAngleSolver._wrap(a1 - a0)
	var steps := maxi(2, ceili(absf(sweep) / ARC_STEP))
	var pts := PackedVector2Array()
	for k in steps + 1:
		pts.append(center + Vector2.from_angle(a0 + sweep * float(k) / float(steps)) * radius)
	return pts
