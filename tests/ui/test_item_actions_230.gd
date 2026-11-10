## 230（作者 19:01 两者都要）：悬浮窗下的道具操作按钮 + 玩家锁定。
## 排行（两两并排、成对不拆、放不下半宽拆行）；锁定拦出售 / 地上 / 一键出售、存档带着；危险按钮两步；右键钉住、点了锁原地刷新；商店的买 / 卖按钮
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const A087 := preload("res://tests/run/test_author_087.gd")
const PREFIX := "item_actions_230"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _act(id: StringName, label: String = "锁定", pair: StringName = &"") -> ItemActions.Action:
	return ItemActions.make(id, label, Callable(), false, pair)


static func _ids(rows: Array) -> Array:
	return rows.map(func(r: Array) -> Array: return r.map(func(a: ItemActions.Action) -> String: return String(a.id)))


static func run_rows(t: TestCase) -> void:
	t.begin("230 · 排行：两两并排；单颗后面紧跟一对 → 独占一行；成对的不拆；放不下半宽的那一行拆成两行")
	var quick := _act(&"quick")
	var lock := _act(&"lock", "锁定", &"lock")
	var anchor := _act(&"anchor")
	t.eq(_ids(ItemActions.rows([quick, lock, anchor])), [["quick", "lock"], ["anchor"]], "棋盘上的信物：放到地上 | 锁定，奉为主信仰独占")
	var carry := _act(&"carry")
	var lock_same := _act(&"lock_same", "锁定同类 ×2", &"lock")
	var sell := _act(&"sell", "出售 3 币", &"sell")
	var sell_same := _act(&"sell_same", "出售同类 ×2 得 6 币", &"sell")
	t.eq(_ids(ItemActions.rows([carry, lock, lock_same, sell, sell_same])), [["carry"], ["lock", "lock_same"], ["sell", "sell_same"]],
		"仓库里一件：带上独占，锁定一对、出售一对")
	t.eq(_ids(ItemActions.rows([lock, lock_same, anchor])), [["lock", "lock_same"], ["anchor"]], "一对后面单颗落在最后：独占")
	var narrow := func(label: String) -> bool: return label.length() < 6
	t.eq(_ids(ItemActions.rows([sell, sell_same], narrow)), [["sell"], ["sell_same"]], "有一颗放不下半宽：拆成两行")
	t.check(TipButton.fits_half("锁定"), "「锁定」放得下半宽")
	t.check(not TipButton.fits_half("出售同类 ×12 得 1234 币 再加一段很长的字"), "很长的放不下半宽")


static func run_lock_guards(t: TestCase) -> void:
	t.begin("230 · 锁定：存档带着；锁着的不能单卖、一键出售跳过并数出来；解锁照常卖；按钮灰掉、出售同类只算没锁的")
	var db := _db()
	var def := db.get_def(&"longsword")
	var a := ItemInstance.create(def)
	t.check(not a.is_locked_by_player(), "新的没锁")
	a.set_locked(true)
	t.check(a.is_locked_by_player(), "锁上了")
	var back := ItemInstance.from_dict(a.to_dict(), db)
	t.check(back != null and back.is_locked_by_player(), "存档读回来还锁着")
	a.set_locked(false)
	t.check(not a.state.has(ItemInstance.LOCKED_KEY), "解锁把键删掉（存档不多一个 false）")

	var meta := MetaState.new()
	var b := ItemInstance.create(def)
	var c := ItemInstance.create(def)
	t.check(meta.warehouse.try_add(b, true) and meta.warehouse.try_add(c, true), "两把长剑进仓库")
	b.set_locked(true)
	t.eq(meta.sell_item(b.uid), -1, "锁着的单卖不了")
	t.check(meta.warehouse.has_item(b.uid), "还在仓库")
	var got := meta.sell_selected([b.uid, c.uid])
	t.eq(int(got["locked"]), 1, "一键出售会跳过 1 件")
	t.eq(int(got["count"]), 1, "一键出售只卖了没锁的那把")
	t.check(meta.warehouse.has_item(b.uid) and not meta.warehouse.has_item(c.uid), "锁着的留下")
	var sold := []
	var do_sell := func(uid: int) -> int:
		sold.append(uid)
		return 1
	var sell := ItemActions.sell(b, 7, do_sell)
	t.check(not sell.enabled and sell.reason == UiText.t("act.locked"), "锁着：出售按钮灰、写已锁定")
	var d := ItemInstance.create(def)
	meta.warehouse.try_add(d, true)
	var same := ItemActions.sell_same(b, meta.warehouse, func(_i: ItemInstance) -> int: return 5, do_sell)
	t.check(same.enabled and same.label == UiText.t("act.sell_same") % 1 and same.coin == 5, "出售同类只算没锁的那 1 件（%s，金币 %d）" % [same.label, same.coin])
	same.run.call()
	t.eq(sold, [d.uid], "点了只卖没锁的")
	var ls := ItemActions.lock_same(b, meta.warehouse)
	t.eq(ls.label, UiText.t("act.lock_same") % 2, "锁定同类 ×2")
	ls.run.call()
	t.check(b.is_locked_by_player() and d.is_locked_by_player(), "同类都锁上")
	t.eq(ItemActions.lock_same(b, meta.warehouse).label, UiText.t("act.unlock_same") % 2, "全锁着：变成解锁同类")
	b.set_locked(false)
	t.eq(meta.sell_item(b.uid), floori(float(ItemValue.of(def)) * 0.5), "解锁后照常卖")


