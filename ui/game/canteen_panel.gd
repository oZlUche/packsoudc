## 355：后勤「食堂」页（[Canteen]）—— 第一批占位，等 UI设计 的样张：
## 左边食材仓库的格子盘，中间锅的格子盘，食材在两块盘之间拖（整屏那一层拖拽，和仓库 → 背包同一套操作）；
## 右边一张纸条：这一锅每条属性固定值、百分比分开列，下面饱腹度。两块盘都画外框和格线；收藏菜单留到第二批
extends HBoxContainer

signal changed()

const CELL := 44.0
const INK := Color("2e2219")

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
