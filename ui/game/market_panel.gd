## 251：基地「集市」页（[Market]）。补充一 §10.1（作者 14:49；15:57 第三版）：木凉棚 —— 货散放在一张透视的大平桌上、前后两排（[MarketStage]：底图 + `market/layout.json`
## 的货位 foot / scale，按级数取前 4 / 6 / 8 个），每个货位是一块只有那件大小的小棋盘（作者 10-31「集市的物品格子要设计成透明的」：不套框、不铺内垫、不画格缝，货直接摆在桌上），货前面平放一张金币价签（[PriceTag] 金币式），卖掉的盖「已售」；
## 钱袋读数是金币 + 数字（[CoinLabel]）。页面上不写等级（在科技页）；没点出集市只画空棚 + 一块签说去科技页点。
## 买法不变：双击 / 右键「买下」（价钱是金币 + 数字）；买到的进仓库（包进包架），钱不够 / 仓库满说一句。
## 补充二 §12.1（作者 10-25 14:20「集市里不需要显示仓库」）：整页，右列仓库收起（[constant MetaScreen.FULL_TABS]），告示说「进了仓库」；底图 1300×950 定稿
## 270（作者 2026-10-31）分摊位：左列六颗摊位木牌（铁匠铺那套 [CatKey]），记住上次看的（[member MetaState.market_stall]）。
## 固定摊 → [StallView]（通用底图 + 货格 + 翻页，货单 [method Market.catalogue]，不断货）；散货摊 → 这座木凉棚，钱牌下多一颗【换货】（[RefreshKey]），
## 货的右键菜单多「锁定 / 解锁」，锁着的货左上一枚小锁（230 那枚）
extends VBoxContainer

signal changed()

## 货位格子边长至少这么大（像素；面板太窄时）—— 不小于框能套的最窄一格（[constant BoardFrame.MIN_SIDE]，再窄框会被裁）
const CELL_MIN := BoardFrame.MIN_SIDE
## 作者 10-31：透明格 —— 格缝和亮线都不画（格子区本来就没底）
const CLEAR_SEAMS := {"seam_alpha": 0.0, "hi_alpha": 0.0, "empty_alpha": 0.0}
## 价签离货底多远（平放在货前面）
const TAG_GAP := 2.0
## 卖掉的货压多灰（UI替换美术 10-25：货还在、压灰，章盖在价签上）
const SOLD_TINT := Color(0.55, 0.55, 0.55, 0.75)
## 补充二（12.1 补二）：「每局回来换一批货」钉在左柱上的便条（底图里没画；设计像素、略斜），便条按整页缩放整块缩
const RESTOCK_AT := Rect2(66, 297, 190, 78)
const RESTOCK_TILT := -0.06
## 钱牌上金币 + 数字的字号 = 钱牌高的这么多倍（整页跟着缩放）
const FUNDS_FONT := 0.55
## 270：【换货】键的左上角（凉棚底图像素，钱牌正下方）
const REFRESH_AT := Vector2(1076, 326)
## 摊位木牌之间的空、木牌列与摊之间的空（原尺寸）
const KEY_GAP := 6.0
const KEYS_GAP := 12
## 木牌列顶上让出多少（原尺寸，同铁匠铺木牌在底图里的高度）
const KEYS_TOP := 128.0
## 木牌跟着整页缩放：按凉棚底图的高算
const PERGOLA_H := 950.0

var flow: GameFlow = null
var font: Font = null
## 说一句（基地的告示卷轴）
var say: Callable = Callable()
var _stage: MarketStage = null
var _funds: CoinLabel = null
var _note: PanelContainer = null
var _restock: PanelContainer = null
var _views: Array[InventoryView] = []
var _frames: Array[Control] = []
var _prices: Array[PriceTag] = []
var _tip: HoverTip = null
var _refresh: RefreshKey = null
## 270：左列摊位木牌（摊 id → 键）、木牌列顶上的空、固定摊那一页、两页共用的格子（摊在这里面切）
var _keys: VBoxContainer = null
var _keys_top: Control = null
var _stall_keys: Dictionary = {}
var _stall: StallView = null
var _body: Control = null
var _stall_id: StringName = &""


