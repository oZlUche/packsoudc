## 270：集市的固定摊（药铺 / 粮铺 / 兵器铺 / 甲胄铺 / 杂货铺）—— UI替换美术 B 格子柜定稿：通用底图 `market/stall`（1100 × 760，浅面）
## + `market/stall.json` 的货格（7 列 × 3 行，一格一件，货按原比例缩进格里、底对齐，格下金币价签 [PriceTag]）、摊名挂牌（[method HeaderTag.hanging]）、
## 右上钱牌（金币 + 数）。多于一页（21 件）在底图右边外面竖排页签（同仓库的挂牌木签）。格子透明（作者 10-31：集市的物品格子不套框、不画格缝）。
## 买法由持有方给：[member on_buy]（`func(id)`）双击买，[member actions_for]（`func(id) -> Array`）右键菜单
class_name StallView
extends Control

const LAYOUT := "market/stall"
const CLEAR_SEAMS := {"seam_alpha": 0.0, "hi_alpha": 0.0, "empty_alpha": 0.0}
## 页签（同仓库）
const TAB_W := 52.0
const TAB_H := 60.0
const TAB_GAP := 8.0
## 钱牌上的字号（原尺寸）
const FUNDS_FONT := 22

var font: Font = null
var tip: HoverTip = null
var on_buy: Callable = Callable()
var actions_for: Callable = Callable()
var stage: MarketStage = null
var funds: CoinLabel = null
var title: HeaderTag = null
var tabs: VBoxContainer = null
## 当前页
var page := 0

var _defs: Array[ItemDef] = []
var _price_of: Callable = Callable()
var _views: Array[InventoryView] = []
var _prices: Array[PriceTag] = []
var _ids: Array[StringName] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	stage = MarketStage.new(LAYOUT, LAYOUT)
	add_child(stage)
	title = HeaderTag.hanging("")
	stage.add_child(title)
	funds = CoinLabel.make(0, FUNDS_FONT)
	funds.centered = true
	funds.mouse_filter = Control.MOUSE_FILTER_STOP
	funds.tooltip_text = UiText.t("hud.wallet")
	stage.add_child(funds)
	tabs = UiTheme.vbox(4)
	add_child(tabs)
	resized.connect(_place)


## 摆一个摊：[param defs] 是货单（按顺序），[param price_of] = `func(def) -> int`；换了摊回第一页
func show_stall(name: String, defs: Array[ItemDef], price_of: Callable, coins: int, keep_page: bool = false) -> void:
	title.text = name
	_defs = defs
	_price_of = price_of
	funds.amount = coins
	if not keep_page:
		page = 0
	page = clampi(page, 0, page_count() - 1)
	_build_tabs()
	_build_page()


func per_page() -> int:
	var g: Dictionary = stage.layout().get("grid", {})
	return maxi(1, int(g.get("cols", 7)) * int(g.get("rows", 3)))


func page_count() -> int:
	return maxi(1, ceili(_defs.size() / float(per_page())))


func show_page(i: int) -> void:
	page = clampi(i, 0, page_count() - 1)
	_mark_tabs()
	_build_page()


func _build_tabs() -> void:
	UiTheme.clear_children(tabs)
	tabs.visible = page_count() > 1
	if not tabs.visible:
		return
	for i in page_count():
		var b := Button.new()
		UiPalette.style_button(b, UiPalette.Tier.MINOR, 14)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(TAB_W, TAB_H)
		b.theme_type_variation = UiTheme.BUTTON_SETUP_TAB
		b.text = WarehousePages.numeral(i)
		b.pressed.connect(show_page.bind(i))
		tabs.add_child(b)
	_mark_tabs()


func _mark_tabs() -> void:
	for i in tabs.get_child_count():
		(tabs.get_child(i) as Button).set_pressed_no_signal(i == page)


