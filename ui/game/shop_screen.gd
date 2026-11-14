## 商店（087；290 重做，作者 2026-11-07 15:11 定）：**左边商人的大棋盘，右边自己的背包**（棋盘 + 地上，[InventoryPanel]），
## 同一层拖拽盖着全部；中下一座天秤（[ShopScale]），秤座就是「成交」键，「离开」在它右边。
##
## **放上桌 = 拖过去**：商人的货拖进自己的包 / 地上，自己的东西拖进商人的棋盘；挪过去的东西染「待成交」色（半透明金底 + 金色虚线边，
## UI设计 15:38 定）。拖回去、悬浮窗里的「收回」、双击都能撤。天秤：左盘 = 你拿的货的售价，右盘 = 你给的东西的收购价 + 你放上的钱；
## **右 ≥ 左「成交」才亮**。点右下角自己的钱袋 = 差多少补多少，点左下角商人的钱袋 = 他把多出来的找给你。离开（Esc 同）= 桌上的各回各家。
## 账全在 [ShopSession]：这里挪东西、挪完叫 [method ShopSession.sync]，画天秤与标色。
## 160 补一：「随身」两格（头像下面那条空地）：点一格放上桌，成交才进腰带
extends GameScreen

## 作者 2026-10-29（选 A 木货匣）：商店的棋盘（商人棋盘、随身格）用 board 的 `shop` 框
const SHOP_BOARD := "shop"
## 待成交色（UI设计 15:38：和 279 拼接描边同一种金）
const PENDING_GOLD := Color("e0b040")
const PENDING_FILL := Color(0.95, 0.78, 0.30, 0.22)
const PENDING_DASH := 3.0

