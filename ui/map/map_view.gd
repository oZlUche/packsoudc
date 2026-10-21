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
## 玩家滚轮缩放了（游戏屏记进设置，下次进图沿用）
signal zoom_changed(zoom: float)

const NODE_RADIUS := 16.0     # 155：13 → 16，图标放大（作者：图案再大一点），外圈与命中都跟着它
## 155：图标的边长 = 节点半径 × 它（圆里留一圈边）
const ICON_SCALE := 1.6
const SLOT_RADIUS := 5.0
const EDGE_PICK := 6.0

## 这一章的手绘底图（[MapSkin]；空 = 照旧石板 / 纯色底）。设了就按它的深浅换字色
## 布局的底纹（同心环布局的整圈辅助圆、格子布局的网格）画不画。作者 2026-10-17：局内只画路，不画不是路的圆弧；地图编辑器打开
var show_backdrop: bool = false
var skin: StringName = &"":
	set(v):
		skin = v
		_skin_tex = MapSkin.texture(v)
		_deco_tex = MapSkin.deco(v)
		_skin_light = _skin_tex != null and MapSkin.tone(v) == UiTheme.TONE_LIGHT
		_sync_paper()
		queue_redraw()
var _skin_tex: Texture2D = null
var _deco_tex: Texture2D = null
## 192：底图在画布坐标里占的矩形（[method MapSkin.paper_rect]）；没底图 / 没图是空矩形
var _paper: Rect2 = Rect2()
## 192：画布外的桌面（`assets/ui/map/desk.png` 平铺；没图用底色）与纸影
const ART_DESK := "map/desk"
const PAPER_SHADOW := Vector2(8, 10)
const PAPER_SHADOW_COLOR := Color(0, 0, 0, 0.35)
## 180 §4 入局转场（[MapScreen] 推这两个；平时 INF / 1）：节点与边按「离出生环几环」一环一环长出来 ——
## 离出生环 k 环的点长到 clamp(node_front − k, 0, 1)（点从圆心放大、边与危险圈按它的透明度）；挑出生点的遮罩在最后一环之后才盖上来
var node_front: float = INF:
	set(v):
		node_front = v
		queue_redraw()
## 装饰层（[method MapSkin.deco]）浮现几成
var deco_alpha: float = 1.0:
	set(v):
		deco_alpha = v
		queue_redraw()
var _skin_light := false
var graph: MapGraph = null:
	set(v):
		graph = v
		_layout = MapLayout.for_graph(v)
		_sync_paper()
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
## 不是图的一部分 —— 关掉它，图一点不变。作者 10-17：路线颜色不给玩家看，默认关，编辑器里打开
var show_routes: bool = false:
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
		_hop = {}     # 184：换了人在的点：没跳完的那一下作废（走一步的跳由 hop_from 另起）
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
## 092：倒计时过半关闭的撤离点：{"id", "closed": bool, "left": 还剩几步关, "at": 倒计时剩几时关}；空 = 没有
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
## 184（作者 2026-10-17 15:36 / 15:37）：大图上一眼看清「我在哪」「哪步能走」——
## 玩家是一枚立在当前节点正中的小兵棋子（屏幕定长），走一步从旧节点弧线跳过去；可走的边画成行进的粗虚线墨路、
## 终点套一圈定长墨环、多于一步的写「计二步」；走一步人出了屏幕中央三分之一，镜头平移把人带回中央；被拖出屏外时屏边有指向他的小棋子。
## 这些都画在屏幕坐标里（像素定长，不随缩放变）
## 可走目标的花费（id → 步数；0 = 这一步不计）与哪些是传送（id → true）
var reach_cost: Dictionary = {}:
	set(v):
		reach_cost = v
		queue_redraw()
var reach_teleport: Dictionary = {}:
	set(v):
		reach_teleport = v
		queue_redraw()
## 走一步要不要播（跳、镜头平移）；关着一步到位（地图屏按「换屏淡入」开关给）
var animate_moves: bool = true
const PAWN_H := 60.0
const PAWN_SHADOW := Vector2(26.0, 8.0)
const HOP_SEC := 0.25
const HOP_LIFT := 24.0
const LAND_SEC := 0.12
const LAND_SQUASH := 0.92
const TELEPORT_FADE := 0.15
const PATH_W := 4.0
const PATH_W_HOVER := 6.0
const PATH_DASH := 12.0
const PATH_GAP := 8.0
## 虚线往前走的速度（像素 / 秒）
const MARCH_SPEED := 6.0
const END_RING_R := 28.0
const END_RING_W := 2.0
const TAG_H := 20.0
const TAG_FONT := 12
## 两枚签叠在一起时错开多少
const TAG_NUDGE := 10.0
const FOLLOW_SEC := 0.3
## 人在安全区中央这么大的一块里就不跟
const FOLLOW_BAND := 1.0 / 3.0
const OFFSCREEN_INSET := 24.0
const OFFSCREEN_SIZE := 36.0
var _march: float = 0.0
## 正在跳：{from, to（画布坐标）, t（已过秒数）, teleport}；空 = 没在跳
var _hop: Dictionary = {}
## 落地后过了几秒（-1 = 没在落地）
var _land_t: float = -1.0
var _follow_tween: Tween = null

