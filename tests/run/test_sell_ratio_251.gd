## 251 §四（作者 2026-10-24 11:47）：局内卖贱、基地卖贵 —— 局内商店收三成（`shop_sell_ratio` 0.3），基地收五成（`MetaRules.sell_ratio` 0.5）；
## 金银 / 贵重品两边各自的规矩不动；出售区悬浮窗说「这里只收三成；带回基地能卖五成」，两个数从规则读、写「几成」
extends RefCounted


static func run_ratios(t: TestCase) -> void:
	t.begin("251 §四：局内 ⌊价 × 0.3⌋、基地 ⌊价值 × 0.5⌋；金银基地按面值、局内照比例")
	var db := ItemDatabase.new()
	db.load_dir()
	var eco := load(ContentPaths.asset_file("economy_rules", "standard")) as EconomyRules
	var meta_rules := GameFlow.load_meta_rules()
	t.check(is_equal_approx(eco.shop_sell_ratio, 0.3), "局内三成（%s）" % eco.shop_sell_ratio)
	t.check(is_equal_approx(meta_rules.sell_ratio, 0.5), "基地五成")
	var shop := ShopSession.new(null, eco, db, Wallet.new(0))
	var def := db.get_def(&"shortsword")
	t.eq(shop.sell_price_of(def), floori(float(shop.price_of(def)) * 0.3), "局内卖短剑：三成")
	t.eq(MetaState.sell_price(def, meta_rules.sell_ratio), floori(float(ItemValue.of(def)) * 0.5), "基地卖短剑：五成")
	t.check(shop.sell_price_of(def) < MetaState.sell_price(def, meta_rules.sell_ratio), "带回去卖得多")
	var gold := db.get_def(&"gold_bar")
	t.eq(MetaState.sell_price(gold, meta_rules.sell_ratio), ItemValue.of(gold), "金银：基地按面值")
	t.eq(shop.sell_price_of(gold), floori(float(shop.price_of(gold)) * 0.3), "金银：局内照比例")


static func run_hint(t: TestCase) -> void:
	t.begin("251 §四：出售区那句提示 —— 两个比例写成「几成」，不写数字")
	UiText.lang = "zh"
	t.eq(UiText.tenths(0.3), "三成", "0.3 = 三成")
	t.eq(UiText.tenths(0.5), "五成", "0.5 = 五成")
	t.eq(UiText.tenths(1.0), "十成", "1.0 = 十成")
	var hint := UiText.t("shop.sell_hint") % [UiText.tenths(0.3), UiText.tenths(0.5)]
	t.eq(hint, "这里只收三成；带回基地能卖五成", "提示")
	t.check(not hint.contains("3") and not hint.contains("5"), "不写阿拉伯数字")