var _session: ShopSession = null
var _view: InventoryView = null
## 160 补一：「随身」那几格（第 i 个 = [member ShopSession.belt_offers] 第 i 格）
var _belt_row: HBoxContainer = null
var _belt_btns: Array[Control] = []
var _scale: ShopScale = null
var _deal_btn: Button = null
var _leave_btn: Button = null
## 319：「换一批货」币座键（点了「局内商店刷新」科技才有）
var _refresh_btn: Button = null
## 右下角自己的钱袋、左下角商人的钱袋
var _pouch: CoinPouch = null
var _his_pouch: CoinPouch = null
var _inv: InventoryPanelScript
## 282：店主
var npc: NpcBadge = null
var _sync_queued := false
## 盖在地上那一层的待成交标记（地上那一层不归这一屏，走的时候摘掉）
var _ground_marks: Control = null


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	var panel := _centered_panel(Vector2(0, 0), 16, OverlayFrame.SKIN_TENT)     # 233（作者 21:42 选乙）：集市帐篷
	var col := _vbox(0)
	panel.add_child(col)
	_frame_title(UiText.t("node.label.shop"))     # 157：标题在框的标题条上
	var row := _hbox(24)
	col.add_child(row)
	# 左：头像 + 随身格（一竖条），商人的棋盘
	var left := _hbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var pcol := _vbox(18)
	left.add_child(pcol)
	if flow != null and flow.run != null:
		npc = NpcBadge.make(NpcDef.SHOPKEEPER, flow.meta, flow.run.items, flow.run)
		npc.greet_on_enter = true     # 300 §2.2：进店问候一句
		npc.greet_quiet = func() -> Array: return [_view, _inv.board_view if _inv != null else null]     # 指针进了哪块棋盘就收
		npc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN     # UI设计 11-07：随身格比头像宽时别把头像拉成横椭圆
		pcol.add_child(npc)
	_belt_row = _hbox(10)
	pcol.add_child(_belt_row)
	BoardFrame.wrap(_belt_row, SHOP_BOARD)     # UI设计 15:38：随身两格放头像下面，放棋盘下面整屏会高出帐篷
	_view = InventoryView.make(_session.board if _session != null else GridInventory.new(ShopSession.BOARD_SIZE, 0, false), font)
	_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): _double_merchant(uid))
	_view.actions_for = _merchant_actions
	left.add_child(_view)
	BoardFrame.wrap(_view, SHOP_BOARD)
	# 右：自己的背包（棋盘 + 地上），和商人的棋盘共用一层拖拽；双击自己的东西 = 放上他的棋盘
	_inv = _mount_bag(row, _view, _session.board if _session != null else null)
	_drag.drop_outside_to_stash = false     # 店里放到外面 = 放回原处
	_drag.drop_filter = _allow_drop
	_inv.fuse_filter = _allow_craft     # 审查 A1：没成交的货不能拿去合成（会被消耗掉、结不了账）
	_inv.quick_action = _offer_action
	_inv.extra_actions = func(_inst: ItemInstance) -> Array: return []
	_mark(_view)
	_mark(_inv.board_view)
	var ground := GroundLayer.current()
	if ground != null:
		_ground_marks = _mark(ground)     # UI设计 11-07：地上的待成交道具也描金

	# 底：商人钱袋 | 天秤（站在「成交」上）| 离开 + 自己钱袋
	var bottom := _hbox(14)
	col.add_child(bottom)
	var lsec := _hbox(14)
	lsec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(lsec)
	_his_pouch = CoinPouch.new()
	_his_pouch.clickable = true
	_his_pouch.tooltip_text = UiText.t("shop.his_pouch_tip")
	_his_pouch.pressed.connect(ask_change)
	lsec.add_child(_bottom_hold(_his_pouch))
	_scale = ShopScale.new()
	bottom.add_child(_scale)
	_deal_btn = ScrollKey.make(UiText.t("shop.deal"), deal)
	_deal_btn.name = "DealKey"
	_scale.add_child(_deal_btn)
	var seat := _scale.control_rect("deal")
	var km := _deal_btn.get_combined_minimum_size()
	_deal_btn.size = Vector2(maxf(km.x, seat.size.x), km.y)
	_deal_btn.position = Vector2(seat.get_center().x - _deal_btn.size.x * 0.5, seat.end.y - _deal_btn.size.y)
	var rsec := _hbox(14)
	rsec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsec.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(rsec)
	if _session != null and _session.refreshes > 0:     # 319
		_refresh_btn = ScrollKey.make(UiText.t("shop.refresh"), restock, true, _session.refresh_price())
		_refresh_btn.name = "RefreshKey"
		_refresh_btn.size_flags_vertical = Control.SIZE_SHRINK_END
		_refresh_btn.tooltip_text = UiText.t("shop.refresh_tip")
		rsec.add_child(_refresh_btn)
	var lv := ScrollKey.make(UiText.t("shop.leave"), leave)
	lv.size_flags_vertical = Control.SIZE_SHRINK_END
	rsec.add_child(lv)
	_leave_btn = lv
	_pouch = CoinPouch.new()
	_pouch.clickable = true
	_pouch.tooltip_text = UiText.t("shop.my_pouch_tip")
	_pouch.pressed.connect(pay_gap)
	rsec.add_child(_bottom_hold(_pouch))

	if _session != null:
		_session.table_changed.connect(_refresh)
		_session.dealt.connect(_on_dealt)
		for c in [_session.board, flow.run.board, flow.run.storage]:
			(c as ItemContainer).changed.connect(_queue_sync)
		flow.run.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh())
	_rebuild_belt()
	_refresh()
	_first_visit_hint()


## 309（v5.85 体验 E05）：头一回进店说一句怎么买（记在局外的 coach_seen，每个存档位一次；帮助页照旧能看）
const VISIT_HINT_SEEN := "shop_first_visit"


## 313（复测 v5.93 发现 1）：这句是三步操作，3 秒读不完 —— 停到玩家在店里头一回按下鼠标再收，最多停这么久
const VISIT_HINT_SEC := 60.0
var _visit_hint_up := false


## 说了返回真
func _first_visit_hint() -> bool:
	if _session == null or flow == null or flow.meta == null or flow.meta.coach_seen.has(VISIT_HINT_SEEN):
		return false
	flow.meta.coach_seen.append(VISIT_HINT_SEEN)
	notice_layer().push(UiText.t("shop.first_visit"), false, notice_cap(), notice_beside(), notice_top(), VISIT_HINT_SEC)
	_visit_hint_up = true
	return true


