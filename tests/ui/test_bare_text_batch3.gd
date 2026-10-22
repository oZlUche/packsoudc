## 226 批三（读数归位）：叠层窗石板皮的标题条铺石刻标题带 band（铜 / 书 / 帐篷不铺），墨字 20 号从槽左头 18 起；
## 商店：货架价签换铜挂牌 `PriceTag`（卖掉的盖已售戳、价钱照写），出售区说明换段头签（说明进悬浮窗），顶上「货币 N……」那行删
extends RefCounted

const Keys := preload("res://tests/ui/test_shop_keys.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_overlay_band(t: TestCase, root: Window) -> void:
	t.begin("226 批三 · 叠层标题带：石板皮铺 band（墨字 20 号，字从槽左头 18 起），帐篷 / 书 / 铜不铺")
	var f := OverlayFrame.new()
	root.add_child(f)
	f.set_title("保险箱")
	f.size = Vector2(800, 400)
	t.check(f.band, "石板皮铺了标题带")
	t.eq(f.title_label.get_theme_font_size("font_size"), 20, "标题 20 号")
	t.eq(f.title_label.get_theme_color("font_color"), Color("2e2219"), "墨字（槽是浅石）")
	var head := f.title_bar.get_parent() as MarginContainer
	t.eq(head.get_theme_constant("margin_left"), 18, "字从槽左头 18 起")
	t.check(f.title_bar.custom_minimum_size.y >= 36.0, "标题条至少 36 高（槽高）")
	f.free()
	for skin in [OverlayFrame.SKIN_TENT, OverlayFrame.SKIN_BOOK, OverlayFrame.SKIN_BRONZE]:
		var g := OverlayFrame.new(-1, skin)
		root.add_child(g)
		t.check(not g.band, "%s 不铺标题带" % skin)
		g.free()


static func frame_shop_tags(t: TestCase, root: Window) -> void:
	t.begin("226 批三 · 商店：价签是铜挂牌（卖掉的盖戳、价钱照写）；出售区是段头签、说明进悬浮窗；没有「货币 N」那行")
	var o := Keys._open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	var tags: Array = []
	for i in screen._shelf_views.size():
		tags.append(screen._shelf_row.get_child(i).get_node_or_null("Price%d" % i))
	t.check(not tags.is_empty() and tags.all(func(p): return p is PriceTag), "每格一块铜挂牌")
	var p0: PriceTag = tags[0]
	t.check(p0.text.begins_with(str(int(session.stock[0]["price"]))), "牌上写价钱")
	t.check(not p0.sold, "没卖：不盖戳")
	t.eq(p0.custom_minimum_size.y, PriceTag.HEIGHT, "高 40")
	var uid: int = session.item_at(0).uid
	t.check(screen.quick_buy(uid), "买下第一格")
	var p1 := screen._shelf_row.get_child(0).get_node_or_null("Price0") as PriceTag
	t.check(p1 != null and p1.sold, "卖掉了：盖戳")
	if p1 != null:
		t.check(p1.text.begins_with(str(int(session.stock[0]["price"]))), "价钱照写，不换成「已售」")
		t.eq(p1.stamp_rect().get_center(), Vector2(p1.size.x, 0.0), "戳中心对准价签右上角")
	var heads: Array = screen.find_children("*", "HeaderTag", true, false)
	var sell: HeaderTag = null
	for h in heads:
		if (h as HeaderTag).text == "出售区":
			sell = h
	t.check(sell != null and sell.tooltip_text == UiText.t("shop.sell_tip"), "出售区段头签，说明进悬浮窗")
	var bare: Array = screen.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text.begins_with("货币"))
	t.eq(bare.size(), 0, "顶上「货币 N……」那行删了")
	screen.free()
	Support.cleanup(Keys.PREFIX)
