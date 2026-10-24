## 251（作者 2026-10-24）：基地集市 —— 科技「集市」三级（4 / 6 / 8 格，素材白 / 绿 / 蓝，消耗品，三级一格空包）；一局一换货、升级也换；
## 买 = 扣钱、进仓库（包进包架）、格子标卖掉；钱不够 / 仓库满不卖；库存跟存档，退役的道具那一格读档时去掉
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const META := "user://test_251_market.json"


static func _meta(lv: int) -> MetaState:
	var m := T110._meta()
	if lv > 0:
		m.facility_levels[Market.ID] = lv
	return m


static func run_content(t: TestCase) -> void:
	t.begin("251 §二：内容 —— 科技「集市」三级、前置讨价、效果 tech_facility(market)；集市规则从资产读")
	var def := load(ContentPaths.asset_file("techs", "market")) as TechDef
	t.not_null(def, "科技资产在")
	if def == null:
		return
	t.eq(def.max_level(), 3, "三级")
	t.eq(def.requires, [&"bargain"] as Array[StringName], "前置讨价")
	t.check(def.effect is TechFacility and (def.effect as TechFacility).facility == Market.ID, "tech_facility(market)")
	var rules := Market.load_rules()
	t.eq(rules.slots_per_level, [4, 6, 8] as Array[int], "4 / 6 / 8 格")
	t.eq(rules.rarity_cap_per_level, [0, 1, 2] as Array[int], "素材白 / 绿 / 蓝")
	var m := T110._meta()
	def.effect.derive(m, 2)
	t.eq(Market.level(m), 2, "derive 记下级数")
	def.effect.derive(m, 0)
	t.eq(Market.level(m), 0, "0 级 = 没有")
	t.check(not m.to_dict().has("facility_levels"), "级数不入档（120）")


static func run_restock(t: TestCase) -> void:
	t.begin("251 §二：上货 —— 0 级没货；1 级 4 格、素材 ≤ 白、消耗品 ≤ 绿、素材至少两格、不卖装备 / 珍宝 / 贵重品；3 级 8 格、见得到蓝素材、最后一格是包")
	var db := T110._db()
	var rules := Market.load_rules()
	var m0 := _meta(0)
	Market.restock(m0, rules, db, BagPool.standard())
	t.check(m0.market_stock.is_empty(), "0 级：没货")
	var m1 := _meta(1)
	Market.restock(m1, rules, db, BagPool.standard())
	t.eq(m1.market_stock.size(), 4, "1 级：4 格")
	var mats := 0
	var ok := true
	for i in m1.market_stock.size():
		var d := Market.def_at(m1, db, i)
		if d.tags.has(&"material"):
			mats += 1
			ok = ok and d.rarity <= 0
		else:
			ok = ok and d.rarity <= 1 and (d.tags.has(&"remedy") or d.tags.has(&"food") or d.tags.has(&"ammo"))
		ok = ok and not d.is_valuable() and not d.is_bullion() and not d.tags.has(&"weapon") and not d.tags.has(&"treasure") and not d.is_bag
	t.check(ok, "都在档内、没有装备 / 珍宝 / 贵重品 / 包")
	t.check(mats >= 2, "素材至少两格（%d）" % mats)
	var cands := Market.candidates(rules, db, 3)
	t.check((cands["material"] as Array).any(func(id): return db.get_def(id).rarity == 2), "3 级候选里有蓝素材")
	t.check((cands["material"] as Array).has(&"steel_ingot"), "建材也卖（待定 1 推荐）")
	var m3 := _meta(3)
	Market.restock(m3, rules, db, BagPool.standard())
	t.eq(m3.market_stock.size(), 8, "3 级：8 格")
	t.check(Market.def_at(m3, db, 7).is_bag, "最后一格是空包")
	t.check(m1.market_seed == 1 and m3.market_seed == 1, "上一次货换一次种子")


