## 拖拽状态机。管理所有已注册的 [ContainerView]，负责跨容器拖拽、拖拽中旋转、
## 落点合法性预览，以及任何失败路径下把物品放回原处。
##
## 视图有两类，落点规则不同，其余一律共用：
##
## [codeblock]
## InventoryView  网格：落点是格坐标，可能压着别人（顶替）
## GroundLayer    地上（128）：落点是放手点（归一化屏幕坐标），永远不会压着谁
## [endcodeblock]
##
## 刻意不用 Godot 内置的 _get_drag_data / _can_drop_data：
## 那套 API 在拖拽过程中无法响应旋转键，也做不出多格落点高亮。
##
## 抓取时就把物品从源容器移除，因此拖拽期间物品不在任何容器里 ——
## 本层持有它的强引用（ItemInstance 是 RefCounted），任何退出路径都必须把它安置好。
##
## 拖「包」时内容物跟着一起走：抓取走 [method GridInventory.detach_bag]，
## 放手走 [method GridInventory.attach_bag]，载荷存在 [member _payload] 里。
## 087（作者定）：**包也能放到地上 / 容器**（列表与自由容器收不下「摆好的一袋」，包进去、内容物脱落到地上），
## **包可以替换包**（压到棋盘上另一个包上：旧包连内容物摘下，内容物到地上、旧包拿在手上，和顶替一件道具同一套感觉）。
class_name DragLayer
extends Control

signal drag_started(uid: int)
signal drag_finished(uid: int, dropped: bool)
## 放下时顶出来了东西。[param grabbed] 为真表示那一件已经拿在手上，
## 否则整批都进了 [member stash]。界面拿它写提示。
signal items_displaced(instances: Array, grabbed: bool)
## 包换了朝向放下，依附不上的内容物脱落进了 [member stash]。
signal items_shed(instances: Array)
## 207：按下去的这件扎了根（或它是被扎根钉住的包），没拿起来。宿主拿它给玩家一句（[constant ROOTED_NOTICE]）
signal grab_refused(uid: int)
## 249：在棋盘外（地上）松手，可这一屏不许往地上放（[member drop_filter] 拦了）—— 东西已经弹回原处。宿主拿它说一句为什么
signal drop_refused(uid: int)

const ROOTED_NOTICE := "notice.rooted"

@export var label_font: Font

## 顶出来一次多于一件时的去处。为空则这类落点直接拒绝 ——
## 宁可这一下不生效，也不能让物品没地方去。
var stash: ItemStash = null
## 「能不能放到那儿」的第二道门（第一道是视图发不发 grab_requested）：`func(inst: ItemInstance, target: ItemContainer) -> bool`，
## 无效 = 哪儿都能放。容器屏用它把没揭示的东西圈在容器里（058 第 5 条：未搜的只能在容器内挪位）
var drop_filter: Callable = Callable()
## 084（作者定）：**棋盘外的空间全都是地上** —— 放手时底下没有任何容器视图，就进 [member stash]（追加在末尾），
## 而不是退回原处。128：登记了铺满屏的 [GroundLayer] 时落点 = 放手点；从地上拿起又放回地上 = 改落点。
## 地上不限大小，所以这一下总能成（被 drop_filter 拦的除外）。
## 一局里的整理面板开它；开局屏（仓库 ↔ 棋盘）不开，那儿放到外面还是退回
var drop_outside_to_stash: bool = false
## 249：顶替顶出两件以上时许不许把它们挤到地上（[member stash]）。战前屏关掉（开战前不丢东西）：这样的落点当放不下
var displace_to_stash: bool = true
## 配方查询 `func(a: ItemInstance, b: ItemInstance) -> ItemDef`：拖起一件时，所有能和它合成的那几件亮一圈；
## 配了 [member craft_drop] 时也用它判「压上去是合成」（预览画绿的，不是顶替）
var craft: Callable = Callable()
## 114（作者定）：**拖到上面立刻合**。`func(a: ItemInstance, b_uid: int) -> bool`：手上的 a 压在 [member craft_grid] 上
## 正好一件 b、两件有配方时放手就调它，成了算放下（a 被消耗）。不给（沙盒、开局屏、基地）= 压上去照常顶替。
## 拖拽层仍然不认识配方，合成那一下在调用方（一局里是 [CraftingModule]）
var craft_drop: Callable = Callable()
## 能合成的那张棋盘（一局里的作战棋盘）。别的格子容器（战利品箱）里压上去照常顶替
var craft_grid: GridInventory = null
## 审查 A1：手上这件许不许拿去合成 `func(inst: ItemInstance) -> bool`。商店给货架上还没付钱的商品返回 false ——
## 否则压到能合的那件上放手，商品在合成里被消耗，结账那一步看不到它，等于白拿。不给 = 都许
var craft_filter: Callable = Callable()
## 140：配方说明 `func(a: ItemInstance, b: ItemInstance) -> String`（作者写的 `note`）。压到能合的那件上时，残影下面一行小字
## 「合成 → 产物：说明」；不给 = 只写产物
var craft_note: Callable = Callable()
## 140：此刻残影下面那行合成提示（没压在能合的那件上 = 空串）。[method update_preview] 算，[method _draw] 画
var craft_hint: String = ""
const HINT_FONT := 13
const HINT_TAG_H := 22.0
## 合成提示的字色：深绿墨（纸签是浅的）
const HINT_INK := Color("2f6b2a")
var _hint_box: StyleBoxTexture = null
## 175 第三批：铸牌附魔 `func(token: ItemInstance, grid: GridInventory, weapon_uid: int) -> bool` —— 手上是铸牌、压在恰好一件武器上，
## 预览画绿的、残影下面写「附魔：嗜血的长剑」，放手就调它（成了算放下，铸牌被消耗）。不给 = 压上去照常顶替
var enchant_drop: Callable = Callable()

var _views: Array[ContainerView] = []

var _inst: ItemInstance = null
var _source: ItemContainer = null
var _src_origin: Vector2i = Vector2i.ZERO
var _src_rot: int = 0
## 源容器是列表时的原行号，取消拖拽要按它插回去
var _src_index: int = -1
## 128：源容器是地上时的原落点
var _src_spot: Vector2 = ItemStash.NO_SPOT
## 198 补充一：从地上拿起时它斜着多少 —— 只在取消（原样放回）时用；放到别处一律从不斜起落
var _src_tilt: float = 0.0
## 162：从棋盘（格子视图）拿起时原来那一格的左上角（全局像素）；拖出去落地从这里飞到放手点。不是从格子拿的为 null
var _src_px: Variant = null
## 抓取点相对物品 origin 的格偏移，拖拽时用它反推落点
var _grab_cell: Vector2i = Vector2i.ZERO
## 249：拿着东西时鼠标最近的几个位置 `{t: 秒, p: 全局像素}`（最多 [constant GroundLayer.THROW_SAMPLES] 个），松手时算手上的速度
var _motion: Array = []
## 139：起拖那块视图的格子边长（基地屏的仓库会放大）。跟手的残影、整块判定按它；吸附到某块视图上时按那块的
var _cell: float = InventoryView.CELL
var _rot: int = 0
## 162 补充二：从地上拿起，放回离原处这么近（像素）以内算「放回原处」（就地，不掉）
const PUT_BACK_PX := 4.0
## 非空表示正在拖一个带内容物的包，内容为 detach_bag 的载荷
var _payload: Dictionary = {}