## 画布 → 屏幕：screen = canvas * zoom + pan
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.5
## 反馈（图标放大后进图太挤）：自动定的进图缩放让相邻两点在屏幕上至少隔这么远（节点按固定屏幕大小画，缩小只会让点挤在一起）
const START_GAP := NODE_RADIUS * 5.0
## 自动定的进图缩放最多放大到这里
const START_ZOOM_MAX := 1.5
## 开局装下出生点时四周留的边（画布像素）
const SPAWN_MARGIN := NODE_RADIUS * 3.0
## 166（作者定）：地图铺满整屏、读数浮在上面 —— 这几条边被顶端栏、左下图例、右下腰带占着（position = 左、上，size = 右、下），
## 「刚好放下」「居中」「把人摆到正中」都按扣掉之后的安全区算（[method safe_rect]）；底图照旧铺满整个视图
var content_inset: Rect2 = Rect2():
	set(v):
		if v == content_inset:
			return
		var was_fit := _last_size != Vector2.ZERO and _fits()
		content_inset = v
		if _open_pending:
			return
		if was_fit:
			center()
		queue_redraw()
## [method open_at] 时视图还没尺寸：等第一次 resized 再定缩放
var _open_pending := false
var _open_zoom := 0.0
var _open_spawns: Array = []
var _last_size := Vector2.ZERO

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
	if _open_pending:
		_apply_open()
	elif _last_size == Vector2.ZERO or _fits():
		center()
	else:
		pan += (size - _last_size) / 2.0     # 看着的那块留在视图正中（放大看局部时改尺寸不跳回整图中央）
	if _paper.has_area() and zoom < zoom_min():     # 192：窗口变大后纸装不满安全区了 —— 缩放下限跟着抬
		zoom = zoom_min()
		center()
	_clamp_pan()
	_last_size = size
	queue_redraw()


func _fits() -> bool:
	var c := canvas_rect().size * zoom
	var room := safe_rect().size
	return c.x <= room.x and c.y <= room.y


## 166：扣掉 [member content_inset] 之后的那块（视图内坐标）；扣得太多时至少留一半
func safe_rect() -> Rect2:
	var lo := content_inset.position
	var hi := content_inset.size
	var room := size - lo - hi
	if room.x < size.x * 0.5 or room.y < size.y * 0.5:
		return Rect2(Vector2.ZERO, size)
	return Rect2(lo, room)


## 人看不看得见：整个视图扣掉顶端栏（底下的读数只占两角，不算挡住）
func visible_rect() -> Rect2:
	var top := minf(content_inset.position.y, size.y * 0.5)
	return Rect2(Vector2(0.0, top), size - Vector2(0.0, top))


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.0, TAU)
	_march = fmod(_march + delta * MARCH_SPEED, PATH_DASH + PATH_GAP)
	if not _hop.is_empty():
		_hop["t"] = float(_hop["t"]) + delta
		if float(_hop["t"]) >= _hop_total():
			finish_hop()
	elif _land_t >= 0.0:
		_land_t += delta
		if _land_t >= LAND_SEC:
			_land_t = -1.0
	queue_redraw()


## 画布多大（布局说了算）。
func canvas_rect() -> Rect2:
	if graph == null or _layout == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(Vector2.ZERO, _layout.canvas_size(graph))


## 原比例、画布居中。画布比视口大的部分靠拖。
func center() -> void:
	stop_follow()
	var safe := safe_rect()
	pan = safe.position + (safe.size - canvas_rect().size * zoom) / 2.0
	queue_redraw()


## 缩到整张图刚好放得下（只缩不放：小图不放大，免得点挤在一起变成点挤在一起的大图）。
func fit() -> void:
	var c := canvas_rect().size
	if c.x <= 0.0 or c.y <= 0.0:
		return
	var room := safe_rect().size
	zoom = zoom_min() if _paper.has_area() else clampf(minf(room.x / c.x, room.y / c.y), ZOOM_MIN, 1.0)     # 192：有底图 = 整张纸刚好装进安全区
	center()


## 进图（游戏屏）：[param preferred] > 0 = 玩家上次滚轮定的缩放（设置里全局沿用）；0 = 自动 [method start_zoom]。
## 然后把人所在的点摆到视图中央。视图还没尺寸就等第一次 resized
## [param spawns]（作者 2026-10-16，每局开始挑出生点时给）：先缩到所有出生点都装得下，再按 [method frame_spawns] 摆视角
func open_at(preferred: float, spawns: Array = []) -> void:
	_open_zoom = preferred
	_open_spawns = spawns.duplicate()
	_open_pending = true
	if size.x > 0.0 and size.y > 0.0:
		_apply_open()


func _apply_open() -> void:
	_open_pending = false
	zoom = clampf(_open_zoom if _open_zoom > 0.0 else start_zoom(), zoom_min(), ZOOM_MAX)
	if not _open_spawns.is_empty():
		frame_spawns(_open_spawns)
		return
	focus(current_id)


## 作者 2026-10-16：开局视角 —— 缩放不超过现在的，且所有出生点（外加一圈边）都装得下；
## 再把出生点那一团摆在屏上「它在图上的相对位置」处：出生点在图的右下，屏上也偏右下，于是另一侧露出尽量多的地图
func frame_spawns(ids: Array) -> void:
	var pos := positions()
	var box := Rect2()
	var any := false
	for id in ids:
		if not pos.has(id):
			continue
		var p: Vector2 = pos[id]
		box = Rect2(p, Vector2.ZERO) if not any else box.expand(p)
		any = true
	if not any or size.x <= 0.0 or size.y <= 0.0:
		focus(current_id)
		return
	box = box.grow(SPAWN_MARGIN)
	var fit := minf(size.x / maxf(box.size.x, 1.0), size.y / maxf(box.size.y, 1.0))
	zoom = clampf(minf(zoom, fit), zoom_min(), ZOOM_MAX)
	var c := canvas_rect().size
	var cover := _paper if _paper.has_area() else Rect2(Vector2.ZERO, c)     # 192：有底图夹的是纸，不是画布
	var mid := box.get_center()
	var p := Vector2.ZERO
	for i in 2:
		var t := clampf(mid[i] / c[i], 0.0, 1.0) if c[i] > 0.0 else 0.5
		# 出生点团在屏上的位置 = 它在图上的相对位置；再夹住，别让团的边出屏
		var want := lerpf(box.size[i] * zoom * 0.5, size[i] - box.size[i] * zoom * 0.5, t)
		p[i] = want - mid[i] * zoom
		var cz := cover.size[i] * zoom
		if cz <= size[i]:
			p[i] = (size[i] - cz) / 2.0 - cover.position[i] * zoom
		else:
			p[i] = clampf(p[i], size[i] - cover.end[i] * zoom, -cover.position[i] * zoom)
	pan = p
	_clamp_pan()
	queue_redraw()


