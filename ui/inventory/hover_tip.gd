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
var _terms: Array = []
var _views: Array[ContainerView] = []
var _board_of: Callable = Callable()     # view → 拿来编译的棋盘（暂存区里的道具单独编）
## 可选：`func(view, uid) -> bool`，假就不显示（容器屏：没亮出来的不说）
var can_show: Callable = Callable()
var _font: Font
var _uid: int = -1
var _for_view: ContainerView = null


func _init(font: Font = null) -> void:
	_font = font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiPalette.PANEL, 0.96)
	style.border_color = UiPalette.LINE
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = MAX_WIDTH
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		_text.add_theme_font_override("normal_font", _font)
		_text.add_theme_font_override("bold_font", _font)
		_text.add_theme_font_override("italics_font", _font)
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.add_theme_font_size_override("bold_font_size", 13)
	_text.add_theme_font_size_override("italics_font_size", 13)
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
	var tip := HoverTip.new(UiPalette.cjk_font())
	top.add_child(tip)
	tip.watch(view)
	return tip


## 登记一个容器视图：停在道具上就显示 [ItemTooltip]。[param board_of] 可选：`func(view) -> GridInventory`，给编译用
func watch(view: ContainerView, board_of: Callable = Callable()) -> void:
	if _views.has(view):
		return
	_views.append(view)
	_board_of = board_of if board_of.is_valid() else _board_of
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


## 现在显示的词条（测试看）
func terms() -> Array:
	return _terms


func _set_terms(terms: Array) -> void:
	_terms = terms
	for c in _side.get_children():
		_side.remove_child(c)
		c.queue_free()
	for t in terms:
		var d := t as Dictionary
		var p := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UiPalette.PANEL, 0.96)
		style.border_color = Glossary.TERM_COLOR.darkened(0.3)
		style.set_border_width_all(1)
		style.set_content_margin_all(8)
		p.add_theme_stylebox_override("panel", style)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = SIDE_WIDTH
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _font != null:
			l.add_theme_font_override("normal_font", _font)
			l.add_theme_font_override("bold_font", _font)
		l.add_theme_font_size_override("normal_font_size", 12)
		l.add_theme_font_size_override("bold_font_size", 12)
		l.text = "[color=#%s][b]%s[/b][/color]\n%s" % [Glossary.TERM_COLOR.to_html(false), String(d["name"]), String(d["text"])]
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
		elif _board_of.is_valid():
			board = _board_of.call(view)
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
	if view is StashView:
		var sv := view as StashView
		if sv.stash == null:
			return -1
		var row := sv.row_at_local(local)
		var list := sv.stash.items()
		return (list[row] as ItemInstance).uid if row < list.size() else -1
	return -1


## 放在鼠标右下，出屏就翻到左 / 上；词条列贴在主面板右边，右边放不下就放左边
func _place(global_at: Vector2) -> void:
	var local := global_at - global_position
	var s := _panel.size
	var area := size
	var side_w := _side.size.x if _side.visible else 0.0
	var p := local + Vector2(16, 16)
	if p.x + s.x + (side_w + 6 if side_w > 0 else 0) > area.x:
		p.x = local.x - s.x - 8
	if p.y + s.y > area.y:
		p.y = local.y - s.y - 8
	_panel.position = Vector2(maxf(0.0, p.x), maxf(0.0, p.y))
	if _side.visible:
		var sp := _panel.position + Vector2(s.x + 6, 0)
		if sp.x + side_w > area.x:
			sp.x = _panel.position.x - side_w - 6
		if sp.y + _side.size.y > area.y:
			sp.y = maxf(0.0, area.y - _side.size.y)
		_side.position = Vector2(maxf(0.0, sp.x), sp.y)