func _ready() -> void:
	# 空闲时不能挡住下面的容器接收点击
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50     # 128：残影画在地上（导演那一层盖在各屏上面）的东西之上
	set_process_input(false)


func register_view(view: ContainerView) -> void:
	if _views.has(view):
		return
	_views.append(view)
	view.grab_requested.connect(_on_grab_requested)


## 撤销登记（开局屏换角色重造棋盘）
func unregister_view(view: ContainerView) -> void:
	if view.grab_requested.is_connected(_on_grab_requested):
		view.grab_requested.disconnect(_on_grab_requested)
	_views.erase(view)


## 审查 A3：登记过的视图被别人释放了（没撤登记）就从名单里拿掉，不去碰已释放的对象
func _prune_views() -> void:
	for i in range(_views.size() - 1, -1, -1):
		if not is_instance_valid(_views[i]):
			_views.remove_at(i)


func is_dragging() -> bool:
	return _inst != null


## 正在拖的这件是从哪个容器拿起来的（没在拖 null）。商店屏靠它认出「这是货架上的商品」（087）
func source() -> ItemContainer:
	return _source if _inst != null else null


## 审查 A2：这个拖拽层现在能不能接抓取 —— 在树里、看得见、没停掉。收起（最小化）的叠层藏起来并停用，
## 它的拖拽层不能再从地上抓东西（否则东西挂在藏起来的手里，那一屏一释放就没了）。不在树里（测试）算能
static func is_live(drag: DragLayer) -> bool:
	if drag == null:
		return false
	if not drag.is_inside_tree():
		return true
	return drag.is_visible_in_tree() and drag.can_process()


func _on_grab_requested(view: ContainerView, uid: int, local_pos: Vector2) -> void:
	var from := view.container()
	if is_dragging() or from == null:
		return
	if not is_live(self):
		return     # 审查 A2：藏起来 / 停掉的那一屏不抓
	if view is GroundLayer and (view as GroundLayer).top_drag() != null and (view as GroundLayer).top_drag() != self:
		return     # 128：同一层地接着好几块面板，只有最上面那块抓
	var inst := from.get_item(uid)
	if inst == null:
		return
	if from is GridInventory and (from as GridInventory).is_locked(uid):
		grab_refused.emit(uid)     # 207：扎了根的拿不起来（包被钉住同理）
		return

	_src_origin = inst.origin
	_src_rot = inst.rotation
	_rot = inst.rotation
	_source = from
	_src_index = -1
	# 先记下「正在拖」再从源容器拿走：源容器发 changed 时 is_dragging() 已经是真 ——
	# 容器屏靠它判「空了是因为拿在手上，还是真的空了」（084：剩最后一件刚点一下屏就关了，就是这一步的顺序错了）
	_inst = inst

	if from is ItemStash:
		# 列表里没有坐标；画在地上的按抓的是哪一格（128），否则一律当作物品的左上角
		_grab_cell = (view as GroundLayer).grab_cell_at(uid, local_pos) if view is GroundLayer else Vector2i.ZERO
		_src_index = (from as ItemStash).index_of(uid)
		_src_spot = (from as ItemStash).spot_of(uid)
		_src_tilt = (from as ItemStash).tilt_of(uid)
		if from.remove(uid) == null:
			_source = null
			_inst = null
			return
	else:
		var grid := from as GridInventory
		_grab_cell = (view as InventoryView).cell_at_local(local_pos) - inst.origin
		_cell = (view as InventoryView).cell_px
		_src_px = (view as InventoryView).global_position + (view as InventoryView).cell_origin_px(inst.origin)
		if grid.is_bag_with_contents(uid):
			_payload = grid.detach_bag(uid)
			if _payload.is_empty():
				_source = null
				_inst = null
				return
		elif grid.remove(uid) == null:
			_source = null
			_inst = null
			return

	set_process_input(true)
	InventoryView.set_focused(_inst, get_tree() if is_inside_tree() else null)     # 作者 10-21：拿起的这件就是点中的那件（地上拿起的也算）
	_highlight_partners()
	UiCursor.set_drag(true)     # 157
	_show_footprints(true)
	queue_redraw()
	AudioHub.play(SfxMaterial.pick_cue(_inst.def))     # 206：上手按材质响
	drag_started.emit(uid)


