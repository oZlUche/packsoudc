## 商店按钮换纸卷（UI替换美术，作者 17:39 定丙）：离开 = 普通纸卷键（宽按字撑，最窄 116）；290：刷新、收起、回购删了，「成交」站在天秤座上。
## 作者 2026-10-27 17:13：随身是一块小框（每种一格、带图标、挂价签）；290 起点一格放上秤、成交才卖掉
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "shop_keys"
const NOWHERE := "res://tests/fixtures/__no_such_art__/"


static func _open(root: Window) -> Dictionary:
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX)
	f.begin(c.chapter, NodeScreens._kit(c), 1)
	f.run.wallet.earn(1000, &"test")
	var econ: EconomyRules = (load(ContentPaths.asset_file("economy_rules", "standard")) as EconomyRules).duplicate()
	econ.belt_picks = 2
	var node := MapNode.new()
	node.content_seed = 17
	var session := ShopSession.new(node, econ, c.items, f.run.wallet)
	session.belt_grant = func(_sid: StringName, n: int) -> int: return n
	var screen = load("res://ui/game/shop_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({"node": node, "session": session})
	return {"screen": screen, "session": session}


static func flow_wallet(screen) -> Wallet:
	return screen.flow.run.wallet


static func frame_scroll_keys(t: TestCase, root: Window) -> void:
	t.begin("商店纸卷键（290）：成交站在秤座上、空桌灰；离开普通纸卷键；随身格带图标和价签，点了上秤描金、成交后压戳；两只钱袋点得着")
	var o := _open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	var deal: Button = screen.deal_key()
	t.check(deal is ScrollKey, "成交是纸卷键")
	t.eq(deal.text, "成交", "字写「成交」")
	t.check(deal.get_parent() == screen.scale_widget(), "站在天秤上")
	t.check(deal.disabled, "空桌：成交灰")
	var leave: Array = screen.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == UiText.t("shop.leave"))
	t.eq(leave.size(), 1, "一枚离开键")
	if not leave.is_empty():
		var k: Button = leave[0]
		t.check(k is ScrollKey and not k.coin, "离开是普通纸卷键")
		t.check(k.get_combined_minimum_size().x >= 116.0, "最窄 116")
		t.eq(k.get_combined_minimum_size().y, 56.0, "高 56")
	t.check(screen.find_children("*", "Button", true, false).all(func(b): return (b as Button).text not in ["刷新", "收起", "回购"]), "刷新、收起、回购都没了")
	for p: CoinPouch in screen.pouches():
		t.check(p.clickable and p.mouse_filter == Control.MOUSE_FILTER_STOP and p.tooltip_text != "", "钱袋点得着、有说明")
	var belt: Array = screen._belt_btns
	t.check(belt.size() > 0, "有随身格")
	if belt.is_empty():
		screen.free()
		Support.cleanup(PREFIX)
		return
	var b0: Control = belt[0]
	var def := BeltSkillDef.find(StringName(String(session.belt_offers[0]["id"])))
	t.check("sold" in b0 and "def" in b0, "随身格是 BeltTile")
	t.eq(b0.def, def, "格里是这件随身技能")
	t.not_null(b0._icon, "画定稿图标")
	var tag := screen._belt_row.get_child(0).get_node_or_null("BeltPrice0") as PriceTag
	t.not_null(tag, "格下挂价签")
	if tag != null:
		t.eq(tag.coin, int(session.belt_offers[0]["price"]), "价签写价钱")
		t.check(not tag.sold, "没卖：不压戳")
	t.eq(screen.toggle_belt(0), "", "点一下：上秤")
	t.check(b0.on_table and not b0.sold, "上秤：描金")
	t.eq(screen.scale_widget().left, int(session.belt_offers[0]["price"]), "左盘写它的价")
	t.check(deal.disabled, "右盘轻：成交灰")
	t.eq(screen.pay_gap(), int(session.belt_offers[0]["price"]), "点自己的钱袋：补上差价")
	t.check(not deal.disabled, "够了：成交亮")
	t.check(screen.deal(), "成交")
	b0 = screen._belt_btns[0]
	tag = screen._belt_row.get_child(0).get_node_or_null("BeltPrice0") as PriceTag
	t.check(b0.sold and not b0.on_table, "卖掉了：格变灰")
	t.check(tag != null and tag.sold, "卖掉了：价签压已售")
	UiText.lang = "en"
	t.eq(UiText.t("shop.deal"), "Deal", "英文：Deal")
	UiText.lang = "zh"
	screen.free()
	Support.cleanup(PREFIX)


