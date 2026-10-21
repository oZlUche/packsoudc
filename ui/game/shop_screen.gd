## 商店（087，作者定重做）：**左边是店，右边是自己的背包**（棋盘 + 地上，[InventoryPanel]），同一层拖拽盖着全部。
##
## 店里摆四个**栏位**（[ShopSession.shelves]，每格一块至少 3×4 的小棋盘，商品更大就跟着大），商品按真实尺寸摆在里面，底下写价。
## **买**：把商品拖进自己的棋盘 = 买（放手时收钱，[method ShopSession.pay_for]）；钱不够放手就弹回栏位、提示一句；双击商品也是买
## （自动找位，先包后地上），钱不够双击没反应、提示一句。**卖**：把包里 / 地上的东西拖进「出售区」= 卖，回定价的一半。
## 刷新、收起（回地图，店还开着）、离开照旧。
## 160 补一：货架下面一排「随身」—— 随身技能（不是道具，不能拖），按按钮买，直接进右下角的腰带
extends GameScreen

var _session: ShopSession = null
var _shelf_row: HBoxContainer
var _shelf_views: Array[InventoryView] = []
## 160 补一：「随身」那一排的按钮（第 i 个 = [member ShopSession.belt_offers] 第 i 格）
var _belt_row: HBoxContainer = null
var _belt_btns: Array[Button] = []
var _sell_view: InventoryView
var _refresh_btn: Button
var _wallet_line: Label
var _inv: InventoryPanelScript


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(0, 0))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	_frame_title(UiText.t("node.label.shop"))     # 157：标题在石板框的标题条上，说明留在原处
	left.add_child(_label(UiText.t("shop.intro"), 13, UiPalette.DIM))
	_wallet_line = _label("", 13, UiPalette.DIM)
	left.add_child(_wallet_line)
	_shelf_row = _hbox(10)
	left.add_child(_shelf_row)
	_belt_row = _hbox(8)
	left.add_child(_belt_row)
	var sell_col := _vbox(4)
	left.add_child(sell_col)
	sell_col.add_child(_label(UiText.t("shop.sell_area"), 13, UiPalette.DIM))
	_sell_view = InventoryView.new()
	_sell_view.label_font = font
	_sell_view.show_adjacency = false
	_sell_view.inventory = _session.sell_box if _session != null else GridInventory.new(ShopSession.SLOT_MIN, 0, false)
	_sell_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sell_col.add_child(_sell_view)
	var buttons := _hbox(8)
	_refresh_btn = _button("", refresh_stock, 13)
	buttons.add_child(_refresh_btn)
	var back := _button(UiText.t("camp.fold"), to_map, 13)
	back.tooltip_text = UiText.t("shop.fold_tip")
	buttons.add_child(back)
	buttons.add_child(_button(UiText.t("shop.leave"), leave, 13))
	left.add_child(buttons)

	# 右边：自己的背包（棋盘 + 地上），和店共用一层拖拽
	_inv = _mount_bag(row, _sell_view, Callable())     # 226 批一：面板的回话走告示层
	_drag.drop_outside_to_stash = false     # 店里放到外面 = 放回原处，不算买也不算卖
	_drag.drop_filter = _allow_drop
	_drag.craft_filter = _allow_craft     # 审查 A1：没付钱的商品不能拿去合成（会被消耗掉、结不了账）
	_drag.drag_finished.connect(_on_drag_finished)
	_inv.extra_actions = _sell_actions     # 230：棋盘上的东西多两颗「出售 | 出售同类」

	if _session != null:
		_session.stock_changed.connect(_rebuild)
		_session.bought.connect(func(def: ItemDef, price: int, _inst: ItemInstance):
			_say(UiText.t("shop.bought") % [Names.of(def), price])
			_refresh())
		_session.sold_item.connect(func(def: ItemDef, gain: int):
			_say(UiText.t("shop.sold") % [Names.of(def), gain])
			_refresh())
		flow.run.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh())
	_rebuild()


#region 公开动作
## 双击 / 按钮买第 i 格：钱不够没反应、提示一句；买到的先进包、放不下到地上（RunState 接 bought）
func buy(i: int) -> bool:
	if _session == null:
		return false
	if not _session.can_buy(i):
		if i >= 0 and i < _session.stock.size() and not _session.sold.has(i):
			var inst := _session.item_at(i)
			_say(UiText.t("shop.short") % [Names.of(inst.def) if inst != null else "?", int(_session.stock[i]["price"]), flow.run.wallet.balance])
		return false
	return _session.buy(i) != null


## 双击栏位里的商品
func quick_buy(uid: int) -> bool:
	return _session != null and buy(_session.slot_of(uid))


