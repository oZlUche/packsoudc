## 商店按钮换纸卷（UI替换美术，作者 17:39 定丙）：收起、离开 = 普通纸卷键（宽按字撑，最窄 116）；
## 刷新、随身买钮 = 币座纸卷键，字只写名字，价钱数字画在金币右边；卖掉的随身钮禁用并压已售戳；缺图退回平板按钮，价钱接在字后
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


static func frame_scroll_keys(t: TestCase, root: Window) -> void:
	t.begin("商店纸卷键：收起 / 离开普通键、刷新与随身币座键（字只写名字，数字在币座上），卖掉的随身钮禁用压戳")
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
	t.check(belt.size() > 0, "有随身买钮")
	if belt.is_empty():
		screen.free()
		Support.cleanup(PREFIX)
		return
	var b0: ScrollKey = belt[0]
	var def := BeltSkillDef.find(StringName(String(session.belt_offers[0]["id"])))
	t.check(b0.coin, "随身买钮是币座键")
	t.eq(b0.text, Names.of(def), "字只写技能名")
	t.eq(b0.price, int(session.belt_offers[0]["price"]), "价钱画在币座上")
	t.check(not b0.sold and not b0.disabled, "没卖：亮、不压戳")
	t.eq(screen.buy_belt(0), "", "买下")
	b0 = screen._belt_btns[0]     # 买下会重摆一遍
	t.check(b0.sold and b0.disabled, "卖掉了：禁用、压已售戳")
	t.eq(b0.stamp_center(), Vector2(b0.size.x - 45.0, 28.0), "戳的中心对准币座中心")
	t.eq(b0.text, Names.of(def), "名字还在")
	UiText.lang = "en"
	screen._refresh()
	t.eq(refresh.text, "Restock", "英文：Restock")
	UiText.lang = "zh"
	screen.free()
	Support.cleanup(PREFIX)


static func frame_scroll_keys_fallback(t: TestCase, root: Window) -> void:
	t.begin("商店纸卷键缺图：退回平板按钮，价钱接在字后，卖掉写「已售」")
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
		var def := BeltSkillDef.find(StringName(String(session.belt_offers[0]["id"])))
		t.eq(screen._belt_btns[0].text, "%s 已售" % Names.of(def), "卖掉：名字后写「已售」")
	screen.free()
	UiTheme.asset_root = keep
	Support.cleanup(PREFIX)