## 192：最小缩放 —— 有底图 = 整张纸刚好装进安全区（再缩就露出纸外的桌面一大片），没底图 = [constant ZOOM_MIN]
func zoom_min() -> float:
	if not _paper.has_area() or size.x <= 0.0 or size.y <= 0.0:
		return ZOOM_MIN
	var room := safe_rect().size
	return clampf(minf(room.x / _paper.size.x, room.y / _paper.size.y), ZOOM_MIN, ZOOM_MAX)


## 192：底图在画布里的矩形（测试读）
func paper() -> Rect2:
	return _paper


## 192：纸在屏幕上的矩形
func paper_on_screen() -> Rect2:
	return Rect2(_paper.position * zoom + pan, _paper.size * zoom)


func _sync_paper() -> void:
	_paper = MapSkin.paper_rect(skin, canvas_rect()) if graph != null and _layout != null and _skin_tex != null else Rect2()


## 192（待定 4 甲，软限制）：纸的任何一边不越过安全区的中心线 —— 拖、滚轮、跟镜头、开局摆视角之后各夹一次
func _clamp_pan() -> void:
	if not _paper.has_area():
		return
	var c := safe_rect().get_center()
	pan.x = clampf(pan.x, c.x - _paper.end.x * zoom, c.x - _paper.position.x * zoom)
	pan.y = clampf(pan.y, c.y - _paper.end.y * zoom, c.y - _paper.position.y * zoom)


## 自动的进图缩放：能看全就看全，但相邻两点在屏幕上至少隔 [constant START_GAP]（最短的那条边算），最多放大到 [constant START_ZOOM_MAX]
func start_zoom() -> float:
	var c := canvas_rect().size
	if c.x <= 0.0 or c.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	var room := safe_rect().size
	var whole := clampf(minf(room.x / c.x, room.y / c.y), ZOOM_MIN, 1.0)
	var gap := shortest_edge()
	if gap <= 0.0:
		return whole
	return clampf(maxf(whole, START_GAP / gap), ZOOM_MIN, START_ZOOM_MAX)


## 画布上最短的一条边（两点间直线距离）；没边 0
func shortest_edge() -> float:
	if graph == null:
		return 0.0
	var pos := positions()
	var best := INF
	for e in graph.edges:
		if pos.has(e.from_id) and pos.has(e.to_id):
			var d := (pos[e.from_id] as Vector2).distance_to(pos[e.to_id])
			if d > 0.0:
				best = minf(best, d)
	return 0.0 if best == INF else best


## 按当前缩放把某个点摆到视图中央（-1 / 没这个点 = 整图居中）；画布比视图小的那一维照旧居中，大的那一维不拖出空边
func focus(id: int) -> void:
	stop_follow()
	var pos := positions()
	if id < 0 or not pos.has(id):
		center()
		return
	pan = focus_pan(id)
	queue_redraw()


## 按当前缩放把 [param id] 摆到安全区中央时的 pan（[method focus] 与跟镜头共用）
func focus_pan(id: int) -> Vector2:
	var pos := positions()
	if not pos.has(id):
		return pan
	var c := canvas_rect().size * zoom
	var safe := safe_rect()
	var p := safe.get_center() - (pos[id] as Vector2) * zoom
	for i in 2:
		if c[i] <= safe.size[i]:
			p[i] = safe.position[i] + (safe.size[i] - c[i]) / 2.0
		else:
			p[i] = clampf(p[i], safe.end[i] - c[i], safe.position[i])
	return p


func to_canvas(screen: Vector2) -> Vector2:
	return (screen - pan) / zoom


func to_screen(canvas: Vector2) -> Vector2:
	return canvas * zoom + pan


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
			stop_follow()
			pan += mm.relative
			_clamp_pan()
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
	if mb.button_index == MOUSE_BUTTON_LEFT and offscreen_rect().has_point(mb.position):
		recenter_on_player()     # 184：点屏边那枚指向自己的小棋子 = 平移回去
		accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		accept_event()
		return
	press(to_canvas(mb.position), mb.button_index, mb.shift_pressed)
	accept_event()


