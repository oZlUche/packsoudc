## 画一张 [MapGraph]，并把点击翻译成「点了哪个点 / 哪条路 / 哪个空位」。
##
## [b]它不改图。[/b] 改图是编辑器的事，走路是导航的事；两者都只听这里的信号。
## 形态相关的一切（点摆在哪、衬底画什么、哪里能加点）都问 [MapLayout]。
##
## 画布由布局按固定间距算出来，**不随视口缩放** —— 六环的图就是比四环大。
## 看不全靠拖（中键拖动）与缩放（滚轮，围着鼠标缩）；`fit()` 缩到刚好放下。
## 坐标分两套：布局给的是**画布坐标**，所有命中测试与信号都用它；
## 屏幕坐标只在 _gui_input 里出现一次，换算完就扔。
class_name MapView
extends Control

signal node_pressed(id: int, button: int, shift: bool)
## 鼠标移到某个点上 / 离开（-1）。沙盒用它做单步预览与路线加粗
signal node_hovered(id: int)
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
		fit()       # 先整张看全；要看细节滚轮放大到原比例（1 键）

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

## 人在哪：高亮描边 + 呼吸。-1 = 没有人（编辑器）
var current_id: int = -1:
	set(v):
		current_id = v
		set_process(v >= 0)
		queue_redraw()
## 加粗描出哪条路线（下标），-1 = 都不加粗。挑出生点时悬停哪个就加粗哪条
var bold_route: int = -1:
	set(v):
		bold_route = v
		queue_redraw()
## 这一步能走到的点：画一圈提示。沙盒每走一步更新
## 侵蚀（075）：{"eroded": 最外几档已被侵蚀（-1 = 没开始）, "warn": 快被侵蚀的那一档（-1 = 没有）}
var erosion: Dictionary = {}:
	set(v):
		erosion = v
		queue_redraw()
## 猎手标记（071）：[{"node": id, "label": 名字}]，画在节点上面
var hunters: Array = []:
	set(v):
		hunters = v
		queue_redraw()
## 092：倒计时过半关闭的撤离点：{"id", "closed": bool, "left": 还剩几步关}；空 = 没有
var closing: Dictionary = {}:
	set(v):
		closing = v
		queue_redraw()
var reachable: Dictionary = {}:
	set(v):
		reachable = v
		queue_redraw()
## 096（作者定）：挑出生点阶段的遮罩 —— 出生点之外全图蒙灰、点不中、悬停不亮；挑完就撤
var spawn_mask: bool = false:
	set(v):
		spawn_mask = v
		queue_redraw()
var _pulse: float = 0.0

## 画布 → 屏幕：screen = canvas * zoom + pan
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.5

var _layout: MapLayout = null
var _font: Font
var _hover_id: int = -1
var _dragging := false
## 岔路口按 graph.version 缓存：呼吸动画每帧都画，不能每帧都找一遍
var _junction_cache: Dictionary = {}
var _junction_version: int = -1
var _junction_graph: MapGraph = null


func _ready() -> void:
	_font = UiPalette.cjk_font()
	clip_contents = true
	resized.connect(_on_resized)


func _on_resized() -> void:
	center()
	queue_redraw()


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.0, TAU)
	queue_redraw()


## 画布多大（布局说了算）。
func canvas_rect() -> Rect2:
	if graph == null or _layout == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(Vector2.ZERO, _layout.canvas_size(graph))


## 原比例、画布居中。画布比视口大的部分靠拖。
func center() -> void:
	pan = (size - canvas_rect().size * zoom) / 2.0
	queue_redraw()


## 缩到整张图刚好放得下（只缩不放：小图不放大，免得点挤在一起变成点挤在一起的大图）。
func fit() -> void:
	var c := canvas_rect().size
	if c.x <= 0.0 or c.y <= 0.0:
		return
	zoom = clampf(minf(size.x / c.x, size.y / c.y), ZOOM_MIN, 1.0)
	center()


func to_canvas(screen: Vector2) -> Vector2:
	return (screen - pan) / zoom


func to_screen(canvas: Vector2) -> Vector2:
	return canvas * zoom + pan


## 图被外面改过之后调一下。
func refresh() -> void:
	queue_redraw()


func positions() -> Dictionary:
	if graph == null or _layout == null:
		return {}
	return _layout.positions(graph, canvas_rect())


