## 一个 [GridInventory] 的可视化。
##
## 全部内容在 [method _draw] 里重画，不使用子节点表示物品 —— 这直接落实了
## 架构原则 1.2「从状态完整重建视图」：容器发 changed 就 queue_redraw，
## 不存在需要与真实状态对账的增量视图状态。
##
## 拖拽本身不在这里处理，见 [DragLayer]。本类只负责「告诉外面哪一件被按下了」
## 以及「按要求显示一个落点预览」。
##
## 只画**空间**容器。暂存区是个列表，见 [StashView]。
class_name InventoryView
extends ContainerView

## 087（作者定）：格子放大
const CELL := 60.0

const COLOR_BG := Color("1b1e24")
const COLOR_CELL := Color("272b33")
const COLOR_BLOCKED := Color("14161a")
## 棋盘上尚未被任何包覆盖的格子：明显比空格更暗，一眼看出「这里还不能用」
const COLOR_UNUSABLE := Color("15171c")
const COLOR_BAG_FILL := Color("2f3542")
const COLOR_BAG_EDGE := Color("5d6577")
const COLOR_GRID := Color("343943")
const COLOR_BORDER := Color("4a515e")
const COLOR_TEXT := Color("e6e9ef")
const COLOR_OK := Color(0.35, 0.85, 0.45, 0.35)
const COLOR_BAD := Color(0.9, 0.3, 0.3, 0.35)
## 放得下，但会把别人顶出来。必须和「放不下」区分开 —— 都画成红的，
## 玩家会以为这一下没生效；都画成绿的，东西就会不声不响地被挤走。
const COLOR_DISPLACE := Color(0.95, 0.72, 0.25, 0.38)
## 即将被顶出来的那几件，描一圈边，让人看清代价
const COLOR_VICTIM := Color(0.98, 0.62, 0.25)

@export var title: String = ""
## 中文标签需要系统字体，Godot 内置字体不含 CJK 字形。
@export var label_font: Font

var inventory: GridInventory:
	set = set_inventory

var _preview_cells: Array[Vector2i] = []
var _preview_origin: Vector2i = Vector2i.ZERO
var _preview_valid: bool = false
var _preview_on: bool = false
## 本次落点会顶掉的物品 uid
var _preview_victims: Array[int] = []
## 合法但有代价：顶人或脱落
var _preview_costly: bool = false

## 是否画邻接标记格。战利品、商店货架这类地方不参战，画了只是噪音。
@export var show_adjacency: bool = true
## 085：物品右上角的小记号（uid → 文字），比如配了对等着合成的「合」。持有方设，改了 queue_redraw
var badges: Dictionary = {}
## 085：亮一圈的物品（uid → true）：拖着的那件能和它合成。拖拽层设
var highlights: Dictionary = {}
const COLOR_HIGHLIGHT := Color(0.42, 0.86, 0.52)


func container() -> ItemContainer:
	return inventory


func set_inventory(inv: GridInventory) -> void:
	if inventory == inv:
		return
	if inventory != null and inventory.changed.is_connected(queue_redraw):
		inventory.changed.disconnect(queue_redraw)
	inventory = inv
	if inventory != null:
		inventory.changed.connect(queue_redraw)
		custom_minimum_size = Vector2(inventory.size) * CELL
		size = custom_minimum_size
	queue_redraw()


