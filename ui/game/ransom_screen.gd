## 求饶（256，安德烈乌斯）：打输了、对方开了价，战斗回放之后弹这一屏 —— 中间一架天平（[BalanceScale]），
## 左盘上方一块托盘（小棋盘，有框有格）：把包里的东西拖上来，每件按局内出售价算重量；左盘下一只金币步进件（±10）。
## 右盘是开价（这一场打赢的钱 × 倍数）。左 ≥ 右「成交」才亮：钱从钱包出、托盘上的东西归对方、这一场不扣体力；
## 「不求饶」= 照常扣体力（归零就战败）。关窗（Esc）也是不求饶，托盘上的东西先回包里。右边是自己的背包（和商店一样）
extends GameScreen

const TRAY_ID := 5
const TRAY_SIZE := Vector2i(4, 3)
const COIN_STEP := 10

var _price := 0
var coins := 0
var _tray: GridInventory = null
var _tray_view: InventoryView = null
var _scale: BalanceScale = null
var _coins: StoneStepper = null
var _pay_btn: Button = null
var _inv: InventoryPanelScript = null


func open(payload: Dictionary) -> void:
	_price = int(payload.get("price", flow.run.events.pending_ransom.get("price", 0)))
	var panel := _centered_panel(Vector2(0, 0), 16)
	_frame_title(UiText.t("ransom.title"))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(10)
	row.add_child(left)
	var intro := HeaderTag.new(UiText.t("ransom.intro"))     # 正面在前；限制写进悬浮窗（小字）
	intro.mouse_filter = Control.MOUSE_FILTER_PASS
	intro.tooltip_text = UiText.t("ransom.limits")
	left.add_child(intro)
	# 托盘在左盘正上方：天平宽的左半边居中
	var top := _hbox(0)
	left.add_child(top)
	var tray_col := _vbox(4)
	tray_col.custom_minimum_size.x = BalanceScale.SIZE.x * 0.5
	tray_col.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(tray_col)
	_tray = GridInventory.new(TRAY_SIZE, TRAY_ID, false)
	_tray_view = InventoryView.new()
	_tray_view.label_font = font
	_tray_view.inventory = _tray
	_tray_view.show_adjacency = false
	_tray_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tray_view.tooltip_text = UiText.t("ransom.tray_tip")
	tray_col.add_child(_tray_view)
	BoardFrame.wrap(_tray_view)     # 227：素框 + 格缝
	_scale = BalanceScale.new()
	_scale.right = _price
	left.add_child(_scale)
	# 金币步进件在左盘下面
	var low := _hbox(0)
	left.add_child(low)
	var coin_col := _vbox(4)
	coin_col.custom_minimum_size.x = BalanceScale.SIZE.x * 0.5
	low.add_child(coin_col)
	_coins = StoneStepper.new(func() -> void: set_coins(coins - COIN_STEP), func() -> void: set_coins(coins + COIN_STEP))
	_coins.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_coins.tooltip_text = UiText.t("ransom.coins_tip")
	coin_col.add_child(_coins)
	var keys := _hbox(12)
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(keys)
	_pay_btn = StoneChip.make(UiText.t("ransom.pay"), func(): pay())     # 平的石键（作者 10-21：小功能键不要立体）
	_pay_btn.tooltip_text = UiText.t("ransom.price_tip") % String.num(flow.run.buff_context().ransom_mult, 2)
	keys.add_child(_pay_btn)
	var no := StoneChip.make(UiText.t("ransom.refuse"), func(): refuse())
	no.tooltip_text = UiText.t("ransom.refuse_tip")
	keys.add_child(no)

	_inv = _mount_bag(row, _tray_view, Callable(), _tray)     # 棋盘上双击 → 托盘
	_tray_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(uid))
	_tip_double(_tray_view, "act.take_back")
	_drag.drop_outside_to_stash = false     # 放到外面 = 放回原处
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		if target != _tray:
			return true
		var why := cant_offer(inst)
		if why != "":
			say(why)
		return why == ""
	_tray.changed.connect(_refresh)
	flow.run.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh())
	_refresh()


#region 公开动作
## 放上左盘的金币：夹在 0 和钱包之间
func set_coins(n: int) -> void:
	coins = clampi(n, 0, flow.run.wallet.balance)
	_refresh()


## 左盘一共多重（金币 + 托盘上的道具）
func weight() -> int:
	return flow.run.events.ransom_weight(coins, _tray.items())


func price() -> int:
	return _price


## 这件不能放上托盘的原因（锁着的、钉着的、装着东西的包）；能放空串
func cant_offer(inst: ItemInstance) -> String:
	if inst == null:
		return UiText.t("ransom.none")
	if inst.is_locked_by_player() or inst.is_pinned():
		return UiText.t("item.locked_no") % Names.of(inst.def)
	var board := flow.run.board
	if board.has_item(inst.uid) and board.acts_as_bag(inst.def) and not board.contents_of(inst.uid).is_empty():
		return UiText.t("act.bag_full")
	return ""


## 把包里 / 地上的一件放上托盘（测试直接调）。放不了返回 false
func offer(uid: int) -> bool:
	var from := flow.run.holder_of(uid)
	var inst := from.get_item(uid) if from != null else null
	if inst == null or cant_offer(inst) != "":
		return false
	return InventoryService.transfer_auto(from, uid, _tray)


## 托盘上的一件回包里（放不下到地上）
func take_back(uid: int) -> bool:
	return _tray.get_item(uid) != null and _take_to_player(_tray, uid) != ""


## 成交：够了才成；托盘上的东西归对方（随托盘一起丢掉）。返回空串 = 成交，否则是原因（告示里也说一句）
func pay() -> String:
	var given := _tray.items().duplicate()
	var why := flow.pay_ransom(coins, given)
	if why != "":
		say(why)
		return why
	for inst in given:
		_tray.remove((inst as ItemInstance).uid)
	say(UiText.t("ransom.paid"))
	return ""


## 不求饶：托盘上的东西先回包里，再照常扣体力
func refuse() -> bool:
	for inst in _tray.items().duplicate():
		take_back((inst as ItemInstance).uid)
	return flow.refuse_ransom()


## Esc / 关窗 = 不求饶
func escape() -> bool:
	return refuse()


func tray() -> GridInventory:
	return _tray


func scale_widget() -> BalanceScale:
	return _scale


func pay_button() -> Button:
	return _pay_btn


func drag_layer() -> DragLayer:
	return _drag
#endregion


func _refresh() -> void:
	if _scale == null:
		return
	coins = clampi(coins, 0, flow.run.wallet.balance)
	_scale.left = weight()
	_coins.set_text(str(coins))
	_coins.minus.disabled = coins <= 0
	_coins.plus.disabled = coins >= flow.run.wallet.balance
	_pay_btn.disabled = _scale.left < _price
