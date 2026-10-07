## 商店（087，作者定重做）：**左边是店，右边是自己的背包**（棋盘 + 地上，[InventoryPanel]），同一层拖拽盖着全部。
##
## 店里摆四个**栏位**（[ShopSession.shelves]，每格一块至少 3×4 的小棋盘，商品更大就跟着大），商品按真实尺寸摆在里面，底下写价。
## **买**：把商品拖进自己的棋盘 = 买（放手时收钱，[method ShopSession.pay_for]）；钱不够放手就弹回栏位、提示一句；双击商品也是买
## （自动找位，先包后地上），钱不够双击没反应、提示一句。**卖**：把包里 / 地上的东西拖进「出售区」= 卖，回定价的一半。
## 刷新、收起（回地图，店还开着）、离开照旧。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

var _session: ShopSession = null
var _shelf_row: HBoxContainer
var _shelf_views: Array[InventoryView] = []
var _sell_view: InventoryView
var _refresh_btn: Button
var _wallet_line: Label
var _line: Label
var _drag: DragLayer
var _inv: Control
var _tip: HoverTip


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(0, 0))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("商店 %d　把商品拖进背包 = 买　双击 = 买　把自己的东西拖进出售区 = 卖（半价）" % (node.id if node != null else -1), 16, UiPalette.FG))
	_wallet_line = _label("", 13, UiPalette.DIM)
	left.add_child(_wallet_line)
	_shelf_row = _hbox(10)
	left.add_child(_shelf_row)
	var sell_col := _vbox(4)
	left.add_child(sell_col)
	sell_col.add_child(_label("出售区　拖进来就卖，回定价的一半", 13, UiPalette.DIM))
	_sell_view = InventoryView.new()
	_sell_view.label_font = font
	_sell_view.show_adjacency = false
	_sell_view.inventory = _session.sell_box if _session != null else GridInventory.new(ShopSession.SLOT_MIN, 0, false)
	_sell_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sell_col.add_child(_sell_view)
	_line = _label("", 13, UiPalette.FG)
	left.add_child(_line)
	var buttons := _hbox(8)
	_refresh_btn = _button("", refresh_stock, 13)
	buttons.add_child(_refresh_btn)
	var back := _button("收起", to_map, 13)
	back.tooltip_text = "回地图，店还开着（Esc）"
	buttons.add_child(back)
	buttons.add_child(_button("离开", leave, 13))
	left.add_child(buttons)

	# 右边：自己的背包（棋盘 + 地上），和店共用一层拖拽
	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
	inv.hint_sink = func(text: String): _say(text)
	_inv = inv
	row.add_child(inv)
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.drop_outside_to_stash = false     # 店里放到外面 = 放回原处，不算买也不算卖
	_drag.register_view(_sell_view)
	_drag.drop_filter = _allow_drop
	_drag.craft_filter = _allow_craft     # 审查 A1：没付钱的商品不能拿去合成（会被消耗掉、结不了账）
	_drag.drag_finished.connect(_on_drag_finished)
	_tip = HoverTip.new()
	add_child(_tip)
	_tip.watch(_sell_view)

	if _session != null:
		_session.stock_changed.connect(_rebuild)
		_session.bought.connect(func(def: ItemDef, price: int, _inst: ItemInstance):
			_say("买下了「%s」，花了 %d 币" % [Names.of(def), price])
			_refresh())
		_session.sold_item.connect(func(def: ItemDef, gain: int):
			_say("卖掉了「%s」，得 %d 币" % [Names.of(def), gain])
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
			_say("金币不足：「%s」要 %d 币，你有 %d" % [Names.of(inst.def) if inst != null else "?", int(_session.stock[i]["price"]), flow.run.wallet.balance])
		return false
	return _session.buy(i) != null


## 双击栏位里的商品
func quick_buy(uid: int) -> bool:
	return _session != null and buy(_session.slot_of(uid))


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


func line_text() -> String:
	return _line.text
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
			_say("金币不足：「%s」要 %d 币，你有 %d" % [Names.of(inst.def), int(_session.stock[slot]["price"]), flow.run.wallet.balance])
			return false
		return false
	# 自己的东西
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
			_say("金币不足，东西放回了栏位")
		_refresh()
		return
	# 自己的东西进了出售区：卖
	if _session.sell_box.has_item(uid):
		var inst := _session.sell_box.get_item(uid)
		_session.sell(inst)
		_refresh()


func _say(text: String) -> void:
	if _line != null:
		_line.text = text


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
		col.add_child(view)
		var inst := _session.item_at(i)     # 卖掉的格子是空的（价签只写「已售」，用不到尺寸）
		var def := inst.def if inst != null else null
		var sold := _session.sold.has(i)
		var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
		var price := _label("已售" if sold else "%d 币　%d×%d" % [int(_session.stock[i]["price"]), size.x, size.y], 12, UiPalette.DIM if sold else UiPalette.STAMINA)
		price.name = "Price%d" % idx
		col.add_child(price)
		_shelf_row.add_child(col)
		_shelf_views.append(view)
		_drag.register_view(view)
		_tip.watch(view)
	_refresh()


func _refresh() -> void:
	if _session == null:
		return
	_wallet_line.text = "货币 %d　商品按真实尺寸摆着；拖进棋盘或地上就买下" % flow.run.wallet.balance
	_refresh_btn.text = "刷新（%d 币）" % _session.refresh_cost()
	_refresh_btn.disabled = not _session.can_refresh()
	for i in _shelf_views.size():
		var price := _shelf_row.get_child(i).get_node_or_null("Price%d" % i) as Label
		if price != null and _session.sold.has(i):
			price.text = "已售"
			price.theme_type_variation = UiTheme.LABEL_DIM     # 121：卖掉了换暗色变体
