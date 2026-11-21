## 355：后勤「食堂」页（[Canteen]）—— 第一批占位，等 UI设计 的样张：
## 左边食材仓库的格子盘，中间锅的格子盘，食材在两块盘之间拖（整屏那一层拖拽，和仓库 → 背包同一套操作）；
## 右边一张纸条：这一锅每条属性固定值、百分比分开列，按当前角色算好的终值，下面饱腹度；
## 第二批：纸条下面是收藏夹 —— 【收藏】锅里这一锅，一排菜单牌点一下照它重做（缺料的位置在锅上标出来），可改名、删除。两块盘都画外框和格线
extends HBoxContainer

signal changed()

const CELL := 44.0
const INK := Color("2e2219")
## 缺料那几格：浅红底 + 朱红细框（占位，等 UI设计）
const GAP_FILL := Color(0.80, 0.25, 0.18, 0.18)
const GAP_LINE := Color("c0392b")

var flow: GameFlow = null
var drag: DragLayer = null
var font: Font = null
var store_view: InventoryView = null
var pot_view: InventoryView = null
var _store: GridInventory = null
var _pot: GridInventory = null
var _store_box: VBoxContainer = null
var _pot_box: VBoxContainer = null
var _lines: VBoxContainer = null
var _satiety: Label = null
var _finals_head: Label = null
var _finals: VBoxContainer = null
var _pot_name: Label = null
var _save_btn: Button = null
var _menu_box: VBoxContainer = null
var _gap_layer: Control = null
## 正在改名的那一份（-1 = 没在改）
var _renaming := -1
var _dirty := false


func setup(p_flow: GameFlow, p_drag: DragLayer, p_font: Font) -> void:
	flow = p_flow
	drag = p_drag
	font = p_font
	name = "CanteenPanel"
	add_theme_constant_override("separation", 24)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_store_box = UiTheme.vbox(8)
	add_child(_store_box)
	_pot_box = UiTheme.vbox(8)
	add_child(_pot_box)
	var paper := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 20, 16, 20, 16)
	paper.name = "MealNote"
	UiTheme.set_tone(paper, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	paper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	paper.custom_minimum_size.x = 240
	add_child(paper)
	var col := UiTheme.vbox(10)
	paper.add_child(col)
	_lines = UiTheme.vbox(6)
	col.add_child(_lines)
	_satiety = UiTheme.make_label("", 18, INK)
	_satiety.name = "Satiety"
	_satiety.tooltip_text = UiText.t("canteen.satiety_tip")
	_satiety.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_satiety)
	_finals_head = UiTheme.make_label("", 15, INK)
	col.add_child(_finals_head)
	_finals = UiTheme.vbox(4)
	col.add_child(_finals)
	col.add_child(HSeparator.new())
	_pot_name = UiTheme.make_label("", 17, INK)
	_pot_name.name = "PotName"
	col.add_child(_pot_name)
	_save_btn = UiTheme.make_button(UiText.t("canteen.menu_save"), func(): save_menu(), UiPalette.Tier.SECONDARY, 16)
	_save_btn.name = "SaveMenu"
	col.add_child(_save_btn)
	_menu_box = UiTheme.vbox(4)
	_menu_box.name = "Menus"
	col.add_child(_menu_box)
	if drag != null:
		drag.drag_finished.connect(func(_uid: int, _dropped: bool): _save_if_dirty())
	refresh()


## 两块盘换了（灰灯升档、读档）就重建视图；再刷右边的纸条
func refresh() -> void:
	if flow == null or flow.meta == null:
		return
	var c := flow.meta.canteen
	if c.store != _store or c.pot != _pot:
		_rebuild(c)
	_fill_note()


func _rebuild(c: Canteen) -> void:
	for v in [store_view, pot_view]:
		if v != null and drag != null:
			drag.unregister_view(v)
	for box in [_store_box, _pot_box]:
		for ch in (box as Control).get_children():
			(box as Control).remove_child(ch)
			ch.queue_free()
	_store = c.store
	_pot = c.pot
	store_view = _board(_store_box, _store, "canteen.store", "StoreView")
	pot_view = _board(_pot_box, _pot, "canteen.pot", "PotView")
	_gap_layer = Control.new()     # 缺料那几格画在锅上面，不挡拖放
	_gap_layer.name = "Gaps"
	_gap_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gap_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gap_layer.draw.connect(_draw_gaps)
	pot_view.add_child(_gap_layer)
	for g in [_store, _pot]:
		(g as GridInventory).changed.connect(_on_grid_changed)


func _board(box: VBoxContainer, grid: GridInventory, head: String, view_name: String) -> InventoryView:
	box.add_child(HeaderTag.new(UiText.t(head)))
	var v := InventoryView.make(grid, font)
	v.name = view_name
	v.cell_px = CELL
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(v)
	BoardFrame.wrap(v)     # 所有棋盘都画外框和格线
	if drag != null:
		drag.register_view(v)
	return v


func _on_grid_changed() -> void:
	_dirty = true
	_fill_note()
	if drag == null or not drag.is_dragging():
		_save_if_dirty()


func _save_if_dirty() -> void:
	if not _dirty:
		return
	_dirty = false
	flow.save_meta()
	changed.emit()


