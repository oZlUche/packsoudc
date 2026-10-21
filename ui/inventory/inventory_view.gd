## 一个 [GridInventory] 的可视化。
##
## 全部内容在 [method _draw] 里重画，不使用子节点表示物品 —— 这直接落实了
## 架构原则 1.2「从状态完整重建视图」：容器发 changed 就 queue_redraw，
## 不存在需要与真实状态对账的增量视图状态。
##
## 拖拽本身不在这里处理，见 [DragLayer]。本类只负责「告诉外面哪一件被按下了」
## 以及「按要求显示一个落点预览」。
##
## 只画**空间**容器。地上是个列表，见 [StashView]。
class_name InventoryView
extends ContainerView

## 139：格子边长变了（基地屏按宽度放大仓库）
signal cell_px_changed

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
## 201：休眠的信仰道具有图时压到 55 % 灰
const DORMANT_ART := Color(0.55, 0.55, 0.55)
const COLOR_OK := Color(0.35, 0.85, 0.45, 0.35)
const COLOR_BAD := Color(0.9, 0.3, 0.3, 0.35)
## 放得下，但会把别人顶出来。必须和「放不下」区分开 —— 都画成红的，
## 玩家会以为这一下没生效；都画成绿的，东西就会不声不响地被挤走。
const COLOR_DISPLACE := Color(0.95, 0.72, 0.25, 0.38)
## 即将被顶出来的那几件，描一圈边，让人看清代价
const COLOR_VICTIM := Color(0.98, 0.62, 0.25)
## 187：格线关着、手上拖着东西时，格底与格线按这个透明度临时画出来（落点要看得准）
const GRID_DRAG_ALPHA := 0.5
## 187：所有棋盘视图都在这一组里 —— 设置一改，整组重画
const GROUP := &"inventory_views"

## 187：棋盘格线画不画（设置「棋盘格线」，[method apply_grid_setting] 写）。背包、棋盘、仓库、敌人棋盘同一个开关
static var grid_shown := true

## 中文标签需要系统字体，Godot 内置字体不含 CJK 字形。
@export var label_font: Font

var inventory: GridInventory:
	set = set_inventory
## 139：这块视图自己的格子边长（默认 [constant CELL]）。基地屏的仓库按可用宽度放大；拖拽层对着视图算落点时读它
var cell_px: float = CELL:
	set(v):
		if is_equal_approx(cell_px, v):
			return
		cell_px = v
		if inventory != null:
			custom_minimum_size = Vector2(inventory.size) * cell_px
			size = custom_minimum_size
		cell_px_changed.emit()
		queue_redraw()

## 187：拖拽层拖着东西时打开（格线关着也临时画半透明的格）
var drag_hint := false:
	set(v):
		if drag_hint == v:
			return
		drag_hint = v
		queue_redraw()

var _preview_cells: Array[Vector2i] = []
var _preview_origin: Vector2i = Vector2i.ZERO
var _preview_valid: bool = false
var _preview_on: bool = false
## 本次落点会顶掉的物品 uid
var _preview_victims: Array[int] = []
## 合法但有代价：顶人或脱落
var _preview_costly: bool = false
## 193 §4：手上拿着的那件（拖拽中从容器里拿走了）与它现在的朝向 —— 落点预览上照样画它的增益 / 受益 / 装载格
var _held: ItemDef = null
var _held_rot: int = 0

## 棋盘美术（2026-10-19 定稿）：外框美术里已经画好了浅灰内垫，格缝由这里按 `layout.json` 的 `cell_seams` 画（容器屏设）；空 = 照旧
var seams: Dictionary = {}:
	set(v):
		seams = v
		queue_redraw()

## 是否画邻接标记格。战利品、商店货架这类地方不参战，画了只是噪音。
@export var show_adjacency: bool = true
## 085：物品右上角的小记号（uid → 文字），比如配了对等着合成的「合」。持有方设，改了 queue_redraw
var badges: Dictionary = {}
## 175：物品左下角的元素小图标（uid → [元素 id…]）。对阵屏给敌人棋盘设：看得出对面会带什么印。持有方设，改了 queue_redraw
var elements: Dictionary = {}
## 085：亮一圈的物品（uid → true）：拖着的那件能和它合成。拖拽层设
var highlights: Dictionary = {}
const COLOR_HIGHLIGHT := Color(0.42, 0.86, 0.52)


func _init() -> void:
	UiTheme.warm_slot_icons()     # 170：格位图标先读好，别等到 _draw 里第一次读（兼容渲染器下会画成白块）
	add_to_group(GROUP)