func setup(p_flow: GameFlow, p_font: Font, p_say: Callable = Callable()) -> void:
	flow = p_flow
	font = p_font
	say = p_say
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := UiTheme.hbox(KEYS_GAP)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var col := UiTheme.vbox(0)
	row.add_child(col)
	_keys_top = Control.new()
	_keys_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_keys_top)
	_keys = UiTheme.vbox(int(KEY_GAP))
	col.add_child(_keys)
	for st in Market.stalls():
		var key := CatKey.make(Names.of(st), show_stall.bind(st.id))
		_keys.add_child(key)
		_stall_keys[st.id] = key
	_body = Control.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.resized.connect(_place)
	row.add_child(_body)
	_stage = MarketStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.custom_minimum_size = Vector2(240, 320)
	_stage.sign_text = Names.of(Market.stall(Market.LOOSE))
	_stage.resized.connect(_place)
	_body.add_child(_stage)
	_stall = StallView.new()
	_stall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stall.font = font
	_stall.on_buy = func(id: StringName): buy_listed(id)
	_stall.actions_for = func(id: StringName) -> Array: return [_listed_action(id)]
	_body.add_child(_stall)
	_funds = CoinLabel.make(0, 18)
	_funds.centered = true
	_funds.tooltip_text = UiText.t("hud.wallet")
	_stage.add_child(_funds)
	_refresh = RefreshKey.new()
	_refresh.tooltip_text = UiText.t("market.locked")
	_refresh.pressed.connect(refresh)
	_stage.add_child(_refresh)
	_tip = HoverTip.new()
	_tip.top_level = true     # 不占排版
	add_child(_tip)
	_stall.tip = _tip
	_restock = UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_SUMMARY_NOTE, 10, 6, 10, 6)
	UiTheme.apply_tone(_restock, UiTheme.PANEL_SUMMARY_NOTE)
	_restock.rotation = RESTOCK_TILT
	var rl := Label.new()
	rl.text = UiText.t("market.restock_note")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_restock.add_child(rl)
	_stage.add_child(_restock)
	flow.meta.changed.connect(rebuild)
	var last := flow.meta.market_stall
	_stall_id = last if _stall_keys.has(last) else (Market.stalls()[0].id if not Market.stalls().is_empty() else Market.LOOSE)
	rebuild()


## 270：翻到这个摊（左列的木牌）；记下来，下回进集市还是它
func show_stall(id: StringName) -> void:
	if not _stall_keys.has(id):
		return
	var changed_stall := _stall_id != id
	_stall_id = id
	flow.meta.market_stall = id
	rebuild(not changed_stall)


func stall_id() -> StringName:
	return _stall_id


## 现在看的是不是散货摊
func on_loose() -> bool:
	var st := Market.stall(_stall_id)
	return st == null or not st.fixed


## 货变了（买了、换货、升级、换摊）：重摆。[param keep_page] 固定摊留在当前页
func rebuild(keep_page: bool = true) -> void:
	if _stage == null:
		return
	for id in _stall_keys:
		var key := _stall_keys[id] as Button
		key.set_pressed_no_signal(id == _stall_id)
		key.queue_redraw()
	var loose := on_loose()
	_stage.visible = loose
	_stall.visible = not loose
	if not loose:
		var st := Market.stall(_stall_id)
		var defs: Array[ItemDef] = []
		for id in Market.catalogue(flow.market(), flow.items, st, Market.level(flow.meta)):
			defs.append(flow.items.get_def(id))
		_stall.tooltip_text = UiText.t("market.stall_tip")
		_stall.show_stall(Names.of(st), defs, func(d: ItemDef) -> int: return Market.price_of(flow.market(), d), flow.meta.funds, keep_page)
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
	_stage.tables = true     # 262：集市默认就有（1 级），不再有「未开」的空棚
	_stage.tooltip_text = UiText.t("market.restock_tip")
	_funds.amount = flow.meta.funds
	_refresh.price = Market.refresh_cost(flow.meta, flow.market())
	_refresh.poor = Market.can_refresh(flow.meta, flow.market()) != ""
	_refresh.tooltip_text = UiText.t("market.refresh_poor") if _refresh.poor else UiText.t("market.locked")
	if flow.meta.market_stock.is_empty():
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
	if def != null:
		var shown := ItemInstance.create(def, 0)
		shown.set_locked(Market.is_locked(flow.meta, i))     # 270：锁着的货左上画 230 那枚小锁
		grid.place(shown, Vector2i.ZERO, 0)     # 卖掉的也摆着（压灰），「已售」章盖在价签上
	var view := InventoryView.new()
	view.label_font = font
	view.show_adjacency = false
	view.inventory = grid
	view.item_double_clicked.connect(func(_v: ContainerView, _uid: int): buy(i))
	view.actions_for = func(_uid: int) -> Array: return [_buy_action(i), _lock_action(i)]
	if sold:
		view.modulate = SOLD_TINT
	_stage.add_child(view)
	BoardFrame.mark(view, _stage, CLEAR_SEAMS)     # 作者 10-31：格子透明 —— 屏自己的桌面就是底（227 守门认它）
	var frame: Control = view
	var price := PriceTag.coins(Market.price_of(flow.market(), def))
	price.sold = sold
	price.poor = not sold and flow.meta.funds < price.coin
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
## 价签平放在货前面；后排先画、前排压在上面；价签一律压在所有货上面（前排大件不挡后排价签，UI替换美术 v4.44 验收）
func _place() -> void:
	if _body == null:
		return
	if _body.size.y > 0.0:
		var kk := clampf(_body.size.y / PERGOLA_H, 0.5, 1.0)
		_keys_top.custom_minimum_size.y = roundf(KEYS_TOP * kk)
		CatKey.space(_keys, maxi(2, roundi(KEY_GAP * kk)))
		for id in _stall_keys:
			var key := _stall_keys[id] as Button
			if key is CatKey:
				(key as CatKey).scale_k = kk
			else:
				key.custom_minimum_size.x = roundf(CatKey.SIZE.x * kk)
	if _stage.size.x <= 0.0:
		return
	var layout := _stage.layout()
	var fr := _stage.to_local_rect(layout.get("funds", {}))
	_funds.size = fr.size
	_funds.position = fr.position
	_funds.font_size = maxi(14, roundi(fr.size.y * FUNDS_FONT))
	_refresh.scale_k = _stage.scale_factor()
	_refresh.position = _stage.at(REFRESH_AT)
	_restock.position = _stage.at(RESTOCK_AT.position)
	_restock.size = RESTOCK_AT.size
	_restock.scale = Vector2.ONE * _stage.scale_factor()
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
	for o in order:
		_stage.move_child(_prices[o[1]], -1)