## 围着屏幕上的某一点缩放：那一点底下的东西缩放前后不动。
func zoom_at(screen: Vector2, factor: float) -> void:
	stop_follow()
	var anchor := to_canvas(screen)
	zoom = clampf(zoom * factor, zoom_min(), ZOOM_MAX)
	pan = screen - anchor * zoom
	_clamp_pan()
	queue_redraw()
	zoom_changed.emit(zoom)


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
	if _paper.has_area():     # 192：底图钉在画布上 —— 桌面（屏幕坐标）→ 纸影 → 底图 → 装饰层，后三样和路网同一个变换
		var desk := UiTheme.art_cached(ART_DESK)
		if desk != null:
			var step := desk.get_size()
			for y in range(0, int(ceil(size.y / step.y))):
				for x in range(0, int(ceil(size.x / step.x))):
					draw_texture(desk, Vector2(x, y) * step)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), UiPalette.bg())
		draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
		draw_rect(Rect2(_paper.position + PAPER_SHADOW, _paper.size).grow(2.0), PAPER_SHADOW_COLOR)
		draw_texture_rect(_skin_tex, _paper, false)
		if _deco_tex != null and deco_alpha > 0.0:     # 180：装饰层叠在底图上、圈下面
			draw_texture_rect(_deco_tex, _paper, false, Color(1, 1, 1, deco_alpha))
		draw_set_transform(Vector2.ZERO)
	elif _skin_tex != null:     # 还没有图（画布未定）：照旧铺满、裁边
		draw_texture_rect_region(_skin_tex, Rect2(Vector2.ZERO, size), MapSkin.cover_region(_skin_tex.get_size(), size))
		if _deco_tex != null and deco_alpha > 0.0:     # 180：装饰层叠在底图上、圈下面
			draw_texture_rect_region(_deco_tex, Rect2(Vector2.ZERO, size), MapSkin.cover_region(_deco_tex.get_size(), size), Color(1, 1, 1, deco_alpha))
	else:     # 157 补充三：地图屏不走石板，没底图就是设置里的底色
		draw_rect(Rect2(Vector2.ZERO, size), UiPalette.bg())
	if graph == null:
		return
	if _layout == null:
		draw_string(_font, Vector2(16, 28), UiText.t("map.no_layout") % graph.layout_kind,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _ink(UiPalette.DIM))
		return
	# 下面全用画布坐标画，变换交给画布→屏幕这一层
	draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
	var rect := canvas_rect()
	if show_backdrop:
		_layout.draw_backdrop(self, graph, rect)
	var pos := _layout.positions(graph, rect)
	var grow := _grow_map()

	# 危险区域：节点底下垫一圈。高危红，中危橙
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.danger > 0 and pos.has(id):
			draw_circle(pos[id], NODE_RADIUS + 9.0,
				Color(UiPalette.HP if n.danger >= 2 else UiPalette.STAMINA, 0.18 * float(grow.get(id, 1.0))))
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
		var f := minf(float(grow.get(e.from_id, 1.0)), float(grow.get(e.to_id, 1.0)))
		if f <= 0.0:
			continue
		var color := _ink(UiPalette.DIM).darkened(0.25)
		var width := 1.5
		if route_of_edge.has(key):
			var ri: int = route_of_edge[key]
			color = Color(MapNodeStyle.route_color(ri), 0.9 if ri == bold_route else 0.7)
			width = 6.0 if ri == bold_route else 3.0
		color.a *= f
		if e.is_portal():
			if f < 1.0:
				continue     # 传送点的虚线自己定色，长全了再画
			MapLayout.draw_portal(self, pos[e.from_id], pos[e.to_id], width)     # 传送点（8-1）：虚线紫，哪种布局都一样
		else:
			_layout.draw_edge(self, graph, e, pos[e.from_id], pos[e.to_id], color, width, rect)

	for clique in (junctions["quads"] as Array) + (junctions["tris"] as Array):
		var f := 1.0
		for id in clique:
			f = minf(f, float(grow.get(int(id), 1.0)))
		if f > 0.0:
			_draw_junction(clique, pos, route_of_edge, f)

	if show_free_slots:
		for slot in _layout.free_slots(graph, rect):
			draw_arc(slot["pos"], SLOT_RADIUS, 0.0, TAU, 16, UiPalette.LINE.lightened(0.15), 1.0, true)

	# 节点画在屏幕坐标里：大小不随缩放变，缩小整张图看全貌时字还看得清
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 侵蚀（075）：被侵蚀的点垫一圈锈色、快被侵蚀的那一档一圈闪的红环（必须预警）。
	# 画在屏幕坐标里、节点底下：缩小整张图时画布坐标的圈会缩到节点底下看不见
	if not erosion.is_empty() and grow.is_empty():
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
			_draw_grown(graph.get_node(id), to_screen(pos[id]), float(grow.get(id, 1.0)))
	for mark in hunters:
		var hid := int((mark as Dictionary).get("node", -1))
		if pos.has(hid) and float(grow.get(hid, 1.0)) >= 1.0:
			_draw_hunter(to_screen(pos[hid]), String((mark as Dictionary).get("label", "")))
	_draw_player_layer(pos, grow, rect)
	if spawn_mask:
		_draw_spawn_mask(pos, grow)


## 180 §4：转场中每个点长到几成（id → 0..1）；不在转场 = 空（都画全）
func _grow_map() -> Dictionary:
	if node_front == INF or graph == null or _layout == null:
		return {}
	var rings: Dictionary = _layout.level_of(graph)     # 213：同心环按环、格阵按层
	if rings.is_empty():
		return {}
	var origin := reveal_origin_ring()
	var out := {}
	for id in rings:
		out[id] = clampf(node_front - float(absi(int(rings[id]) - origin)), 0.0, 1.0)
	return out


## 长出来从哪一环（格阵：哪一层）起：人在的那个点，挑出生点时是第一个出生点（没有 = 第 0 环）
func reveal_origin_ring() -> int:
	if graph == null or _layout == null:
		return 0
	var rings: Dictionary = _layout.level_of(graph)
	var from := current_id if current_id >= 0 else (int(graph.entry_ids[0]) if not graph.entry_ids.is_empty() else -1)
	return int(rings.get(from, 0))