## 187：按设置定格线画不画，开着的棋盘都重画（启动时导演调、设置屏切了也调）
static func apply_grid_setting(settings: GameSettings, tree: SceneTree = null) -> void:
	grid_shown = settings == null or settings.grid_on(ItemPainter.art_available())
	if tree != null:
		tree.call_group(GROUP, "queue_redraw")


func container() -> ItemContainer:
	return inventory


func set_inventory(inv: GridInventory) -> void:
	if inventory == inv:
		return
	if inventory != null and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = inv
	if inventory != null:
		inventory.changed.connect(_on_inventory_changed)
		custom_minimum_size = Vector2(inventory.size) * cell_px
		size = custom_minimum_size
	queue_redraw()


## 110：容器变了就重画；格子长了（仓库扩建 `grow_rows`）视图跟着变高
func _on_inventory_changed() -> void:
	var want := Vector2(inventory.size) * cell_px
	if custom_minimum_size != want:
		custom_minimum_size = want
		size = want
	queue_redraw()


#region 坐标换算
## 本控件内的像素坐标 → 格坐标。可能越界，调用方自行判断。
func cell_at_local(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell_px), floori(p.y / cell_px))


## 全局像素坐标 → 格坐标。
func cell_at_global(p: Vector2) -> Vector2i:
	return cell_at_local(p - global_position)


## 格坐标 → 本控件内的像素坐标（该格左上角）。
func cell_origin_px(c: Vector2i) -> Vector2:
	return Vector2(c) * cell_px
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


## 193 §4：落点预览带上手上这件（[DragLayer] 每次刷新预览时给）；null = 不画它的格位
func set_held(def: ItemDef, rot: int) -> void:
	_held = def
	_held_rot = rot
	queue_redraw()


## 193 §4：一件道具在 [param rot] 朝向下的格位标记（相对它的锚点，和 [method ItemInstance.absolute_cells] 同一套旋转）：
## `[[格, 种类, 过滤, 全要过滤]]`，种类 grant / receive / load。拖拽层在棋盘外也按它画
static func marker_offsets(def: ItemDef, rot: int) -> Array:
	var out := []
	if def == null or def.adjacency == null or def.shape == null:
		return out
	var p := def.adjacency
	if p.has_grant():
		for o in p.grant_cells:
			out.append([def.shape.transform_point(o, rot), "grant", p.grant_filter, p.grant_filter_all])
	if p.has_receive():
		for o in p.receive_cells:
			out.append([def.shape.transform_point(o, rot), "receive", p.receive_filter, [] as Array[StringName]])
	if p.has_load():
		for o in p.load_cells:
			out.append([def.shape.transform_point(o, rot), "load", p.load_tags(), [] as Array[StringName]])
	return out


## 193 §4：这一帧落点预览上会画的手上这件的格位 `[[格, 种类, 点亮]]` —— 点亮按现在棋盘上的邻居算，放手前就看得见谁会亮
func preview_markers() -> Array:
	var out := []
	if not _preview_on or _held == null or inventory == null or inventory.acts_as_bag(_held):
		return out
	for m in marker_offsets(_held, _held_rot):
		var cell: Vector2i = _preview_origin + (m[0] as Vector2i)
		if inventory.in_bounds(cell):
			out.append([cell, String(m[1]), _cell_lit(-1, cell, m[2], m[3])])
	return out


## 157：现在画着的落点预览是不是能放（拖拽层按它切光标）
func preview_ok() -> bool:
	return _preview_on and _preview_valid


func clear_preview() -> void:
	if not _preview_on:
		return
	_preview_on = false
	_preview_cells = []
	_preview_victims = []
	_preview_costly = false
	_held = null
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


## 187：格底与格线此刻按多少透明度画：开着 1；关着时拖着东西 [constant GRID_DRAG_ALPHA]，否则 0（不画）
func grid_alpha() -> float:
	return 1.0 if grid_shown else (GRID_DRAG_ALPHA if drag_hint else 0.0)


## 这件要不要画名字。[LootView] 覆盖：没亮的不画（087）
func _label_visible(_item: ItemInstance) -> bool:
	return true