func free_slots() -> Array[Dictionary]:
	if graph == null or _layout == null:
		return [] as Array[Dictionary]
	return _layout.free_slots(graph, canvas_rect())


#region 命中
## 节点画成固定的屏幕大小（缩小整张图时字还看得清），所以命中半径要换算回画布尺度。
func node_at(p: Vector2) -> int:
	var pos := positions()
	var reach := (NODE_RADIUS + 2.0) / zoom
	for id in pos:
		if spawn_mask and graph != null and not graph.entry_ids.has(int(id)):
			continue     # 096：遮罩下只有出生点能点中
		if (pos[id] as Vector2).distance_to(p) <= reach:
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
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= EDGE_PICK / zoom:
			return e
	return null


func slot_at(p: Vector2) -> Dictionary:
	if not show_free_slots:
		return {}
	for slot in free_slots():
		if (slot["pos"] as Vector2).distance_to(p) <= SLOT_RADIUS + 5.0:
			return slot
	return {}


## 不再悬停任何点（鼠标离开地图、点了一个点走过去 / 打开界面之后）：发一次 -1，浮窗跟着收起；
## 鼠标回到同一个点上会重新发悬停
func clear_hover() -> void:
	if _hover_id == -1:
		return
	_hover_id = -1
	node_hovered.emit(-1)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		clear_hover()


func _gui_input(event: InputEvent) -> void:
	if graph == null:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			pan += mm.relative
			queue_redraw()
			accept_event()
			return
		var h := node_at(to_canvas(mm.position))
		if h != _hover_id:
			_hover_id = h
			node_hovered.emit(h)
			queue_redraw()
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	# 中键拖动；滚轮围着鼠标缩放；其余按键才是「点了图上什么」
	if mb.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = mb.pressed
		accept_event()
		return
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		accept_event()
		return
	press(to_canvas(mb.position), mb.button_index, mb.shift_pressed)
	accept_event()


## 围着屏幕上的某一点缩放：那一点底下的东西缩放前后不动。
func zoom_at(screen: Vector2, factor: float) -> void:
	var anchor := to_canvas(screen)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	pan = screen - anchor * zoom
	queue_redraw()


## 在画布坐标 [param p] 处按下。拆出来是为了测试能直接调，不必伪造输入事件。
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
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.bg())
	if graph == null:
		return
	if _layout == null:
		draw_string(_font, Vector2(16, 28), "没有登记布局：%s" % graph.layout_kind,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiPalette.DIM)
		return
	# 下面全用画布坐标画，变换交给画布→屏幕这一层
	draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
	var rect := canvas_rect()
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
			var key := MapJunctions.edge_key(int(ids[k - 1]), int(ids[k]))
			if not route_of_edge.has(key):
				route_of_edge[key] = i

	# 四个点两两相连画成四岔路口，三个点两两相连画成三岔路口（先四后三，由内向外）。
	# 被路口占用的边不再单独画线 —— 六条线在中间打叉，看不出那是一个路口
	var junctions := _junctions() if merge_junctions else {"quads": [], "tris": [], "edge_keys": {}}
	var in_junction: Dictionary = junctions["edge_keys"]

	for e in graph.edges:
		if not pos.has(e.from_id) or not pos.has(e.to_id):
			continue
		var key := MapJunctions.edge_key(e.from_id, e.to_id)
		if in_junction.has(key):
			continue
		if route_of_edge.has(key):
			var ri: int = route_of_edge[key]
			_layout.draw_edge(self, graph, e, pos[e.from_id], pos[e.to_id],
				Color(MapNodeStyle.route_color(ri), 0.9 if ri == bold_route else 0.7),
				6.0 if ri == bold_route else 3.0, rect)
		else:
			_layout.draw_edge(self, graph, e, pos[e.from_id], pos[e.to_id], UiPalette.DIM.darkened(0.25), 1.5, rect)

	for clique in (junctions["quads"] as Array) + (junctions["tris"] as Array):
		_draw_junction(clique, pos, route_of_edge)

	if show_free_slots:
		for slot in _layout.free_slots(graph, rect):
			draw_arc(slot["pos"], SLOT_RADIUS, 0.0, TAU, 16, UiPalette.LINE.lightened(0.15), 1.0, true)

	# 节点画在屏幕坐标里：大小不随缩放变，缩小整张图看全貌时字还看得清
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 侵蚀（075）：被侵蚀的点垫一圈锈色、快被侵蚀的那一档一圈闪的红环（必须预警）。
	# 画在屏幕坐标里、节点底下：缩小整张图时画布坐标的圈会缩到节点底下看不见
	if not erosion.is_empty():
		var eroded := int(erosion.get("eroded", -1))
		var warn := int(erosion.get("warn", -1))
		for id in graph.node_ids():
			if not pos.has(id):
				continue
			var band := graph.get_node(id).erosion_band
			var sp := to_screen(pos[id])
			if eroded >= 0 and band <= eroded:
				draw_circle(sp, NODE_RADIUS + 7.0, Color(0.72, 0.36, 0.12, 0.55))
				draw_arc(sp, NODE_RADIUS + 7.0, 0.0, TAU, 32, Color(0.95, 0.55, 0.22, 0.9), 1.5, true)
			elif warn >= 0 and band == warn:
				draw_arc(sp, NODE_RADIUS + 6.0, 0.0, TAU, 32, Color(UiPalette.HP, 0.35 + 0.35 * (0.5 + 0.5 * sin(_pulse * 4.0))), 2.0, true)
	for id in graph.node_ids():
		if pos.has(id):
			_draw_node(graph.get_node(id), to_screen(pos[id]))
	for mark in hunters:
		var hid := int((mark as Dictionary).get("node", -1))
		if pos.has(hid):
			_draw_hunter(to_screen(pos[hid]), String((mark as Dictionary).get("label", "")))
	if spawn_mask:
		_draw_spawn_mask(pos)


