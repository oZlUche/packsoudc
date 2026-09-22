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
func draw_edge(
	canvas: CanvasItem, graph: MapGraph, edge: MapEdge, a: Vector2, b: Vector2,
	color: Color, width: float
) -> void:
	var levels := levels_of(graph)
	var la := int(levels.get(edge.from_id, -1))
	if la != int(levels.get(edge.to_id, -2)) or la <= 0:
		canvas.draw_line(a, b, color, width, true)
		return
	var center := (a + b) / 2.0    # 只是占位；真正的圆心从半径反推
	var radius := RING_STEP * float(la)
	var c := _center_from(a, b, radius)
	var a0 := (a - c).angle()
	var a1 := (b - c).angle()
	var sweep := RingAngleSolver._wrap(a1 - a0)
	var steps := maxi(2, ceili(absf(sweep) / ARC_STEP))
	var pts := PackedVector2Array()
	for k in steps + 1:
		pts.append(c + Vector2.from_angle(a0 + sweep * float(k) / float(steps)) * radius)
	canvas.draw_polyline(pts, color, width, true)
	center = c


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
		if int(levels.get(e.from_id, -1)) != int(levels.get(e.to_id, -1)):
			radial.append([e.from_id, e.to_id])
	var solver := RingAngleSolver.new()
	solver.anchor = anchor_weight()
	_angles = solver.solve(levels, fractions_of(graph), radial)
	_warnings = solver.warnings
	_cache_graph = graph
	_cache_version = graph.version


## 两个点都在半径 r 的圆上时圆心在哪：画布里所有环同心，所以就是画布中心 ——
## 但从两点反推不依赖 rect，画弧时手上没有 rect
static func _center_from(a: Vector2, b: Vector2, r: float) -> Vector2:
	var mid := (a + b) / 2.0
	var half := a.distance_to(b) / 2.0
	if half >= r or half < 1e-6:
		return mid
	var h := sqrt(r * r - half * half)
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	# 两个候选圆心，取离原点（画布中心方向）近的那个：同心环的圆心在弧的内侧
	var c1 := mid + normal * h
	var c2 := mid - normal * h
	return c1 if c1.length_squared() < c2.length_squared() else c2
