## 163（作者定）：分页仓库的界面 —— 左边一列竖排页签（「一」「二」「三」……，下面一行小字写几件），右边一块格子显示当前页。
## 切页只换视图的 [member InventoryView.inventory]，视图与拖拽登记不重建。没解锁的页也列出来、灰色加一把小锁，悬停写要扩建到第几级。
## 拖着东西停在一个页签上 [constant HOVER_SEC] 秒切到那页（放手就落在那页）。
## 三处共用：基地右半边、开局屏第二页、结算屏。持有方把 [member view] 登记进自己的拖拽层、接双击
class_name WarehousePages
extends HBoxContainer

signal page_changed(index: int)
## 268：快速出售的勾选变了
signal selection_changed
## 268：点了一件勾不上的（锁着 / 收藏）
signal refused(item: ItemInstance)
## 268 补充二：筛选变了（出售条跟着重算【全选】的范围）
signal filter_changed

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
## 255 补充二：页签列末尾多出的一页（开局屏第二页的「地上」），按下时格子那块换成 [member extra]，大小和格子一样
var extra: Control = null
var _extra_tab: Button = null
var _on_extra := false
## 264 §六：筛选 —— 标签（&"" = 不限）与稀有度上限（-1 = 全部）；有筛选时不匹配的格压灰、页签第二行写匹配件数
var filter_tag: StringName = &""
var filter_rarity := -1
## 265：只看收藏
var filter_fav := false
## 268：快速出售的勾选模式 —— 单击格子勾 / 取消（[member selected]，uid → true，跨页）；锁定 / 收藏的压灰、勾不上
var select_mode := false
var selected: Dictionary = {}


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
	view.selected = selected
	view.item_picked.connect(func(_v: InventoryView, uid: int): toggle_select(uid))
	warehouse.changed.connect(_prune_selection)
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
	_on_extra = false
	view.visible = true
	if extra != null:
		extra.visible = false
	view.inventory = warehouse.page(i)
	_mark()
	page_changed.emit(i)
	return true


## 切到这件东西所在的页（双击置入落到哪页就看哪页）。不在仓库里返回 false
func show_item(uid: int) -> bool:
	var i := warehouse.page_of(uid) if warehouse != null else -1
	return i >= 0 and ((i == _current and not _on_extra) or show_page(i))


## 第几个页签在这个全局坐标下（不在 -1；多出的那页是 [method tab_count]）
func tab_at(global_pos: Vector2) -> int:
	for i in _tabs.size():
		if _tabs[i].get_global_rect().has_point(global_pos):
			return i
	if _extra_tab != null and _extra_tab.visible and _extra_tab.get_global_rect().has_point(global_pos):
		return _tabs.size()
	return -1


## 255 补充二：在页签列里加一页 [param c]（只在 [method set_extra_tab] 说有时出现），排在已有的页后面、没解锁的页前面
## （排最末会被十个页签挤到滚动区外）。返回它的页签
func add_extra(c: Control) -> Button:
	extra = c
	c.visible = false
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(c)
	move_child(c, view.get_index() + 1)
	_extra_tab = _make_tab()
	_extra_tab.clip_text = true     # 页签列宽不随字变
	_extra_tab.pressed.connect(show_extra)
	_extra_tab.visible = false
	tab_box.add_child(_extra_tab)
	_place_extra_tab()
	return _extra_tab


func _place_extra_tab() -> void:
	if _extra_tab != null and warehouse != null:
		tab_box.move_child(_extra_tab, mini(warehouse.page_count(), tab_box.get_child_count() - 1))


## 多出那页的页签：出不出、两行字、悬停说明；收起时正看着它就退回格子
func set_extra_tab(shown: bool, text: String, tip: String) -> void:
	if _extra_tab == null:
		return
	_extra_tab.visible = shown
	_extra_tab.text = text
	_extra_tab.tooltip_text = tip
	if not shown and _on_extra:
		show_page(_current)