static func run_tip_button(t: TestCase) -> void:
	t.begin("230 · 危险按钮两步：第一下变「再点一次」不做事；两秒不点回弹；两秒内再点才做。灰的点了没反应")
	var fired := []
	var a := ItemActions.make(&"sell", "出售 3 币", Callable(), true, &"sell")
	var b := TipButton.make(a, TipButton.HALF)
	b.chosen.connect(func(x: ItemActions.Action): fired.append(x.id))
	t.eq(b.custom_minimum_size, Vector2(TipButton.HALF, TipButton.HEIGHT), "半宽 177 × 28")
	b._on_pressed()
	t.check(b.confirming() and b.text == UiText.t("act.confirm"), "第一下：再点一次")
	t.eq(fired.size(), 0, "还没做")
	b.tick(TipButton.CONFIRM_SEC + 0.1)
	t.check(not b.confirming() and b.text == "出售 3 币", "两秒没点：回弹")
	b._on_pressed()
	b.tick(1.0)
	b._on_pressed()
	t.eq(fired, [&"sell"], "两秒内再点：做了")
	var safe := TipButton.make(ItemActions.make(&"lock", "锁定", Callable()), TipButton.FULL)
	safe.chosen.connect(func(x: ItemActions.Action): fired.append(x.id))
	safe._on_pressed()
	t.eq(fired.size(), 2, "不危险的一下就做")
	var off := TipButton.make(ItemActions.disable(ItemActions.make(&"buy", "买下 9 币", Callable()), "钱不够"), TipButton.FULL)
	off.chosen.connect(func(x: ItemActions.Action): fired.append(x.id))
	off._on_pressed()
	t.check(off.disabled and off.tooltip_text == "钱不够" and fired.size() == 2, "灰的：没反应，悬浮提示写原因")
	for x in [b, safe, off]:
		x.free()


static func frame_pin_and_lock(t: TestCase, root: Window) -> void:
	t.begin("230 · 右键一件 = 立刻钉住、按钮展开；点「锁定」原地刷新成「解锁」、角上画锁；没登记按钮的视图不画按钮")
	var db := _db()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var sword := ItemInstance.create(db.get_def(&"longsword"))
	t.check(board.place(sword, Vector2i(0, 0), 0), "长剑摆上")
	var view := InventoryView.new()
	view.auto_tooltip = false
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	view.item_context.emit(view, sword.uid)
	t.check(tip.is_showing() and tip.is_pinned(), "右键：开了、钉住")
	t.eq(tip.action_buttons().size(), 0, "没登记按钮：一颗也没有")
	tip.hide_tip()
	view.actions_for = func(uid: int) -> Array:
		var inst := board.get_item(uid)
		return [ItemActions.make(&"quick", UiText.t("act.drop"), func(): board.remove(uid), true), ItemActions.lock(inst, board)]
	view.item_context.emit(view, sword.uid)
	t.eq(tip.action_rows(), [["quick", "lock"]], "放到地上 | 锁定 一行")
	var lock_btn: TipButton = tip.action_buttons()[1]
	t.eq(lock_btn.text, UiText.t("act.lock"), "写着锁定")
	t.eq(lock_btn.get_combined_minimum_size().y, TipButton.HEIGHT, "按钮高 28（内边距不跟九宫格边走）")
	lock_btn._on_pressed()
	t.check(sword.is_locked_by_player(), "锁上了")
	t.check(tip.is_pinned(), "窗还钉着")
	t.eq(tip.action_buttons()[1].text, UiText.t("act.unlock"), "原地刷新：变成解锁")
	t.check(tip._panel.text().contains(UiText.t("tip.locked")), "副标题写已锁定")
	var r := ItemPainter.lock_rect(sword, 0, Vector2.ZERO, InventoryView.CELL)
	t.check(r.size == Vector2.ONE * ItemPainter.LOCK_SIDE and r.position.x > 0.0, "小锁画在左上那格里（%s）" % r)
	var drop: TipButton = tip.action_buttons()[0]
	drop._on_pressed()
	t.check(board.has_item(sword.uid), "放到地上要两下：第一下没动")
	drop._on_pressed()
	t.check(not board.has_item(sword.uid), "第二下：拿走了")
	t.check(not tip.is_showing(), "东西不在了：窗收起")
	host.free()


