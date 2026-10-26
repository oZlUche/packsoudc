## 求饶（256，安德烈乌斯）：打输了 / 逃跑失败、对方开了价，回放之后弹这一屏 —— 一整块天平舞台（[BalanceScale]，作者 15:49 定稿四层图）
## 浮在压暗的底屏上：左盘上方一块托盘（小棋盘，有框有格），把包里的东西拖上来，每件按局内出售价算重量；石台左边一只金币步进件（±10）。
## 右盘是开价（打赢对方的钱 × 倍数），梁上的差额牌写还差多少。左 ≥ 右「成交」才亮：钱从钱包出、托盘上的东西归对方、不扣体力；
## 「不求饶」= 照常扣体力（归零就战败）。关窗（Esc）也是不求饶，托盘上的东西先回包里。舞台右边是自己的背包（和商店一样）
extends GameScreen

const TRAY_ID := 5
## 6 × 3：美术稿托盘的格数（tray_rect 300 × 168）
const TRAY_SIZE := Vector2i(6, 3)
const COIN_STEP := 10
## 比别的叠层压得暗一点（美术：「窗后面那层遮罩可以压暗一点，盘子之间是透明的」）
const SHADE := 0.8

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
	_shade(SHADE)
	var center := _full_center()
	center.offset_top = HudHost.bar_height_in(get_tree()) if is_inside_tree() else 0.0     # 在顶端栏下面居中
	add_child(center)
	var row := _hbox(24)
	center.add_child(row)

	_scale = BalanceScale.new()
	_scale.right = _price
	row.add_child(_scale)
	_reserve_ground(_scale)
	# 底座上的字都落在石牌 / 石台上（226）
	_place(_label(UiText.t("ransom.title"), 22, BalanceScale.INK), "title", true)
	var intro := _label(UiText.t("ransom.intro"), 17, BalanceScale.INK)     # 正面在前；限制写在石台底下的小字（作者 10-26：短处后放、小字）
	_place(intro, "subtitle", true)
	_place(_label(UiText.t("ransom.limits"), 13, BalanceScale.INK_SOFT), "hint", true)
	# 托盘：左盘上方，底边坐在盘里两根矮柱上（柱间堆放上来的金币）
	_tray = GridInventory.new(TRAY_SIZE, TRAY_ID, false)
	_tray_view = InventoryView.new()
	_tray_view.label_font = font
	_tray_view.inventory = _tray
	_tray_view.show_adjacency = false
	_tray_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tray_view.tooltip_text = UiText.t("ransom.tray_tip")
	_scale.tray_slot.add_child(_tray_view)
	var tray_frame := BoardFrame.wrap(_tray_view)     # 227：素框 + 格缝
	tray_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# 格子按托盘那块地缩（美术稿 300 × 168 放 6 × 3 格连框），不按背包的大格
	var sb := tray_frame.get_theme_stylebox("panel")
	var room := _scale.tray_slot.size - Vector2(sb.content_margin_left + sb.content_margin_right, sb.content_margin_top + sb.content_margin_bottom)
	_tray_view.cell_px = floorf(minf(room.x / TRAY_SIZE.x, room.y / TRAY_SIZE.y))
	# 石台：金币步进件（左边那块凹槽里）、成交 / 不求饶两把平石键
	_coins = StoneStepper.new(func() -> void: set_coins(coins - COIN_STEP), func() -> void: set_coins(coins + COIN_STEP))
	_coins.tooltip_text = UiText.t("ransom.coins_tip")
	_place(_coins, "stepper", true)
	_pay_btn = StoneChip.make(UiText.t("ransom.pay"), func(): pay())     # 平的石键（作者 10-21：小功能键不要立体）
	_pay_btn.tooltip_text = UiText.t("ransom.price_tip") % String.num(flow.run.buff_context().ransom_mult, 2)
	_place(_pay_btn, "deal", false)
	var no := StoneChip.make(UiText.t("ransom.refuse"), func(): refuse())
	no.tooltip_text = UiText.t("ransom.refuse_tip")
	_place(no, "refuse", false)

	_inv = _mount_bag(row, _tray_view, Callable(), _tray)     # 棋盘上双击 → 托盘
	_reserve_ground(_inv)
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


## 把一个控件摆进底座上 [param slot] 那一格（`ransom_layout.json` 的 controls）：[param fill] 为真撑满那一格（字居中），否则居中放
func _place(c: Control, slot: String, fill: bool) -> void:
	var r := _scale.control_rect(slot)
	var box := CenterContainer.new()
	box.position = r.position
	box.size = r.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scale.add_child(box)
	if fill and c is Label:
		(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(c as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.custom_minimum_size = r.size
	elif not (c is Label):
		c.custom_minimum_size = Vector2(r.size.x, c.custom_minimum_size.y) if fill else c.custom_minimum_size
	box.add_child(c)


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
	_scale.coins = coins
	_scale.left = weight()
	_coins.set_text(str(coins))
	_coins.minus.disabled = coins <= 0
	_coins.plus.disabled = coins >= flow.run.wallet.balance
	_pay_btn.disabled = _scale.left < _price
