## 163（作者定）：分页仓库的界面 —— 左边一列竖排页签（「一」「二」「三」……，下面一行小字写几件），右边一块格子显示当前页。
## 切页只换视图的 [member InventoryView.inventory]，视图与拖拽登记不重建。没解锁的页也列出来、灰色加一把小锁，悬停写要扩建到第几级。
## 拖着东西停在一个页签上 [constant HOVER_SEC] 秒切到那页（放手就落在那页）。
## 三处共用：基地右半边、开局屏第二页、结算屏。持有方把 [member view] 登记进自己的拖拽层、接双击
class_name WarehousePages
extends HBoxContainer

signal page_changed(index: int)

const TAB_W := 52.0
const TAB_H := 52.0
const HOVER_SEC := 0.4
## 164：基地右半边按宽高两个约束取小，夹在这两个数之间（40 保证 1280 × 720 下 10 × 8 整块可见、不滚）
const CELL_MIN := 40.0
const CELL_MAX := 80.0
## 页签列与格子之间的空（HBox 默认间距）
const GAP := 4.0
const NUMERALS := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

var warehouse: Warehouse = null
## 当前页的格子
var view: InventoryView = null
## 拖拽层（拖着东西悬停页签切页用；不给就不切）
var drag: DragLayer = null
var tab_box: VBoxContainer = null
## 180 定稿：页签换皮（开局屏第二页的挂牌，选中是按下态的图、没解锁是灰态的图，字色在变体里）；空 = 原来的平面按钮
var tab_variation: StringName = &""
## 页签多高（挂牌 60，绳子在上面）
var tab_height := TAB_H
## 格子外面套的框（[method setup] 之前给；空 = 不套，只有格子自己那圈深边）。228 结算第二页套基地那副木架 PANEL_SHELF，页签在框外左边
var frame_variation: StringName = &""
## 套上的框（没套是 null）
var frame: PanelContainer = null

var _tabs: Array[Button] = []
var _current := 0
## 一共列几个页签（含没解锁的）与每级几页（[method TechWarehousePages.plan_of]）
var _max_pages := 0
var _per_level := 1
var _tech_name := UiText.t("wh.expand_tech")
var _hover_tab := -1
var _hover_t := 0.0


## [param plan] 见 [method TechWarehousePages.plan_of]（空 = 只列已有的页）
func setup(p_warehouse: Warehouse, font: Font, p_drag: DragLayer = null, plan: Dictionary = {}) -> void:
	warehouse = p_warehouse
	drag = p_drag
	_max_pages = int(plan.get("max", 0))
	_per_level = maxi(1, int(plan.get("per_level", 1)))
	_tech_name = String(plan.get("name", _tech_name))
	tab_box = UiTheme.vbox(4)
	add_child(tab_box)
	view = InventoryView.new()
	view.label_font = font
	view.show_adjacency = false
	view.ground = InventoryView.GROUND_WAREHOUSE     # 224：棕底、浅格线在道具下面、外圈深色细边（三处一样）
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if frame_variation != &"":
		frame = UiTheme.panel(PanelContainer.new(), -1, frame_variation)
		frame.name = "ShelfFrame"
		frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
		frame.add_child(view)
		_finish_setup()
		return
	add_child(view)
	var edge_room := Control.new()     # 外圈深边（4 px）画在格子外面：右边垫一个空件，默认间距 4 正好让出它，别被滚动区裁掉（结算屏仓库右对齐时）
	edge_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge_room)
	_finish_setup()


func _finish_setup() -> void:
	warehouse.changed.connect(_refresh)
	_refresh()


## 框占掉的宽、高（两边合计；没套框是 0）
func frame_pad() -> Vector2:
	if frame == null:
		return Vector2.ZERO
	var box := frame.get_theme_stylebox("panel")
	return Vector2(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT), box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))


func current() -> int:
	return _current


func current_page() -> GridInventory:
	return warehouse.page(_current) if warehouse != null else null


func tab_count() -> int:
	return _tabs.size()


func tab(i: int) -> Button:
	return _tabs[i] if i >= 0 and i < _tabs.size() else null


func is_locked(i: int) -> bool:
	return warehouse == null or i >= warehouse.page_count()


## 164：一格多大 —— 一页 [param page] 整块摆进 [param width] × [param height]（宽里扣掉页签列），两个约束取小，夹在 [constant CELL_MIN] ～ [constant CELL_MAX]
static func cell_for(width: float, height: float, page: Vector2i) -> float:
	var by_w := (width - TAB_W - GAP) / float(maxi(1, page.x))
	var by_h := height / float(maxi(1, page.y))
	return clampf(floorf(minf(by_w, by_h)), CELL_MIN, CELL_MAX)


