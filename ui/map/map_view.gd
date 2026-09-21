## 画一张 [MapGraph]，并把点击翻译成「点了哪个点 / 哪条路 / 哪个空位」。
##
## [b]它不改图。[/b] 改图是编辑器的事，走路是导航的事；两者都只听这里的信号。
## 形态相关的一切（点摆在哪、衬底画什么、哪里能加点）都问 [MapLayout]。
class_name MapView
extends Control

signal node_pressed(id: int, button: int, shift: bool)
signal edge_pressed(edge: MapEdge, button: int)
signal slot_pressed(slot: Dictionary)
signal empty_pressed

const NODE_RADIUS := 13.0
const SLOT_RADIUS := 5.0
const EDGE_PICK := 6.0

var graph: MapGraph = null:
	set(v):
		graph = v
		_layout = MapLayout.for_graph(v)
		queue_redraw()

var selected_id: int = -1:
	set(v):
		selected_id = v
		queue_redraw()

## 画出还能加点的空位（编辑器开，游戏里关）
var show_free_slots: bool = false:
	set(v):
		show_free_slots = v
		queue_redraw()

## 把生成器留下的路线标注描出来。路线只是「这张图当初是照着什么规则长出来的」，
## 不是图的一部分 —— 关掉它，图一点不变
var show_routes: bool = true:
	set(v):
		show_routes = v
		queue_redraw()

## 把两两相连的三个 / 四个点画成一个路口。关掉就是每条边一条线（编辑器里核对数据时有用）
var merge_junctions: bool = true:
	set(v):
		merge_junctions = v
		queue_redraw()

var _layout: MapLayout = null
var _font: Font
var _hover_id: int = -1


func _ready() -> void:
	_font = UiPalette.cjk_font()
	clip_contents = true
	resized.connect(queue_redraw)


## 图被外面改过之后调一下。
func refresh() -> void:
	queue_redraw()


func positions() -> Dictionary:
	if graph == null or _layout == null:
		return {}
	return _layout.positions(graph, Rect2(Vector2.ZERO, size))


func free_slots() -> Array[Dictionary]:
	if graph == null or _layout == null:
		return [] as Array[Dictionary]
	return _layout.free_slots(graph, Rect2(Vector2.ZERO, size))


#region 命中
func node_at(p: Vector2) -> int:
	var pos := positions()
	for id in pos:
		if (pos[id] as Vector2).distance_to(p) <= NODE_RADIUS + 2.0:
			return int(id)
	return -1


func edge_at(p: Vector2) -> MapEdge:
	if graph == null:
		return null
	var pos := positions()
	for e in graph.edges:
		if not pos.has(e.from_id) or not pos.has(e.to_id):
			continue
		var a: Vector2 = pos[e.from_id]
		var b: Vector2 = pos[e.to_id]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= EDGE_PICK:
			return e
	return null


func slot_at(p: Vector2) -> Dictionary:
	if not show_free_slots:
		return {}
	for slot in free_slots():
		if (slot["pos"] as Vector2).distance_to(p) <= SLOT_RADIUS + 5.0:
			return slot
	return {}


func _gui_input(event: InputEvent) -> void:
	if graph == null:
		return
	if event is InputEventMouseMotion:
		var h := node_at((event as InputEventMouseMotion).position)
		if h != _hover_id:
			_hover_id = h
			queue_redraw()
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	press(mb.position, mb.button_index, mb.shift_pressed)
	accept_event()