## 096（作者定）：挑出生点的遮罩 —— 整张图盖一层底色，只把出生点重新画在上面（带呼吸的绿环），顶上一行字
func _draw_spawn_mask(pos: Dictionary) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiPalette.bg(), 0.8))
	for id in graph.entry_ids:
		if not pos.has(id):
			continue
		var sp := to_screen(pos[id])
		draw_circle(sp, NODE_RADIUS + 18.0, Color(UiPalette.HEAL, 0.10 + 0.08 * sin(_pulse * 2.0)))
		_draw_node(graph.get_node(id), sp)
		draw_arc(sp, NODE_RADIUS + 10.0 + 2.0 * sin(_pulse * 2.0), 0.0, TAU, 40, UiPalette.HEAL, 2.0, true)
	var text := "挑一个出生点" if UiText.lang == "zh" else "Pick a starting point"
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(_font, Vector2((size.x - tw) / 2.0, 34.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiPalette.HEAL)


func _junctions() -> Dictionary:
	if _junction_graph != graph or _junction_version != graph.version:
		_junction_cache = MapJunctions.find(graph)
		_junction_graph = graph
		_junction_version = graph.version
	return _junction_cache


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
			var key := MapJunctions.edge_key(int(id), int(other))
			if other != id and route_of_edge.has(key):
				route = int(route_of_edge[key])
		if route >= 0:
			draw_line(center, pos[int(id)], Color(MapNodeStyle.route_color(route), 0.85), 3.0, true)
		else:
			draw_line(center, pos[int(id)], UiPalette.DIM.darkened(0.25), 1.5, true)
	draw_circle(center, 3.0, UiPalette.DIM)


## 猎手：节点外一圈红环 + 名字（占位画法）
func _draw_hunter(p: Vector2, label: String) -> void:
	draw_arc(p, NODE_RADIUS + 7.0, 0.0, TAU, 32, UiPalette.HP, 3.0, true)
	if label != "" and _font != null:
		draw_string(_font, p + Vector2(NODE_RADIUS + 10.0, -NODE_RADIUS), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiPalette.HP)


func _draw_node(n: MapNode, p: Vector2) -> void:
	var style := MapNodeStyle.of(n.type)
	var color: Color = style["color"]
	# 用过的点去饱和变灰 —— 但连线照旧、照样能点：走回头路是这一章的核心规则，
	# 「用过」和「走不了」必须一眼分得开（5.9）。核心永远不灰，它是方向锚点。
	# 反馈：站在用过的点上（走回头路）也保持灰 —— 玩家在哪由「你」的三角标和脉动环说明，不靠把点涂回彩色
	if n.is_visited() and n.type != &"core":
		var grey := color.get_luminance()
		color = Color(grey, grey, grey).lerp(UiPalette.DIM, 0.5)
	draw_circle(p, NODE_RADIUS, color.darkened(0.55))
	draw_arc(p, NODE_RADIUS, 0.0, TAU, 32, color, 2.0, true)
	if graph.entry_ids.has(n.id):
		draw_arc(p, NODE_RADIUS + 4.0, 0.0, TAU, 32, UiPalette.HEAL, 2.0, true)
	if graph.goal_ids.has(n.id):
		draw_arc(p, NODE_RADIUS + 4.0, 0.0, TAU, 32, UiPalette.STAMINA, 2.0, true)
	if reachable.has(n.id):
		draw_arc(p, NODE_RADIUS + 5.5, 0.0, TAU, 32, Color(UiPalette.FG, 0.55), 1.5, true)
	if n.id == current_id:
		var r := NODE_RADIUS + 8.0 + 2.5 * sin(_pulse)
		draw_arc(p, r, 0.0, TAU, 40, UiPalette.FG, 2.5, true)
		_draw_player_marker(p)
	elif n.id == selected_id:
		draw_arc(p, NODE_RADIUS + 7.5, 0.0, TAU, 32, UiPalette.FG, 2.0, true)
	elif n.id == _hover_id:
		draw_arc(p, NODE_RADIUS + 7.5, 0.0, TAU, 32, Color(UiPalette.FG, 0.35), 1.0, true)
	var glyph: String = style["glyph"]
	var w := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_font, p + Vector2(-w / 2.0, 5.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	# 「这里有可看的内容」的标记位（5.10，内容归 M4）：random 没有 —— 那是地图上唯一看不透的点
	if n.type != &"random" and not n.is_visited() and not MapNodeTypes.STRUCTURAL.has(n.type):
		draw_circle(p + Vector2(-NODE_RADIUS + 3.0, -NODE_RADIUS + 3.0), 2.0, Color(UiPalette.FG, 0.6))
	# 127：进阶搜索点 —— 左下角一个琥珀色角标
	if n.type == &"search" and not n.is_visited() and SearchSession.is_advanced(n):
		var c := p + Vector2(-NODE_RADIUS + 2.0, NODE_RADIUS - 2.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 4), c + Vector2(4, 4), c + Vector2(0, -4)]), UiPalette.STAMINA)
	# 危险等级：右上角几个红点
	for k in n.danger:
		draw_circle(p + Vector2(NODE_RADIUS - 2.0 - 6.0 * k, -NODE_RADIUS + 1.0), 2.5, UiPalette.HP)
	# 092：倒计时过半关闭的撤离点 —— 关了画红叉 + 「已关闭」，没关写着「剩 n 步关闭」
	if not closing.is_empty() and int(closing.get("id", -1)) == n.id:
		var closed := bool(closing.get("closed", false))
		var text := "已关闭" if closed else "剩 %d 步关闭" % int(closing.get("left", 0))
		var col := UiPalette.HP if closed else UiPalette.STAMINA
		if closed:
			var d := NODE_RADIUS * 0.8
			draw_line(p + Vector2(-d, -d), p + Vector2(d, d), col, 3.0, true)
			draw_line(p + Vector2(-d, d), p + Vector2(d, -d), col, 3.0, true)
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_rect(Rect2(p + Vector2(-tw / 2.0 - 4.0, NODE_RADIUS + 6.0), Vector2(tw + 8.0, 17.0)), Color(UiPalette.PANEL, 0.9))
		draw_string(_font, p + Vector2(-tw / 2.0, NODE_RADIUS + 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


## 玩家在哪（084）：节点上方一个朝下的三角标，上下轻轻浮动 —— 一眼找到自己，不用在一圈圈环里找那个亮的环
func _draw_player_marker(p: Vector2) -> void:
	var lift := NODE_RADIUS + 14.0 + 2.0 * sin(_pulse * 1.3)
	var tip := p + Vector2(0.0, -lift)
	var w := 9.0
	var h := 14.0
	var pts := PackedVector2Array([tip, tip + Vector2(-w, -h), tip + Vector2(w, -h)])
	draw_colored_polygon(pts, UiPalette.HEAL)
	var outline := PackedVector2Array([tip, tip + Vector2(-w, -h), tip + Vector2(w, -h), tip])
	draw_polyline(outline, UiPalette.FG, 1.5, true)
	if _font != null:
		var text := "你"
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, tip + Vector2(-tw / 2.0, -h - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiPalette.FG)
#endregion