static func frame_scroll_keys_fallback(t: TestCase, root: Window) -> void:
	t.begin("商店纸卷键缺图：退回平板按钮；天秤画铜色占位；随身格卖掉写「已售」")
	var keep := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	var o := _open(root)
	var screen = o["screen"]
	t.not_null(screen.scale_widget(), "天秤照画（占位）")
	if not screen._belt_btns.is_empty():
		screen.toggle_belt(0)
		screen.pay_gap()
		screen.deal()
		var tag := screen._belt_row.get_child(0).get_node_or_null("BeltPrice0") as PriceTag
		t.check(screen._belt_btns[0].sold and tag != null and tag.sold, "随身格卖掉：格变灰、价签写「已售」")
	screen.free()
	UiTheme.asset_root = keep
	Support.cleanup(PREFIX)


## 277 第 4 条「回购」290 起自然成立：这次卖给他的挂你拿到的价，拿回来原价；离开就按正常售价
static func frame_buyback(t: TestCase, root: Window) -> void:
	t.begin("277 / 290 · 回购：卖给他的这次进店挂你拿到的价；拿回来钱回到卖之前；离开清掉")
	var o := _open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	var run: RunState = screen.flow.run
	var inst: ItemInstance = null
	for it in run.board.items():
		var ii := it as ItemInstance
		if session.refuse_reason(ii) == "" and not ii.def.is_bag:
			inst = ii
			break
	t.not_null(inst, "棋盘上有一件能卖的")
	if inst == null:
		screen.queue_free()
		Support.cleanup(PREFIX)
		return
	var before := run.wallet.balance
	t.check(screen.offer(inst.uid), "放上他的棋盘")
	t.check(screen.pending(inst.uid), "染待成交色")
	var gain := session.right_total()
	t.check(gain > 0, "右盘写收购价")
	screen.ask_change()
	t.check(screen.deal(), "成交")
	t.eq(run.wallet.balance, before + gain, "进账")
	t.check(not screen.pending(inst.uid), "色褪了")
	t.eq(session.tag_price(session.board.get_item(inst.uid)), gain, "挂你拿到的价")
	t.check(screen.take(inst.uid), "拿回来")
	t.eq(session.left_total(), gain, "左盘 = 原价")
	screen.pay_gap()
	t.check(screen.deal(), "成交")
	t.eq(run.wallet.balance, before, "原价买回：钱回到卖之前")
	t.check(run.board.has_item(inst.uid) or run.storage.has_item(inst.uid), "那件回来了（包里或地上）")
	screen.offer(inst.uid)
	screen.deal()
	session.leave()
	t.check(session.resale.is_empty(), "离开商店：清掉")
	screen.queue_free()
	Support.cleanup(PREFIX)


## UI设计 11-07 核 v5.39：头像不被随身格撑成横椭圆；包里放不下的货落在自己这边（天秤右边）
static func frame_badge_and_ground(t: TestCase, root: Window) -> void:
	t.begin("290 · 店主头像保持原宽；买下放不下的货落在天秤右边的地上")
	var o := _open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	if screen.npc != null:
		t.eq(screen.npc.size_flags_horizontal, Control.SIZE_SHRINK_BEGIN, "头像不横向撑满")
	var run: RunState = screen.flow.run
	var keep := run.board
	var full := GridInventory.new(Vector2i(1, 1), 1, false)     # 包里一格都放不下
	run.board = full
	screen.size = Vector2(1920, 1200)
	for _i in 3:
		screen.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var ware := session.board.items()[0] as ItemInstance
	var spot: Vector2 = screen._ground_spot(ware)
	t.check(ItemStash.has_spot_value(spot), "算得出落点")
	if ItemStash.has_spot_value(spot):
		var vp: Vector2 = screen.get_viewport_rect().size
		t.check(spot.x * vp.x >= screen.scale_widget().get_global_rect().end.x - 0.5, "落点在天秤右边（%.0f）" % (spot.x * vp.x))
	run.board = keep
	screen.free()
	Support.cleanup(PREFIX)