## 长到 [param f] 成的点：绕自己的圆心从零放大
func _draw_grown(n: MapNode, p: Vector2, f: float) -> void:
	if f <= 0.0:
		return
	if f < 1.0:
		draw_set_transform(p * (1.0 - f), 0.0, Vector2(f, f))
	_draw_node(n, p)
	if f < 1.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 096（作者定）：挑出生点的遮罩 —— 整张图盖一层底色，只把出生点重新画在上面（带呼吸的绿环），顶上一行字
func _draw_spawn_mask(pos: Dictionary, grow: Dictionary = {}) -> void:
	# 180：转场里最后一环长全之后才盖上来
	var k := 1.0 if grow.is_empty() else clampf(node_front - float(level_count()), 0.0, 1.0)
	if k <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiPalette.bg(), 0.8 * k))
	for id in graph.entry_ids:
		if not pos.has(id):
			continue
		var sp := to_screen(pos[id])
		draw_circle(sp, NODE_RADIUS + 18.0, Color(UiPalette.HEAL, (0.10 + 0.08 * sin(_pulse * 2.0)) * k))
		_draw_node(graph.get_node(id), sp)
		draw_arc(sp, NODE_RADIUS + 10.0 + 2.0 * sin(_pulse * 2.0), 0.0, TAU, 40, Color(UiPalette.HEAL, k), 2.0, true)
	# 226 批二：蒙层上那句「挑一个出生点」删了（告示层会说）


## 最远一层的层号（同心环 = 环数，213 格阵 = 行数 − 1；别的布局 0）
func level_count() -> int:
	return _layout.layer_count(graph) if graph != null and _layout != null else 0


func _junctions() -> Dictionary:
	if _junction_graph != graph or _junction_version != graph.version:
		_junction_cache = MapJunctions.find(graph)
		_junction_graph = graph
		_junction_version = graph.version
	return _junction_cache


