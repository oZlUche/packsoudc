## 布局策略：把一张 [MapGraph] 摆到屏幕上（架构文档 5.9）。
##
## 数据层只记「谁和谁相连」与次序，**不记坐标**；点画在哪儿是这里的事。
## 每种地图形态一个子类，按 `graph.layout_kind` 取 —— 和生成器注册表同一个套路。
@abstract
class_name MapLayout
extends RefCounted

## layout_kind → 脚本路径。加一种形态就加一行
const LAYOUTS := {
	&"ring": "res://ui/map/ring_map_layout.gd",
	&"grid_script": "res://ui/map/grid_map_layout.gd",
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


## 还能加点的空位。编辑器用：每项 `{pos, layout, tier, erosion_band}` ——
## 点在这个位置上新建时该带的布局载荷与档位。形态不支持加点就返回空。
func free_slots(_graph: MapGraph, _rect: Rect2) -> Array[Dictionary]:
	return [] as Array[Dictionary]


## 手动连一条边时它该是什么 kind。形态不区分就返回空。
func edge_kind(_graph: MapGraph, _a: int, _b: int) -> StringName:
	return &""


## 画在节点与边底下的衬底（环形图的那几圈同心圆）。
func draw_backdrop(_canvas: CanvasItem, _graph: MapGraph, _rect: Rect2) -> void:
	pass