## 切到多出的那页：格子藏起，它顶上格子的位子、一样大
func show_extra() -> bool:
	if extra == null or _extra_tab == null or not _extra_tab.visible:
		return false
	extra.custom_minimum_size = view.get_combined_minimum_size()
	view.visible = false
	extra.visible = true
	_on_extra = true
	_mark()
	page_changed.emit(-1)
	return true


## 正看着多出的那页
func on_extra() -> bool:
	return _on_extra


## 拖着东西停在页签上：光标下是第几个页签交给 [method hover_tab]。返回这一下切了没有
func drag_hover(global_pos: Vector2, delta: float) -> bool:
	return hover_tab(tab_at(global_pos), delta)


## 停在第 [param i] 个页签上（-1 = 不在页签上）：同一个页签累计 [param delta] 秒，够 [constant HOVER_SEC] 切过去；换了页签重新计时
func hover_tab(i: int, delta: float) -> bool:
	var to_extra := _extra_tab != null and i == _tabs.size()
	if i < 0 or (to_extra and _on_extra) or (not to_extra and ((i == _current and not _on_extra) or is_locked(i))):
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
	return show_extra() if to_extra else show_page(i)


func _process(delta: float) -> void:
	if drag == null or not drag.is_dragging() or not is_visible_in_tree():
		_hover_tab = -1
		_hover_t = 0.0
		return
	drag_hover(get_global_mouse_position(), delta)


## 264 §六：设筛选（[param tag] &"" = 不限，[param rarity_max] -1 = 全部）；两样都不限 = 不筛
func set_filter(tag: StringName, rarity_max: int, fav_only: bool = filter_fav) -> void:
	filter_tag = tag
	filter_rarity = rarity_max
	filter_fav = fav_only
	_apply_dim()
	_refresh()
	filter_changed.emit()


func _apply_dim() -> void:
	if view == null:
		return
	view.dim_filter = (func(it: ItemInstance) -> bool: return matches(it) and can_select(it)) if select_mode else (matches if filtering() else Callable())
	view.queue_redraw()


func filtering() -> bool:
	return filter_tag != &"" or filter_rarity >= 0 or filter_fav


## 这一件合不合当前筛选（没筛选都合）
func matches(item: ItemInstance) -> bool:
	return item != null and (filter_rarity < 0 or item.rarity() <= filter_rarity) and (filter_tag == &"" or item.def.tags.has(filter_tag)) \
		and (not filter_fav or ItemFavorites.has(item.def.id))


## 第 [param i] 页合筛选的件数（没筛选 = 全部件数）
func match_count(i: int) -> int:
	if is_locked(i):
		return 0
	var page := warehouse.page(i)
	if not filtering():
		return page.item_count()
	return page.items().filter(func(it) -> bool: return matches(it as ItemInstance)).size()


#region 268 快速出售的勾选
## 开 / 关勾选模式（关了勾选全清）
func set_select_mode(on: bool) -> void:
	select_mode = on
	if not on:
		selected.clear()
	if view != null:
		view.select_mode = on
	_apply_dim()
	_refresh()
	selection_changed.emit()


## 这件能不能勾：锁着的、收藏的不卖
static func can_select(item: ItemInstance) -> bool:
	return item != null and not item.is_locked_by_player() and not ItemFavorites.has(item.def.id)


## 勾 / 取消一件；勾不上（不在仓库、锁着、收藏）返回 false（持有方说原因）
func toggle_select(uid: int) -> bool:
	var it := warehouse.get_item(uid) if warehouse != null else null
	if not select_mode or it == null:
		return false
	if selected.has(uid):
		selected.erase(uid)
	elif can_select(it):
		selected[uid] = true
	else:
		refused.emit(it)
		return false
	_changed_selection()
	return true


## 全选：所有页里合筛选、能勾的全勾上（筛选外已勾的留着，测试 v4.81）；返回现在一共勾了几件
func select_matching() -> int:
	for it in warehouse.items():
		if matches(it as ItemInstance) and can_select(it as ItemInstance):
			selected[(it as ItemInstance).uid] = true
	_changed_selection()
	return selected.size()


