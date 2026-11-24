## 355：后勤「食堂」页（[Canteen]）—— 第一批占位，等 UI设计 的样张：
## 左边食材仓库的格子盘，中间锅的格子盘，食材在两块盘之间拖（整屏那一层拖拽，和仓库 → 背包同一套操作）；
## 右边一张纸条：这一锅每条属性固定值、百分比分开列，按当前角色算好的终值，下面饱腹度；
## 第二批：纸条下面是收藏夹 —— 【收藏】锅里这一锅，一排菜单牌点一下照它重做（缺料的位置在锅上标出来），可改名、删除。两块盘都画外框和格线。
## 383（作者 2026-11-23）：收藏改叫【配方】；应用配方时食材不够也照摆够的那部分，弹窗「食材不足，配方效果无法完整复现」。
## 纸条上多一颗【开饭】（确认这一锅，留到下一次出征），开过饭锅拖不动、配方换不了，出发吃掉才解开。
## 作者 2026-11-23 18:02 选 B 换石刻（UI设计 基地例图 2）：两块盘头上浅石小签、盘框深色；右边两块深石板 ——
## 「这一锅」（每条属性左名右数、饱腹，【记为配方】浅键 +【开饭】深键）与「配方」（每份一条浅石，名、缺几样朱红小牌、改名 / 删除、【应用】）
extends HBoxContainer

signal changed()

const CELL := 44.0
## 缺料那几格：浅红底 + 朱红细框（占位，等 UI设计）
const GAP_FILL := Color(0.80, 0.25, 0.18, 0.18)
const GAP_LINE := Color("c0392b")
## 收藏夹最多这么高，再多就在框里滚（收满 8 份也不出屏幕）
const MENUS_MAX_H := 330.0
## 右边那一列（两块深石板）的宽、【记为配方】【开饭】两颗键
const SIDE_W := 440.0
const KEY_SIZE := Vector2(150, 48)
const ROW_H := 48.0

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
var _eat_btn: Button = null
var _menu_box: VBoxContainer = null
var _menu_scroll: ScrollContainer = null
var _menus_card: PanelContainer = null
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
	var side := UiTheme.vbox(18)
	side.name = "Side"
	side.custom_minimum_size.x = SIDE_W
	add_child(side)
	var note := StoneKit.slate(20)
	note.name = "MealNote"
	note.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(note)
	var col := UiTheme.vbox(8)
	note.add_child(col)
	col.add_child(StoneKit.head(UiText.t("canteen.prep_title")))
	_lines = UiTheme.vbox(4)
	col.add_child(_lines)
	_satiety = UiTheme.make_label("", 17, StoneKit.TEXT)
	_satiety.name = "Satiety"
	_satiety.tooltip_text = UiText.t("canteen.satiety_tip")
	_satiety.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_satiety)
	_finals_head = UiTheme.make_label("", 15, StoneKit.BRASS)
	col.add_child(_finals_head)
	_finals = UiTheme.vbox(4)
	col.add_child(_finals)
	_pot_name = UiTheme.make_label("", 16, StoneKit.DIM)
	_pot_name.name = "PotName"
	col.add_child(_pot_name)
	var keys := UiTheme.hbox(12)
	col.add_child(keys)
	_save_btn = UiTheme.make_stone_button(UiText.t("canteen.menu_save"), func(): save_menu(), false, KEY_SIZE, 18)
	_save_btn.name = "SaveMenu"
	keys.add_child(_save_btn)
	_eat_btn = UiTheme.make_stone_button(UiText.t("canteen.eat"), func(): eat(), true, KEY_SIZE, 20)
	_eat_btn.name = "Eat"
	keys.add_child(_eat_btn)
	_menus_card = StoneKit.slate(20)
	_menus_card.name = "Recipes"
	side.add_child(_menus_card)
	var mcol := UiTheme.vbox(10)
	_menus_card.add_child(mcol)
	mcol.add_child(StoneKit.head(UiText.t("canteen.recipes")))
	_menu_scroll = UiTheme.vscroll()
	_menu_scroll.name = "MenuScroll"
	_menu_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mcol.add_child(_menu_scroll)
	_menu_box = UiTheme.vbox(8)
	_menu_box.name = "Menus"
	_menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_scroll.add_child(_menu_box)
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
	box.add_child(StoneKit.tag(UiText.t(head)))
	var v := InventoryView.make(grid, font)
	v.name = view_name
	v.cell_px = CELL
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(v)
	BoardFrame.wrap(v, "", true)     # 所有棋盘都画外框和格线（石刻：深框）
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
			_lines.add_child(_stat_row(text))
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
		_finals.add_child(UiTheme.make_label(t, 15, StoneKit.TEXT))
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
	_eat_btn.disabled = c.eaten or c.pot.item_count() == 0     # 383
	_eat_btn.text = UiText.t("canteen.eaten_mark") if c.eaten else UiText.t("canteen.eat")
	_eat_btn.tooltip_text = UiText.t("canteen.eaten_note") if c.eaten else (UiText.t("canteen.menu_empty_pot") if c.pot.item_count() == 0 else UiText.t("canteen.eat_tip"))
	_lock_pot(c.eaten)
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
	_menu_scroll.custom_minimum_size.y = minf(_menu_box.get_minimum_size().y, MENUS_MAX_H)
	_menus_card.visible = not c.menus.is_empty()


