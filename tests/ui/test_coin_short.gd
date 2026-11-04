## 「金币不够」不写字（2026-10-31 17:27 转来：钱用金币图标，不够就红 / 打叉，「图像能说明的不加文字」）：
## 六句原因都只是记号 `[coin_short]`（撤离费带数），告示卷 / 操作按钮 / 铁匠铺工钱画一枚红色斜划的金币
extends RefCounted


static func run_tokens(t: TestCase) -> void:
	t.begin("金币不够：六句原因中英文都是记号，不写「钱」「金币」「coins」")
	for key in ["market.no_funds", "market.refresh_poor", "smithy.no_funds", "act.short", "log.shop_no_coins", "notice.extract_fee"]:
		for lang in ["zh", "en"]:
			var keep := UiText.lang
			UiText.lang = lang
			var s := UiText.t(key)
			UiText.lang = keep
			t.check(CoinShort.has(s) and CoinShort.strip(s % 30 if s.contains("%d") else s) == "", "%s（%s）只是记号：%s" % [key, lang, s])
	t.eq(CoinShort.amount(UiText.t("notice.extract_fee") % 30), 30, "撤离费带数")
	t.eq(CoinShort.amount(CoinShort.tag()), -1, "不带数")
	t.eq(CoinShort.strip("「纱布」买不了：" + CoinShort.tag()), "「纱布」买不了", "去掉记号连带前面的冒号")
	t.check(not CoinShort.has("仓库放不下"), "别的原因不算")


static func frame_surfaces(t: TestCase, root: Window) -> void:
	t.begin("金币不够：告示卷字后跟一枚红色斜划的金币（撤离费带红字的数）；操作按钮价钱那枚变红、不挂悬停字；铁匠铺工钱变红")
	var s := NoticeScroll.make(UiText.t("shop.cant_buy") % ["纱布", UiText.t("act.short")])
	root.add_child(s)
	t.check(s.coin() != null and s.coin().short and s.coin().amount < 0, "告示卷：一枚红金币（不带数）")
	t.check(not CoinShort.has(s.label().text) and s.label().text != "", "字里没有记号：%s" % s.label().text)
	t.check(s.coin().position.x >= s.label().position.x + s.label().size.x, "金币在字后面")
	var fee := NoticeScroll.make(UiText.t("notice.extract_fee") % 30)
	root.add_child(fee)
	t.check(fee.coin() != null and fee.coin().short and fee.coin().amount == 30 and fee.label().text == "", "撤离费：只有红金币 + 30，没字")
	var plain := NoticeScroll.make("仓库放不下")
	root.add_child(plain)
	t.check(plain.coin() == null, "别的告示不带金币")
	var bought := NoticeScroll.make(UiText.t("shop.bought") % "腰包" + CoinShort.coin(5))     # 11-04：买卖告示的钱画金币
	root.add_child(bought)
	t.check(bought.coin() != null and not bought.coin().short and bought.coin().amount == 5, "买下：句末一枚金币 + 5（不是红的）")
	t.check(not bought.label().text.contains("[coin") and not bought.label().text.contains("币") and not bought.label().text.contains("coin"), "字里不写「币」、没有记号：%s" % bought.label().text)
	for key in ["shop.bought", "shop.sold", "meta.sold_one", "meta.sold_many"]:
		for lang in ["zh", "en"]:
			t.check(not String(UiText.TEXT[key][lang]).contains("币") and not String(UiText.TEXT[key][lang]).contains("coin"), "%s/%s 不写钱字" % [key, lang])
	var a := ItemActions.make(&"buy", UiText.t("act.buy_coin"), Callable())
	a.coin = 40
	var b := TipButton.make(ItemActions.disable(a, UiText.t("market.no_funds")), TipButton.FULL)
	root.add_child(b)
	var c: CoinLabel = null
	for ch in b.get_children():
		if ch is CoinLabel:
			c = ch
	t.check(c != null and c.short and c.amount == 40, "按钮：价钱那枚金币变红、斜划")
	t.eq(b.tooltip_text, "", "按钮不挂「金币不够」的字")
	t.check(CoinLabel.short_texture() != null, "美术设计 A 定稿（作者 11-02 15:07）：hud/coin_short 在")
	t.check(CoinLabel.make_short(-1).custom_minimum_size.x <= CoinLabel.make_short(-1).coin_side() + 0.5, "不带数：只占一枚金币宽")
	for n in [s, fee, plain, b]:
		n.queue_free()