## 230：直接卖掉自己的一件（不经出售区）：从它所在的容器拿走、进账。锁着的不卖。返回得了多少；没卖 -1
func sell_now(uid: int) -> int:
	if _session == null:
		return -1
	var from := flow.run.holder_of(uid)
	var inst := from.get_item(uid) if from != null else null
	if inst == null or inst.is_locked_by_player() or _cant_sell(inst) != "" or from.remove(uid) == null:
		return -1
	return _session.sell(inst)


func refresh_stock() -> bool:
	return _session != null and _session.refresh()


func leave() -> void:
	if _session != null:
		_session.leave()


## 084：收起回地图，店还开着（地图上「回到这个点」能再开）；走了才算离开
func to_map() -> bool:
	return flow.hide_overlay()


## 090：Esc = 收起
func escape() -> bool:
	return to_map()


func drag_layer() -> DragLayer:
	return _drag


func shelf_views() -> Array[InventoryView]:
	return _shelf_views


func sell_view() -> InventoryView:
	return _sell_view


## 226 批一：最新一句告示（测试看）
func line_text() -> String:
	return notice_layer().current_text()
#endregion


## 「能不能放到那儿」：商品只能进自己的棋盘（地上也行）且钱够；自己的东西不能放到栏位上、能放进出售区
func _allow_drop(inst: ItemInstance, target: ItemContainer) -> bool:
	if _session == null or inst == null:
		return false
	var slot := _session.slot_of(inst.uid)
	if slot < 0 and inst.uid == _dragged_uid:
		slot = _dragged_slot     # 拖着的商品此刻不在任何容器里：按抓起时记的格
	if slot >= 0:
		# 商品：回栏位随便；进玩家的容器要钱够
		if _is_shelf(target):
			return _session.shelves[slot] == target
		if target == flow.run.board or target == flow.run.storage:
			if _session.can_buy(slot):
				return true
			_say(UiText.t("shop.short") % [Names.of(inst.def), int(_session.stock[slot]["price"]), flow.run.wallet.balance])
			return false
		return false
	# 自己的东西（230：锁住的不进出售区）
	if target == _session.sell_box and inst.is_locked_by_player():
		_say(UiText.t("item.locked_no") % Names.of(inst.def))
		return false
	return not _is_shelf(target)


## 审查 A1：只有自己的东西能压上去合成；商品（在栏位上、或正拿在手上的那件）先买下再说
func _allow_craft(inst: ItemInstance) -> bool:
	if _session == null or inst == null:
		return true
	if _session.slot_of(inst.uid) >= 0:
		return false
	return not (inst.uid == _dragged_uid and _dragged_slot >= 0)


## 正在拖的商品是从哪格拿起来的（抓起时它已经离开了栏位，拖拽层告诉我们源容器）；不是商品 -1
var _dragged_slot: int = -1
var _dragged_uid: int = -1


func _is_shelf(c: ItemContainer) -> bool:
	return _session != null and _session.shelves.has(c)


func _on_drag_started(uid: int) -> void:
	_dragged_uid = uid
	_dragged_slot = _session.shelves.find(_drag.source()) if _session != null else -1


func _on_drag_finished(uid: int, dropped: bool) -> void:
	var slot := _dragged_slot
	_dragged_slot = -1
	_dragged_uid = -1
	if _session == null or not dropped:
		return
	# 商品进了玩家的容器：结账。（drop_filter 已经拦过钱不够的；这里失败只可能是同一瞬别处花了钱）
	if slot >= 0 and (flow.run.board.has_item(uid) or flow.run.storage.has_item(uid)):
		# 101 第 6 刀：结账与结不成时的回滚都在会话里（ShopSession.pay_or_return），这里只说一句
		if not _session.pay_or_return(slot, uid, [flow.run.board, flow.run.storage]):
			_say(UiText.t("shop.returned"))
		_refresh()
		return
	# 自己的东西进了出售区：卖
	if _session.sell_box.has_item(uid):
		var inst := _session.sell_box.get_item(uid)
		_session.sell(inst)
		_refresh()


## 230：栏位上那件的按钮「买下 N 币」；钱不够灰
func _buy_action(i: int) -> ItemActions.Action:
	var a := ItemActions.make(&"buy", UiText.t("act.buy") % int(_session.stock[i]["price"]), func(): buy(i))
	return a if _session.can_buy(i) else ItemActions.disable(a, UiText.t("act.short"))


func _sell_actions(inst: ItemInstance) -> Array:
	if _session == null:
		return []
	var price_of := func(i: ItemInstance) -> int: return _session.sell_price_of(i.def)
	var one := ItemActions.sell(inst, _session.sell_price_of(inst.def), sell_now)
	var why := _cant_sell(inst)
	return [ItemActions.disable(one, why) if why != "" and one.enabled else one,
		ItemActions.sell_same(inst, flow.run.board, price_of, sell_now)]