## 「负重上限 +3」拆成左名右数（金色）；拆不开就整句一行
func _stat_row(text: String) -> Control:
	var cut := text.rfind(" ")
	if cut <= 0:
		return UiTheme.make_label(text, 17, StoneKit.TEXT)
	return StoneKit.row(text.substr(0, cut), text.substr(cut + 1), StoneKit.GOLD, 17)


## 一份配方一条浅石：名字、缺料朱红小牌、改名 / 删除、【应用】（选中的那份字金色）
func _menu_row(i: int, title: String, lit: bool) -> Control:
	var row := StoneKit.strip([16, 6, 8, 6])
	row.name = "Menu%d" % i
	row.custom_minimum_size.y = ROW_H
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
	var c := flow.meta.canteen
	var line := UiTheme.hbox(8)
	row.add_child(line)
	var name_ := UiTheme.make_label(title, 18, LIT_INK if lit else UiTheme.STONE_INK)
	name_.name = "Title"
	name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_)
	var cov := c.coverage(c.menus[i].get("cells", []) as Array)
	var miss := (cov.get("gaps", []) as Array).size()
	if miss > 0:
		line.add_child(MealChip.make(UiText.t("canteen.gaps") % miss, MealChip.SHORT, 13))
	var ren := UiTheme.make_stone_button(UiText.t("canteen.menu_rename"), func(): start_rename(i), false, SMALL_KEY, 14)
	ren.name = "Rename"
	line.add_child(ren)
	var del := UiTheme.make_stone_button(UiText.t("canteen.menu_delete"), func(): delete_menu(i), false, SMALL_KEY, 14)
	del.name = "Delete"
	line.add_child(del)
	var pick := UiTheme.make_stone_button(UiText.t("canteen.apply"), func(): load_menu(i), true, SMALL_KEY, 15)
	pick.name = "Load"
	pick.tooltip_text = UiText.t("canteen.menu_load_tip")
	pick.disabled = c.eaten     # 383：吃过了不能换
	line.add_child(pick)
	return row


const SMALL_KEY := Vector2(58, 34)
## 锅里正照着的那份：名字换深琥珀
const LIT_INK := Color("8a5a1c")


## 【收藏】：成了返回第几份
func save_menu(p_name: String = "") -> int:
	var i := flow.canteen_save_menu(p_name)
	_after_menu()
	return i


## 点配方：照这份重做（缺料的格在锅上标出来）；缺料时弹窗提示（383，作者 2026-11-23）
func load_menu(i: int) -> Array[Dictionary]:
	var gaps := flow.canteen_load_menu(i)
	_after_menu()
	if not gaps.is_empty():
		short_notice = NoticeModal.open(self, UiText.t("canteen.short_title"), UiText.t("canteen.short_body"), [[UiText.t("coach.ok"), Callable(), true]])
	return gaps


## 最近一次「食材不足」的弹窗（测试用）
var short_notice: NoticeModal = null


## 383：【开饭】
func eat() -> bool:
	var ok := flow.canteen_eat()
	_after_menu()
	return ok


## 吃过了：锅不进拖拽层（拿不出、放不进）
func _lock_pot(on: bool) -> void:
	if drag == null or pot_view == null:
		return
	if on:
		drag.unregister_view(pot_view)
	else:
		drag.register_view(pot_view)     # 登记过的不重复登记


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