## 按 [param width] × [param height] 定格子大小（[method cell_for]），返回定下的边长
func fit(width: float, height: float) -> float:
	if view == null or warehouse == null:
		return InventoryView.CELL
	var pad := frame_pad()
	view.cell_px = cell_for(width - pad.x, height - pad.y, warehouse.size)
	return view.cell_px


## 切到第 [param i] 页。没解锁 / 越界返回 false
func show_page(i: int) -> bool:
	if i < 0 or is_locked(i):
		return false
	_current = i
	view.inventory = warehouse.page(i)
	_mark()
	page_changed.emit(i)
	return true


## 切到这件东西所在的页（双击置入落到哪页就看哪页）。不在仓库里返回 false
func show_item(uid: int) -> bool:
	var i := warehouse.page_of(uid) if warehouse != null else -1
	return i >= 0 and (i == _current or show_page(i))


## 第几个页签在这个全局坐标下（不在 -1）
func tab_at(global_pos: Vector2) -> int:
	for i in _tabs.size():
		if _tabs[i].get_global_rect().has_point(global_pos):
			return i
	return -1


## 拖着东西停在页签上：光标下是第几个页签交给 [method hover_tab]。返回这一下切了没有
func drag_hover(global_pos: Vector2, delta: float) -> bool:
	return hover_tab(tab_at(global_pos), delta)


## 停在第 [param i] 个页签上（-1 = 不在页签上）：同一个页签累计 [param delta] 秒，够 [constant HOVER_SEC] 切过去；换了页签重新计时
func hover_tab(i: int, delta: float) -> bool:
	if i < 0 or i == _current or is_locked(i):
		_hover_tab = -1
		_hover_t = 0.0
		return false
	if i != _hover_tab:
		_hover_tab = i
		_hover_t = 0.0
	_hover_t += delta
	if _hover_t + 0.0001 < HOVER_SEC:
		return false
	_hover_tab = -1
	_hover_t = 0.0
	return show_page(i)


func _process(delta: float) -> void:
	if drag == null or not drag.is_dragging() or not is_visible_in_tree():
		_hover_tab = -1
		_hover_t = 0.0
		return
	drag_hover(get_global_mouse_position(), delta)


func _refresh() -> void:
	if warehouse == null:
		return
	var want := maxi(warehouse.page_count(), _max_pages)
	if want != _tabs.size():
		_rebuild_tabs(want)
	for i in _tabs.size():
		var b := _tabs[i]
		var locked := is_locked(i)
		b.disabled = locked
		b.text = "%s\n%s" % [numeral(i), "　" if locked else UiText.t("wh.tab_count") % warehouse.page(i).item_count()]     # 锁着的第二行留空给锁
		b.tooltip_text = UiText.t("wh.tab_locked_tip") % [_tech_name, ceili(float(i) / float(_per_level))] if locked else UiText.t("wh.tab_tip") % [numeral(i), warehouse.page(i).item_count()]
		b.queue_redraw()
	if is_locked(_current) or view.inventory == null:
		show_page(clampi(_current, 0, warehouse.page_count() - 1))
	else:
		_mark()


func _rebuild_tabs(n: int) -> void:
	for b in _tabs:
		b.queue_free()
	_tabs.clear()
	for i in n:
		var idx := i
		var b := Button.new()
		b.text = numeral(i)
		UiPalette.style_button(b, UiPalette.Tier.MINOR, 14)     # 窄页签：两行小字（页名、件数）
		b.pressed.connect(func(): show_page(idx))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(TAB_W, tab_height)
		if tab_variation != &"":
			b.theme_type_variation = tab_variation
		b.draw.connect(_draw_lock.bind(b, idx))
		tab_box.add_child(b)
		_tabs.append(b)


func _mark() -> void:
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(i == _current)
		if tab_variation == &"":
			UiTheme.mark(_tabs[i], i == _current)


## 没解锁的页签右下角画一把小锁
func _draw_lock(b: Button, i: int) -> void:
	if not is_locked(i):
		return
	var c := Vector2(b.size.x * 0.5, b.size.y - 13.0)
	var col := Color(UiPalette.DIM, 0.9)
	b.draw_arc(c + Vector2(0, -4), 4.0, PI, TAU, 12, col, 1.6, true)
	b.draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 9)), col)


## 页名：一、二、三……（十以后照写数字）
static func numeral(i: int) -> String:
	if UiText.lang != "zh":     # 221 F5b: digits in English
		return str(i + 1)
	return NUMERALS[i] if i >= 0 and i < NUMERALS.size() else str(i + 1)