## 290 天秤定稿 A 铜天平（作者 11-07 18:37 挑定）：版式读 json，有图不画底牌，差额牌的字缩到放得下；缺图退回占位版式
static func frame_scale_art(t: TestCase, root: Window) -> void:
	t.begin("290 · 天秤定稿：五张图和版式都在；差额牌的字中英文大号字都放得下")
	var lay := ShopScale.layout()
	t.eq(BalanceScale._v(lay["pivot"]), Vector2(210, 36), "版式读定稿 json")
	for p in ["base", "beam", "pan_left", "pan_right", "coin"]:
		t.not_null(UiTheme.art_cached(ShopScale.ART + p), "有图 scale_%s" % p)
	var keep_lang := UiText.lang
	var keep_size := UiTheme.text_size
	var f := UiPalette.cjk_font_bold()
	var status := BalanceScale._rect(lay["controls"]["status"])
	var max_w := status.size.x - 12.0
	for tier in [&"medium", &"large"]:
		UiTheme.set_text_size(tier)
		for lang in ["zh", "en"]:
			UiText.lang = lang
			for key in ["shop.gap_short", "shop.gap_even", "shop.gap_change", "shop.gap_cant_pay"]:
				var words := UiText.t(key)
				var num := "" if key == "shop.gap_even" else "1000"
				var fs := ShopScale.fit_size(f, words, num, UiTheme.sz(ShopScale.PLATE_FONT), max_w)
				t.check(fs >= ShopScale.MIN_FONT + 1 and ShopScale.coin_text_width(f, words, num, fs) <= max_w,
					"%s / %s：「%s」%d 号放得下" % [tier, lang, words, fs])
	UiText.lang = keep_lang
	UiTheme.set_text_size(keep_size)
	var o := _open(root)
	var screen = o["screen"]
	var scale: ShopScale = screen.scale_widget()
	scale.size = scale.custom_minimum_size
	t.eq(scale.custom_minimum_size, Vector2(420, 204), "天秤 420 × 204")
	screen.free()
	Support.cleanup(PREFIX)
	var keep := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	t.eq(BalanceScale._v(ShopScale.layout()["pivot"]), Vector2(210, 28), "缺图：退回占位版式")
	UiTheme.asset_root = keep


## 309（v5.85 体验 E05）：头一回进店说一句怎么买，第二回不说；点钱袋补差：不差钱说不用补，钱不够说还差多少
static func frame_first_visit_hint(t: TestCase, root: Window) -> void:
	t.begin("309 · 商店首访提示只说一次；点钱袋时不差钱 / 钱不够各说一句")
	var o := _open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	t.eq(screen.notice_layer().current_text(), UiText.t("shop.first_visit"), "头一回进店：说怎么买")
	t.check(screen.flow.meta.coach_seen.has(screen.VISIT_HINT_SEEN), "记在局外")
	var hint := UiText.t("shop.first_visit")
	screen.notice_layer().step(10.0)
	t.check(screen.notice_layer().lines().has(hint), "313：过了 10 秒还挂着（普通告示 3 秒就收）")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	screen._input(press)
	t.check(not screen.notice_layer().lines().has(hint), "313：在店里头一回按下鼠标就收")
	var f = screen.flow
	screen.free()
	var again = load("res://ui/game/shop_screen.gd").new()
	again.flow = f
	again.font = UiPalette.cjk_font()
	root.add_child(again)
	again.open({"node": session.node, "session": session})
	t.check(not again._first_visit_hint() and f.meta.coach_seen.count(screen_seen_id()) == 1, "第二回不说")
	t.eq(again.toggle_belt(0), "", "随身一格上秤")
	var price := int(session.belt_offers[0]["price"])
	var w := flow_wallet(again)
	w.spend(w.balance - (price - 1), &"test")
	again.pay_gap()
	t.eq(again.notice_layer().current_text(), UiText.t("shop.gap_short") + CoinShort.coin(1), "钱不够：说还差 1")
	again.free()
	Support.cleanup(PREFIX)


static func screen_seen_id() -> String:
	return (load("res://ui/game/shop_screen.gd") as GDScript).get_script_constant_map()["VISIT_HINT_SEEN"]
