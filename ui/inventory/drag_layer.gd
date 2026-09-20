## 拖拽状态机。管理所有已注册的 [InventoryView]，负责跨容器拖拽、拖拽中旋转、
## 落点合法性预览，以及任何失败路径下把物品放回原处。
##
## 刻意不用 Godot 内置的 _get_drag_data / _can_drop_data：
## 那套 API 在拖拽过程中无法响应旋转键，也做不出多格落点高亮。
##
## 抓取时就把物品从源容器移除，因此拖拽期间物品不在任何容器里 ——
## 本层持有它的强引用（ItemInstance 是 RefCounted），任何退出路径都必须把它安置好。
class_name DragLayer
extends Control

signal drag_started(uid: int)
signal drag_finished(uid: int, dropped: bool)

@export var label_font: Font

var _views: Array[InventoryView] = []

var _inst: ItemInstance = null
var _source: GridInventory = null
var _src_origin: Vector2i = Vector2i.ZERO
var _src_rot: int = 0
## 抓取点相对物品 origin 的格偏移，拖拽时用它反推落点
var _grab_cell: Vector2i = Vector2i.ZERO
var _rot: int = 0


func _ready() -> void:
	# 空闲时不能挡住下面的容器接收点击
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)


func register_view(view: InventoryView) -> void:
	if _views.has(view):
		return
	_views.append(view)
	view.grab_requested.connect(_on_grab_requested)


func is_dragging() -> bool:
	return _inst != null


func _on_grab_requested(view: InventoryView, uid: int, local_pos: Vector2) -> void:
	if is_dragging() or view.inventory == null:
		return
	var inst := view.inventory.get_item(uid)
	if inst == null:
		return

	_grab_cell = view.cell_at_local(local_pos) - inst.origin
	_src_origin = inst.origin
	_src_rot = inst.rotation
	_rot = inst.rotation
	_source = view.inventory

	if _source.remove(uid) == null:
		_source = null
		return

	_inst = inst
	set_process_input(true)
	queue_redraw()
	drag_started.emit(uid)


func _input(event: InputEvent) -> void:
	if not is_dragging():
		return

	if event is InputEventMouseMotion:
		update_preview(get_global_mouse_position())
		queue_redraw()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			drop_at(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			cancel()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_R:
			rotate_dragged()
			get_viewport().set_input_as_handled()
		elif key == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()


## 拖拽中顺时针转一步。
func rotate_dragged() -> void:
	if _inst == null or _inst.def == null or not _inst.def.can_rotate:
		return
	_rot = posmod(_rot + 1, 4)
	# 抓取点必须跟着落进新的包围盒，否则旋转后物品会离奇地跳开
	var box := _inst.def.shape.size_rotated(_rot)
	_grab_cell.x = clampi(_grab_cell.x, 0, maxi(0, box.x - 1))
	_grab_cell.y = clampi(_grab_cell.y, 0, maxi(0, box.y - 1))
	# 测试里本控件不在场景树内，取不到鼠标；那时由调用方自行刷新预览
	if is_inside_tree():
		update_preview(get_global_mouse_position())
	queue_redraw()


## 指定全局坐标下的容器视图，没有则返回 null。
func view_at(global_pos: Vector2) -> InventoryView:
	for view in _views:
		if view.visible and view.get_global_rect().has_point(global_pos):
			return view
	return null


## 当前拖拽物在该视图中的落点锚点。
func target_origin(view: InventoryView, global_pos: Vector2) -> Vector2i:
	return view.cell_at_global(global_pos) - _grab_cell


## 按指定鼠标位置刷新落点高亮。
##
## 鼠标位置作为入参而不是内部取，是为了让拖拽逻辑能在没有真实输入的
## 测试里被驱动 —— 否则这整块只能靠手工拖拽验证。
func update_preview(global_pos: Vector2) -> void:
	if not is_dragging():
		return
	var target := view_at(global_pos)
	for view in _views:
		if view != target:
			view.clear_preview()
	if target == null or target.inventory == null:
		return
	var cells := _inst.def.cells_rotated(_rot)
	var origin := target_origin(target, global_pos)
	var ok := target.inventory.accepts(_inst.def) and target.inventory.can_place(cells, origin)
	target.set_preview(cells, origin, ok)


## 在指定位置放手。返回是否成功落入某个容器（否则已退回源容器）。
func drop_at(global_pos: Vector2) -> bool:
	if not is_dragging():
		return false
	var inst := _inst
	var dropped := false
	var target := view_at(global_pos)

	if target != null and target.inventory != null:
		if target.inventory.place(inst, target_origin(target, global_pos), _rot):
			dropped = true

	if not dropped:
		_restore()

	_end_drag()
	drag_finished.emit(inst.uid, dropped)
	return dropped


## 放弃本次拖拽，物品退回源容器。
func cancel() -> void:
	if not is_dragging():
		return
	var inst := _inst
	_restore()
	_end_drag()
	drag_finished.emit(inst.uid, false)


## 放回源容器原位。源容器的那几格在抓取后一直空着，这里必然放得回去；
## 万一放不回（说明别处动过这个容器），退而求其次找个空位，绝不允许物品凭空消失。
func _restore() -> void:
	if _inst == null or _source == null:
		return
	if _source.place(_inst, _src_origin, _src_rot):
		return
	push_warning("DragLayer: uid %d 无法放回原位，改为自动装填" % _inst.uid)
	if not _source.try_add(_inst):
		push_error("DragLayer: uid %d 放不回源容器，物品已丢失" % _inst.uid)


func _end_drag() -> void:
	for view in _views:
		view.clear_preview()
	_inst = null
	_source = null
	set_process_input(false)
	queue_redraw()


func _draw() -> void:
	if not is_dragging():
		return
	var cells := _inst.def.cells_rotated(_rot)
	# 让被抓住的那一格正好压在光标下。
	# Control 没有 to_local()（那是 Node2D 的），用本控件内的鼠标坐标。
	var anchor := get_local_mouse_position() \
		- (Vector2(_grab_cell) + Vector2(0.5, 0.5)) * InventoryView.CELL

	var body := ItemPainter.body_color(_inst.def)
	body.a = 0.85
	ItemPainter.draw_item(
		self, cells, anchor, InventoryView.CELL, body, ItemPainter.rarity_color(_inst.def)
	)
	var font := label_font if label_font != null else get_theme_default_font()
	ItemPainter.draw_label(
		self, cells, anchor, InventoryView.CELL,
		_inst.def.display_name, font, 13, Color("f2f4f8")
	)
