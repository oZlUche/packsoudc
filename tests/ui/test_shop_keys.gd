## 商店按钮换纸卷（UI替换美术，作者 17:39 定丙）：收起、离开 = 普通纸卷键（宽按字撑，最窄 116）；
## 刷新 = 币座纸卷键，字只写名字，价钱数字画在金币右边；缺图退回平板按钮，价钱接在字后。
## 作者 2026-10-27 17:13：随身改成货架下面一块小框（每种一格、带图标、挂价签），钱不够时价钱写红
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
	t.begin("商店纸卷键：收起 / 离开普通键、刷新币座键（字只写名字，数字在币座上）；随身格带图标和价签，卖掉压戳；钱不够价钱写红")
	var o := _open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	var refresh: Button = screen._refresh_btn
	t.check(refresh is ScrollKey and refresh.coin and refresh.art, "刷新是币座纸卷键")
	t.eq(refresh.text, "刷新", "字只写「刷新」")
	t.eq(refresh.price, session.refresh_cost(), "价钱 = 刷新费")
	var box := refresh.get_theme_stylebox("normal") as StyleBoxTexture
	t.check(box != null and box.texture == UiTheme.art_cached("shop/key_coin_normal"), "币座键的图")
	if box != null:
		t.eq([box.texture_margin_left, box.texture_margin_right], [20.0, 96.0], "九宫格：右边币座 96 不拉")
		t.eq(box.content_margin_right, 26.0 + 90.0 - 2.0, "字让开币座")
	t.eq(refresh.price_at(), Vector2(refresh.size.x - 90.0 + 37.0, 28.0), "数字在币座左沿 + 37")
	var keys: Array = refresh.get_parent().get_children()
	t.eq(keys.size(), 3, "刷新、收起、离开一排")
	for k: Button in keys.slice(1):
		t.check(k is ScrollKey and not k.coin and k.art, "「%s」普通纸卷键" % k.text)
		t.check(k.get_combined_minimum_size().x >= 116.0, "「%s」最窄 116" % k.text)
		t.eq(k.get_combined_minimum_size().y, 56.0, "高 56")
	t.eq(keys[1].text, "收起", "收起")
	t.eq(keys[2].text, "离开", "离开")
	var belt: Array = screen._belt_btns
	t.check(belt.size() > 0, "有随身格")
	if belt.is_empty():
		screen.free()
		Support.cleanup(PREFIX)
		return
	var b0: Control = belt[0]
	var def := BeltSkillDef.find(StringName(String(session.belt_offers[0]["id"])))
	t.check("sold" in b0 and "def" in b0, "随身格是 BeltTile（作者 17:13：货架下面一块小框，每种一格）")
	t.eq(b0.def, def, "格里是这件随身技能")
	t.not_null(b0._icon, "画定稿图标")
	var tag := screen._belt_row.get_child(0).get_node_or_null("BeltPrice0") as PriceTag
	t.not_null(tag, "格下挂价签")
	if tag != null:
		t.eq(tag.coin, int(session.belt_offers[0]["price"]), "价签写价钱")
		t.check(not tag.sold and not tag.poor, "没卖、钱够：墨色、不压戳")
	t.check(not b0.sold, "没卖：亮")
	t.eq(screen.buy_belt(0), "", "买下")
	b0 = screen._belt_btns[0]
	tag = screen._belt_row.get_child(0).get_node_or_null("BeltPrice0") as PriceTag
	t.check(b0.sold, "卖掉了：格变灰")
	t.check(tag != null and tag.sold and not tag.poor, "卖掉了：价签压已售、不写红")
	var cash := flow_wallet(screen)
	cash.spend(cash.balance - 1, &"test")
	screen._refresh()
	if screen._belt_btns.size() > 1:
		var tag1 := screen._belt_row.get_child(1).get_node_or_null("BeltPrice1") as PriceTag
		t.check(tag1 != null and tag1.poor and not tag1.sold, "钱不够：随身价签写红（作者 17:14「红色」）")
	var shelf_tag := screen._shelf_row.get_child(0).get_node_or_null("Price0") as PriceTag
	t.check(shelf_tag != null and (shelf_tag.poor or shelf_tag.sold), "钱不够：货架价签写红")
	t.check((refresh as ScrollKey).poor, "钱不够：刷新币座价钱写红")
	cash.earn(1000, &"test")
	screen._refresh()
	t.check(not (refresh as ScrollKey).poor and (shelf_tag == null or not shelf_tag.poor), "钱又够了：回墨色")
	UiText.lang = "en"
	screen._refresh()
	t.eq(refresh.text, "Restock", "英文：Restock")
	UiText.lang = "zh"
	screen.free()
	Support.cleanup(PREFIX)


static func frame_scroll_keys_fallback(t: TestCase, root: Window) -> void:
	t.begin("商店纸卷键缺图：退回平板按钮，价钱接在字后；随身格卖掉写「已售」")
	var keep := UiTheme.asset_root
	UiTheme.asset_root = NOWHERE
	var o := _open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	var refresh: Button = screen._refresh_btn
	t.check(not (refresh is ScrollKey), "平板按钮")
	t.eq(refresh.text, "刷新 %d" % session.refresh_cost(), "字后接价钱")
	if not screen._belt_btns.is_empty():
		screen.buy_belt(0)
		var tag := screen._belt_row.get_child(0).get_node_or_null("BeltPrice0") as PriceTag
		t.check(screen._belt_btns[0].sold and tag != null and tag.sold, "随身格卖掉：格变灰、价签写「已售」")
	screen.free()
	UiTheme.asset_root = keep
	Support.cleanup(PREFIX)
