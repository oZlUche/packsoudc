## 地上（128，作者定）：不画地上框 —— 格子外的整块屏幕就是「地上」，拖出背包放哪就在哪。
##
## 画的是一个 [ItemStash]：每件按它的形状画在自己的落点上（[member ItemStash.spots]，归一化坐标，乘回本控件尺寸），
## 和棋盘同一套画法、同一个格子尺寸，所以「放下去是什么样就是什么样」。允许重叠，后放的在上；没有框、没有标题、没有滚动条。
## 落点**只是样子**：不占格、不碰撞、不参与任何规则（3.4）。
##
## 两种用法：
## [codeblock]
## fills_screen = true   导演持有的那一层（一个节点一层）：铺满视口，盖在所有屏上面；只有道具本身接鼠标，
##                       拖拽层把它当「棋盘外」—— 放手在哪就落在哪（[method DragLayer.drop_at]）
## fills_screen = false  一块普通的落点区域（开局屏、沙盒）：拖进这块就落在放手点
## [endcodeblock]
##
## 各屏向它登记自己占住的面板（[method reserve]）：地上的东西被面板盖住就往最近的空处推开，面板关了也不挪回。
class_name GroundLayer
extends ContainerView

## 自动推开时离面板留的空（像素）
const PUSH_GAP := 6.0
const COLOR_HIGHLIGHT := Color(0.42, 0.86, 0.52)

## 导演持有的那一层（没有 = null：测试、沙盒）。各屏开拖拽时拿它登记
static var _current: GroundLayer = null

@export var label_font: Font

var stash: ItemStash:
	set = set_stash
## 见类注释
var fills_screen: bool = false
## 085：亮一圈的（uid → true）：拖着的那件能和它合成。拖拽层设
var highlights: Dictionary = {}
## 登记占着地方的面板
var _reserved: Array[Control] = []
var tip: HoverTip = null
## 接着这层地的拖拽层（后接的在上）。好几块面板同时开着时（地图上的背包浮窗 + 叠层），只有最上面那块接地上的抓取 / 双击
var _drags: Array[DragLayer] = []


static func current() -> GroundLayer:
	return _current if _current != null and is_instance_valid(_current) else null


## 导演设 / 撤
static func set_current(layer: GroundLayer) -> void:
	_current = layer


func attach(drag: DragLayer) -> void:
	_drags.erase(drag)
	_drags.append(drag)


func detach(drag: DragLayer) -> void:
	_drags.erase(drag)


## 现在接地上抓取的那个拖拽层（没人接 = null：谁都能抓，测试里就是这样）
func top_drag() -> DragLayer:
	for i in range(_drags.size() - 1, -1, -1):
		if is_instance_valid(_drags[i]) and _drags[i].is_inside_tree():
			return _drags[i]
	return null


func _init() -> void:
	auto_tooltip = false     # 自己带一个悬浮窗（画在地上的东西上面）
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	super._ready()
	tip = HoverTip.new(label_font if label_font != null else UiPalette.cjk_font())
	add_child(tip)
	tip.watch(self)
	resized.connect(_on_resized)
	_on_resized()


func set_stash(s: ItemStash) -> void:
	if stash == s:
		return
	if stash != null and stash.changed.is_connected(queue_redraw):
		stash.changed.disconnect(queue_redraw)
	stash = s
	if stash != null:
		stash.changed.connect(queue_redraw)
		_sync_norms()
	queue_redraw()


func container() -> ItemContainer:
	return stash


func _on_resized() -> void:
	_sync_norms()
	queue_redraw()


## 把一格的大小和面板占的地方换成归一化坐标告诉 stash（自动铺放用）
func _sync_norms() -> void:
	if stash == null or size.x <= 0.0 or size.y <= 0.0:
		return
	stash.cell_norm = Vector2(InventoryView.CELL / size.x, InventoryView.CELL / size.y)
	var norm: Array[Rect2] = []
	for r in reserved_rects():
		norm.append(Rect2(r.position / size, r.size / size))
	stash.avoid = norm


