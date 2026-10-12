## 悬浮窗（084）：跟着鼠标的一小块面板，写 BBCode。两处用：容器视图里停在一件道具上（[ItemTooltip]），地图上停在一个点上（[NodeTooltip]）。
## 087：主面板旁边一列**词条小窗**（[Glossary]）：主文字里标了色的名词，每个在侧边有一块写具体效果；放不下右边就放左边。
##
## 加进一个铺满的宿主控件里（叠层 / 屏），自己不挡鼠标。登记容器视图后，鼠标在视图里动就查底下是哪件、显示说明；
## 别的来源（地图）直接调 [method show_text] / [method hide_tip]
class_name HoverTip
extends Control

const MAX_WIDTH := 380.0

const SIDE_WIDTH := 240.0

var _panel: PanelContainer
var _text: RichTextLabel
var _extra: Control = null
## 词条小窗那一列
var _side: VBoxContainer
var _views: Array[ContainerView] = []
## 可选：`func(view, uid) -> bool`，假就不显示（容器屏：没亮出来的不说）
var can_show: Callable = Callable()
var _uid: int = -1
var _for_view: ContainerView = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60     # 128：画在地上（盖在各屏上面的那一层）的东西之上
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	UiTheme.panel(_panel, -1, UiTheme.PANEL_TOOLTIP)     # 157：悬浮窗底（美术给了纸就是九宫格，没给是半透明底细边）
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_text = UiTheme.rich_block(MAX_WIDTH, UiTheme.RICH_SMALL_SIZE)     # 121：13 号
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 6)
	_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.visible = false
	add_child(_side)


## 087：给一个容器视图找它该用的悬浮窗并登记上去：沿祖先往上找，谁的直接子节点里有 HoverTip 就用它（屏 / 面板自己造的那个）；
## 一路没有就在最顶层的 Control 祖先下造一个。返回用的那个（视图不在树里返回 null）
static func ensure_for(view: ContainerView) -> HoverTip:
	if view == null or not view.is_inside_tree():
		return null
	var node: Node = view.get_parent()
	var top: Control = null
	while node != null:
		for c in node.get_children():
			if c is HoverTip:
				(c as HoverTip).watch(view)
				return c
		if node is Control:
			top = node
		node = node.get_parent()
	if top == null:
		return null
	var tip := HoverTip.new()
	top.add_child(tip)
	tip.watch(view)
	return tip


## 登记一个容器视图：停在道具上就显示 [ItemTooltip]
func watch(view: ContainerView) -> void:
	if _views.has(view):
		return
	_views.append(view)
	view.gui_input.connect(func(event: InputEvent): _on_view_input(view, event))
	view.mouse_exited.connect(func():
		if _for_view == view:
			hide_tip())


## 直接显示一段文字（地图上的点）；[param extra] 是文字下面再放的一个控件（对手的棋盘），可为 null；
## [param terms] 是侧边词条 `[{name, text}]`（[Glossary.terms_in] 的结果），空 = 没有侧窗
func show_text(bbcode: String, at: Vector2, extra: Control = null, terms: Array = []) -> void:
	_text.text = bbcode
	if _extra != null:
		_extra.queue_free()
		_extra = null
	if extra != null:
		_extra = extra
		_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.get_child(0).add_child(_extra)
	_set_terms(terms)
	_panel.visible = true
	_panel.reset_size()
	_place(at)


func _set_terms(terms: Array) -> void:
	UiTheme.clear_children(_side)
	for t in terms:
		var d := t as Dictionary
		var p := UiTheme.panel(PanelContainer.new(), 8, UiTheme.PANEL_TOOLTIP)     # 157：词条小窗和主面板同一块底
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiTheme.rich_block(SIDE_WIDTH, 12, "[color=#%s][b]%s[/b][/color]\n%s" % [Glossary.TERM_COLOR.to_html(false), String(d["name"]), String(d["text"])])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
		_side.add_child(p)
	_side.visible = not terms.is_empty()
	_side.reset_size()


## 跟着鼠标走（地图上的浮窗：节点不变时也要跟）
func follow(global_at: Vector2) -> void:
	if _panel.visible:
		_place(global_at)


func hide_tip() -> void:
	_panel.visible = false
	_side.visible = false
	_uid = -1
	_for_view = null


func is_showing() -> bool:
	return _panel.visible


func text() -> String:
	return _text.text


func _on_view_input(view: ContainerView, event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null:
		return
	var uid := _uid_under(view, mm.position)
	if uid < 0 or uid == GridInventory.EMPTY_UID:
		if _for_view == view:
			hide_tip()
		return
	var inst := view.container().get_item(uid)
	if inst == null or (can_show.is_valid() and not bool(can_show.call(view, uid))):
		hide_tip()
		return
	_for_view = view
	if uid != _uid:
		_uid = uid
		var board: GridInventory = null
		if view is InventoryView:
			board = (view as InventoryView).inventory
		var full := ItemTooltip.describe_full(inst, board)
		_text.text = String(full["text"])
		if _extra != null:
			_extra.queue_free()
			_extra = null
		_set_terms(full["terms"])
		_panel.visible = true
		_panel.reset_size()
	_place(view.get_global_position() + mm.position)


func _uid_under(view: ContainerView, local: Vector2) -> int:
	if view is InventoryView:
		var iv := view as InventoryView
		if iv.inventory == null:
			return -1
		var c := iv.cell_at_local(local)
		var uid := iv.inventory.cell_uid(c)
		return uid if uid != GridInventory.EMPTY_UID else iv.inventory.bag_at(c)
	if view.has_method("uid_at_local"):
		return view.uid_at_local(local)     # 128：地上；157：事件的收获行
	return -1


## 放在鼠标右下，出屏就翻到左 / 上；词条列贴在主面板右边，右边放不下就放左边。
## 090（作者：主窗贴屏幕左边时侧窗压在了主窗上）：主窗 + 词条列当**一组**摆 —— 先试鼠标右边（主窗贴鼠标、词条列在它右边），
## 放不下再试左边（主窗贴鼠标、词条列在更左），两边都放不下就整组夹进屏里、词条列在右；不再各自夹边，所以永远不叠。
## 「屏」是真正的视口，不是本控件的尺寸（背包浮窗那种比屏窄的宿主里也要按屏算）
func _place(global_at: Vector2) -> void:
	var local := global_at - global_position
	var s := _panel.size
	var side_w := _side.size.x if _side.visible else 0.0
	var gap := 6.0 if _side.visible else 0.0
	var group_w := s.x + gap + side_w
	# 视口换到本控件坐标
	var vp_size := get_viewport_rect().size if is_inside_tree() else size
	var lo := -global_position
	var hi := lo + vp_size
	var px := local.x + 16
	var side_right := true
	if px + group_w > hi.x:
		var left_px := local.x - s.x - 8
		if left_px - gap - side_w >= lo.x:
			px = left_px
			side_right = false
		else:
			px = maxf(lo.x, hi.x - group_w)
	var py := local.y + 16
	if py + s.y > hi.y:
		py = local.y - s.y - 8
	py = maxf(lo.y, py)
	_panel.position = Vector2(px, py)
	if _side.visible:
		var sx := px + s.x + gap if side_right else px - gap - side_w
		var sy := py
		if sy + _side.size.y > hi.y:
			sy = maxf(lo.y, hi.y - _side.size.y)
		_side.position = Vector2(sx, sy)