## 一个路口：中心一个小点，向每个成员伸一条腿。
## 腿的颜色：这个成员在路口内部有路线经过的边，就用那条路线的颜色。
func _draw_junction(clique: Array, pos: Dictionary, route_of_edge: Dictionary, fade: float = 1.0) -> void:
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
			draw_line(center, pos[int(id)], Color(MapNodeStyle.route_color(route), 0.85 * fade), 3.0, true)
		else:
			var c := _ink(UiPalette.DIM).darkened(0.25)
			draw_line(center, pos[int(id)], Color(c, c.a * fade), 1.5, true)
	var dot := _ink(UiPalette.DIM)
	draw_circle(center, 3.0, Color(dot, dot.a * fade))


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
	# 反馈：站在用过的点上（走回头路）也保持灰 —— 玩家在哪由棋子说明（184），不靠把点涂回彩色
	if n.is_visited() and n.type != &"core":
		var grey := color.get_luminance()
		color = Color(grey, grey, grey).lerp(_ink(UiPalette.DIM), 0.5)
	draw_circle(p, NODE_RADIUS, color.darkened(0.55))
	draw_arc(p, NODE_RADIUS, 0.0, TAU, 32, color, 2.0, true)
	if graph.entry_ids.has(n.id):
		draw_arc(p, NODE_RADIUS + 4.0, 0.0, TAU, 32, UiPalette.HEAL, 2.0, true)
	if graph.goal_ids.has(n.id):
		draw_arc(p, NODE_RADIUS + 4.0, 0.0, TAU, 32, UiPalette.STAMINA, 2.0, true)
	# 184：可走的点由墨路与墨环说明、玩家由棋子说明（原来的细环、脉动环、三角标都撤了）；选中 / 悬停环是操作反馈，留着
	if n.id == selected_id:
		draw_arc(p, NODE_RADIUS + 7.5, 0.0, TAU, 32, _ink(UiPalette.FG), 2.0, true)
	elif n.id == _hover_id:
		draw_arc(p, NODE_RADIUS + 7.5, 0.0, TAU, 32, Color(_ink(UiPalette.FG), 0.35), 1.0, true)
	# 155：有图标画图标（白线稿按节点色着色，圆底是同色压暗的深色，图标不会融进去）；没图退回写字
	var tex := MapNodeStyle.icon(n.type)
	if tex != null:
		var side := NODE_RADIUS * ICON_SCALE
		draw_texture_rect(tex, Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)), false, color)
	else:
		var glyph: String = style["glyph"]
		var w := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(_font, p + Vector2(-w / 2.0, 5.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	# 184：出生点在右上插一面小旗（182 的那面）
	if graph.entry_ids.has(n.id):
		var flag := UiTheme.art_cached(UiTheme.ART_LEGEND_FLAG)
		if flag != null:
			draw_texture_rect(flag, Rect2(p + Vector2(NODE_RADIUS * 0.35, -NODE_RADIUS * 1.75), Vector2(24.0, 24.0)), false)
	# 「这里有可看的内容」的标记位（5.10，内容归 M4）：random 没有 —— 那是地图上唯一看不透的点
	if n.type != &"random" and not n.is_visited() and not MapNodeTypes.STRUCTURAL.has(n.type):
		draw_circle(p + Vector2(-NODE_RADIUS + 3.0, -NODE_RADIUS + 3.0), 2.0, Color(_ink(UiPalette.FG), 0.6))
	# 127：进阶搜索点 —— 左下角一个琥珀色角标
	if n.type == &"search" and not n.is_visited() and SearchSession.is_advanced(n):
		var c := p + Vector2(-NODE_RADIUS + 2.0, NODE_RADIUS - 2.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 4), c + Vector2(4, 4), c + Vector2(0, -4)]), UiPalette.STAMINA)
	# 危险等级：右上角几个红点
	for k in n.danger:
		draw_circle(p + Vector2(NODE_RADIUS - 2.0 - 6.0 * k, -NODE_RADIUS + 1.0), 2.5, UiPalette.HP)
	# 092：倒计时过半关闭的撤离点 —— 关了画红叉 + 「已关闭」，没关写着「倒计时剩 n 时关闭」（193 补充一：n 是关闭时倒计时的读数）
	if not closing.is_empty() and int(closing.get("id", -1)) == n.id:
		var closed := bool(closing.get("closed", false))
		var text := UiText.t("map.extract_closed") if closed else UiText.t("map.extract_closes_at") % int(closing.get("at", 0))
		var col := UiPalette.HP if closed else UiPalette.STAMINA
		if closed:
			var d := NODE_RADIUS * 0.8
			draw_line(p + Vector2(-d, -d), p + Vector2(d, d), col, 3.0, true)
			draw_line(p + Vector2(-d, d), p + Vector2(d, -d), col, 3.0, true)
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_rect(Rect2(p + Vector2(-tw / 2.0 - 4.0, NODE_RADIUS + 6.0), Vector2(tw + 8.0, 17.0)), Color(UiPalette.PANEL, 0.9))
		draw_string(_font, p + Vector2(-tw / 2.0, NODE_RADIUS + 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


## 底图是浅纸时，按深底配的前景 / 暗色字换成字色模板的浅版（169）
func _ink(c: Color) -> Color:
	return UiPalette.for_tone(c, UiTheme.TONE_LIGHT if _skin_light else UiTheme.TONE_DARK)


## 现在的底是不是浅的（测试看）
func skin_is_light() -> bool:
	return _skin_light
#endregion


#region 184：棋子、可走的墨路、跟镜头、离屏指示
## 走了一步（[member current_id] 已经是新点）：棋子从 [param from_id] 跳过去（传送是旧处淡出、新处淡入）。
## 不播动画 / 不知道旧点在哪 = 直接站上去
func hop_from(from_id: int, teleport: bool = false) -> void:
	_hop = {}
	_land_t = -1.0
	var pos := positions()
	if not animate_moves or from_id < 0 or from_id == current_id or not pos.has(from_id) or not pos.has(current_id) or not is_inside_tree():
		return
	_hop = {"from": pos[from_id], "to": pos[current_id], "t": 0.0, "teleport": teleport}


func hopping() -> bool:
	return not _hop.is_empty()


## 跳直接到头（落地那一下也省了）
func finish_hop() -> void:
	var was := not _hop.is_empty() and not bool(_hop.get("teleport", false))
	_hop = {}
	_land_t = 0.0 if was and animate_moves else -1.0
	queue_redraw()


func _hop_total() -> float:
	return TELEPORT_FADE * 2.0 if bool(_hop.get("teleport", false)) else HOP_SEC


## 棋子现在立在哪（屏幕坐标，脚底中心）与透明度；没人 = 空
func pawn_at() -> Dictionary:
	var pos := positions()
	if current_id < 0 or not pos.has(current_id):
		return {}
	if _hop.is_empty():
		return {"at": to_screen(pos[current_id]), "alpha": 1.0}
	var t := float(_hop["t"])
	var a := to_screen(_hop["from"])
	var b := to_screen(_hop["to"])
	if bool(_hop["teleport"]):
		if t < TELEPORT_FADE:
			return {"at": a, "alpha": 1.0 - t / TELEPORT_FADE}
		return {"at": b, "alpha": clampf((t - TELEPORT_FADE) / TELEPORT_FADE, 0.0, 1.0)}
	var k := clampf(t / HOP_SEC, 0.0, 1.0)
	return {"at": a.lerp(b, k) + Vector2(0.0, -HOP_LIFT * 4.0 * k * (1.0 - k)), "alpha": 1.0}


## 走一步之后：人出了安全区中央那三分之一，镜头平移（缩放不动）把他带回中央；在里面不动。返回动没动
func follow_current(animate: bool = true) -> bool:
	if graph == null or current_id < 0 or size.x <= 0.0 or size.y <= 0.0 or _open_pending or node_front != INF:
		return false
	var pos := positions()
	if not pos.has(current_id):
		return false
	var safe := safe_rect()
	var band := Rect2(safe.position + safe.size * (1.0 - FOLLOW_BAND) * 0.5, safe.size * FOLLOW_BAND)
	if band.has_point(to_screen(pos[current_id])):
		return false
	var target := focus_pan(current_id)
	if target.distance_to(pan) < 1.0:
		return false     # 人在图边上：画布不往外拖出空边，已经是能摆到最中间的地方了
	_pan_to(target, animate)
	return true


## 平移回自己（离屏指示点了）：缩放不动
func recenter_on_player() -> void:
	if current_id >= 0:
		_pan_to(focus_pan(current_id), animate_moves)


func _pan_to(target: Vector2, animate: bool) -> void:
	stop_follow()
	if not animate or not animate_moves or not is_inside_tree():
		pan = target
		_clamp_pan()
		queue_redraw()
		return
	_follow_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_follow_tween.tween_property(self, ^"pan", target, FOLLOW_SEC)
	_follow_tween.finished.connect(_clamp_pan)


## 镜头正在跟人
func following() -> bool:
	return _follow_tween != null and _follow_tween.is_valid() and _follow_tween.is_running()


## 玩家自己动了镜头（拖、滚轮、看全图……）：正在跟的那一下作罢
func stop_follow() -> void:
	if _follow_tween != null:
		_follow_tween.kill()
		_follow_tween = null


## 离屏指示在哪（屏幕坐标的矩形）；人在屏上 / 正在跟 = 空矩形
func offscreen_rect() -> Rect2:
	var at := _offscreen_point()
	if at == Vector2.INF:
		return Rect2()
	return Rect2(at - Vector2(OFFSCREEN_SIZE, OFFSCREEN_SIZE) * 0.5, Vector2(OFFSCREEN_SIZE, OFFSCREEN_SIZE))


func _offscreen_point() -> Vector2:
	var pos := positions()
	if current_id < 0 or not pos.has(current_id) or following() or not _hop.is_empty() or node_front != INF:
		return Vector2.INF
	var safe := safe_rect()
	var p := to_screen(pos[current_id])
	if visible_rect().has_point(p):     # 人看得见就不指（底下两角的读数只占角落，夹在中间的人照样看得见）
		return Vector2.INF
	var inner := safe.grow(-OFFSCREEN_INSET)
	var c := inner.get_center()
	var d := p - c
	var k := INF
	for i in 2:
		if absf(d[i]) > 0.001:
			k = minf(k, (inner.size[i] * 0.5) / absf(d[i]))
	return c + d * minf(k, 1.0)


## 屏幕坐标的那一层：可走的路 → 终点墨环 → 步数签 → 棋子 → 离屏指示（棋子永远压在最上）
func _draw_player_layer(pos: Dictionary, grow: Dictionary, rect: Rect2) -> void:
	if current_id < 0 or not pos.has(current_id):
		return
	var ink := _ink(UiPalette.FG)
	if grow.is_empty() and _hop.is_empty():     # 跳的时候路先不画，落地那一帧和人一起出现
		var tags: Array[Rect2] = []
		var from_sp := to_screen(pos[current_id])
		for id in reachable:
			if not pos.has(id):
				continue
			var hot := int(id) == _hover_id
			var to_sp := to_screen(pos[id])
			var cost := int(reach_cost.get(id, 1))
			var mid := to_sp
			if bool(reach_teleport.get(id, false)):
				mid = to_sp + Vector2(END_RING_R + 30.0, 0.0)
				_draw_tag(UiText.t("map.tag_teleport"), mid, tags)
			else:
				var e := MapNavigator.edge_for_step(graph, current_id, int(id))
				var pts := PackedVector2Array([pos[current_id], pos[id]])
				if e != null:
					pts = _layout.edge_points(graph, e, pos[current_id], pos[id], rect)
				var sp := PackedVector2Array()
				for q in pts:
					sp.append(to_screen(q))
				sp = _trim(sp, NODE_RADIUS + 4.0, NODE_RADIUS + 4.0)
				if sp.size() >= 2:
					_march_line(sp, PATH_W_HOVER if hot else PATH_W, Color(ink, 1.0 if hot else 0.85), _march)
					mid = _point_at(sp, _length(sp) * 0.5)
				if cost > 1:
					_draw_tag(step_tag(cost), mid, tags)
			var r := END_RING_R + 2.0 * sin(_pulse)
			draw_arc(to_sp, r, 0.0, TAU, 48, Color(ink, 1.0 if hot else 0.6), END_RING_W, true)
	var pawn := pawn_at()
	if not pawn.is_empty():
		var alpha := float(pawn["alpha"]) * (float(grow.get(current_id, 1.0)) if not grow.is_empty() else 1.0)
		var squash := 1.0
		if _land_t >= 0.0:
			squash = lerpf(LAND_SQUASH, 1.0, clampf(_land_t / LAND_SEC, 0.0, 1.0))
		_draw_pawn(pawn["at"], PAWN_H, alpha, squash, UiTheme.ART_MAP_PAWN)
	var off := _offscreen_point()
	if off != Vector2.INF:
		var target := to_screen(pos[current_id])
		var dir := (target - off).normalized()
		var tip := off + dir * (OFFSCREEN_SIZE * 0.5 + 10.0)
		var side := dir.orthogonal() * 6.0
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 10.0 + side, tip - dir * 10.0 - side]), Color(ink, 0.85))
		draw_circle(off, OFFSCREEN_SIZE * 0.5, Color(UiTheme.PAPER, 0.85))
		draw_arc(off, OFFSCREEN_SIZE * 0.5, 0.0, TAU, 32, Color(ink, 0.85), 1.5, true)
		_draw_pawn(off + Vector2(0.0, OFFSCREEN_SIZE * 0.3), OFFSCREEN_SIZE * 0.8, 0.85, 1.0, UiTheme.ART_MAP_PAWN_SMALL)


