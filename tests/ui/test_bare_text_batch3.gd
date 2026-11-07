## 226 批三（读数归位）：叠层窗石板皮的标题条铺石刻标题带 band（铜 / 书 / 帐篷不铺），墨字 20 号从槽左头 18 起；
## 商店：顶上「货币 N……」那行删；290 起货架价签、出售区都没了，钱写在两只钱袋上
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
	t.eq(f.title_label.get_theme_font_size("font_size"), UiTheme.sz(20), "标题 20 号（258：按字号档）")
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
	t.begin("226 批三 / 290 · 商店：两只钱袋在左下、右下角（不压按键），写各自的金币；放上秤的钱从钱袋里扣着写；没有出售区、没有「货币 N」那行")
	var o := Keys._open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	var pouches: Array = screen.pouches()
	var his: CoinPouch = pouches[0]
	var mine: CoinPouch = pouches[1]
	t.eq(mine.amount, screen.flow.run.wallet.balance, "自己的钱袋写当前金币")
	t.eq(his.amount, session.purse, "商人的钱袋写他的钱")
	_lay_out(screen)
	_lay_out(screen)     # 两遍：外层排好了内层才拿到尺寸
	var hr := his.get_global_rect()
	var mr := mine.get_global_rect()
	var hit: Array = screen.find_children("*", "BaseButton", true, false).filter(func(b): return (b as Control).is_visible_in_tree() and (mr.intersects((b as Control).get_global_rect()) or hr.intersects((b as Control).get_global_rect())))
	t.eq(hit.size(), 0, "钱袋不压按键")
	var sc: ShopScale = screen.scale_widget()
	var sr := sc.get_global_rect()
	t.check(hr.end.x <= sr.position.x + 0.5 and mr.position.x >= sr.end.x - 0.5, "商人钱袋在天秤左边、自己的在右边（%s | %s | %s）" % [hr, sr, mr])
	var board_r: Rect2 = screen.merchant_view().get_global_rect()
	t.check(hr.position.y >= board_r.end.y - 0.5 and mr.position.y >= board_r.end.y - 0.5, "两只钱袋都在棋盘下面")
	var ware := session.board.items()[0] as ItemInstance
	t.check(screen.take(ware.uid), "拿一件上秤")
	var paid: int = screen.pay_gap()
	t.eq(mine.amount, screen.flow.run.wallet.balance - paid, "放上秤的钱从钱袋里扣着写")
	t.check(screen.deal(), "成交")
	t.eq(mine.amount, screen.flow.run.wallet.balance, "成交了：钱袋跟着变")
	var heads: Array = screen.find_children("*", "HeaderTag", true, false).filter(func(h): return (h as HeaderTag).text == "出售区")
	t.eq(heads.size(), 0, "出售区删了")
	var bare: Array = screen.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text.begins_with("货币"))
	t.eq(bare.size(), 0, "顶上「货币 N……」那行删了")
	screen.free()
	Support.cleanup(Keys.PREFIX)


## 容器当场排一遍（不等下一帧）
static func _lay_out(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_lay_out(c)