static func frame_shop_buttons(t: TestCase, _root: Window) -> void:
	t.begin("230 / 290 · 商店：他的货「拿上秤」画售价；棋盘上的东西 放上秤（画收购价）| 锁定；锁着的不上秤、不丢地上")
	var c := A087._content()
	var f := Support.flow(c, PREFIX)
	var run := f.begin(c.chapter, A087._kit(c), 3)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var shop_node: MapNode = null
	for id in run.map.node_ids():
		if run.map.get_node(id).type == &"shop":
			shop_node = run.map.get_node(id)
			break
	if shop_node == null:
		t.check(true, "（这个种子没有商店点）")
		Support.cleanup(PREFIX)
		return
	run.wallet.earn(1000, &"test")
	run.events.handle(shop_node)
	while f.run.events.pending_event() != null:
		f.choose_event(0)
	var session := run.events.current_shop
	if session == null:
		t.check(false, "开了店")
		Support.cleanup(PREFIX)
		return
	var screen = load("res://ui/game/shop_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.SHOP
	screen.open({"node": shop_node, "session": session})
	var ware := session.board.items()[0] as ItemInstance     # 290：商人一块大棋盘
	var take: Array = screen.merchant_view().actions_for.call(ware.uid)
	t.eq(take.size(), 1, "他的货上一颗")
	t.eq(String((take[0] as ItemActions.Action).id), "take", "拿上秤")
	t.eq((take[0] as ItemActions.Action).coin, session.tag_price(ware), "按钮上画售价（金币 + 数）")
	t.check((take[0] as ItemActions.Action).enabled, "亮着（钱够不够天秤上看）")
	var mine: ItemInstance = null
	for i in run.board.items():
		var it := i as ItemInstance
		if not run.board.acts_as_bag(it.def):
			mine = it
			break
	if mine == null:
		t.check(false, "棋盘上有一件不是包的")
		screen.free()
		Support.cleanup(PREFIX)
		return
	var acts: Array = screen._inv.board_actions(mine.uid)
	# 2026-10-22：「不参战」排在锁定之后 —— 会参与战斗的那几件才有（信物与材料没有）
	var want := ["offer", "lock"]
	if mine.def.combat != null and not mine.def.is_anchor():
		want.append("bench")
	t.eq(acts.map(func(a: ItemActions.Action) -> String: return String(a.id)), want, "放上秤、锁定、（不参战）")
	var by_id := {}
	for a in acts:
		by_id[String((a as ItemActions.Action).id)] = a
	t.eq((by_id["offer"] as ItemActions.Action).coin, session.sell_price_of(mine.def, mine), "放上秤：画收购价")
	mine.set_locked(true)
	acts = screen._inv.board_actions(mine.uid)
	by_id = {}
	for a in acts:
		by_id[String((a as ItemActions.Action).id)] = a
	t.check(not (by_id["offer"] as ItemActions.Action).enabled, "锁着：放上秤灰")
	t.check(not screen._inv.quick_move(screen._inv.board_view, mine.uid), "锁着：双击不上秤")
	t.check(run.board.has_item(mine.uid), "还在棋盘上")
	t.check(not screen._allow_drop(mine, session.board), "锁着：拖不上他的棋盘")
	t.check(not screen.drag_layer()._stash_accepts(run.storage, mine), "锁着：拖不到地上")
	t.check(not screen.offer(mine.uid), "锁着：直接放也不放")
	mine.set_locked(false)
	var before := run.wallet.balance
	var price := session.sell_price_of(mine.def, mine)
	t.check(screen.offer(mine.uid), "解锁：放上秤")
	t.eq(session.right_total(), price, "右盘 = 收购价")
	t.eq(screen.ask_change(), price, "点商人钱袋：他找钱")
	t.check(screen.deal(), "成交")
	t.eq(run.wallet.balance, before + price, "进了 %d" % price)
	t.check(not run.board.has_item(mine.uid), "从棋盘上拿走")
	var notes: Array = []
	for line in screen.notice_layer()._lines:
		notes.append((line["scroll"] as NoticeScroll).text)
	t.check(notes.size() == 1 and String(notes[0]).begins_with(UiText.t("shop.dealt") % Names.of(mine.def)), "成交告示写物品名（%s）" % [notes])
	t.check(notes.size() == 1 and String(notes[0]).ends_with(UiText.t("shop.sell_hint") % [UiText.tenths(0.3), UiText.tenths(0.5)]), "第一次卖：比例提示接在后面")
	screen.free()
	Support.cleanup(PREFIX)


static func run_english(t: TestCase) -> void:
	t.begin("230 · 英文：按钮字都有英文、格式对得上")
	var was := UiText.lang
	UiText.lang = "en"
	t.eq(UiText.t("act.lock"), "Lock", "Lock")
	t.eq(UiText.t("act.sell"), "Sell", "Sell（268 复测：价钱是金币小图 + 数字）")
	t.eq(UiText.t("act.sell_same") % 3, "Sell all ×3", "Sell all")
	t.eq(UiText.t("act.confirm"), "Click again", "Click again")
	t.check(not UiText.t("item.locked_no").is_empty() and UiText.t("meta.sell_skipped") % 2 == " (skipped 2 locked)", "提示句")
	UiText.lang = was