func _buy_action(i: int) -> ItemActions.Action:
	var def := Market.def_at(flow.meta, flow.items, i)
	var a := ItemActions.make(&"buy", UiText.t("act.buy_coin"), func(): buy(i))
	a.coin = Market.price_of(flow.market(), def)     # 补充一：价钱是金币 + 数字
	var why := Market.can_buy(flow.meta, flow.market(), flow.items, i)
	return a if why == "" else ItemActions.disable(a, why)


## 270：锁定 / 解锁散货摊第 i 格（卖掉的灰着）
func _lock_action(i: int) -> ItemActions.Action:
	var on := Market.is_locked(flow.meta, i)
	var a := ItemActions.make(&"lock", UiText.t("act.unlock" if on else "act.lock"), func(): toggle_lock(i))
	return ItemActions.disable(a, UiText.t("market.sold_out")) if Market.is_sold(flow.meta, i) else a


func toggle_lock(i: int) -> bool:
	var on := flow.toggle_market_lock(i)
	changed.emit()
	return on


## 270：花钱换货；返回空串 = 换了，否则是原因（说一句）
func refresh() -> String:
	var why := flow.refresh_market()
	if why != "" and say.is_valid():
		say.call(why)
	changed.emit()
	return why


## 270：固定摊这一件的「买下」（金币 + 价钱）
func _listed_action(id: StringName) -> ItemActions.Action:
	var a := ItemActions.make(&"buy", UiText.t("act.buy_coin"), func(): buy_listed(id))
	a.coin = Market.price_of(flow.market(), flow.items.get_def(id))
	var why := Market.can_buy_listed(flow.meta, flow.market(), flow.items, Market.stall(_stall_id), id)
	return a if why == "" else ItemActions.disable(a, why)


## 270：买固定摊的一件（货单不减）；返回空串 = 买了，否则是原因（说一句）
func buy_listed(id: StringName) -> String:
	var def := flow.items.get_def(id)
	var why := flow.buy_listed(_stall_id, id)
	_say_bought(def, why)
	changed.emit()
	return why


func _say_bought(def: ItemDef, why: String) -> void:
	var name := Names.of(def) if def != null else ""
	if say.is_valid():
		say.call(UiText.t("market.bought") % [name, Market.price_of(flow.market(), def), flow.meta.funds] if why == "" else UiText.t("shop.cant_buy") % [name, why])


## 买散货摊第 i 格；返回空串 = 买了，否则是原因（说一句）
func buy(i: int) -> String:
	var def := Market.def_at(flow.meta, flow.items, i)
	var why := flow.buy_market(i)
	_say_bought(def, why)
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


func stall_view() -> StallView:
	return _stall


func refresh_key() -> RefreshKey:
	return _refresh


func stall_key(id: StringName) -> Button:
	return _stall_keys.get(id, null)