## 棋盘上这件现在卖不了的原因（扎了根、包里还有东西）；能卖空串
func _cant_sell(inst: ItemInstance) -> String:
	var board := flow.run.board
	if not board.has_item(inst.uid):
		return ""
	if board.is_locked(inst.uid):
		return UiText.t(DragLayer.ROOTED_NOTICE)
	if board.acts_as_bag(inst.def) and not board.contents_of(inst.uid).is_empty():
		return UiText.t("act.bag_full")
	return ""


func _say(text: String) -> void:
	say(text)     # 226 批一：本地回话行删了，走告示卷轴


## 重摆栏位（开店、刷新之后）
func _rebuild() -> void:
	if _session == null or _shelf_row == null:
		return
	for v in _shelf_views:
		_drag.unregister_view(v)
	_shelf_views.clear()
	UiTheme.clear_children(_shelf_row)
	if not _drag.drag_started.is_connected(_on_drag_started):
		_drag.drag_started.connect(_on_drag_started)
	for i in _session.shelves.size():
		var idx := i
		var col := _vbox(4)
		var view := InventoryView.new()
		view.label_font = font
		view.show_adjacency = false
		view.inventory = _session.shelves[i]
		view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		view.item_double_clicked.connect(func(_v: ContainerView, uid: int): quick_buy(uid))
		view.actions_for = func(_uid: int) -> Array: return [_buy_action(idx)]     # 230
		col.add_child(view)
		var inst := _session.item_at(i)     # 卖掉的格子是空的（价签只写「已售」，用不到尺寸）
		var def := inst.def if inst != null else null
		var sold := _session.sold.has(i)
		var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
		var price := _label(UiText.t("shop.sold_tag") if sold else UiText.t("shop.price_tag") % [int(_session.stock[i]["price"]), size.x, size.y], 12, UiPalette.DIM if sold else UiPalette.STAMINA)
		price.name = "Price%d" % idx
		col.add_child(price)
		_shelf_row.add_child(col)
		_shelf_views.append(view)
		_drag.register_view(view)
		_tip.watch(view)
	_rebuild_belt()
	_refresh()


## 160 补一：「随身」那一排：每种一个按钮（名字、价格），买了直接进腰带
func _rebuild_belt() -> void:
	UiTheme.clear_children(_belt_row)
	_belt_btns.clear()
	if _session.belt_offers.is_empty():
		return
	_belt_row.add_child(_label(UiText.t("shop.carried_row"), 13, UiPalette.DIM))
	for i in _session.belt_offers.size():
		var idx := i
		var def := BeltSkillDef.find(StringName(String(_session.belt_offers[i]["id"])))
		var b := _button("", func(): buy_belt(idx), 13)
		b.tooltip_text = UiText.t("shop.belt_tip") % [Names.description_of(def), def.describe()] if def != null else ""
		_belt_row.add_child(b)
		_belt_btns.append(b)


## 160 补一：买「随身」那一排第 i 格。返回空串 = 买了，否则是原因（写在提示行）
func buy_belt(i: int) -> String:
	var why := _session.buy_belt(i) if _session != null else UiText.t("shop.no_shop")
	var def := BeltSkillDef.find(StringName(String(_session.belt_offers[i]["id"]))) if _session != null and i >= 0 and i < _session.belt_offers.size() else null
	var name := Names.of(def) if def != null else UiText.t("shop.carried_tool")
	_say(UiText.t("shop.belt_bought") % name if why == "" else UiText.t("shop.cant_buy") % [name, why])
	_refresh()
	return why


func _refresh() -> void:
	if _session == null:
		return
	_wallet_line.text = UiText.t("shop.wallet") % flow.run.wallet.balance
	_refresh_btn.text = UiText.t("shop.refresh") % _session.refresh_cost()
	_refresh_btn.disabled = not _session.can_refresh()
	for i in _shelf_views.size():
		var price := _shelf_row.get_child(i).get_node_or_null("Price%d" % i) as Label
		if price != null and _session.sold.has(i):
			price.text = UiText.t("shop.sold_tag")
			price.theme_type_variation = UiTheme.LABEL_DIM     # 121：卖掉了换暗色变体
	for i in _belt_btns.size():
		var offer: Dictionary = _session.belt_offers[i]
		var def := BeltSkillDef.find(StringName(String(offer["id"])))
		var sold := _session.belt_sold.has(i)
		_belt_btns[i].text = UiText.t("shop.belt_sold") % Names.of(def) if sold else UiText.t("shop.belt_price") % [Names.of(def) if def != null else String(offer["id"]), int(offer["price"])]
		_belt_btns[i].disabled = sold