func _input(event: InputEvent) -> void:
	if _visit_hint_up and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_visit_hint_up = false
		notice_layer().dismiss(UiText.t("shop.first_visit"))


func _bottom_hold(c: Control) -> Control:
	var hold := CenterContainer.new()
	hold.size_flags_vertical = Control.SIZE_SHRINK_END
	hold.add_child(c)
	return hold


## 251：「这里只收三成；带回基地能卖五成」—— 两个数从规则读
func sell_hint() -> String:
	var here := _session.rules.shop_sell_ratio if _session != null and _session.rules != null else 0.5
	return UiText.t("shop.sell_hint") % [UiText.tenths(here), UiText.tenths(flow.sell_ratio())]


## 251：第一次在局内卖东西说一次（记在局外的 coach_seen，每个存档位一次）
const SELL_HINT_SEEN := "shop_sell_hint"


## 第一次给出东西时说的那句；说过了返回空串
func _first_sale_hint() -> String:
	if flow.meta == null or flow.meta.coach_seen.has(SELL_HINT_SEEN):
		return ""
	flow.meta.coach_seen.append(SELL_HINT_SEEN)
	return sell_hint()


#region 公开动作
## 把商人的一件拿过来（先进包、放不下到地上）。不是他的、店关了返回 false
func take(uid: int) -> bool:
	if _session == null or not _session.active or not _session.board.has_item(uid) or not _session.is_merchants(uid):
		return false
	if not InventoryService.transfer_auto(_session.board, uid, flow.run.board):
		var inst := _session.board.remove(uid)
		if inst == null or not flow.run.storage.insert(inst, -1, _ground_spot(inst)):
			return false
	_session.sync()
	return true


## 包里放不下、落到地上的那件放在自己这边（UI设计 11-07）：天秤右边、「离开」左边那条空地的底上，别压住天秤、离开键和钱袋
func _ground_spot(inst: ItemInstance) -> Vector2:
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	if vp.x <= 0.0 or vp.y <= 0.0 or _scale == null or not _scale.is_inside_tree():
		return ItemStash.NO_SPOT
	var span := flow.run.storage.span_of(inst)
	var w := maxf(span.x * vp.x, span.y * vp.y)     # 落地会翻到重心最低的朝向（长条躺平），按长边留位
	var lo := _scale.get_global_rect().end.x + 16.0
	var hi := lo + w
	if _leave_btn != null and _leave_btn.is_inside_tree():
		hi = _leave_btn.get_global_rect().position.x - 16.0
	var x := (lo + hi - w) * 0.5 if hi - lo >= w else lo     # 空地够宽就放正中，不够就贴天秤右边
	return Vector2(x / vp.x, 1.0 - ItemStash.SPOT_MARGIN - span.y)


## 把自己的一件放上他的棋盘（自动找位）。不让上桌的说一句原因、返回 false
func offer(uid: int) -> bool:
	if _session == null or not _session.active:
		return false
	var from := flow.run.holder_of(uid)
	var inst := from.get_item(uid) if from != null else null
	if inst == null or _session.is_merchants(uid):
		return false
	var why := _session.refuse_reason(inst)
	if why != "":
		say(why)
		return false
	if not InventoryService.transfer_auto(from, uid, _session.board):
		say(UiText.t("shop.board_full"))
		return false
	_session.sync()
	return true


## 撤下桌上的一件：你拿的放回他棋盘原位，你给的回自己的包（放不下到地上）
func withdraw(uid: int) -> bool:
	if _session == null or not _session.active:
		return false
	if _session.taken.has(uid):
		var from := flow.run.holder_of(uid)
		var inst := from.remove(uid) if from != null else null
		if inst == null:
			return false
		var at: Array = _session._owned[uid]
		if not _session.board.place(inst, at[0], int(at[1])) and not _session.board.try_add(inst):
			if not (from is GridInventory and (from as GridInventory).place(inst, inst.origin, inst.rotation)):
				flow.run.storage.admit(inst)
			return false
	elif _session.given.has(uid):
		if not InventoryService.transfer_auto(_session.board, uid, flow.run.board):
			var inst := _session.board.remove(uid)
			if inst == null or not flow.run.storage.insert(inst, -1, _ground_spot(inst)):
				return false
	else:
		return false
	_session.sync()
	return true