## 右边纸条：每条属性一行（固定值、百分比分开），饱腹度一行。锅是空的只留饱腹 0
func _fill_note() -> void:
	if _lines == null:
		return
	for ch in _lines.get_children():
		_lines.remove_child(ch)
		ch.queue_free()
	var meal := flow.canteen_meal()
	for stat in Canteen.STATS:
		var text := Canteen.line_of(meal, stat)
		if text != "":
			_lines.add_child(UiTheme.make_label(text, 17, INK))
	_satiety.text = UiText.t("canteen.satiety") % int(meal.get("satiety", 0))
	var ch := flow.canteen_viewer()
	Canteen.viewer = ch
	for c in _finals.get_children():
		_finals.remove_child(c)
		c.queue_free()
	var finals := Canteen.final_lines(ch, meal)
	_finals_head.text = UiText.t("canteen.for") % Names.of(ch) if ch != null and not finals.is_empty() else ""
	_finals_head.visible = _finals_head.text != ""
	for t in finals:
		_finals.add_child(UiTheme.make_label(t, 15, INK))
	_fill_menus()
	if _gap_layer != null:
		_gap_layer.queue_redraw()


#region 收藏夹
## 锅的名字（照收藏的 = 那份的名字，缺几样跟在后面）、【收藏】、一排菜单牌
func _fill_menus() -> void:
	var c := flow.meta.canteen
	var n := c.menu_name()
	var miss := c.gaps().size()
	_pot_name.text = (n if n != "" else UiText.t("canteen.unnamed")) + ("  " + UiText.t("canteen.gaps") % miss if miss > 0 else "")
	_save_btn.disabled = c.menus.size() >= Canteen.MAX_MENUS or c.pot.item_count() == 0
	if c.menus.size() >= Canteen.MAX_MENUS:
		_save_btn.tooltip_text = UiText.t("canteen.menu_full")
	elif c.pot.item_count() == 0:
		_save_btn.tooltip_text = UiText.t("canteen.menu_empty_pot")
	else:
		_save_btn.tooltip_text = UiText.t("canteen.menu_save_tip") % Canteen.MAX_MENUS
	for ch in _menu_box.get_children():
		_menu_box.remove_child(ch)
		ch.queue_free()
	for i in c.menus.size():
		_menu_box.add_child(_menu_row(i, String(c.menus[i].get("name", "")), i == c.active))


func _menu_row(i: int, title: String, lit: bool) -> Control:
	var row := UiTheme.hbox(4)
	row.name = "Menu%d" % i
	if _renaming == i:
		var edit := LineEdit.new()
		edit.name = "NameEdit"
		edit.text = title
		edit.max_length = Canteen.NAME_MAX
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_submitted.connect(func(t: String): rename_menu(i, t))
		edit.focus_exited.connect(func(): rename_menu(i, edit.text))
		row.add_child(edit)
		(func(): if edit.is_inside_tree(): edit.grab_focus()).call_deferred()
		return row
	var pick := UiTheme.make_button(title, func(): load_menu(i), UiPalette.Tier.SECONDARY, 15)
	pick.name = "Load"
	pick.tooltip_text = UiText.t("canteen.menu_load_tip")
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiTheme.mark(pick, lit)
	row.add_child(pick)
	var ren := UiTheme.make_button(UiText.t("canteen.menu_rename"), func(): start_rename(i), UiPalette.Tier.SECONDARY, 13)
	ren.name = "Rename"
	row.add_child(ren)
	var del := UiTheme.make_button(UiText.t("canteen.menu_delete"), func(): delete_menu(i), UiPalette.Tier.SECONDARY, 13)
	del.name = "Delete"
	row.add_child(del)
	return row


## 【收藏】：成了返回第几份
func save_menu(p_name: String = "") -> int:
	var i := flow.canteen_save_menu(p_name)
	_after_menu()
	return i


## 点菜单牌：照这份重做（缺料的格在锅上标出来）
func load_menu(i: int) -> Array[Dictionary]:
	var gaps := flow.canteen_load_menu(i)
	_after_menu()
	return gaps


func start_rename(i: int) -> void:
	_renaming = i
	_fill_menus()


func rename_menu(i: int, p_name: String) -> bool:
	if _renaming != i:
		return false
	_renaming = -1
	var ok := flow.canteen_rename_menu(i, p_name)
	_fill_menus.call_deferred()     # 正在处理 LineEdit 自己的信号，下一帧再拆
	return ok


func delete_menu(i: int) -> bool:
	_renaming = -1
	var ok := flow.canteen_delete_menu(i)
	_after_menu()
	return ok


func _after_menu() -> void:
	_dirty = false
	_fill_note()
	changed.emit()


## 锅上缺料的那几格：照收藏的那份摆法，对不上的格子画浅红底、朱红框
func _draw_gaps() -> void:
	if pot_view == null or flow == null or flow.meta == null:
		return
	var px := pot_view.cell_px
	for g in flow.meta.canteen.gaps():
		var def := flow.items.get_def(StringName(String(g.get("id", ""))))
		if def == null:
			continue
		var at := Vector2i(int(g.get("x", 0)), int(g.get("y", 0)))
		for cell in def.cells_rotated(int(g.get("rot", 0))):
			var r := Rect2(pot_view.cell_origin_px(at + cell), Vector2(px, px)).grow(-3.0)
			_gap_layer.draw_rect(r, GAP_FILL, true)
			_gap_layer.draw_rect(r, GAP_LINE, false, 2.0)
#endregion
