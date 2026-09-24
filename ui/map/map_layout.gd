## 布局策略：把一张 [MapGraph] 摆到屏幕上（架构文档 5.9）。
##
## 数据层只记「谁和谁相连」与次序，**不记坐标**；点画在哪儿是这里的事。
## 每种地图形态一个子类，按 `graph.layout_kind` 取 —— 和生成器注册表同一个套路。
##
## 同心环这一族（随机生成的、手绘的）共用一个角度求解器（[RingAngleSolver]）：
## 子类只负责把自己的 ring/order 或 row/col 翻成「层 + 圈上的位置」，角度由求解器给。
@abstract
class_name MapLayout
extends RefCounted

## layout_kind → 脚本路径。加一种形态就加一行
const LAYOUTS := {
	&"ring": "res://ui/map/ring_map_layout.gd",
	&"grid_script": "res://ui/map/grid_map_layout.gd",
	&"hourglass": "res://ui/map/lattice_map_layout.gd",
	&"tower": "res://ui/map/lattice_map_layout.gd",
}


## 这张图该用哪个布局。没登记的形态返回 null。
static func for_graph(graph: MapGraph) -> MapLayout:
	if graph == null or not LAYOUTS.has(graph.layout_kind):
		return null
	var script := load(LAYOUTS[graph.layout_kind]) as GDScript
	return script.new() as MapLayout if script != null else null


## 画布多大：布局按自己的固定间距算出来，**不随视口缩放** ——
## 图大了画布就大，看不全靠拖动与缩放（[MapView]），不靠把环挤到一起。
## 默认给一个方形，形态自己覆盖。
func canvas_size(_graph: MapGraph) -> Vector2:
	return Vector2(800, 800)


## 每个节点画在哪：id → Vector2（[param rect] 之内；rect 就是画布）。
@abstract func positions(graph: MapGraph, rect: Rect2) -> Dictionary


## 求解时的告警（画得出来但作者该知道的事）。没有求解器的形态返回空。
func warnings(_graph: MapGraph) -> Array[String]:
	return [] as Array[String]


## 还能加点的空位。编辑器用：每项 `{pos, layout, tier, erosion_band}` ——
## 点在这个位置上新建时该带的布局载荷与档位。形态不支持加点就返回空。
func free_slots(_graph: MapGraph, _rect: Rect2) -> Array[Dictionary]:
	return [] as Array[Dictionary]


## 手动连一条边时它该是什么 kind。形态不区分就返回空。
func edge_kind(_graph: MapGraph, _a: int, _b: int) -> StringName:
	return &""


## 画一条边。默认直线；同心环的切向边画弧 —— 画直线会把同心环的视觉语言破坏掉，
## 玩家看到的就是一张普通的网。[param rect] 是画布（点的坐标就是按它算的），画弧要拿它当圆心。
func draw_edge(
	canvas: CanvasItem, _graph: MapGraph, _edge: MapEdge, a: Vector2, b: Vector2,
	color: Color, width: float, _rect: Rect2 = Rect2()
) -> void:
	if _edge.is_portal():
		draw_portal(canvas, a, b, width)
		return
	canvas.draw_line(a, b, color, width, true)


## 传送点（8-1）：虚线、紫色，两端各一个小圈 —— 和普通的路一眼能分开
static func draw_portal(canvas: CanvasItem, a: Vector2, b: Vector2, width: float) -> void:
	var color := Color(0.70, 0.55, 1.0, 0.85)
	canvas.draw_dashed_line(a, b, color, maxf(width, 2.0), 10.0, true)
	canvas.draw_arc(a, 18.0, 0.0, TAU, 24, color, 1.5, true)
	canvas.draw_arc(b, 18.0, 0.0, TAU, 24, color, 1.5, true)


## 画在节点与边底下的衬底（环形图的那几圈同心圆）。
func draw_backdrop(_canvas: CanvasItem, _graph: MapGraph, _rect: Rect2) -> void:
	pass