## 点自己的钱袋：把还差的钱放上右盘 / 收回
func pay_gap() -> int:
	if _session == null:
		return 0
	var was := _session.my_coins
	var n := _session.toggle_my_coins()
	# 309（E05）：补差时说清楚 —— 不差钱就说不用补；钱不够就说还差多少（钱照样全放上去，和以前一样）
	if was == 0 and not _session.table_empty():
		var gap := _session.left_total() - _session.goods_right()
		if gap <= 0:
			say(UiText.t("shop.gap_none"))
		elif gap > n:
			say(UiText.t("shop.gap_short") + CoinShort.coin(gap - n))
	return n


## 点商人的钱袋：让他把多出来的放上左盘 / 收回
func ask_change() -> int:
	return _session.toggle_his_coins() if _session != null else 0


## 160 补一：随身第 i 格放上桌 / 撤下。返回原因（空串 = 动了）
func toggle_belt(i: int) -> String:
	var why := _session.toggle_belt(i) if _session != null else UiText.t("shop.no_shop")
	if why != "":
		say(why)
	return why


## 成交（右 ≥ 左才成）
func deal() -> bool:
	if _session == null:
		return false
	if not _session.deal():
		var st := _session.status()
		if String(st["kind"]) == "short":
			say(UiText.t("shop.gap_short") + CoinShort.coin(int(st["n"])))
		return false
	return true


func leave() -> void:
	if _session != null:
		_session.leave()


## 290：「收起」删了 —— 回地图就是离开（桌上的各回各家）
func to_map() -> bool:
	leave()
	return true


## 090：Esc = 离开
func escape() -> bool:
	return to_map()


func drag_layer() -> DragLayer:
	return _drag


func merchant_view() -> InventoryView:
	return _view


func scale_widget() -> ShopScale:
	return _scale


func deal_key() -> Button:
	return _deal_btn


## 319：「换一批货」那把钥匙（没点科技 = null）
func refresh_key() -> Button:
	return _refresh_btn


## 319：付钱换一批货。拖着东西、秤上有东西、钱不够、换过了都不换，说一句原因
func restock() -> bool:
	if _session == null:
		return false
	var why := _session.refresh_reason()
	if why == "" and _drag != null and _drag.is_dragging():
		why = UiText.t("shop.refresh_table")
	if why != "":
		say(why)
		return false
	if not _session.refresh():
		say(UiText.t("shop.refresh_none"))
		return false
	_refresh()
	return true


func pouches() -> Array[CoinPouch]:
	return [_his_pouch, _pouch] as Array[CoinPouch]


## 这件现在算「待成交」（标金色）
func pending(uid: int) -> bool:
	return _session != null and (_session.taken.has(uid) or _session.given.has(uid))


## 226 批一：最新一句告示（测试看）
func line_text() -> String:
	return notice_layer().current_text()
#endregion


## 「能不能放到那儿」：商人的棋盘收他自己的货（放回 / 挪位）和你能上桌的东西；你那边（棋盘、地上）什么都收（拿他的货 = 放上桌）
func _allow_drop(inst: ItemInstance, target: ItemContainer) -> bool:
	if _session == null or inst == null or not _session.active:
		return false
	if target == _session.board:
		if _session.is_merchants(inst.uid):
			return true
		if _drag != null and _drag.carrying_contents():
			say(UiText.t("act.bag_full"))
			return false
		var why := _session.refuse_reason(inst)
		if why != "":
			say(why)
			return false
		return true
	return target == flow.run.board or target == flow.run.storage


