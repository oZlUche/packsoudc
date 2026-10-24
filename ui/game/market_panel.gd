## 251：基地「集市」页（[Market]）—— 一排货位（一块素框 + 每格一圈缝，227），每格摆着那件、底下铜价签（226）；双击 / 右键「买」。
## 买到的进右边仓库（包进包架），钱不够 / 仓库满说一句。没点出集市就一块段头签说怎么开。占位：美术设计出样（石台集市）后由 UI替换美术换
extends VBoxContainer

signal changed()

## 货位最小几格（同局内商店）
const SLOT_MIN := Vector2i(2, 2)

var flow: GameFlow = null
var font: Font = null
## 说一句（基地的告示卷轴）
var say: Callable = Callable()
var _head: HeaderTag = null
var _row: HFlowContainer = null
var _views: Array[InventoryView] = []
var _prices: Array[PriceTag] = []
var _tip: HoverTip = null


func setup(p_flow: GameFlow, p_font: Font, p_say: Callable = Callable()) -> void:
	flow = p_flow
	font = p_font
	say = p_say
	_head = HeaderTag.new(UiText.t("market.title"))
	_head.mouse_filter = Control.MOUSE_FILTER_PASS
	_head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_head)
	_row = HFlowContainer.new()
	add_child(_row)
	BoardFrame.wrap(_row, "plain")     # 227：整排货位一块素框
	_tip = HoverTip.new()
	_tip.top_level = true     # 不占这一列的排版
	add_child(_tip)
	flow.meta.changed.connect(rebuild)
	rebuild()


## 货变了（买了、换货、升级）：重摆
func rebuild() -> void:
	if _row == null:
		return
	UiTheme.clear_children(_row)
	_views.clear()
	_prices.clear()
	var lv := Market.level(flow.meta)
	_head.text = UiText.t("market.title") if lv > 0 else UiText.t("market.locked")
	_head.tooltip_text = UiText.t("market.restock_tip") if lv > 0 else UiText.t("market.locked_tip")
	var frame := _row.get_parent() as Control
	if frame != null:
		frame.visible = lv > 0
	if lv <= 0:
		return
	if flow.meta.market_stock.is_empty():
		var empty := HeaderTag.new(UiText.t("market.empty"))
		_row.add_child(empty)
		return
	for i in flow.meta.market_stock.size():
		var idx := i
		var def := Market.def_at(flow.meta, flow.items, i)
		var col := UiTheme.vbox(4)
		var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
		var grid := GridInventory.new(Vector2i(maxi(SLOT_MIN.x, size.x), maxi(SLOT_MIN.y, size.y)), 0, false)
		var sold := Market.is_sold(flow.meta, i)
		if def != null and not sold:
			grid.place(ItemInstance.create(def, 0), Vector2i.ZERO, 0)
		var view := InventoryView.new()
		view.label_font = font
		view.show_adjacency = false
		view.inventory = grid
		view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		view.seams = BoardFrame.light_seams().merged({"edge": true})
		view.item_double_clicked.connect(func(_v: ContainerView, _uid: int): buy(idx))
		view.actions_for = func(_uid: int) -> Array: return [_buy_action(idx)]
		col.add_child(view)
		var price := PriceTag.new(UiText.t("shop.price_tag") % [Market.price_of(flow.market(), def), size.x, size.y])
		price.sold = sold
		col.add_child(price)
		_row.add_child(col)
		_views.append(view)
		_prices.append(price)
		_tip.watch(view)


func _buy_action(i: int) -> ItemActions.Action:
	var def := Market.def_at(flow.meta, flow.items, i)
	var a := ItemActions.make(&"buy", UiText.t("act.buy") % Market.price_of(flow.market(), def), func(): buy(i))
	var why := Market.can_buy(flow.meta, flow.market(), flow.items, i)
	return a if why == "" else ItemActions.disable(a, why)


## 买第 i 格；返回空串 = 买了，否则是原因（说一句）
func buy(i: int) -> String:
	var def := Market.def_at(flow.meta, flow.items, i)
	var why := flow.buy_market(i)
	var name := Names.of(def) if def != null else ""
	if say.is_valid():
		say.call(UiText.t("market.bought") % [name, Market.price_of(flow.market(), def), flow.meta.funds] if why == "" else UiText.t("shop.cant_buy") % [name, why])
	changed.emit()
	return why


## 测试看：货位视图、价签
func views() -> Array[InventoryView]:
	return _views


func prices() -> Array[PriceTag]:
	return _prices