## 一枚棋子：脚底中心（图的 json `anchor`）对准 [param foot]，高 [param h]；脚下一枚淡影。没图画一个墨线的小兵
func _draw_pawn(foot: Vector2, h: float, alpha: float, squash: float, art_name: String) -> void:
	if alpha <= 0.0:
		return
	var shadow := PackedVector2Array()
	for k in 20:
		var a := TAU * float(k) / 20.0
		shadow.append(foot + Vector2(cos(a) * PAWN_SHADOW.x * 0.5 * h / PAWN_H, sin(a) * PAWN_SHADOW.y * 0.5 * h / PAWN_H))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.2 * alpha))
	var tex := UiTheme.art_cached(art_name)
	if tex != null:
		draw_texture_rect(tex, pawn_rect(foot, h, squash, art_name), false, Color(1, 1, 1, alpha))
		return
	var ink := Color(_ink(UiPalette.FG), alpha)
	var paper := Color(UiTheme.PAPER, alpha)
	var u := h / 10.0 * Vector2(1.0, squash)
	var body := PackedVector2Array([foot + Vector2(-2.5, 0) * u, foot + Vector2(2.5, 0) * u, foot + Vector2(1.2, -5) * u, foot + Vector2(-1.2, -5) * u])
	draw_colored_polygon(body, paper)
	body.append(body[0])
	draw_polyline(body, ink, 1.5, true)
	var head := foot + Vector2(0, -6.6) * u
	draw_circle(head, 1.8 * u.x, paper)
	draw_arc(head, 1.8 * u.x, 0.0, TAU, 24, ink, 1.5, true)