## 审查 A1：没成交的东西（他的货、你放上桌的）不能压上去合成
func _allow_craft(inst: ItemInstance) -> bool:
	return _session == null or inst == null or not (_session.is_merchants(inst.uid) or _session.board.has_item(inst.uid))


## 拖完、双击完、按钮挪完：等这一帧挪完再重算一次桌上（几个容器的 changed 合成一次）
func _queue_sync() -> void:
	if _sync_queued or _session == null:
		return
	_sync_queued = true
	_flush_sync.call_deferred()     # 方法 Callable：屏在这一帧里被释放了就不调（lambda 会撞上已释放的 self）


func _flush_sync() -> void:
	_sync_queued = false
	if _session != null and _session.active:
		_session.sync()


func _double_merchant(uid: int) -> void:
	if _session == null:
		return
	if _session.given.has(uid):
		withdraw(uid)
	else:
		take(uid)


## 悬浮窗按钮：商人棋盘上他的货「拿过来 ◎N」，你放上去的「收回」
func _merchant_actions(uid: int) -> Array:
	if _session == null:
		return []
	if _session.given.has(uid):
		return [ItemActions.make(&"withdraw", UiText.t("shop.withdraw"), func(): withdraw(uid))]
	var inst := _session.board.get_item(uid)
	if inst == null:
		return []
	var a := ItemActions.make(&"take", UiText.t("shop.take"), func(): take(uid))
	a.coin = _session.tag_price(inst)
	return [a]


## 自己那边「双击做的那件事」：你的东西「放上桌 ◎收购价」（不能上桌的灰着写原因），拿过来没成交的「收回」
func _offer_action(inst: ItemInstance) -> ItemActions.Action:
	if _session != null and _session.is_merchants(inst.uid):
		return ItemActions.make(&"withdraw", UiText.t("shop.withdraw"), func(): withdraw(inst.uid))
	var a := ItemActions.make(&"offer", UiText.t("shop.offer"), func(): offer(inst.uid))
	if _session == null:
		return a
	a.coin = _session.sell_price_of(inst.def, inst)
	var why := _session.refuse_reason(inst)
	if why != "":
		a.coin = -1
		return ItemActions.disable(a, why)
	return a


func _on_dealt(got: Array, gave: Array, _paid: int, _change: int) -> void:
	var names: Array[String] = []
	for inst in got + gave:
		names.append(Names.of((inst as ItemInstance).def))
	var line := UiText.t("shop.dealt") % "、".join(names) if not names.is_empty() else UiText.t("shop.dealt_plain")
	var hint := _first_sale_hint() if not gave.is_empty() else ""
	say(line + ("　" + hint if hint != "" else ""))
	_rebuild_belt()


## 待成交色：盖在一块视图上的一层（不接鼠标；棋盘或地上），标出这块视图里桌上的东西
func _mark(view: ContainerView) -> Control:
	var m := PendingMarks.new()
	m.view = view
	m.screen = self
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.add_child(m)
	return m


func _exit_tree() -> void:
	if _ground_marks != null and is_instance_valid(_ground_marks):
		_ground_marks.queue_free()
	_ground_marks = null


class PendingMarks extends Control:
	var view: ContainerView = null
	var screen = null

	func _process(_d: float) -> void:
		queue_redraw()     # 拖拽时道具跟着挪，标记跟着画

	func _draw() -> void:
		if view == null or screen == null or not is_instance_valid(screen) or view.container() == null:
			return
		for v in view.container().items():
			var inst := v as ItemInstance
			if not screen.pending(inst.uid):
				continue
			var r: Rect2 = view.item_rect(inst.uid)
			if not r.has_area():
				continue
			r = r.grow(-3.0)
			draw_rect(r, PENDING_FILL)
			var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
			for i in 4:
				draw_dashed_line(pts[i], pts[i + 1], PENDING_GOLD, PENDING_DASH, 9.0)