## 在 [param p] 处按下。拆出来是为了测试能直接调，不必伪造输入事件。
func press(p: Vector2, button: int = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	var id := node_at(p)
	if id >= 0:
		node_pressed.emit(id, button, shift)
		return
	var e := edge_at(p)
	if e != null:
		edge_pressed.emit(e, button)
		return
	var slot := slot_at(p)
	if not slot.is_empty() and button == MOUSE_BUTTON_LEFT:
		slot_pressed.emit(slot)
		return
	empty_pressed.emit()
#endregion


#region 绘制
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.BG)
	if graph == null:
		return
	if _layout == null:
		draw_string(_font, Vector2(16, 28), "没有登记布局：%s" % graph.layout_kind,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiPalette.DIM)
		return
	var rect := Rect2(Vector2.ZERO, size)
	_layout.draw_backdrop(self, graph, rect)
	var pos := _layout.positions(graph, rect)

	# 危险区域：节点底下垫一圈。高危红，中危橙
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.danger > 0 and pos.has(id):
			draw_circle(pos[id], NODE_RADIUS + 9.0,
				Color(UiPalette.HP if n.danger >= 2 else UiPalette.STAMINA, 0.18))

	# 路线经过的边：哪条边属于哪条路线
	var route_of_edge := {}
	for i in graph.routes.size() if show_routes else 0:
		var ids: Array = graph.routes[i].get("node_ids", [])
		for k in range(1, ids.size()):
			var key := _edge_key(int(ids[k - 1]), int(ids[k]))
			if not route_of_edge.has(key):
				route_of_edge[key] = i

	# 四个点两两相连画成四岔路口，三个点两两相连画成三岔路口（先四后三，由内向外）。
	# 被路口占用的边不再单独画线 —— 六条线在中间打叉，看不出那是一个路口
	var junctions := MapJunctions.find(graph) if merge_junctions else {"quads": [], "tris": [], "edge_keys": {}}
	var in_junction: Dictionary = junctions["edge_keys"]

	for e in graph.edges:
		if not pos.has(e.from_id) or not pos.has(e.to_id):
			continue
		var key := _edge_key(e.from_id, e.to_id)
		if in_junction.has(key):
			continue
		if route_of_edge.has(key):
			draw_line(pos[e.from_id], pos[e.to_id],
				Color(MapNodeStyle.route_color(route_of_edge[key]), 0.85), 3.0, true)
		else:
			draw_line(pos[e.from_id], pos[e.to_id], UiPalette.DIM.darkened(0.25), 1.5, true)

	for clique in (junctions["quads"] as Array) + (junctions["tris"] as Array):
		_draw_junction(clique, pos, route_of_edge)

	if show_free_slots:
		for slot in _layout.free_slots(graph, rect):
			draw_arc(slot["pos"], SLOT_RADIUS, 0.0, TAU, 16, UiPalette.LINE.lightened(0.15), 1.0, true)

	for id in graph.node_ids():
		if pos.has(id):
			_draw_node(graph.get_node(id), pos[id])


## 一个路口：中心一个小点，向每个成员伸一条腿。
## 腿的颜色：这个成员在路口内部有路线经过的边，就用那条路线的颜色。
func _draw_junction(clique: Array, pos: Dictionary, route_of_edge: Dictionary) -> void:
	var center := Vector2.ZERO
	for id in clique:
		if not pos.has(int(id)):
			return
		center += pos[int(id)]
	center /= float(clique.size())
	for id in clique:
		var route := -1
		for other in clique:
			var key := _edge_key(int(id), int(other))
			if other != id and route_of_edge.has(key):
				route = int(route_of_edge[key])
		if route >= 0:
			draw_line(center, pos[int(id)], Color(MapNodeStyle.route_color(route), 0.85), 3.0, true)
		else:
			draw_line(center, pos[int(id)], UiPalette.DIM.darkened(0.25), 1.5, true)
	draw_circle(center, 3.0, UiPalette.DIM)


func _draw_node(n: MapNode, p: Vector2) -> void:
	var style := MapNodeStyle.of(n.type)
	var color: Color = style["color"]
	draw_circle(p, NODE_RADIUS, color.darkened(0.55))
	draw_arc(p, NODE_RADIUS, 0.0, TAU, 32, color, 2.0, true)
	if graph.entry_ids.has(n.id):
		draw_arc(p, NODE_RADIUS + 4.0, 0.0, TAU, 32, UiPalette.HEAL, 2.0, true)
	if graph.goal_ids.has(n.id):
		draw_arc(p, NODE_RADIUS + 4.0, 0.0, TAU, 32, UiPalette.STAMINA, 2.0, true)
	if n.id == selected_id:
		draw_arc(p, NODE_RADIUS + 7.5, 0.0, TAU, 32, UiPalette.FG, 2.0, true)
	elif n.id == _hover_id:
		draw_arc(p, NODE_RADIUS + 7.5, 0.0, TAU, 32, Color(UiPalette.FG, 0.35), 1.0, true)
	var glyph: String = style["glyph"]
	var w := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_font, p + Vector2(-w / 2.0, 5.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	# 危险等级：右上角几个红点
	for k in n.danger:
		draw_circle(p + Vector2(NODE_RADIUS - 2.0 - 6.0 * k, -NODE_RADIUS + 1.0), 2.5, UiPalette.HP)


static func _edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]
#endregion