func _draw() -> void:
	if inventory == null:
		return
	var grid_px := Vector2(inventory.size) * cell_px

	# 187：格线关着时不画底、格底、线、外框 —— 包体与道具照画；拖着东西时格底与线按 [constant GRID_DRAG_ALPHA] 临时画
	var grid_alpha := grid_alpha()
	var framed := not seams.is_empty()
	if framed:
		_draw_seams(grid_px, grid_alpha)     # 棋盘美术：内垫在外框图里，这里只画格缝（拖着东西时压暗不能用的格）
	else:
		if grid_shown:
			draw_rect(Rect2(Vector2.ZERO, grid_px), COLOR_BG, true)
		if grid_alpha > 0.0:
			_draw_grid(grid_px, grid_alpha)

	var font := label_font if label_font != null else get_theme_default_font()

	# 包体：作为底层区域先画，物品压在上面。
	# 用统一的灰调而不是物品配色 —— 包是承载物，抢了内容物的视觉就本末倒置了
	for bag in inventory.bags():
		var b := bag as ItemInstance
		var bag_cells := b.cells()
		var bag_anchor := cell_origin_px(b.origin)
		if ItemPainter.draw_art(self, b.def, b.rotation, bag_anchor, cell_px, Color.WHITE, Transform2D.IDENTITY, ItemPainter.variant_of(b)):
			continue     # 201：包有图就画图（包也是道具），内容物照样压在上面
		ItemPainter.draw_item(self, bag_cells, bag_anchor, cell_px, COLOR_BAG_FILL, COLOR_BAG_EDGE)
		ItemPainter.draw_label(
			self, bag_cells, bag_anchor, cell_px, Names.of(b.def), font, 11, Color("79839a")
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
		if item.def.is_bag and not item.def.has_faith():
			# 自由容器里（战利品落成一堆东西、仓库）的包也是包：画成统一的包灰，不按稀有度上色（和棋盘上当底层的包一致）
			body = COLOR_BAG_FILL
			edge = COLOR_BAG_EDGE
			text_color = Color("79839a")
		if dormant:
			body = body.lerp(COLOR_BAG_FILL, 0.7)
			edge = edge.lerp(COLOR_BAG_EDGE, 0.7)
			text_color = COLOR_TEXT.darkened(0.35)
		# 201：有图就画图、不写名字（170：名字在悬浮窗）；休眠的压到 55 % 灰，仍写小字「休眠」
		var tint := DORMANT_ART if dormant else Color.WHITE
		if ItemPainter.draw_art(self, item.def, item.rotation, anchor, cell_px, tint, Transform2D.IDENTITY, ItemPainter.variant_of(item)):
			if dormant and _label_visible(item):
				ItemPainter.draw_label(self, cells, anchor, cell_px, UiText.t("inv.dormant"), font, 13, COLOR_TEXT)
		else:
			ItemPainter.draw_item(self, cells, anchor, cell_px, body, edge)
			if _label_visible(item):
				ItemPainter.draw_label(
					self, cells, anchor, cell_px, Names.of_item(item) + ("
休眠" if dormant else ""), font, 13, text_color
				)
		ItemPainter.draw_charges(self, item, item.rotation, anchor, cell_px, tint)     # 208：耐久没满、又没这一档的图：左下角次数点
		if highlights.has(item.uid):
			var hb := item.def.shape.size_rotated(item.rotation)
			var pulse := 0.6 + 0.4 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
			draw_rect(Rect2(anchor - Vector2(3, 3), Vector2(hb) * cell_px + Vector2(6, 6)), Color(COLOR_HIGHLIGHT, pulse), false, 3.0)
		if elements.has(item.uid):
			_draw_elements(item, anchor, elements[item.uid])
		if badges.has(item.uid):
			var badge := String(badges[item.uid])
			var box := item.def.shape.size_rotated(item.rotation)
			var at := anchor + Vector2(box.x * cell_px - 18.0, 4.0)
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
			draw_rect(Rect2(cell_origin_px(p), Vector2(cell_px, cell_px)), tint, true)

		# 193 §4：手上这件的格位（含旋转），点亮照现在的邻居
		var held := {}
		for m in preview_markers():
			if not held.has(m[0]):
				held[m[0]] = []
			(held[m[0]] as Array).append(m)
		for cell in held:
			var list: Array = held[cell]
			for i in list.size():
				var kind := String(list[i][1])
				_draw_marker(cell, kind, bool(list[i][2]), MARK_COLORS.get(kind, UiPalette.GRANT), MARK_INSET_GRANT if kind == "grant" else MARK_INSET_RECEIVE, i, list.size())

		# 被顶的那几件描一圈，让人放手前就知道要付什么代价
		for uid in _preview_victims:
			var victim := inventory.get_item(uid)
			if victim == null:
				continue
			for c in victim.cells():
				var p := victim.origin + c
				draw_rect(
					Rect2(cell_origin_px(p) + Vector2(2, 2), Vector2(cell_px - 4, cell_px - 4)),
					COLOR_VICTIM, false, 2.0
				)

	if grid_shown and not framed:
		draw_rect(Rect2(Vector2.ZERO, grid_px), COLOR_BORDER, false, 2.0)


## 棋盘美术：格缝 = 深线 + 右 / 下错开一点的亮线，两端各留一点；外圈不画（内垫的缝线框就是边）。
## 格线开着或拖着东西时，被挡住的、没被包盖住的格压一层暗（按 [param alpha]），落点照样看得准
func _draw_seams(grid_px: Vector2, alpha: float) -> void:
	if alpha > 0.0:
		for y in inventory.size.y:
			for x in inventory.size.x:
				var c := Vector2i(x, y)
				if inventory.is_blocked(c) or not inventory.is_covered(c):
					draw_rect(Rect2(cell_origin_px(c), Vector2(cell_px, cell_px)), Color(0, 0, 0, 0.16 * alpha), true)
	var seam := Color(String(seams.get("seam", "#8e8b85")))
	var hi := Color(String(seams.get("hi", "#ebe9e4")))
	var seam_w := float(seams.get("seam_w", 1.6))
	var hi_w := float(seams.get("hi_w", 1.0))
	var off := float(seams.get("hi_offset", 1.4))
	const TRIM := 2.0
	for x in range(1, inventory.size.x):
		var fx := x * cell_px
		draw_line(Vector2(fx, TRIM), Vector2(fx, grid_px.y - TRIM), seam, seam_w)
		draw_line(Vector2(fx + off, TRIM), Vector2(fx + off, grid_px.y - TRIM), hi, hi_w)
	for y in range(1, inventory.size.y):
		var fy := y * cell_px
		draw_line(Vector2(TRIM, fy), Vector2(grid_px.x - TRIM, fy), seam, seam_w)
		draw_line(Vector2(TRIM, fy + off), Vector2(grid_px.x - TRIM, fy + off), hi, hi_w)


## 格底（棋盘模式下未被包覆盖的格子最暗，表示「还不能用」）与网格线
func _draw_grid(grid_px: Vector2, alpha: float) -> void:
	for y in inventory.size.y:
		for x in inventory.size.x:
			var c := Vector2i(x, y)
			var col := COLOR_CELL
			if inventory.is_blocked(c):
				col = COLOR_BLOCKED
			elif not inventory.is_covered(c):
				col = COLOR_UNUSABLE
			draw_rect(Rect2(cell_origin_px(c) + Vector2.ONE, Vector2(cell_px - 2, cell_px - 2)), Color(col, col.a * alpha), true)
	var line := Color(COLOR_GRID, COLOR_GRID.a * alpha)
	for x in inventory.size.x + 1:
		var fx := x * cell_px
		draw_line(Vector2(fx, 0), Vector2(fx, grid_px.y), line, 1.0)
	for y in inventory.size.y + 1:
		var fy := y * cell_px
		draw_line(Vector2(0, fy), Vector2(grid_px.x, fy), line, 1.0)


#region 邻接标记
## 170：有美术图标就画图标（增益 / 受益 / 装载三种，点亮 / 没点亮两态）；没图时的老画法 ——
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
## 193：格位种类 → 没图时画角括号用的颜色
const MARK_COLORS := {"grant": UiPalette.GRANT, "receive": UiPalette.RECEIVE, "load": UiPalette.MANA}
## 角括号单边长度，占格边的比例
const MARK_CORNER := 0.3


## 175：元素小图标 —— 左下角一排深色圆片，元素的伤害色描圈、写单字（火 / 冰 / 雷 / 毒 / 血；图标交美术）
func _draw_elements(item: ItemInstance, anchor: Vector2, els: Array) -> void:
	var box := item.def.shape.size_rotated(item.rotation)
	var font := label_font if label_font != null else get_theme_default_font()
	var r := 11.0
	var fs := 14
	for i in els.size():
		var el := StringName(String(els[i]))
		var c := anchor + Vector2(4.0 + r + i * (r * 2.0 + 3.0), box.y * cell_px - 4.0 - r)
		draw_circle(c, r, Color(0.08, 0.08, 0.1, 0.9))
		draw_arc(c, r, 0.0, TAU, 24, UiPalette.damage_color(el), 2.0)
		var ch := ReactionResolver.element_name(el, "zh")
		var at := c + Vector2(-font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, fs * 0.36)
		draw_string(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiPalette.damage_color(el))


## 175：一块棋盘上每件道具带的元素（编译后，含别人挂上来的规则；不带的不列）—— 给 [member elements] 用
static func elements_of_board(board: GridInventory) -> Dictionary:
	var out := {}
	if board == null:
		return out
	var spec := BattleCompiler.compile_board(board)
	if spec == null:
		return out
	for it in spec.items:
		var els := ReactionResolver.elements_of_item(it as CompiledItem)
		if not els.is_empty():
			out[(it as CompiledItem).source_uid] = els
	return out


func _draw_adjacency() -> void:
	var marks := {}     # 170：格 → [[种类, 点亮, 颜色, 缩进]]；同一格好几种时图标错开摆
	var loads := {}     # 171：晶石 uid → 拿到它的法杖（被别的法杖抢走的那把，装载格按空画）
	for inst in inventory.items():
		var item := inst as ItemInstance
		if item.def == null or item.def.adjacency == null:
			continue
		if inventory.acts_as_bag(item.def):
			continue
		var profile := item.def.adjacency
		if profile.has_grant():
			_collect_markers(marks, item, profile.grant_cells, profile.grant_filter, profile.grant_filter_all, "grant", UiPalette.GRANT, MARK_INSET_GRANT)
		if profile.has_receive():
			_collect_markers(marks, item, profile.receive_cells, profile.receive_filter, [] as Array[StringName], "receive", UiPalette.RECEIVE, MARK_INSET_RECEIVE)
		if profile.has_load():     # 171：法杖的装载格
			if loads.is_empty():
				loads = BattleCompiler.load_assignments(inventory)
				loads[-1] = -1     # 算过了（空表也只算一次）
			_collect_markers(marks, item, profile.load_cells, profile.load_tags(), [] as Array[StringName], "load", UiPalette.MANA, MARK_INSET_RECEIVE, loads)
	for cell in marks:
		var list: Array = marks[cell]
		for i in list.size():
			var m: Array = list[i]
			_draw_marker(cell, String(m[0]), bool(m[1]), m[2], float(m[3]), i, list.size())


func _collect_markers(
	marks: Dictionary, item: ItemInstance, offsets: Array[Vector2i], filter: Array[StringName], filter_all: Array[StringName],
	kind: String, color: Color, inset: float, loads: Dictionary = {}
) -> void:
	for cell in item.absolute_cells(offsets):
		if not inventory.in_bounds(cell):
			continue
		if not marks.has(cell):
			marks[cell] = []
		var lit := _marker_lit(item, cell, filter, filter_all)
		if kind == "load":
			lit = lit and int(loads.get(inventory.cell_uid(cell), -2)) == item.uid
		marks[cell].append([kind, lit, color, inset])


## 193 补充二（作者 2026-10-18 21:39 定 40）：格位图标的边长 —— 40，格子小了按格宽的 0.67 缩（格 60 时正好 40）
static func marker_side(cell: float) -> float:
	return minf(MARKER_SIDE, cell * 0.67)


const MARKER_SIDE := 40.0


## 170（作者定）：格位画美术给的图标（`assets/ui/tip/<种类>_on|off.png`，点亮 / 没点亮两张），替换原来的半透明方框；
## 一格上只有一种就居中，好几种沿对角线错开。图不在就画回原来的角括号（点亮的填色加粗）
func _draw_marker(cell: Vector2i, kind: String, lit: bool, color: Color, inset: float, index: int, count: int) -> void:
	var tex := UiTheme.slot_icon(kind, lit)
	if tex != null:
		var side := marker_side(cell_px)
		var origin := cell_origin_px(cell)
		var at := origin + Vector2.ONE * (cell_px - side) * 0.5
		if count > 1:
			var t := float(index) / float(count - 1)
			at = origin + Vector2.ONE * lerpf(2.0, cell_px - side - 2.0, t)
		draw_texture_rect(tex, Rect2(at, Vector2(side, side)), false)
		return
	var rect := Rect2(
		cell_origin_px(cell) + Vector2(inset, inset),
		Vector2(cell_px - inset * 2.0, cell_px - inset * 2.0)
	)
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
func _marker_lit(item: ItemInstance, cell: Vector2i, filter: Array[StringName], filter_all: Array[StringName] = []) -> bool:
	return _cell_lit(item.uid, cell, filter, filter_all)


## 193：[method _marker_lit] 按 uid 的版本（手上那件不在棋盘上，传 -1）
func _cell_lit(self_uid: int, cell: Vector2i, filter: Array[StringName], filter_all: Array[StringName] = []) -> bool:
	var other := inventory.cell_uid(cell)
	if other == GridInventory.EMPTY_UID or other == self_uid:
		return false
	var other_inst := inventory.get_item(other)
	return other_inst != null and AdjacencyProfile.accepts(filter, other_inst.def) and AdjacencyProfile.accepts_all(filter_all, other_inst.def)
#endregion