## 160 补一：「随身」那几格：每种一格（图标，没图写名字头一个字），格下挂价签；点一下放上桌 / 撤下，卖掉的变灰
func _rebuild_belt() -> void:
	if _belt_row == null:
		return
	UiTheme.clear_children(_belt_row)
	_belt_btns.clear()
	var frame := _belt_row.get_parent() as Control
	var offers: Array = _session.belt_offers if _session != null else []
	if frame != null:
		frame.visible = not offers.is_empty()
	for i in offers.size():
		var idx := i
		var def := BeltSkillDef.find(StringName(String(offers[i]["id"])))
		var cell := _vbox(4)
		var view := InventoryView.make(GridInventory.new(Vector2i.ONE, 0, false), font)
		view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		view.seams = BoardFrame.seams_of(SHOP_BOARD).merged({"edge": true})
		cell.add_child(view)
		var tile := BeltTile.new()
		tile.def = def
		tile.set_anchors_preset(Control.PRESET_FULL_RECT)
		tile.tooltip_text = UiText.t("shop.belt_tip") % [Names.description_of(def), def.describe()] if def != null else ""
		tile.clicked.connect(func(): toggle_belt(idx))
		view.add_child(tile)
		var price := PriceTag.coins(int(offers[i]["price"]))
		price.name = "BeltPrice%d" % idx
		cell.add_child(price)
		_belt_row.add_child(cell)
		_belt_btns.append(tile)
	_refresh()


## 随身格的一格：画随身技能的图标（没图写名字头一个字），点一下放上桌 / 撤下；放上桌的描金，卖掉了变灰
class BeltTile extends Control:
	signal clicked
	var def: BeltSkillDef = null:
		set(v):
			def = v
			_icon = def.icon() if def != null else null     # 拿住贴图：_draw 里现读的图画完就被放掉，画出来是白块
	var _icon: Texture2D = null
	var sold := false:
		set(v):
			sold = v
			queue_redraw()
	var on_table := false:
		set(v):
			on_table = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not sold:
			clicked.emit()
			accept_event()

	func _draw() -> void:
		var c := size * 0.5
		var tint := Color(1, 1, 1, 0.35) if sold else Color.WHITE
		if on_table:
			var r := Rect2(Vector2.ZERO, size).grow(-3.0)
			draw_rect(r, PENDING_FILL)
			draw_rect(r, PENDING_GOLD, false, PENDING_DASH)
		if _icon != null:
			var s := minf(size.x, size.y) - 8.0
			draw_texture_rect(_icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
		else:
			var f := UiPalette.cjk_font_bold()
			var glyph := (Names.of(def) if def != null else "?").left(1)
			var fs := 30
			var w := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, c + Vector2(-w.x * 0.5, fs * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("2a1d0c") * tint)


func _refresh() -> void:
	if _session == null or _scale == null:
		return
	_scale.left = _session.left_total()
	_scale.right = _session.right_total()
	_scale.left_coins = _session.his_coins
	_scale.right_coins = _session.my_coins
	var st := _session.status()
	_scale.plate = plate_text(st)
	_deal_btn.disabled = not _session.can_deal()
	if _refresh_btn != null:
		_refresh_btn.disabled = _session.refresh_reason() != ""
	_pouch.amount = flow.run.wallet.balance - _session.my_coins
	_his_pouch.amount = _session.purse - _session.his_coins
	for i in _belt_btns.size():
		var tile := _belt_btns[i] as BeltTile
		tile.sold = _session.belt_sold.has(i)
		tile.on_table = _session.belt_on.has(i)
		var price := _belt_row.get_child(i).get_node_or_null("BeltPrice%d" % i) as PriceTag
		if price != null:
			price.sold = tile.sold


## 差额牌上的字：还差 N / 够了 / 找你 N / 他只付得起 N（钱写成 [method CoinShort.coin] 记号，秤上画成金币；空桌写空）
func plate_text(st: Dictionary) -> String:
	if _session == null or _session.table_empty():
		return ""
	var key := {"short": "shop.gap_short", "change": "shop.gap_change", "cant_pay": "shop.gap_cant_pay"}.get(String(st["kind"]), "") as String
	if key == "":
		return UiText.t("shop.gap_even")
	return UiText.t(key) + CoinShort.coin(int(st["n"]))