func _build_page() -> void:
	for v in _views:
		v.queue_free()
	for p in _prices:
		p.queue_free()
	_views.clear()
	_prices.clear()
	_ids.clear()
	var from := page * per_page()
	for j in range(from, mini(_defs.size(), from + per_page())):
		var def := _defs[j]
		var grid := GridInventory.new(def.shape.size_rotated(0) if def.shape != null else Vector2i.ONE, 0, false)
		grid.place(ItemInstance.create(def, 0), Vector2i.ZERO, 0)
		var view := InventoryView.new()
		view.label_font = font
		view.show_adjacency = false
		view.inventory = grid
		var id := def.id
		view.item_double_clicked.connect(func(_v: ContainerView, _uid: int): if on_buy.is_valid(): on_buy.call(id))
		view.actions_for = func(_uid: int) -> Array: return actions_for.call(id) if actions_for.is_valid() else []
		stage.add_child(view)
		BoardFrame.mark(view, stage, CLEAR_SEAMS)     # 格子透明：底图的格子柜就是底（227 守门认它）
		var price_n: int = _price_of.call(def) if _price_of.is_valid() else 0
		var price := PriceTag.coins(price_n)
		price.poor = funds.amount < price_n
		stage.add_child(price)
		_views.append(view)
		_prices.append(price)
		_ids.append(id)
		if tip != null:
			tip.watch(view)
	_place()


## 一格的矩形（设计像素）：第 c 列 r 行
func cell_rect(slot: int) -> Rect2:
	var g: Dictionary = stage.layout().get("grid", {})
	var cols := int(g.get("cols", 7))
	var rows := int(g.get("rows", 3))
	var cell := float(g.get("cell", 110))
	var cw := float(g.get("w", 1020)) / cols
	var rh := float(g.get("h", 560)) / rows
	var c := slot % cols
	var r := slot / cols
	return Rect2(float(g.get("x", 40)) + c * cw + (cw - cell) * 0.5, float(g.get("y", 160)) + r * rh + float(g.get("cell_top", 14)), cell, cell)


func _place() -> void:
	if size.x <= 0.0:
		return
	var tab_w := TAB_W + TAB_GAP if tabs.visible else 0.0
	stage.position = Vector2.ZERO
	stage.size = Vector2(maxf(0.0, size.x - tab_w), size.y)
	var k := stage.scale_factor()
	var lay := stage.layout()
	var fr := stage.to_local_rect(lay.get("funds", {}))
	funds.position = fr.position
	funds.size = fr.size
	funds.font_size = maxi(12, roundi(UiTheme.sz(FUNDS_FONT) * k))
	var hang: Dictionary = lay.get("hang", {})
	title.scale = Vector2.ONE * k
	title.position = stage.at(Vector2(float(hang.get("cx", 550)), float(hang.get("y", 66)))) - Vector2(title.size.x * k * 0.5, 0.0)
	var gap := float(lay.get("price_gap", 4)) * k
	for j in _views.size():
		var cr := cell_rect(j)
		var box := Rect2(stage.at(cr.position), cr.size * k)
		var view := _views[j]
		var shape := view.inventory.size
		view.cell_px = maxf(BoardFrame.MIN_SIDE, floorf(minf(box.size.x / shape.x, box.size.y / shape.y)))
		view.size = view.get_combined_minimum_size()
		view.position = Vector2(box.get_center().x - view.size.x * 0.5, box.end.y - view.size.y)
		var price := _prices[j]
		price.position = Vector2(box.get_center().x - price.size.x * 0.5, box.end.y + gap)
	for p in _prices:
		stage.move_child(p, -1)     # 价签压在货上（大件不挡价签）
	stage.move_child(title, -1)
	var d := stage.design_size() * k
	tabs.position = stage.origin() + Vector2(d.x + TAB_GAP, float((lay.get("grid", {}) as Dictionary).get("y", 160)) * k)


## 测试看
func views() -> Array[InventoryView]:
	return _views


func prices() -> Array[PriceTag]:
	return _prices


func ids() -> Array[StringName]:
	return _ids