## 棋子图画在哪（屏幕坐标）：高 [param h]，图的 `anchor`（脚底中心，json 里按 `size` 的逻辑尺寸给）对准 [param foot]。只看像素，和缩放无关
func pawn_rect(foot: Vector2, h: float = PAWN_H, squash: float = 1.0, art_name: String = UiTheme.ART_MAP_PAWN) -> Rect2:
	var tex := UiTheme.art_cached(art_name)
	var meta := UiTheme.art_meta(art_name)
	var sz: Array = meta.get("size", [tex.get_width(), tex.get_height()] if tex != null else [h, h])
	var anchor: Array = meta.get("anchor", [float(sz[0]) * 0.5, float(sz[1])])
	var k := h / float(sz[1])
	return Rect2(foot - Vector2(float(anchor[0]) * k, float(anchor[1]) * k * squash), Vector2(float(sz[0]) * k, float(sz[1]) * k * squash))


## 步数 / 传送的小纸签，中心在 [param at]；和已经摆了的签叠上就往下错开
func _draw_tag(text: String, at: Vector2, placed: Array[Rect2]) -> void:
	if _font == null:
		return
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT).x
	var box := Rect2(at - Vector2(tw * 0.5 + 8.0, TAG_H * 0.5), Vector2(tw + 16.0, TAG_H))
	var guard := 0
	while placed.any(func(r: Rect2) -> bool: return r.intersects(box)) and guard < 6:
		box.position.y += TAG_NUDGE
		guard += 1
	placed.append(box)
	var tex := UiTheme.art_cached(UiTheme.ART_MAP_TAG)
	if tex != null:
		var m: Array = UiTheme.art_meta(UiTheme.ART_MAP_TAG).get("margin", [6, 4, 6, 4])
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = float(m[0])
		sb.texture_margin_top = float(m[1])
		sb.texture_margin_right = float(m[2])
		sb.texture_margin_bottom = float(m[3])
		draw_style_box(sb, box)
	else:
		draw_rect(box, Color(UiTheme.PAPER, 0.9))
		draw_rect(box, Color(UiTheme.INK, 0.6), false, 1.0)
	draw_string(_font, Vector2(box.position.x + 8.0, box.position.y + TAG_H * 0.5 + TAG_FONT * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT, UiTheme.INK)


## 摆过的签（测试看）：这一帧画了哪些字
func tags_text() -> Array[String]:
	var out: Array[String] = []
	if current_id < 0 or not _hop.is_empty():
		return out
	for id in reachable:
		if bool(reach_teleport.get(id, false)):
			out.append(UiText.t("map.tag_teleport"))
		elif int(reach_cost.get(id, 1)) > 1:
			out.append(step_tag(int(reach_cost.get(id, 1))))
	return out


## 墨路上的「计二步」签（221 F1：按当前语言；数写成字，十以上写数字）
static func step_tag(cost: int) -> String:
	return UiText.t("map.tag_steps") % _count_word(cost)


## 汉字的数（测试照它对「计N步」的中文）
static func _han(n: int) -> String:
	const DIGITS := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	return DIGITS[n] if n >= 0 and n <= 10 else str(n)


## 当前语言的数（中文同 [method _han]）
static func _count_word(n: int) -> String:
	var words := UiText.t("map.count_words").split(",")
	return words[n] if n >= 0 and n < words.size() else str(n)


## 行进的虚线：段 [constant PATH_DASH]、隙 [constant PATH_GAP]，整串往离开玩家的方向挪 [param phase] 像素
func _march_line(pts: PackedVector2Array, width: float, color: Color, phase: float) -> void:
	var total := _length(pts)
	var period := PATH_DASH + PATH_GAP
	var d := fposmod(phase, period) - period
	while d < total:
		var a := maxf(d, 0.0)
		var b := minf(d + PATH_DASH, total)
		if b > a:
			draw_polyline(_sub_line(pts, a, b), color, width, true)
		d += period


static func _length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


## 折线上离起点 [param d] 处的点
static func _point_at(pts: PackedVector2Array, d: float) -> Vector2:
	var left := d
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if left <= seg and seg > 0.0:
			return pts[i - 1].lerp(pts[i], left / seg)
		left -= seg
	return pts[pts.size() - 1]


## 折线上 [param a]～[param b] 那一截
static func _sub_line(pts: PackedVector2Array, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array([_point_at(pts, a)])
	var walked := 0.0
	for i in range(1, pts.size()):
		walked += pts[i - 1].distance_to(pts[i])
		if walked > a and walked < b:
			out.append(pts[i])
	out.append(_point_at(pts, b))
	return out


## 两头各剪掉一截（从节点边缘起、到节点边缘止）；剪没了返回空
static func _trim(pts: PackedVector2Array, head: float, tail: float) -> PackedVector2Array:
	var total := _length(pts)
	if total <= head + tail:
		return PackedVector2Array()
	return _sub_line(pts, head, total - tail)
#endregion