#region 坐标
## 本控件内像素 → 落点（归一化）
func to_spot(local_px: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(clampf(local_px.x / size.x, 0.0, 1.0), clampf(local_px.y / size.y, 0.0, 1.0))


## 一件道具的包围盒尺寸（像素）
static func span_px(inst: ItemInstance, rot: int) -> Vector2:
	var hi := Vector2i.ZERO
	if inst != null and inst.def != null:
		for c in inst.def.cells_rotated(rot):
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Vector2(hi + Vector2i.ONE) * InventoryView.CELL


## 一件画在哪（本控件内像素）：落点乘回尺寸，再整块夹进屏里 —— 换了窗口大小东西也还在屏内
func item_rect(uid: int) -> Rect2:
	var inst := stash.get_item(uid) if stash != null else null
	if inst == null:
		return Rect2()
	return _fit(Rect2(stash.spot_of(uid) * size, span_px(inst, inst.rotation)))


func _fit(r: Rect2) -> Rect2:
	var p := Vector2(
		clampf(r.position.x, 0.0, maxf(0.0, size.x - r.size.x)),
		clampf(r.position.y, 0.0, maxf(0.0, size.y - r.size.y)))
	return Rect2(p, r.size)


## 鼠标下最上面那一件（后放的在上）；没有 -1
func uid_at_local(p: Vector2) -> int:
	if stash == null:
		return -1
	var list := stash.items()
	for i in range(list.size() - 1, -1, -1):
		var inst := list[i] as ItemInstance
		var r := item_rect(inst.uid)
		if not r.has_point(p):
			continue
		var cell := Vector2i(((p - r.position) / InventoryView.CELL).floor())
		if inst.def.cells_rotated(inst.rotation).has(cell):
			return inst.uid
	return -1


## 抓在这一件的哪一格（拖拽层反推落点用）
func grab_cell_at(uid: int, local: Vector2) -> Vector2i:
	var r := item_rect(uid)
	if r.size == Vector2.ZERO:
		return Vector2i.ZERO
	var c := Vector2i(((local - r.position) / InventoryView.CELL).floor())
	var span := Vector2i(r.size / InventoryView.CELL)
	return Vector2i(clampi(c.x, 0, maxi(0, span.x - 1)), clampi(c.y, 0, maxi(0, span.y - 1)))


## 放手：残影左上角在 [param global_top_left]，这件（朝向 [param rot]）该落在哪（归一化）。
## 压在登记的面板上就往最近的空处推开（128 §2.4）
func spot_for_drop(global_top_left: Vector2, inst: ItemInstance, rot: int) -> Vector2:
	var r := _fit(Rect2(global_top_left - global_position, span_px(inst, rot)))
	return to_spot(push_out(r).position)


func _has_point(point: Vector2) -> bool:
	if not fills_screen:
		return Rect2(Vector2.ZERO, size).has_point(point)
	# 铺满屏的那一层只有道具本身接鼠标，空地上的点击穿下去给各屏
	return uid_at_local(point) >= 0
#endregion


#region 面板占地
## 登记一块占着地方的面板（各屏打开时）；它离开树就自动撤销
func reserve(panel: Control) -> void:
	if panel == null or _reserved.has(panel):
		return
	_reserved.append(panel)
	panel.resized.connect(_settle_deferred)
	panel.visibility_changed.connect(_settle_deferred)
	panel.tree_exited.connect(func(): unreserve(panel))
	_settle_deferred()


func unreserve(panel: Control) -> void:
	if not _reserved.has(panel):
		return
	_reserved.erase(panel)
	if is_instance_valid(panel):
		if panel.resized.is_connected(_settle_deferred):
			panel.resized.disconnect(_settle_deferred)
		if panel.visibility_changed.is_connected(_settle_deferred):
			panel.visibility_changed.disconnect(_settle_deferred)
	_sync_norms()


## 现在占着地方的面板（本控件内像素）
func reserved_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for panel in _reserved:
		if is_instance_valid(panel) and panel.is_inside_tree() and panel.is_visible_in_tree():
			var r := panel.get_global_rect()
			if r.size.x > 0.0 and r.size.y > 0.0:
				out.append(Rect2(r.position - global_position, r.size))
	return out


## 一块压在面板上就推到最近的空处（上下左右各试一下，取挪得最少、不压别的面板、在屏内的）；推不开原样返回
func push_out(r: Rect2) -> Rect2:
	var blocks := reserved_rects()
	for _round in 4:
		var hit := Rect2()
		var found := false
		for b in blocks:
			if b.intersects(r):
				hit = b
				found = true
				break
		if not found:
			return r
		var tries: Array[Vector2] = [
			Vector2(hit.position.x - r.size.x - PUSH_GAP, r.position.y),
			Vector2(hit.end.x + PUSH_GAP, r.position.y),
			Vector2(r.position.x, hit.position.y - r.size.y - PUSH_GAP),
			Vector2(r.position.x, hit.end.y + PUSH_GAP),
		]
		var best := Rect2()
		var best_d := INF
		for p in tries:
			var cand := Rect2(p, r.size)
			if cand.position.x < 0.0 or cand.position.y < 0.0 or cand.end.x > size.x or cand.end.y > size.y:
				continue
			var clear := true
			for b in blocks:
				if b.intersects(cand):
					clear = false
					break
			var d := p.distance_to(r.position) + (0.0 if clear else 100000.0)
			if d < best_d:
				best_d = d
				best = cand
		if best_d == INF:
			return r
		r = best
	return r


func _settle_deferred() -> void:
	settle.call_deferred()


## 被面板盖住的东西推开（面板关了也不挪回）
func settle() -> void:
	if not is_instance_valid(self):
		return
	_sync_norms()
	if is_inside_tree() and not is_visible_in_tree():
		return     # 地藏着（战斗回放之类）时不挪
	if stash == null or size.x <= 0.0 or size.y <= 0.0:
		return
	for inst in stash.items():
		var r := item_rect((inst as ItemInstance).uid)
		var moved := push_out(r)
		if moved.position != r.position:
			stash.set_spot((inst as ItemInstance).uid, to_spot(moved.position))
#endregion


func _gui_input(event: InputEvent) -> void:
	if stash == null or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var uid := uid_at_local(mb.position)
	if uid < 0:
		return
	if mb.double_click:
		item_double_clicked.emit(self, uid)     # 084：双击 = 快速置入棋盘
	else:
		grab_requested.emit(self, uid, mb.position)
	accept_event()


func _draw() -> void:
	if stash == null:
		return
	var font := label_font if label_font != null else get_theme_default_font()
	for one in stash.items():
		var inst := one as ItemInstance
		if inst.def == null:
			continue
		var r := item_rect(inst.uid)
		var cells := inst.def.cells_rotated(inst.rotation)
		var edge := COLOR_HIGHLIGHT if highlights.has(inst.uid) else ItemPainter.rarity_color(inst.def)
		ItemPainter.draw_item(self, cells, r.position, InventoryView.CELL, ItemPainter.body_color(inst.def), edge)
		ItemPainter.draw_label(self, cells, r.position, InventoryView.CELL, Names.of(inst.def), font, 13, ItemPainter.label_color(inst.def))