#region 坐标换算
## 本控件内的像素坐标 → 格坐标。可能越界，调用方自行判断。
func cell_at_local(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


## 全局像素坐标 → 格坐标。
func cell_at_global(p: Vector2) -> Vector2i:
	return cell_at_local(p - global_position)


## 格坐标 → 本控件内的像素坐标（该格左上角）。
func cell_origin_px(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL
#endregion


#region 落点预览
## [param costly] 为真表示落点合法但有代价（会顶掉别人、会有内容物脱落），画成黄的。
## 被顶的那几件另由 [param victims] 描边；脱落的东西不在本容器里，由拖拽残影自己标。
func set_preview(
	cells: Array[Vector2i], origin: Vector2i, valid: bool,
	victims: Array[int] = [], costly: bool = false
) -> void:
	_preview_cells = cells
	_preview_origin = origin
	_preview_valid = valid
	_preview_victims = victims
	_preview_costly = costly or not victims.is_empty()
	_preview_on = true
	queue_redraw()


func clear_preview() -> void:
	if not _preview_on:
		return
	_preview_on = false
	_preview_cells = []
	_preview_victims = []
	_preview_costly = false
	queue_redraw()
#endregion


func _gui_input(event: InputEvent) -> void:
	if inventory == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var c := cell_at_local(mb.position)
			# 先抓普通物品；点在包的空白处才抓包本身
			var uid := inventory.cell_uid(c)
			if uid == GridInventory.EMPTY_UID:
				uid = inventory.bag_at(c)
			if uid != GridInventory.EMPTY_UID:
				# 099：右键按在一件上 = 这一屏自己决定做什么（棋盘：信物奉为主信仰）。
				# 拖拽中的右键是「取消」，那一下已经被 [DragLayer] 吃掉，走不到这里
				if mb.button_index == MOUSE_BUTTON_RIGHT:
					item_context.emit(self, uid)
				elif mb.double_click:
					item_double_clicked.emit(self, uid)     # 084：双击 = 快速置入，不再抓
				else:
					grab_requested.emit(self, uid, mb.position)
				accept_event()


## 这件要不要画名字。[LootView] 覆盖：没亮的不画（087）
func _label_visible(_item: ItemInstance) -> bool:
	return true


func _draw() -> void:
	if inventory == null:
		return
	var grid_px := Vector2(inventory.size) * CELL

	draw_rect(Rect2(Vector2.ZERO, grid_px), COLOR_BG, true)

	# 格底。棋盘模式下未被包覆盖的格子最暗，表示「还不能用」
	for y in inventory.size.y:
		for x in inventory.size.x:
			var c := Vector2i(x, y)
			var col := COLOR_CELL
			if inventory.is_blocked(c):
				col = COLOR_BLOCKED
			elif not inventory.is_covered(c):
				col = COLOR_UNUSABLE
			draw_rect(Rect2(cell_origin_px(c) + Vector2.ONE, Vector2(CELL - 2, CELL - 2)), col, true)

	# 网格线
	for x in inventory.size.x + 1:
		var fx := x * CELL
		draw_line(Vector2(fx, 0), Vector2(fx, grid_px.y), COLOR_GRID, 1.0)
	for y in inventory.size.y + 1:
		var fy := y * CELL
		draw_line(Vector2(0, fy), Vector2(grid_px.x, fy), COLOR_GRID, 1.0)

	var font := label_font if label_font != null else get_theme_default_font()

	# 包体：作为底层区域先画，物品压在上面。
	# 用统一的灰调而不是物品配色 —— 包是承载物，抢了内容物的视觉就本末倒置了
	for bag in inventory.bags():
		var b := bag as ItemInstance
		var bag_cells := b.cells()
		var bag_anchor := cell_origin_px(b.origin)
		ItemPainter.draw_item(self, bag_cells, bag_anchor, CELL, COLOR_BAG_FILL, COLOR_BAG_EDGE)
		ItemPainter.draw_label(
			self, bag_cells, bag_anchor, CELL, Names.of(b.def), font, 11, Color("79839a")
		)

	# 物品。休眠的信仰道具（8-4：不是激活的那个信仰）画灰、标「休眠」
	var active_faith := FaithState.active_tag(inventory) if show_adjacency else &""
	for inst in inventory.items():
		var item := inst as ItemInstance
		if inventory.acts_as_bag(item.def):
			continue
		var cells := item.cells()
		var anchor := cell_origin_px(item.origin)
		var dormant := show_adjacency and FaithState.is_dormant(item.def, active_faith)
		var body := ItemPainter.body_color(item.def)
		var edge := ItemPainter.rarity_color(item.def).lightened(0.2)
		var text_color := ItemPainter.label_color(item.def)
		if dormant:
			body = body.lerp(COLOR_BAG_FILL, 0.7)
			edge = edge.lerp(COLOR_BAG_EDGE, 0.7)
			text_color = COLOR_TEXT.darkened(0.35)
		ItemPainter.draw_item(self, cells, anchor, CELL, body, edge)
		if _label_visible(item):
			ItemPainter.draw_label(
				self, cells, anchor, CELL, Names.of(item.def) + ("
休眠" if dormant else ""), font, 13, text_color
			)
		if highlights.has(item.uid):
			var hb := item.def.shape.size_rotated(item.rotation)
			var pulse := 0.6 + 0.4 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
			draw_rect(Rect2(anchor - Vector2(3, 3), Vector2(hb) * CELL + Vector2(6, 6)), Color(COLOR_HIGHLIGHT, pulse), false, 3.0)
		if badges.has(item.uid):
			var badge := String(badges[item.uid])
			var box := item.def.shape.size_rotated(item.rotation)
			var at := anchor + Vector2(box.x * CELL - 18.0, 4.0)
			draw_rect(Rect2(at, Vector2(16, 16)), UiPalette.HEAL, true)
			draw_string(font, at + Vector2(2.0, 13.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("101216"))

	# 邻接标记：画在物品之上、落点预览之下。
	# 压在物品身上才看得出「这一格已经被谁占住了」—— 那正是标记点亮与否的判据。
	if show_adjacency:
		_draw_adjacency()

	# 落点预览：整片染色。合法绿、会顶人黄、放不下红
	if _preview_on:
		var tint := COLOR_BAD
		if _preview_valid:
			tint = COLOR_DISPLACE if _preview_costly else COLOR_OK
		for c in _preview_cells:
			var p := _preview_origin + c
			if p.x < 0 or p.y < 0 or p.x >= inventory.size.x or p.y >= inventory.size.y:
				continue
			draw_rect(Rect2(cell_origin_px(p), Vector2(CELL, CELL)), tint, true)

		# 被顶的那几件描一圈，让人放手前就知道要付什么代价
		for uid in _preview_victims:
			var victim := inventory.get_item(uid)
			if victim == null:
				continue
			for c in victim.cells():
				var p := victim.origin + c
				draw_rect(
					Rect2(cell_origin_px(p) + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)),
					COLOR_VICTIM, false, 2.0
				)

	draw_rect(Rect2(Vector2.ZERO, grid_px), COLOR_BORDER, false, 2.0)


#region 邻接标记
## 增益／受益格画成**四个角括号**，不是一圈方框。
##
## 方框会和物品自己的稀有度描边撞车 —— 蓝框的稀有物品和蓝色的增益标记挨在一起，
## 谁也分不出哪个是哪个。角括号一看就是「贴在格子上的标注」而不是某件东西的轮廓。
##
## 两类标记缩进不同：**增益贴着格边、受益缩在里面**，同时落在一格上也分得清。
##
## 点亮（这一格确实站着一个符合条件的邻居）就填色加粗，没点亮只留细线。
## 这一层是玩家判断「摆位对不对」的唯一依据 —— 只画位置不画点亮状态，
## 等于让人对着说明书心算，而摆位正是这类游戏的全部乐趣所在。
const MARK_INSET_GRANT := 3.0
const MARK_INSET_RECEIVE := 9.0
## 角括号单边长度，占格边的比例
const MARK_CORNER := 0.3


func _draw_adjacency() -> void:
	for inst in inventory.items():
		var item := inst as ItemInstance
		if item.def == null or item.def.adjacency == null:
			continue
		if inventory.acts_as_bag(item.def):
			continue
		var profile := item.def.adjacency
		if profile.has_grant():
			_draw_markers(
				item, profile.grant_cells, profile.grant_filter,
				UiPalette.GRANT, MARK_INSET_GRANT
			)
		if profile.has_receive():
			_draw_markers(
				item, profile.receive_cells, profile.receive_filter,
				UiPalette.RECEIVE, MARK_INSET_RECEIVE
			)


func _draw_markers(
	item: ItemInstance,
	offsets: Array[Vector2i],
	filter: Array[StringName],
	color: Color,
	inset: float
) -> void:
	for cell in item.absolute_cells(offsets):
		if not inventory.in_bounds(cell):
			continue
		var rect := Rect2(
			cell_origin_px(cell) + Vector2(inset, inset),
			Vector2(CELL - inset * 2.0, CELL - inset * 2.0)
		)
		var lit := _marker_lit(item, cell, filter)
		if lit:
			var fill := color
			fill.a = 0.20
			draw_rect(rect, fill, true)
		var line := color
		if not lit:
			line.a = 0.5
		_draw_corners(rect, line, 2.0 if lit else 1.0)


## 四个角括号。比整圈描边省墨，也不会被误读成物品轮廓。
func _draw_corners(rect: Rect2, color: Color, width: float) -> void:
	var arm := rect.size.x * MARK_CORNER
	var l := rect.position.x
	var r := rect.position.x + rect.size.x
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y
	for corner in [
		[Vector2(l, top), Vector2(arm, 0), Vector2(0, arm)],
		[Vector2(r, top), Vector2(-arm, 0), Vector2(0, arm)],
		[Vector2(l, bottom), Vector2(arm, 0), Vector2(0, -arm)],
		[Vector2(r, bottom), Vector2(-arm, 0), Vector2(0, -arm)],
	]:
		var at: Vector2 = corner[0]
		draw_line(at, at + corner[1], color, width)
		draw_line(at, at + corner[2], color, width)


## 这一格是否被一个符合过滤条件的邻居占住。判据与 [Compiler] 的点亮规则一致：
## 得是别人、得是普通物品、标签得对得上。
func _marker_lit(item: ItemInstance, cell: Vector2i, filter: Array[StringName]) -> bool:
	var other := inventory.cell_uid(cell)
	if other == GridInventory.EMPTY_UID or other == item.uid:
		return false
	var other_inst := inventory.get_item(other)
	return other_inst != null and AdjacencyProfile.accepts(filter, other_inst.def)
#endregion
