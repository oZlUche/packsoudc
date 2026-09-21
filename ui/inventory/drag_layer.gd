## 拖拽状态机。管理所有已注册的 [InventoryView]，负责跨容器拖拽、拖拽中旋转、
## 落点合法性预览，以及任何失败路径下把物品放回原处。
##
## 刻意不用 Godot 内置的 _get_drag_data / _can_drop_data：
## 那套 API 在拖拽过程中无法响应旋转键，也做不出多格落点高亮。
##
## 抓取时就把物品从源容器移除，因此拖拽期间物品不在任何容器里 ——
## 本层持有它的强引用（ItemInstance 是 RefCounted），任何退出路径都必须把它安置好。
##
## 拖「包」时内容物跟着一起走：抓取走 [method GridInventory.detach_bag]，
## 放手走 [method GridInventory.attach_bag]，载荷存在 [member _payload] 里。
class_name DragLayer
extends Control

signal drag_started(uid: int)
signal drag_finished(uid: int, dropped: bool)
## 放下时顶出来了东西。[param grabbed] 为真表示那一件已经拿在手上，
## 否则整批都进了 [member stash]。界面拿它写提示。
signal items_displaced(instances: Array, grabbed: bool)

@export var label_font: Font

## 顶出来一次多于一件时的去处。为空则这类落点直接拒绝 ——
## 宁可这一下不生效，也不能让物品没地方去。
var stash: GridInventory = null

var _views: Array[InventoryView] = []

var _inst: ItemInstance = null
var _source: GridInventory = null
var _src_origin: Vector2i = Vector2i.ZERO
var _src_rot: int = 0
## 抓取点相对物品 origin 的格偏移，拖拽时用它反推落点
var _grab_cell: Vector2i = Vector2i.ZERO
var _rot: int = 0
## 非空表示正在拖一个带内容物的包，内容为 detach_bag 的载荷
var _payload: Dictionary = {}


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

	if _source.is_bag_with_contents(uid):
		_payload = _source.detach_bag(uid)
		if _payload.is_empty():
			_source = null
			return
	elif _source.remove(uid) == null:
		_source = null
		return

	_inst = inst
	set_process_input(true)
	queue_redraw()
	drag_started.emit(uid)


## 让一件**已经游离**的物品直接上手。顶替时被挤出来的那一件走这条路 ——
## 它此刻不在任何容器里，没有 view 可以「按下」。
##
## [param home] / [param home_rot] 只用于取消时的回退落点，不保证还回得去。
func grab_free(inst: ItemInstance, home: GridInventory, home_at: Vector2i, home_rot: int,
		grab_cell: Vector2i) -> void:
	if is_dragging() or inst == null or inst.def == null:
		return
	var box := inst.def.shape.size_rotated(inst.rotation)
	_grab_cell = Vector2i(
		clampi(grab_cell.x, 0, maxi(0, box.x - 1)),
		clampi(grab_cell.y, 0, maxi(0, box.y - 1))
	)
	_src_origin = home_at
	_src_rot = home_rot
	_rot = inst.rotation
	_source = home
	_payload = {}
	_inst = inst
	set_process_input(true)
	if is_inside_tree():
		update_preview(get_global_mouse_position())
	queue_redraw()
	drag_started.emit(inst.uid)


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


## 拖拽中顺时针转一步。带内容物的包不能转，与 GridInventory.rotate_item 的限制一致。
func rotate_dragged() -> void:
	if _inst == null or _inst.def == null or not _inst.def.can_rotate:
		return
	if not _payload.is_empty():
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
	var inv := target.inventory
	var cells := _inst.def.cells_rotated(_rot)
	var origin := target_origin(target, global_pos)

	if not _payload.is_empty():
		target.set_preview(cells, origin, inv.can_attach_bag(_payload, origin, _rot))
		return

	if inv.can_place_def(_inst.def, origin, _rot, _inst.uid):
		target.set_preview(cells, origin, true)
		return

	# 放不进空位，但地形允许 —— 那就是「压着别人」，可以顶替
	var victims := _displaceable(inv, origin)
	target.set_preview(cells, origin, not victims.is_empty(), victims)


## 在指定位置放手。返回是否成功落入某个容器（否则已退回源容器）。
func drop_at(global_pos: Vector2) -> bool:
	if not is_dragging():
		return false
	var inst := _inst
	var dropped := false
	var target := view_at(global_pos)

	# 顶替留到本次拖拽收尾之后再处理：被顶出来的那一件要接着上手，
	# 而上手的前提是当前这一次已经彻底结束
	var pending: Array = []
	var home: GridInventory = null

	if target != null and target.inventory != null:
		var at := target_origin(target, global_pos)
		if not _payload.is_empty():
			dropped = target.inventory.attach_bag(_payload, at, _rot)
		elif target.inventory.place(inst, at, _rot):
			dropped = true
		else:
			# 「顶成功但一件没顶到」不可能发生（放不进空位才会走到这儿），
			# 但成败不能靠数组空不空来推断 —— 那是把不变式当接口用。
			var outcome := _drop_displacing(target.inventory, inst, at)
			dropped = outcome["ok"]
			pending = outcome["victims"]
		if dropped:
			home = target.inventory

	if not dropped:
		_restore()

	_end_drag()
	drag_finished.emit(inst.uid, dropped)

	if not pending.is_empty():
		_settle_displaced(pending, home, global_pos)
	return dropped