static func run_buy(t: TestCase) -> void:
	t.begin("251 §二：买 —— 钱减、仓库多一件、格子标卖掉；卖掉的 / 钱不够 / 仓库满都不卖，钱与仓库不动；包进包架")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var rules := Market.load_rules()
	var m := _meta(3)
	Market.restock(m, rules, db, BagPool.standard())
	var def := Market.def_at(m, db, 0)
	var price := Market.price_of(rules, def)
	t.eq(price, maxi(1, roundi(float(ItemValue.of(def)) * rules.price_mult)), "价 = 价值 × 倍数")
	m.funds = price - 1
	t.eq(Market.can_buy(m, rules, db, 0), UiText.t("market.no_funds"), "钱不够")
	t.is_null(Market.buy(m, rules, db, 0), "钱不够：不卖")
	t.eq(m.warehouse.item_count(), 0, "仓库没动")
	m.funds = 10000
	var got := Market.buy(m, rules, db, 0)
	t.not_null(got, "买到了")
	t.eq(m.funds, 10000 - price, "钱减了")
	t.check(got != null and m.warehouse.has_item(got.uid), "进了仓库")
	t.check(Market.is_sold(m, 0), "格子标卖掉")
	t.eq(Market.can_buy(m, rules, db, 0), UiText.t("market.sold_out"), "卖掉的不能再买")
	var bag := Market.buy(m, rules, db, 7)
	t.check(bag != null and m.rack.get_item(bag.uid) != null, "空包进了包架")
	# 仓库塞满
	var filler := db.get_def(&"oak_log")
	while true:
		var inst := ItemInstance.create(filler, m.allocate_uid())
		if not m.warehouse.try_add(inst, true):
			break
	var idx := -1
	for i in m.market_stock.size():
		if not Market.is_sold(m, i) and not Market.def_at(m, db, i).is_bag:
			idx = i
			break
	var before := m.funds
	var n := m.warehouse.item_count()
	if not m.warehouse.can_admit(Market.def_at(m, db, idx)):
		t.eq(Market.can_buy(m, rules, db, idx), UiText.t("market.full"), "仓库满：说放不下")
		t.is_null(Market.buy(m, rules, db, idx), "仓库满：不卖")
		t.check(m.funds == before and m.warehouse.item_count() == n, "钱与仓库不动")
	else:
		t.check(false, "仓库没塞满（%s 还放得下）" % Market.def_at(m, db, idx).id)


static func run_flow(t: TestCase) -> void:
	t.begin("251 §二：一局结束回基地重新上货；升级集市那一刻也重新上货（多的格立刻有东西）；开发区改级数也补货")
	var db := T110._db()
	var f := GameFlow.new(db, null, null, T110._meta())
	f.tech_defs = GameFlow.load_techs()
	f.meta.tech_levels["bargain"] = 1
	f.meta.tech_levels["market"] = 1
	f.derive_techs()
	f.restock_market()
	t.eq(f.meta.market_stock.size(), 4, "1 级 4 格")
	var seed0 := f.meta.market_seed
	f.after_run_market()
	t.eq(f.meta.market_seed, seed0 + 1, "回基地：换了一次货")
	f.meta.funds = 1000000
	var def := f.tech_of(&"market")
	for key in TechService.needed(f.meta, def):
		for _i in int(TechService.needed(f.meta, def)[key]):
			TechService.deposit(f.meta, def, db.get_def(StringName(key)))
	t.check(f.upgrade_tech(&"market"), "升到 2 级")
	t.eq(f.meta.market_stock.size(), 6, "升级后立刻 6 格")
	f.dev_set_tech_level(&"market", 3)
	t.eq(f.meta.market_stock.size(), 8, "开发区改到 3 级：8 格")
	f.dev_set_tech_level(&"market", 0)
	t.check(f.meta.market_stock.is_empty(), "改回 0 级：没货")


static func run_save(t: TestCase) -> void:
	t.begin("251 §二：存档 —— 库存（id、卖没卖）与种子读回一致；道具库里没有了的那一格去掉（173）")
	var db := T110._db()
	var m := _meta(2)
	Market.restock(m, Market.load_rules(), db, BagPool.standard())
	m.market_stock[1]["sold"] = true
	var d := m.to_dict()
	var back := MetaState.from_dict(JSON.parse_string(JSON.stringify(d)), db, m.rules)
	t.eq(back.market_stock, m.market_stock, "库存一致")
	t.eq(back.market_seed, m.market_seed, "种子一致")
	(d["market_stock"] as Array).append({"id": "no_such_item_251", "sold": false})
	var back2 := MetaState.from_dict(JSON.parse_string(JSON.stringify(d)), db, m.rules)
	t.eq(back2.market_stock.size(), m.market_stock.size(), "退役的那一格去掉")