## 合筛选、能勾的是不是都勾了（有可勾的才算）
func all_matching_selected() -> bool:
	var any := false
	for it in warehouse.items():
		if matches(it as ItemInstance) and can_select(it as ItemInstance):
			any = true
			if not selected.has((it as ItemInstance).uid):
				return false
	return any


## 全不选：只取消合筛选的那些（筛选外已勾的留着）
func deselect_matching() -> void:
	for it in warehouse.items():
		if matches(it as ItemInstance):
			selected.erase((it as ItemInstance).uid)
	_changed_selection()


func clear_selection() -> void:
	selected.clear()
	_changed_selection()


## 勾了的卖多少钱
func selected_value(ratio: float) -> int:
	var n := 0
	for uid in selected:
		n += MetaState.sell_price_of(warehouse.get_item(int(uid)), ratio)
	return n


## 合筛选却勾不上的：[锁着的, 收藏的] 件数
func skipped_matching() -> Array:
	var locked := 0
	var fav := 0
	for it in warehouse.items():
		var item := it as ItemInstance
		if not matches(item):
			continue
		if item.is_locked_by_player():
			locked += 1
		elif ItemFavorites.has(item.def.id):
			fav += 1
	return [locked, fav]


## 第 [param i] 页勾了几件
func selected_on(i: int) -> int:
	if is_locked(i):
		return 0
	var n := 0
	for it in warehouse.page(i).items():
		if selected.has((it as ItemInstance).uid):
			n += 1
	return n


## 仓库变了：卖掉 / 挪走的、新锁上的从勾选里去掉
func _prune_selection() -> void:
	var gone := false
	for uid in selected.keys():
		var it := warehouse.get_item(int(uid))
		if it == null or not can_select(it):
			selected.erase(uid)
			gone = true
	if gone:
		_changed_selection()


func _changed_selection() -> void:
	if view != null:
		view.queue_redraw()
	_refresh()
	selection_changed.emit()
#endregion


func _refresh() -> void:
	if warehouse == null:
		return
	var want := maxi(warehouse.page_count(), _max_pages)
	if want != _tabs.size():
		_rebuild_tabs(want)
	_place_extra_tab()
	for i in _tabs.size():
		var b := _tabs[i]
		var locked := is_locked(i)
		b.disabled = locked
		b.text = "%s\n%s" % [numeral(i), "　" if locked else (UiText.t("wh.tab_picked") % [selected_on(i), warehouse.page(i).item_count()] if select_mode else UiText.t("wh.tab_count") % match_count(i))]     # 锁着的第二行留空给锁；264：筛选时写匹配数；268：勾选模式写 勾了 / 本页
		b.tooltip_text = UiText.t("wh.tab_locked_tip") % [_tech_name, ceili(float(i) / float(_per_level))] if locked else (UiText.t("wh.tab_picked_tip") % [numeral(i), selected_on(i), warehouse.page(i).item_count()] if select_mode else UiText.t("wh.tab_tip") % [numeral(i), warehouse.page(i).item_count()])
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
		var b := _make_tab()
		b.text = numeral(i)
		b.pressed.connect(func(): show_page(idx))
		b.draw.connect(_draw_lock.bind(b, idx))
		tab_box.add_child(b)
		_tabs.append(b)


func _make_tab() -> Button:
	var b := Button.new()
	UiPalette.style_button(b, UiPalette.Tier.MINOR, 14)     # 窄页签：两行小字（页名、件数）
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(TAB_W, tab_height)
	if tab_variation != &"":
		b.theme_type_variation = tab_variation
	return b


func _mark() -> void:
	for i in _tabs.size():
		var on := i == _current and not _on_extra
		_tabs[i].set_pressed_no_signal(on)
		if tab_variation == &"":
			UiTheme.mark(_tabs[i], on)
	if _extra_tab != null:
		_extra_tab.set_pressed_no_signal(_on_extra)
		if tab_variation == &"":
			UiTheme.mark(_extra_tab, _on_extra)


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
