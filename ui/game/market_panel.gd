## 251：基地「集市」页（[Market]）。补充一 §10.1（作者 14:49；15:57 第三版）：木凉棚 —— 货散放在一张透视的大平桌上、前后两排（[MarketStage]：底图 + `market/layout.json`
## 的货位 foot / scale，按级数取前 4 / 6 / 8 个），每个货位是一块只有那件大小的小棋盘（带框，227），货前面平放一张金币价签（[PriceTag] 金币式），卖掉的盖「已售」；
## 钱袋读数是金币 + 数字（[CoinLabel]）。页面上不写等级（在科技页）；没点出集市只画空棚 + 一块签说去科技页点。
## 买法不变：双击 / 右键「买下」（价钱是金币 + 数字）；买到的进右边仓库（包进包架），钱不够 / 仓库满说一句
extends VBoxContainer

signal changed()

## 货位格子边长至少这么大（像素；面板太窄时）—— 不小于框能套的最窄一格（[constant BoardFrame.MIN_SIDE]，再窄框会被裁）
const CELL_MIN := BoardFrame.MIN_SIDE
## 价签离货底多远（平放在货前面）
const TAG_GAP := 2.0

var flow: GameFlow = null
var font: Font = null
## 说一句（基地的告示卷轴）
var say: Callable = Callable()
var _stage: MarketStage = null
var _funds: CoinLabel = null
var _note: PanelContainer = null
var _views: Array[InventoryView] = []
var _frames: Array[Control] = []
var _prices: Array[PriceTag] = []
var _tip: HoverTip = null


func setup(p_flow: GameFlow, p_font: Font, p_say: Callable = Callable()) -> void:
	flow = p_flow
	font = p_font
	say = p_say
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage = MarketStage.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(240, 320)
	_stage.sign_text = UiText.t("market.title")
	_stage.resized.connect(_place)
	add_child(_stage)
	_funds = CoinLabel.make(0, 18)
	_funds.centered = true
	_funds.tooltip_text = UiText.t("hud.wallet")
	_stage.add_child(_funds)
	_tip = HoverTip.new()
	_tip.top_level = true     # 不占排版
	add_child(_tip)
	flow.meta.changed.connect(rebuild)
	rebuild()


## 货变了（买了、换货、升级）：重摆
func rebuild() -> void:
	if _stage == null:
		return
	for f in _frames:
		f.queue_free()
	for p in _prices:
		p.queue_free()
	if _note != null:
		_note.queue_free()
		_note = null
	_views.clear()
	_frames.clear()
	_prices.clear()
	var lv := Market.level(flow.meta)
	_stage.tables = lv > 0
	_stage.tooltip_text = UiText.t("market.restock_tip") if lv > 0 else ""
	_funds.visible = lv > 0
	_funds.amount = flow.meta.funds
	if lv <= 0:
		_note = _make_note(UiText.t("market.locked_tip"))
	elif flow.meta.market_stock.is_empty():
		_note = _make_note(UiText.t("market.empty"))
	else:
		var n := mini(flow.meta.market_stock.size(), _stage.spots().size())
		for i in n:
			_add_spot(i)
	_place()


func _add_spot(i: int) -> void:
	var def := Market.def_at(flow.meta, flow.items, i)
	var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
	var grid := GridInventory.new(size, 0, false)
	var sold := Market.is_sold(flow.meta, i)
	if def != null and not sold:
		grid.place(ItemInstance.create(def, 0), Vector2i.ZERO, 0)
	var view := InventoryView.new()
	view.label_font = font
	view.show_adjacency = false
	view.inventory = grid
	view.item_double_clicked.connect(func(_v: ContainerView, _uid: int): buy(i))
	view.actions_for = func(_uid: int) -> Array: return [_buy_action(i)]
	_stage.add_child(view)
	var frame := BoardFrame.wrap(view, "plain")     # 227：每个货位一块小棋盘、带框
	view.seams = BoardFrame.light_seams().merged({"edge": true})
	var price := PriceTag.coins(Market.price_of(flow.market(), def))
	price.sold = sold
	_stage.add_child(price)
	_views.append(view)
	_frames.append(frame)
	_prices.append(price)
	_tip.watch(view)


## 一块签（没点出集市 / 今日没货）：浅底纸牌、墨字，摆在头一张木台的位置
func _make_note(text: String) -> PanelContainer:
	var plate := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 14, 8, 14, 8)
	UiTheme.set_tone(plate, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 220
	plate.add_child(l)
	_stage.add_child(plate)
	return plate


## 照棚子的摆法放货位、价签、钱袋读数（棚子大小变了也走这里）：货底中点落在货位的 `foot`、格子按 `scale` 缩（后排小、前排大），
## 价签平放在货前面；后排先画、前排压在上面
func _place() -> void:
	if _stage == null or _stage.size.x <= 0.0:
		return
	var layout := _stage.layout()
	var fr := _stage.to_local_rect(layout.get("funds", {}))
	_funds.size = fr.size
	_funds.position = fr.position
	if _note != null:
		var ns := _note.get_combined_minimum_size()
		_note.size = ns
		_note.position = Vector2((_stage.size.x - ns.x) * 0.5, _stage.size.y * 0.4)
	var spots := _stage.spots()
	var order: Array = []
	for i in _views.size():
		var spot: Dictionary = spots[i]
		var foot := _stage.foot_of(spot)
		_views[i].cell_px = maxf(CELL_MIN, floorf(_stage.cell_of(spot)))
		var frame := _frames[i]
		frame.size = frame.get_combined_minimum_size()
		frame.position = Vector2(foot.x - frame.size.x * 0.5, foot.y - frame.size.y)
		var price := _prices[i]
		price.position = Vector2(foot.x - price.size.x * 0.5, foot.y + TAG_GAP)
		order.append([foot.y, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for o in order:
		_stage.move_child(_frames[o[1]], -1)
		_stage.move_child(_prices[o[1]], -1)


func _buy_action(i: int) -> ItemActions.Action:
	var def := Market.def_at(flow.meta, flow.items, i)
	var a := ItemActions.make(&"buy", UiText.t("act.buy_coin"), func(): buy(i))
	a.coin = Market.price_of(flow.market(), def)     # 补充一：价钱是金币 + 数字
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


## 测试看：货位视图、价签、钱袋读数、没开 / 没货时那块签
func views() -> Array[InventoryView]:
	return _views


func prices() -> Array[PriceTag]:
	return _prices


func funds_label() -> CoinLabel:
	return _funds


func note() -> PanelContainer:
	return _note


func stage() -> MarketStage:
	return _stage