## 让一件**已经游离**的物品直接上手。顶替时被挤出来的那一件走这条路 ——
## 它此刻不在任何容器里，没有 view 可以「按下」。
##
## [param home] / [param home_rot] 只用于取消时的回退落点，不保证还回得去。
func grab_free(inst: ItemInstance, home: ItemContainer, home_at: Vector2i, home_rot: int,
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
	_src_index = -1
	_rot = inst.rotation
	_source = home
	_payload = {}
	_inst = inst
	set_process_input(true)
	_highlight_partners()
	UiCursor.set_drag(true)     # 157
	_show_footprints(true)
	if is_inside_tree():
		update_preview(get_global_mouse_position())
	queue_redraw()
	AudioHub.play(SfxMaterial.pick_cue(inst.def))     # 206
	drag_started.emit(inst.uid)


func _input(event: InputEvent) -> void:
	if not is_dragging():
		return

	if event is InputEventMouseMotion:
		record_motion(get_global_mouse_position())
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
			get_viewport().set_input_as_handled()     # 099：取消就是取消，别再被容器视图读成「右键奉为主信仰」
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
##
## 包也能转。内容物不跟着转，仍按原偏移画在残影上 —— 落到新轮廓之外的那些
## 会在放手时脱落到地上，残影上先给它们打好标记，玩家放手前就看得见代价。
func rotate_dragged() -> void:
	if _inst == null or _inst.def == null:
		return
	_rot = posmod(_rot + 1, 4)
	# 抓取点必须跟着落进新的包围盒，否则旋转后物品会离奇地跳开
	var box := _inst.def.shape.size_rotated(_rot)
	_grab_cell.x = clampi(_grab_cell.x, 0, maxi(0, box.x - 1))
	_grab_cell.y = clampi(_grab_cell.y, 0, maxi(0, box.y - 1))
	AudioHub.play(&"bag.rotate")     # 206
	# 测试里本控件不在场景树内，取不到鼠标；那时由调用方自行刷新预览
	if is_inside_tree():
		update_preview(get_global_mouse_position())
	queue_redraw()


## 指定全局坐标下的容器视图，没有则返回 null。
## 110：视图包在滚动容器里时，矩形按**当前**全局位置取（滚过之后会变），且被滚动区裁掉的部分不接落点
func view_at(global_pos: Vector2) -> ContainerView:
	_prune_views()
	for view in _views:
		if view is GroundLayer and (view as GroundLayer).fills_screen:
			continue     # 128：铺满屏的地上 = 「棋盘外」，不当落点视图
		if shown(view) and visible_rect(view).has_point(global_pos):
			return view
	return _view_under_footprint(global_pos)


## 视图真的露在外面：自己显示、而且（在场景树里时）祖先也都显示。
## 反馈（开局屏：包或道具放在棋盘左半边吸附不上）：地上那一栏的外框藏起来了，可地上视图自己的 visible 还是 true，
## 停在原处的矩形盖着棋盘左半边，落点全被它截走（地上又不收仓库来的）—— 只看自己的 visible 不够
static func shown(view: Control) -> bool:
	return view.visible and (not view.is_inside_tree() or view.is_visible_in_tree())


## 光标在格子视图外一点、但被拖的东西（按抓取点反推的整块）有一半以上压在视图里：算落在那个视图上（吸附范围）。
## 反馈（开局拖物品：整体对不准，背包在左上角时最明显）：抓着物品的某一格拖向左上角时，光标先出了棋盘边界，
## 物品其实大半还在棋盘上，却被当成「棋盘外」退回去了
func _view_under_footprint(global_pos: Vector2) -> ContainerView:
	if _inst == null or _inst.def == null:
		return null
	var cells := _inst.def.cells_rotated(_rot)
	if cells.is_empty():
		return null
	var size := _footprint_cells(cells)
	var rect := Rect2(global_pos - (Vector2(_grab_cell) + Vector2(0.5, 0.5)) * _cell, Vector2(size) * _cell)
	var best: ContainerView = null
	var best_area := 0.0
	for view in _views:
		if not (view is InventoryView) or not shown(view) or (view as InventoryView).inventory == null:
			continue
		var hit := visible_rect(view).intersection(rect)
		var area := hit.size.x * hit.size.y if hit.size.x > 0.0 and hit.size.y > 0.0 else 0.0
		if area * 2.0 > rect.size.x * rect.size.y and area > best_area:
			best = view
			best_area = area
	return best


static func _footprint_cells(cells: Array[Vector2i]) -> Vector2i:
	var hi := Vector2i.ZERO
	for c in cells:
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return hi + Vector2i.ONE


## 视图现在露在外面的那块（全局坐标）：自身矩形与所有裁剪祖先（滚动容器）的交集
static func visible_rect(view: Control) -> Rect2:
	var r := view.get_global_rect()
	var p := view.get_parent() as Control
	while p != null:
		if p.clip_contents or p is ScrollContainer:
			r = r.intersection(p.get_global_rect())
		p = p.get_parent() as Control
	return r


## 当前拖拽物在该网格视图中的落点锚点。
## 落点会吸进棋盘边界：整块能放得下就不让它伸出去（光标贴着边或略出边时落在最靠边的那一格）
func target_origin(view: InventoryView, global_pos: Vector2) -> Vector2i:
	var origin := view.cell_at_global(global_pos) - _grab_cell
	var inv := view.inventory
	# 光标还在视图里：老老实实按格算（越界就是越界）；只有光标已出界、靠整块判定才落到这个视图时才吸进边界
	if inv != null and _inst != null and not visible_rect(view).has_point(global_pos) and _inst.def != null:
		var cells := _inst.def.cells_rotated(_rot)
		if not cells.is_empty():
			var span := _footprint_cells(cells)
			if span.x <= inv.size.x and span.y <= inv.size.y:
				origin = Vector2i(clampi(origin.x, 0, inv.size.x - span.x), clampi(origin.y, 0, inv.size.y - span.y))
	return origin


## 残影的左上角（本控件内的坐标）。
## 在格子视图上方：**吸附到真正会落下的那一格** —— 放手落在哪、残影就画在哪，和落点高亮重合。
## 反馈（开局拖物品「有时对不准格子」）：以前残影永远让被抓的那一格正压在光标正下方（逐像素跟手），而落点按光标所在的格取整，
## 光标靠近格子边缘时残影与落点相差近半格，看起来就是没对准。不在任何格子视图上方（地上 / 棋盘外）仍然跟手。
## 本控件不在场景树里（测试）时 global_position 就是 position，换算照样成立
func ghost_anchor(global_pos: Vector2) -> Vector2:
	var view := view_at(global_pos)
	if view is InventoryView and (view as InventoryView).inventory != null:
		var grid_view := view as InventoryView
		return grid_view.global_position - global_position + Vector2(target_origin(grid_view, global_pos)) * grid_view.cell_px
	# 光标逐像素跟手：让被抓住的那一格正好压在光标下
	return global_pos - global_position - (Vector2(_grab_cell) + Vector2(0.5, 0.5)) * _cell


## 139：残影按多大的格子画 —— 吸附在某块格子视图上就按那块的，否则按起拖那块的
func ghost_cell(global_pos: Vector2) -> float:
	var view := view_at(global_pos)
	if view is InventoryView and (view as InventoryView).inventory != null:
		return (view as InventoryView).cell_px
	return _cell


## 按指定鼠标位置刷新落点高亮。
##
## 鼠标位置作为入参而不是内部取，是为了让拖拽逻辑能在没有真实输入的
## 测试里被驱动 —— 否则这整块只能靠手工拖拽验证。
## 157：画完预览按「这里能不能放」切光标（可放 / 不可放）
func update_preview(global_pos: Vector2) -> void:
	_update_preview(global_pos)
	if is_dragging():
		UiCursor.set_drag(true, drop_ok_at(global_pos))


## 157：在这里松手算不算放下了（不是弹回原处）：棋盘外看会不会到地上（249：也看 [member drop_filter] 许不许），格子看预览是不是绿 / 黄的
func drop_ok_at(global_pos: Vector2) -> bool:
	var target := view_at(global_pos)
	if target == null:
		return _drops_outside_to_stash() and _drop_allowed(stash)
	if target.container() == null or not _drop_allowed(target.container()):
		return false
	if target is InventoryView:
		return (target as InventoryView).preview_ok()
	if target is BagRackView:
		return _payload.is_empty() and (target as BagRackView).rack.accepts(_inst.def)     # 225：包架只收空包
	return target is GroundLayer


func _update_preview(global_pos: Vector2) -> void:
	_prune_views()
	if not is_dragging():
		return
	_set_craft_hint("")
	var target := view_at(global_pos)
	for view in _views:
		if view != target:
			view.clear_preview()
	if target == null or target is GroundLayer:
		return     # 128：棋盘外 = 地上，残影跟手，放手在哪就落在哪（不再画插入线）
	if target.container() == null:
		return
	if not _drop_allowed(target.container()):
		target.clear_preview()
		return
	if not (target is InventoryView):
		return     # 157：事件的收获行（背后是地上）只拿不放

	var grid_view := target as InventoryView
	var inv := grid_view.inventory
	var cells := _inst.def.cells_rotated(_rot)
	var origin := target_origin(grid_view, global_pos)
	grid_view.set_held(_inst.def if _payload.is_empty() else null, _rot)     # 193 §4：落点上画手上这件的格位（摆好的一袋不画）

	if not _payload.is_empty():
		if not inv.requires_bag:
			# 087：自由容器收不下摆好的一袋：包进去、内容物脱落到地上
			var bag: ItemInstance = _payload["bag"]
			var fine := inv.can_place_def(bag.def, origin, _rot, bag.uid) and _can_shed(_payload_items())
			grid_view.set_preview(cells, origin, fine, [], true)
			return
		var report := inv.bag_fit_report(_payload, origin, _rot)
		var fallen: Array = report["fallen"]
		var ok: bool = report["ok"] and _can_shed(fallen)
		if not ok:
			var victim := _replaceable_bag(inv, origin)
			if victim != GridInventory.EMPTY_UID:
				grid_view.set_preview(cells, origin, true, [victim], true)     # 087：替换那个包
				return
		grid_view.set_preview(cells, origin, ok, [], not fallen.is_empty())
		return

	if inv.can_place_def(_inst.def, origin, _rot, _inst.uid):
		grid_view.set_preview(cells, origin, true)
		return

	# 175：手上是铸牌、压在恰好一件武器上 → 附魔（绿的，不算顶替）
	var weapon := _enchant_target(inv, origin)
	if weapon != null:
		grid_view.set_preview(cells, origin, true)
		_set_craft_hint(enchant_hint(_inst, weapon))
		return

	# 114：压在恰好一件上、两件有配方 → 合成（绿的，不算顶替）；140：残影下面写一行产物与说明
	var partner := _craft_target(inv, origin)
	if partner != null:
		grid_view.set_preview(cells, origin, true)
		_set_craft_hint(_hint_for(partner))
		return

	if inv.acts_as_bag(_inst.def):
		# 087：空包压到另一个包上 = 替换它
		var victim := _replaceable_bag(inv, origin)
		grid_view.set_preview(cells, origin, victim != GridInventory.EMPTY_UID, [victim] if victim != GridInventory.EMPTY_UID else [], true)
		return

	# 放不进空位，但地形允许 —— 那就是「压着别人」，可以顶替
	var victims := _displaceable(inv, origin)
	grid_view.set_preview(cells, origin, not victims.is_empty(), victims)


func _drop_allowed(target: ItemContainer) -> bool:
	return not drop_filter.is_valid() or _inst == null or bool(drop_filter.call(_inst, target))


## 现在这一下放到外面会不会到地上（开着开关、有地上）。带东西的包也行（087）：包和内容物都进去
func _drops_outside_to_stash() -> bool:
	return drop_outside_to_stash and stash != null and _inst != null


## 载荷里除了包本身的全部实例：内容物 + 跨包的（087：包进列表 / 自由容器时它们脱落到地上）
func _payload_items() -> Array:
	var out: Array = []
	if _payload.is_empty():
		return out
	out.append_array(_payload.get("contents", []))
	for sd in _payload.get("straddlers", []):
		out.append((sd as Dictionary)["inst"])
	return out


## 087：手上这个包放到这儿会替换掉哪个包。条件：新包每一格在界内、不是禁用格；压到的包恰好一个（不是自己）；
## 压到的普通道具全是那个包的内容物 / 跨包物（别的包里的东西不能被压）；那个包的东西有地方去（地上）。不能替换返回 EMPTY_UID
func _replaceable_bag(inv: GridInventory, origin: Vector2i) -> int:
	if _inst == null or _inst.def == null or not inv.acts_as_bag(_inst.def):
		return GridInventory.EMPTY_UID
	var victim := GridInventory.EMPTY_UID
	var pressed: Array[int] = []
	for c in _inst.def.cells_rotated(_rot):
		var p := origin + c
		if not inv.in_bounds(p) or inv.is_blocked(p):
			return GridInventory.EMPTY_UID
		var owner := inv.bag_at(p)
		if owner != GridInventory.EMPTY_UID and owner != _inst.uid:
			if victim == GridInventory.EMPTY_UID:
				victim = owner
			elif victim != owner:
				return GridInventory.EMPTY_UID     # 压着两个包：不替换
		var item := inv.cell_uid(p)
		if item != GridInventory.EMPTY_UID and item != owner and item != _inst.uid and not pressed.has(item):
			pressed.append(item)
	if victim == GridInventory.EMPTY_UID:
		return GridInventory.EMPTY_UID
	if inv.is_locked(victim):
		return GridInventory.EMPTY_UID     # 207：钉住的包不被替换
	var belongs := inv.contents_of(victim)
	belongs.append_array(inv.straddlers_of(victim))
	if inv.any_locked(belongs):
		return GridInventory.EMPTY_UID     # 207：包里有扎了根的，换包会把它抖出来
	for item in pressed:
		if not belongs.has(item):
			return GridInventory.EMPTY_UID
	if not belongs.is_empty() and (stash == null or not stash.room_for(belongs.size())):
		return GridInventory.EMPTY_UID
	return victim


## 087：用手上的包替换 [method _replaceable_bag] 找到的那个：旧包连内容物摘下，新包（连它自己的内容物）放上，
## 旧包的东西与新包放不下的东西到地上，旧包拿在手上（作为顶替的那一件）。失败时容器原样不动
func _drop_replacing_bag(inv: GridInventory, at: Vector2i) -> Dictionary:
	var failed := {"ok": false, "victims": []}
	var victim_uid := _replaceable_bag(inv, at)
	if victim_uid == GridInventory.EMPTY_UID:
		return failed
	var old := inv.get_item(victim_uid)
	var old_home := old.origin
	var old_rot := old.rotation
	var old_payload := inv.detach_bag(victim_uid)
	if old_payload.is_empty():
		return failed
	var shed: Array = []
	shed.append_array(old_payload.get("contents", []))
	for sd in old_payload.get("straddlers", []):
		shed.append((sd as Dictionary)["inst"])
	var ok := false
	if _payload.is_empty():
		ok = inv.place(_inst, at, _rot)
	else:
		var report := inv.bag_fit_report(_payload, at, _rot)
		var fallen: Array = report["fallen"]
		if report["ok"] and (stash != null and stash.room_for(shed.size() + fallen.size()) or (shed.is_empty() and fallen.is_empty())):
			var res := inv.attach_bag_shedding(_payload, at, _rot)
			ok = res["ok"]
			if ok:
				shed.append_array(res["fallen"])
	if not ok:
		if not inv.attach_bag(old_payload, old_home, old_rot):
			push_error("DragLayer: 替换失败后旧包放不回原位")
		return failed
	if not shed.is_empty():
		if stash == null or not _admit_all(stash, shed):
			push_error("DragLayer: 被替换的包里的东西放不到地上")
		else:
			items_shed.emit(shed)
	return {"ok": true, "victims": [old]}


## 128：登记过的、铺满屏画 [member stash] 的那层地（没有就 null：放到外面就自动找空处）
func _ground_view() -> GroundLayer:
	for view in _views:
		if view is GroundLayer and (view as GroundLayer).fills_screen and (view as GroundLayer).stash == stash:
			return view
	return null


## 162 补充二：松手那一刻残影的左上角（全局像素）—— 掉落的起点
func _release_px(global_pos: Vector2) -> Vector2:
	return global_pos - (Vector2(_grab_cell) + Vector2(0.5, 0.5)) * _cell


## 249：记一个鼠标位置（拿着东西时每次移动；[param t_sec] 不给 = 现在）。只留最近的 [constant GroundLayer.THROW_SAMPLES] 个
func record_motion(global_pos: Vector2, t_sec: float = -1.0) -> void:
	var now := t_sec if t_sec >= 0.0 else Time.get_ticks_usec() / 1000000.0
	_motion.append({"t": now, "p": global_pos})
	while _motion.size() > GroundLayer.THROW_SAMPLES:
		_motion.pop_front()


## 249：松手那一刻手上的速度（全局像素 / 秒）：最近 [constant GroundLayer.THROW_WINDOW_SEC] 秒里最早那个样本到松手点的位移 ÷ 时间。
## 窗口里没有样本（停住了才放手）= 零
func release_velocity(global_pos: Vector2, t_sec: float = -1.0) -> Vector2:
	var now := t_sec if t_sec >= 0.0 else Time.get_ticks_usec() / 1000000.0
	for sample in _motion:
		var dt := now - float(sample["t"])
		if dt <= GroundLayer.THROW_WINDOW_SEC + 0.000001:
			return (global_pos - (sample["p"] as Vector2)) / dt if dt >= 0.01 else Vector2.ZERO
	return Vector2.ZERO


## 249：甩到地上的这件带着多快落地（手上的速度 × 密度因子）写进 [param target] 的 [member ItemStash.landing_vel]；就地放回（单击）不写
func _note_throw(target: ItemStash, inst: ItemInstance, global_pos: Vector2) -> void:
	var vel := release_velocity(global_pos) * GroundLayer.throw_factor(inst.def)
	if vel != Vector2.ZERO:
		target.landing_vel[inst.uid] = vel


## 从地上拿起又放回差不多原处、没转（单击一下）：就地落下，不往下掉 —— 否则紧跟的双击落空
func _put_back(spot: Vector2) -> bool:
	if not (_source is ItemStash) or _rot != _src_rot or not ItemStash.has_spot_value(_src_spot) or not ItemStash.has_spot_value(spot):
		return false
	var g := _ground_view()
	var scale := g.size if g != null else Vector2.ONE * 1000.0
	return ((spot - _src_spot) * scale).length() < PUT_BACK_PX


## 128：放手在 [param global_pos]，这件在地 [param ground] 上落在哪（没有地 = [constant ItemStash.NO_SPOT]）
func _drop_spot(ground: GroundLayer, global_pos: Vector2, inst: ItemInstance) -> Vector2:
	if ground == null:
		return ItemStash.NO_SPOT
	var top_left := global_pos - (Vector2(_grab_cell) + Vector2(0.5, 0.5)) * _cell
	return ground.spot_for_drop(top_left, inst, _rot)


## 这件东西能不能进这个列表。列表没有坐标，装不下「包 + 各内容物的相对位置」——
## 087 作者定：包照样能进，内容物打散成各一行（脱落）；要整袋带着走就放回棋盘
func _stash_accepts(target: ItemStash, inst: ItemInstance) -> bool:
	if target == null or inst == null or inst.def == null:
		return false
	if not target.accepts(inst.def):
		return false
	if inst.is_locked_by_player() and _source != target:
		return false     # 230：锁住的不丢到地上（地上拿起来挪位置照旧）
	# 087：带东西的包也能进列表 —— 包一行、内容物各一行（打散），得都装得下
	return target.room_for(1 + _payload_items().size())


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
	var home: ItemContainer = null

	# 249：棋盘外（地上）松手、这一屏却不许往地上放 —— 弹回原处之后告诉宿主
	var refused := target == null and _drops_outside_to_stash() and not _drop_allowed(stash)
	if target != null and not _drop_allowed(target.container()):
		target = null     # 那儿不许放：当没放，退回源容器
	elif target == null and _drops_outside_to_stash() and _drop_allowed(stash) and _stash_accepts(stash, inst):
		# 棋盘外的空间全都是地上（084 / 128）：落点 = 放手点；从地上拿起又放回地上 = 改落点（列表里的行不变）；
		# 没有铺满屏的地层（测试）时，地上来的放回原处，别处来的追加在末尾、自动找空处
		var spot := _drop_spot(_ground_view(), global_pos, inst)
		if _source == stash and ItemStash.has_spot_value(spot):
			dropped = stash.insert(inst, _src_index, spot)
			if not dropped:
				_restore()
		elif _source == stash:
			_restore()
		else:
			var loose := _payload_items()
			dropped = _admit_with_payload(stash, inst, -1, spot)
			home = stash
			if dropped:
				_land_from(stash, loose, global_pos)     # 134：脱落的内容物从放手点落下
		if dropped:
			# 162 补充二（作者定）：从松手那一刻残影的位置竖直往下掉（地层改落点与朝向）；地上拿起又原样放回（单击）= 就地，不掉
			inst.rotation = _rot
			stash.landing_from[inst.uid] = true if _put_back(spot) else _release_px(global_pos)
			if not _put_back(spot):
				_note_throw(stash, inst, global_pos)     # 249：手上带着速度就甩出去
		if _source == stash or dropped:
			if not dropped:
				AudioHub.play(&"bag.invalid")     # 206：落到地上那一声在落稳时（GroundLayer）
			_end_drag()
			drag_finished.emit(inst.uid, dropped)
			return dropped
	if target is GroundLayer:
		# 一块地（开局屏、沙盒）：落在放手点
		var gl := target as GroundLayer
		var at_spot := _drop_spot(gl, global_pos, inst)
		if _stash_accepts(gl.stash, inst):
			if _source == gl.stash:
				dropped = gl.stash.insert(inst, _src_index, at_spot)
			else:
				dropped = _admit_with_payload(gl.stash, inst, -1, at_spot)
		if dropped:
			home = gl.stash
			inst.rotation = _rot
			gl.stash.landing_from[inst.uid] = true if _source == gl.stash and _put_back(at_spot) else _release_px(global_pos)     # 162 补充二：同上
			if gl.stash.landing_from[inst.uid] is Vector2:
				_note_throw(gl.stash, inst, global_pos)     # 249
	elif target is BagRackView and (target as BagRackView).rack != null:
		# 225：包架只收空包（带东西的包先把东西拿下来）；从包架拿起又放回 = 原样
		var rack := (target as BagRackView).rack
		if _payload.is_empty() and rack.accepts(inst.def):
			dropped = rack.insert(inst, _src_index if _source == rack else -1)
		if dropped:
			home = rack
	elif target is InventoryView and (target as InventoryView).inventory != null:     # 157：别的列表视图（事件的收获行）不是落点
		var grid_view := target as InventoryView
		var at := target_origin(grid_view, global_pos)
		# 099（作者定）：落回同一个容器不算「从别处置入」—— 置入顺序只由 reseat 改（见下），
		# 这样普通道具在棋盘内挪位置不再刷信力，取消拖拽也不会切信仰
		var back_home := grid_view.inventory == _source
		if back_home:
			inst.container_id = grid_view.inventory.id
		if not _payload.is_empty():
			dropped = _drop_bag(grid_view.inventory, at)
			if not dropped and grid_view.inventory.requires_bag:
				var swap := _drop_replacing_bag(grid_view.inventory, at)     # 087：包替换包
				dropped = swap["ok"]
				pending = swap["victims"]
		elif grid_view.inventory.place(inst, at, _rot):
			dropped = true
		elif _enchant_target(grid_view.inventory, at) != null:
			# 175：铸牌压到武器上 = 附魔（铸牌被消耗，不再落到任何容器里）
			dropped = bool(enchant_drop.call(inst, grid_view.inventory, _enchant_target(grid_view.inventory, at).uid))
			back_home = false
		elif _craft_target(grid_view.inventory, at) != null:
			# 114：压到能合的那件上 = 立刻合成（a 被消耗，不再落到任何容器里）
			dropped = bool(craft_drop.call(inst, _craft_target(grid_view.inventory, at).uid))
			back_home = false
		elif grid_view.inventory.acts_as_bag(inst.def):
			var swap2 := _drop_replacing_bag(grid_view.inventory, at)     # 087：空包替换包
			dropped = swap2["ok"]
			pending = swap2["victims"]
		else:
			# 「顶成功但一件没顶到」不可能发生（放不进空位才会走到这儿），
			# 但成败不能靠数组空不空来推断 —— 那是把不变式当接口用。
			var outcome := _drop_displacing(grid_view.inventory, inst, at)
			dropped = outcome["ok"]
			pending = outcome["victims"]
			if dropped and pending.size() >= 2 and stash != null:
				# 134：顶到地上的那几件从它们原来那一格落过来
				for v in pending:
					var vi := v as ItemInstance
					if stash.has_item(vi.uid):
						stash.landing_from[vi.uid] = grid_view.global_position + grid_view.cell_origin_px(vi.origin)
		if dropped:
			home = grid_view.inventory
			# 099（作者定）：在棋盘里把信物重新落下 = 奉它为主信仰。只有信物盖序号，普通道具不盖
			if back_home and inst.def.is_anchor():
				grid_view.inventory.reseat(inst.uid)

	if not dropped:
		_restore()
		AudioHub.play(&"bag.invalid")     # 206：放不下、退回原处（Esc / 右键取消走 [method cancel]，不响）
	elif target is InventoryView or target is BagRackView:
		AudioHub.play(SfxMaterial.place_cue(inst.def))     # 206：放进棋盘按材质响；放到地上的那一声在落稳时（225：挂上包架同一声）

	_end_drag()
	drag_finished.emit(inst.uid, dropped)
	if refused and not dropped:
		drop_refused.emit(inst.uid)

	if not pending.is_empty():
		_settle_displaced(pending, home, global_pos)
	return dropped


## 放下一个包（可能带着内容物、可能换了朝向）。脱落的内容物到地上；
## 没地方安置就整件事不成立，容器原样不动。
func _drop_bag(inv: GridInventory, at: Vector2i) -> bool:
	if not inv.requires_bag:
		# 087：自由容器（战利品箱、出售区……）收不下摆好的一袋：包当普通物品放进去，内容物脱落到地上
		var bag: ItemInstance = _payload["bag"]
		var loose := _payload_items()
		if not inv.can_place_def(bag.def, at, _rot, bag.uid) or not _can_shed(loose):
			return false
		if not inv.place(bag, at, _rot):
			return false
		if not loose.is_empty():
			if not _admit_all(stash, loose):
				inv.remove(bag.uid)
				return false
			items_shed.emit(loose)
		return true
	var report := inv.bag_fit_report(_payload, at, _rot)
	var fallen: Array = report["fallen"]
	if not report["ok"] or not _can_shed(fallen):
		return false
	var result := inv.attach_bag_shedding(_payload, at, _rot)
	if not result["ok"]:
		return false
	var shed: Array = result["fallen"]
	if shed.is_empty():
		return true
	if not _admit_all(stash, shed):
		# 预览刚说过塞得下，走到这里说明地上在别处被动过。绝不能让东西悬着：
		# 把包连同还在里面的东西摘回来，脱落的也一并塞回载荷，整件事作废。
		push_error("DragLayer: 脱落的内容物放不到地上，整件事作废")
		# 原载荷里每一件的引用都还在（脱落的从没被放下，其余的这一下摘回来），
		# 之后 _restore 用它整体放回原处即可
		inv.detach_bag((_payload["bag"] as ItemInstance).uid)
		return false
	items_shed.emit(shed)
	return true


## 脱落的这几件有没有地方去。为空就不需要地方。
func _can_shed(fallen: Array) -> bool:
	if fallen.is_empty():
		return true
	return stash != null and stash.room_for(fallen.size())


## 114：拖着的这件压到这个位置上会正好压着一件、且两件有配方吗。返回被压的那件；没有 null。
## 只在 [member craft_grid] 上、配了 [member craft_drop] 时成立
func _craft_target(inv: GridInventory, origin: Vector2i) -> ItemInstance:
	if _inst == null or not _payload.is_empty() or not craft.is_valid() or not craft_drop.is_valid():
		return null
	if craft_filter.is_valid() and not bool(craft_filter.call(_inst)):
		return null
	if inv == null or inv != craft_grid:
		return null
	var under := inv.displaced_by(_inst.def, origin, _rot, _inst.uid)
	if under.size() != 1:
		return null
	var b := inv.get_item(int(under[0]))
	if b == null or b.def == null:
		return null
	return b if craft.call(_inst, b) is ItemDef else null


## 175：拖着的铸牌压到这个位置上会正好压着一件武器吗。返回那件武器；没有 null
func _enchant_target(inv: GridInventory, origin: Vector2i) -> ItemInstance:
	if _inst == null or not _payload.is_empty() or not enchant_drop.is_valid() or not Forge.is_token(_inst) or inv == null:
		return null
	var under := inv.displaced_by(_inst.def, origin, _rot, _inst.uid)
	if under.size() != 1:
		return null
	var b := inv.get_item(int(under[0]))
	return b if Forge.accepts(b) else null


## 175：「附魔：嗜血的长剑」（武器原有的附魔被覆盖时再写一句）
static func enchant_hint(token: ItemInstance, weapon: ItemInstance) -> String:
	var ench := Forge.enchant_of(token)
	var text := UiText.t("bag.enchant") % [Forge.prefix(ench), Names.of(weapon.def)]
	if not Forge.enchant_of(weapon).is_empty():
		text += UiText.t("bag.enchant_replace") % Forge.prefix(Forge.enchant_of(weapon)).trim_suffix("的").strip_edges()     # en prefixes end with a space
	return text


## 140：「合成 → 产物：说明」
func _hint_for(partner: ItemInstance) -> String:
	var out: Variant = craft.call(_inst, partner)
	if not (out is ItemDef):
		return ""
	var text := UiText.t("bag.craft") + Names.of(out as ItemDef)
	var note := String(craft_note.call(_inst, partner)) if craft_note.is_valid() else ""
	return text + (UiText.t("tip.colon") + note if note != "" else "")


## 226 批三：合成 / 附魔提示写在纸签上（地图墨路签那张 `map/tag_paper`），左上角在 [param at]，跟着残影走
func _draw_hint_tag(at: Vector2, font: Font) -> void:
	var tw := font.get_string_size(craft_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_FONT).x
	var box := Rect2(at, Vector2(tw + 16.0, HINT_TAG_H))
	if _hint_box == null:
		_hint_box = UiTheme.art_box(UiTheme.ART_MAP_TAG)
	if _hint_box != null:
		draw_style_box(_hint_box, box)
	else:
		draw_rect(box, Color(UiTheme.PAPER, 0.95))
		draw_rect(box, Color(UiTheme.INK, 0.6), false, 1.0)
	draw_string(font, Vector2(box.position.x + 8.0, box.position.y + HINT_TAG_H * 0.5 + HINT_FONT * 0.36), craft_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_FONT, HINT_INK)


func _set_craft_hint(text: String) -> void:
	if craft_hint != text:
		craft_hint = text
		queue_redraw()


## 085 / 114：拖起一件时，所有登记的视图里能和它合成的那几件亮一圈（放下 / 取消时熄）—— 提醒「拖到它上面就合」
func _highlight_partners() -> void:
	for view in _views:
		var marks := {}
		var c := view.container()
		if _inst != null and _payload.is_empty() and craft.is_valid() and c != null:
			for inst in c.items():
				var b := inst as ItemInstance
				if b.uid != _inst.uid and craft.call(_inst, b) is ItemDef:
					marks[b.uid] = true
		view.set("highlights", marks)
		view.queue_redraw()


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

	# 多于一件：全部到地上，进不去就整件事作废。
	# 只塞进去一半、另一半留在手上，玩家根本追不过来。
	if stash != null and displace_to_stash and _admit_all(stash, victims):
		return {"ok": true, "victims": victims}

	inv.begin_batch()
	inv.remove(inst.uid)
	for v in victims:
		var h: Array = homes[(v as ItemInstance).uid]
		if not inv.place(v, h[0], h[1]):
			push_error("DragLayer: uid %d 放不回原位，物品已丢失" % (v as ItemInstance).uid)
	inv.end_batch()
	return failed


## 安置被顶出来的物品：一件就直接拿在手上，多于一件已经在地上了。
##
## 「一件就上手」是因为那几乎总是接下来要挪的东西 —— 顶掉它再去地上翻出来，
## 中间那两下纯属多余。
func _settle_displaced(victims: Array, home: ItemContainer, global_pos: Vector2) -> void:
	if victims.size() == 1:
		var v := victims[0] as ItemInstance
		var view := view_at(global_pos)
		var cell := v.origin
		if view is InventoryView:
			cell = (view as InventoryView).cell_at_global(global_pos)
		grab_free(v, home, v.origin, v.rotation, cell - v.origin)
		AudioHub.play(&"bag.bump")     # 206：顶出一批响一声
		items_displaced.emit(victims, true)
		return
	AudioHub.play(&"bag.bump")
	items_displaced.emit(victims, false)


## 顶出来之后界面写的那一句（[signal items_displaced] 的两种情况）：一件已经拿在手上，多件都到了地上
static func displaced_text(instances: Array, grabbed: bool) -> String:
	var names: Array[String] = []
	for inst in instances:
		var item := inst as ItemInstance
		names.append(Names.of(item.def) if item.def != null else "?")
	return UiText.t("bag.displaced_one") % names[0] if grabbed else UiText.t("bag.displaced_many") % [names.size(), UiText.t("tip.list_sep").join(names)]


## 这个落点能顶掉哪些：地形得允许，且确实压着别人。
## 多于一件时还要有地方安置，否则不算可顶 —— 预览就该是红的，不该给出做不到的承诺。
func _displaceable(inv: GridInventory, origin: Vector2i) -> Array[int]:
	var none: Array[int] = []
	if _inst == null or not _payload.is_empty():
		return none
	if not inv.terrain_allows(_inst.def, origin, _rot):
		return none
	var victims := inv.displaced_by(_inst.def, origin, _rot, _inst.uid)
	if victims.size() >= 2 and (stash == null or not displace_to_stash):
		return none
	if inv.any_locked(victims):
		return none     # 207：扎了根的顶不动
	return victims


## 087：把手上的东西放进列表：包在 [param at] 行（-1 = 末尾）、落点 [param spot]（128），带着的内容物打散追加在后面（自动找空处）。
## 有一件放不下就整件事作废
func _admit_with_payload(dest: ItemStash, inst: ItemInstance, at: int, spot: Vector2 = ItemStash.NO_SPOT) -> bool:
	var loose := _payload_items()
	if not dest.room_for(1 + loose.size()):
		return false
	if not dest.insert(inst, at, spot):
		return false
	if loose.is_empty():
		return true
	if not _admit_all(dest, loose):
		dest.remove(inst.uid)
		return false
	items_shed.emit(loose)
	return true


## 134：这几件（已经在地上）从放手点附近落下
static func _land_from(dest: ItemStash, items: Array, global_pos: Vector2) -> void:
	for it in items:
		var inst := it as ItemInstance
		if inst != null and dest.has_item(inst.uid):
			dest.landing_from[inst.uid] = global_pos - Vector2.ONE * InventoryView.CELL * 0.5


## 整批塞进目标容器：有一件放不下就整批退回。
static func _admit_all(dest: ItemContainer, items: Array) -> bool:
	dest.begin_batch()
	var done: Array[ItemInstance] = []
	for it in items:
		if dest.admit(it):
			done.append(it)
			continue
		for placed in done:
			dest.remove(placed.uid)
		dest.end_batch()
		return false
	dest.end_batch()
	return true


## 放弃本次拖拽，物品退回源容器。
## 审查 A2：拿着东西的时候这一层被藏起来（收起最小化）或离开场景树（那一屏被释放）—— 先把手上的放回原处，
## 不让它挂在没人看得见的手里丢掉
func _notification(what: int) -> void:
	if (what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED) and is_dragging():
		if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
			return
		cancel()


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
	if _source is ItemStash:
		if (_source as ItemStash).insert(_inst, _src_index, _src_spot):
			(_source as ItemStash).landing_from[_inst.uid] = false     # 134：放回原处不算落地
			if _src_tilt != 0.0:
				(_source as ItemStash).tilts[_inst.uid] = _src_tilt     # 198 补充一：原样放回还斜着
			return
		push_error("DragLayer: uid %d 放不回地上，物品已丢失" % _inst.uid)
		return
	if not _payload.is_empty():
		if not (_source as GridInventory).attach_bag(_payload, _src_origin, _src_rot):
			push_error("DragLayer: 包 uid %d 连内容物放不回源容器，已丢失" % _inst.uid)
		return
	_inst.container_id = (_source as GridInventory).id     # 099：原样放回不算重新置入（取消拖拽不切信仰、不记信力）
	if (_source as GridInventory).place(_inst, _src_origin, _src_rot):
		return
	# 原位没了（顶替之后取消，多半如此）。依次退而求其次，
	# 每一级都比上一级更不合玩家心意，但都好过物品凭空消失。
	push_warning("DragLayer: uid %d 无法放回原位，改为自动装填" % _inst.uid)
	if _source.admit(_inst):
		return
	if stash != null and stash.admit(_inst):
		return
	push_error("DragLayer: uid %d 放不回源容器，物品已丢失" % _inst.uid)


func _end_drag() -> void:
	_prune_views()
	for view in _views:
		view.clear_preview()
	_inst = null
	_motion.clear()
	_cell = InventoryView.CELL
	craft_hint = ""
	_highlight_partners()     # _inst 空了：全熄
	_source = null
	_src_index = -1
	_src_spot = ItemStash.NO_SPOT
	_src_tilt = 0.0
	_src_px = null
	_payload = {}
	set_process_input(false)
	UiCursor.set_drag(false)     # 157：光标还原
	_show_footprints(false)
	queue_redraw()


## 239：拿起时所有棋盘逐格描出占格（按组：战前的敌人棋盘、商店货架这些没登记的视图也算），放下 / 取消收起
func _show_footprints(on: bool) -> void:
	if is_inside_tree():
		get_tree().call_group(InventoryView.GROUP, "set_footprints", on)


func _draw() -> void:
	if not is_dragging():
		return
	var cells := _inst.def.cells_rotated(_rot)
	var mouse := get_global_mouse_position()
	var anchor := ghost_anchor(mouse)
	var cell := ghost_cell(mouse)

	var font := label_font if label_font != null else get_theme_default_font()
	var is_bag := not _payload.is_empty()

	var body := (
		InventoryView.COLOR_BAG_FILL if is_bag else ItemPainter.body_color(_inst.def, _inst.rarity())
	)
	body.a = 0.85
	var edge := (
		InventoryView.COLOR_BAG_EDGE if is_bag else ItemPainter.rarity_color(_inst.def, _inst.rarity())
	)
	if not ItemPainter.draw_art(self, _inst.def, _rot, anchor, cell, Color(1, 1, 1, 0.85), Transform2D.IDENTITY, ItemPainter.variant_of(_inst)):     # 201：有图画图
		ItemPainter.draw_item(self, cells, anchor, cell, body, edge)
		ItemPainter.draw_label(
			self, cells, anchor, cell,
			Names.of_item(_inst), font, 11 if is_bag else 13, Color("f2f4f8")
		)
	InventoryView.draw_footprint(self, _inst.def, cells, anchor, cell, is_bag or InventoryView.footprint_hollow(_inst.def), _inst.rarity())     # 239：手里那件也逐格描
	if not is_bag and not (view_at(mouse) is InventoryView):
		_draw_held_markers(anchor, cell)
	if craft_hint != "":     # 140：压在能合的那件上：残影下面一行小字
		var rows := 0
		for c in cells:
			rows = maxi(rows, (c as Vector2i).y + 1)
		_draw_hint_tag(anchor + Vector2(0.0, rows * cell + 4.0), font)

	# 包里的东西要跟着残影一起画，否则玩家看不出自己正拖着什么。
	# 按本地坐标算它们在当前朝向下的位置 —— 包转了，它们就跟着转
	if is_bag:
		var bag: ItemInstance = _payload["bag"]
		var contents: Array = _payload["contents"]
		var locals: Array = _payload["locals"]
		for i in contents.size():
			var item: ItemInstance = contents[i]
			var g := GridInventory.to_global(bag, locals[i], item, Vector2i.ZERO, _rot)
			var at: Vector2 = anchor + Vector2(g["origin"] as Vector2i) * cell
			var item_cells := item.def.cells_rotated(int(g["rot"]))
			if ItemPainter.draw_art(self, item.def, int(g["rot"]), at, cell, Color(1, 1, 1, 0.9), Transform2D.IDENTITY, ItemPainter.variant_of(item)):
				InventoryView.draw_footprint(self, item.def, item_cells, at, cell, false, item.rarity())     # 239：袋里各件描自己的稀有度框
				continue
			var c_body := ItemPainter.body_color(item.def, item.rarity())
			c_body.a = 0.9
			ItemPainter.draw_item(
				self, item_cells, at, cell, c_body, ItemPainter.rarity_color(item.def, item.rarity())
			)
			ItemPainter.draw_label(
				self, item_cells, at, cell,
				Names.of_item(item), font, 12, Color("f2f4f8")
			)
			InventoryView.draw_footprint(self, item.def, item_cells, at, cell, false, item.rarity())
		_draw_straddlers(font)


## 193 §4：棋盘外（地上 / 空处）在残影上画手上这件的格位，未点亮态 —— 转了方向在哪儿都看得出格位转到哪了
func _draw_held_markers(anchor: Vector2, cell: float) -> void:
	var side := InventoryView.marker_side(cell)
	for m in InventoryView.marker_offsets(_inst.def, _rot):
		var tex := UiTheme.slot_icon(String(m[1]), false)
		if tex != null:
			draw_texture_rect(tex, Rect2(anchor + Vector2(m[0] as Vector2i) * cell + Vector2.ONE * (cell - side) * 0.5, Vector2(side, side)), false)


## 跨包的物品被包一起摘了下来，但带不走 —— 画在它们原来的位置上，压暗描橙：
## 放回原处它们就回去，放到别处它们就脱落。
func _draw_straddlers(font: Font) -> void:
	var straddlers: Array = _payload.get("straddlers", [])
	if straddlers.is_empty():
		return
	var src_view: ContainerView = null
	for v in _views:
		if v.container() == _source:
			src_view = v
			break
	if src_view == null or not (src_view is InventoryView):
		return
	var base := (src_view as InventoryView).global_position - global_position
	var cell := (src_view as InventoryView).cell_px
	for s in straddlers:
		var item: ItemInstance = s["inst"]
		var at := base + Vector2(s["origin"] as Vector2i) * cell
		var item_cells := item.def.cells_rotated(int(s["rot"]))
		if ItemPainter.draw_art(self, item.def, int(s["rot"]), at, cell, Color(1, 1, 1, 0.45)):
			ItemPainter.draw_item(self, item_cells, at, cell, Color(0, 0, 0, 0), InventoryView.COLOR_VICTIM)     # 201：图压暗，照旧描橙
			continue
		var c_body := ItemPainter.body_color(item.def, item.rarity())
		c_body.a = 0.45
		ItemPainter.draw_item(
			self, item_cells, at, cell, c_body, InventoryView.COLOR_VICTIM
		)
		ItemPainter.draw_label(
			self, item_cells, at, cell,
			Names.of_item(item), font, 12, Color("f2f4f8", 0.6)
		)