## 顶替式放下。返回 [code]{"ok": bool, "victims": Array}[/code]；
## 失败时容器保持原样。
func _drop_displacing(inv: GridInventory, inst: ItemInstance, at: Vector2i) -> Dictionary:
	var failed := {"ok": false, "victims": []}
	if _displaceable(inv, at).is_empty():
		return failed

	# 原位先记下来。remove 不清 origin，但依赖那个残值等于依赖实现细节 —— 显式抄一份。
	var homes := {}
	for uid in inv.displaced_by(inst.def, at, _rot, inst.uid):
		var v := inv.get_item(uid)
		if v != null:
			homes[uid] = [v.origin, v.rotation]

	var victims = inv.place_displacing(inst, at, _rot)
	if victims == null:
		return failed
	if victims.size() < 2:
		return {"ok": true, "victims": victims}

	# 多于一件：全部进暂存区，进不去就整件事作废。
	# 只塞进去一半、另一半留在手上，玩家根本追不过来。
	if stash != null and _admit_all(stash, victims):
		return {"ok": true, "victims": victims}

	inv.begin_batch()
	inv.remove(inst.uid)
	for v in victims:
		var h: Array = homes[(v as ItemInstance).uid]
		if not inv.place(v, h[0], h[1]):
			push_error("DragLayer: uid %d 放不回原位，物品已丢失" % (v as ItemInstance).uid)
	inv.end_batch()
	return failed


## 安置被顶出来的物品：一件就直接拿在手上，多于一件已经在暂存区了。
##
## 「一件就上手」是因为那几乎总是接下来要挪的东西 —— 顶掉它再去暂存区里翻出来，
## 中间那两下纯属多余。
func _settle_displaced(victims: Array, home: GridInventory, global_pos: Vector2) -> void:
	if victims.size() == 1:
		var v := victims[0] as ItemInstance
		var view := view_at(global_pos)
		var cell := view.cell_at_global(global_pos) if view != null else v.origin
		grab_free(v, home, v.origin, v.rotation, cell - v.origin)
		items_displaced.emit(victims, true)
		return
	items_displaced.emit(victims, false)


## 这个落点能顶掉哪些：地形得允许，且确实压着别人。
## 多于一件时还要有地方安置，否则不算可顶 —— 预览就该是红的，不该给出做不到的承诺。
func _displaceable(inv: GridInventory, origin: Vector2i) -> Array[int]:
	var none: Array[int] = []
	if _inst == null or not _payload.is_empty():
		return none
	if not inv.terrain_allows(_inst.def, origin, _rot):
		return none
	var victims := inv.displaced_by(_inst.def, origin, _rot, _inst.uid)
	if victims.size() >= 2 and stash == null:
		return none
	return victims


## 整批塞进目标容器：有一件放不下就整批退回。
static func _admit_all(dest: GridInventory, items: Array) -> bool:
	dest.begin_batch()
	var done: Array[ItemInstance] = []
	for it in items:
		if dest.try_add(it):
			done.append(it)
			continue
		for placed in done:
			dest.remove(placed.uid)
		dest.end_batch()
		return false
	dest.end_batch()
	return true


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
	if not _payload.is_empty():
		if not _source.attach_bag(_payload, _src_origin, _src_rot):
			push_error("DragLayer: 包 uid %d 连内容物放不回源容器，已丢失" % _inst.uid)
		return
	if _source.place(_inst, _src_origin, _src_rot):
		return
	# 原位没了（顶替之后取消，多半如此）。依次退而求其次，
	# 每一级都比上一级更不合玩家心意，但都好过物品凭空消失。
	push_warning("DragLayer: uid %d 无法放回原位，改为自动装填" % _inst.uid)
	if _source.try_add(_inst):
		return
	if stash != null and stash.try_add(_inst):
		return
	push_error("DragLayer: uid %d 放不回源容器，物品已丢失" % _inst.uid)


func _end_drag() -> void:
	for view in _views:
		view.clear_preview()
	_inst = null
	_source = null
	_payload = {}
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

	var font := label_font if label_font != null else get_theme_default_font()
	var is_bag := not _payload.is_empty()

	var body := (
		InventoryView.COLOR_BAG_FILL if is_bag else ItemPainter.body_color(_inst.def)
	)
	body.a = 0.85
	var edge := (
		InventoryView.COLOR_BAG_EDGE if is_bag else ItemPainter.rarity_color(_inst.def)
	)
	ItemPainter.draw_item(self, cells, anchor, InventoryView.CELL, body, edge)
	ItemPainter.draw_label(
		self, cells, anchor, InventoryView.CELL,
		_inst.def.display_name, font, 11 if is_bag else 13, Color("f2f4f8")
	)

	# 包里的东西要跟着残影一起画，否则玩家看不出自己正拖着什么
	if is_bag:
		var contents: Array = _payload["contents"]
		var offsets: Array = _payload["offsets"]
		for i in contents.size():
			var item: ItemInstance = contents[i]
			var at: Vector2 = anchor + Vector2(offsets[i]) * InventoryView.CELL
			var c_body := ItemPainter.body_color(item.def)
			c_body.a = 0.9
			ItemPainter.draw_item(
				self, item.cells(), at, InventoryView.CELL,
				c_body, ItemPainter.rarity_color(item.def)
			)
			ItemPainter.draw_label(
				self, item.cells(), at, InventoryView.CELL,
				item.def.display_name, font, 12, Color("f2f4f8")
			)
