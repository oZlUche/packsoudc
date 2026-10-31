## 270（作者 2026-10-31 12:01 / 12:58「其余按推荐」）：集市分摊位 —— 五个固定摊按标签列货单（白 → 绿 → 蓝随级数，不足 3 件从下一档补，买了不减）；
## 散货摊只进战斗道具、绿起按递减权重抽，花钱换货（40 / 60 / 80，回一局归零），锁着的换货不动、买走解锁；老档没有锁当没锁
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const FLOW_META := "user://test_270_flow_meta.json"
const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")
const Bare := preload("res://tests/ui/test_no_bare_text_226.gd")


static func _meta(lv: int) -> MetaState:
	var m := T110._meta()
	m.facility_levels[Market.ID] = lv
	return m


static func run_content(t: TestCase) -> void:
	t.begin("270 §四.1：六个摊位按顺序（药铺 / 粮铺 / 兵器铺 / 甲胄铺 / 杂货铺 / 散货摊）；散货摊规矩从资产读")
	var stalls := Market.stalls()
	t.eq(stalls.map(func(st: StallDef) -> String: return String(st.id)), ["remedy", "food", "arms", "armor", "goods", "loose"], "六个摊、顺序对")
	t.eq(stalls.map(func(st: StallDef) -> String: return st.display_name), ["药铺", "粮铺", "兵器铺", "甲胄铺", "杂货铺", "散货摊"], "摊名")
	t.eq(stalls.map(func(st: StallDef) -> bool: return st.fixed), [true, true, true, true, true, false], "前五个固定、散货摊不固定")
	t.eq(Market.stall(&"food").tags, [&"food", &"supply"] as Array[StringName], "粮铺 = 食物 + 补给")
	t.eq(Market.stall(&"armor").tags, [&"armor", &"shield"] as Array[StringName], "甲胄铺 = 护甲 + 盾")
	t.check(stalls.all(func(st: StallDef) -> bool: return Names.of(st, "en") != st.display_name), "摊名都有英文")
	var rules := Market.load_rules()
	t.eq(rules.battle_tags, [&"weapon", &"armor", &"shield", &"trinket", &"ammo", &"remedy"] as Array[StringName], "散货摊只进战斗道具（药算）")
	t.eq(rules.loose_rarity_weights, [50.0, 30.0, 14.0, 5.0, 1.0] as Array[float], "绿到红权重 50 / 30 / 14 / 5 / 1")
	t.eq([rules.loose_rarity_min, rules.refresh_cost, rules.refresh_step, rules.stall_min_listed], [1, 40, 20, 3], "绿起、换货 40 + 20 × 次、不足 3 件补")
	t.check(GameFlow.load_help_pages().any(func(h: HelpPageDef) -> bool: return h.id == &"market"), "百科有「集市」页")


static func run_catalogue(t: TestCase) -> void:
	t.begin("270 §四.5：固定摊货单 = 标签 ∩ 稀有度 ≤ 本级上限（白货 1 级就全卖）、按稀有度再按价排；排除表生效；不足 3 件从下一档补到 3 件")
	var db := T110._db()
	var rules := Market.load_rules()
	for st in Market.stalls():
		if not st.fixed:
			t.eq(Market.catalogue(rules, db, st, 3), [] as Array[StringName], "散货摊没有货单")
			continue
		for lv in [1, 2, 3]:
			var got := Market.catalogue(rules, db, st, lv)
			var want: Array[StringName] = []
			for id in db.ids():
				var d := db.get_def(id)
				if d.rarity <= rules.rarity_cap_at(lv) and d.tags.any(func(tg: StringName) -> bool: return st.tags.has(tg)) and Market._sellable(rules, d):
					want.append(id)
			var head := got.slice(0, want.size())
			head.sort()
			want.sort()
			t.eq(head, want, "%s %d 级：前面是本级全部货" % [st.id, lv])
			t.eq(got.size(), maxi(want.size(), rules.stall_min_listed), "%s %d 级：只在不足 3 件时补到 3 件" % [st.id, lv])
			var sorted := true
			for i in range(1, got.size()):
				var a := db.get_def(got[i - 1])
				var b := db.get_def(got[i])
				sorted = sorted and (a.rarity < b.rarity or (a.rarity == b.rarity and Market.price_of(rules, a) <= Market.price_of(rules, b)))
			t.check(sorted, "%s %d 级：按稀有度、再按价排" % [st.id, lv])
	var armor := Market.catalogue(rules, db, Market.stall(&"armor"), 1)
	t.eq(armor.size(), 3, "甲胄铺开局没有白货：从绿货补到 3 件")
	t.check(armor.all(func(id: StringName) -> bool: return db.get_def(id).rarity == 1), "补的是下一档（绿）")
	var goods3 := Market.catalogue(rules, db, Market.stall(&"goods"), 3)
	t.check(not goods3.has(&"mithril_ingot"), "排除表：秘银锭不卖")
	t.check(goods3.all(func(id: StringName) -> bool: var d := db.get_def(id); return not d.is_bag and not d.is_valuable() and not d.is_bullion() and not d.tags.has(&"treasure")), "包、贵重品、金银、珍宝不卖")
	t.check(Market.catalogue(rules, db, Market.stall(&"goods"), 1).has(&"wooden_stick"), "杂货铺 1 级就有木棍（素材从散货摊搬来）")


static func run_buy_listed(t: TestCase) -> void:
	t.begin("270 §二.1：固定摊买了不减 —— 钱减、仓库多一件、货单照旧；货单外的 / 钱不够不卖")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var rules := Market.load_rules()
	var m := _meta(1)
	var st := Market.stall(&"remedy")
	var before := Market.catalogue(rules, db, st, 1)
	var id := before[0]
	var price := Market.price_of(rules, db.get_def(id))
	m.funds = price * 2
	t.not_null(Market.buy_listed(m, rules, db, st, id), "买到第一件")
	t.not_null(Market.buy_listed(m, rules, db, st, id), "同一件还能再买")
	t.eq(m.funds, 0, "钱扣了两次")
	t.eq(m.warehouse.item_count(), 2, "仓库多两件")
	t.eq(Market.catalogue(rules, db, st, 1), before, "货单不减")
	t.eq(Market.can_buy_listed(m, rules, db, st, id), UiText.t("market.no_funds"), "钱不够")
	t.eq(Market.can_buy_listed(m, rules, db, st, &"strong_salve"), UiText.t("market.sold_out"), "蓝货 1 级不在货单里")
	t.eq(Market.can_buy_listed(m, rules, db, Market.stall(&"goods"), id), UiText.t("market.sold_out"), "别的摊的货不在这个摊买")


static func run_loose_draw(t: TestCase) -> void:
	t.begin("270 §四.5：散货摊只进战斗道具、稀有度 ≥ 绿；一万次抽签各档占比和权重差不到 2%")
	var db := T110._db()
	var rules := Market.load_rules()
	var cands := Market.loose_candidates(rules, db)
	t.check(not cands.is_empty(), "有候选")
	t.check(cands.all(func(id: StringName) -> bool: var d := db.get_def(id); return d.rarity >= 1 and d.tags.any(func(tg: StringName) -> bool: return rules.battle_tags.has(tg))), "都是绿起的战斗道具")
	t.check(not cands.any(func(id: StringName) -> bool: return db.get_def(id).tags.has(&"material") and not db.get_def(id).tags.any(func(tg: StringName) -> bool: return rules.battle_tags.has(tg))), "素材不在散货摊")
	var tiers := {}
	for id in cands:
		tiers[db.get_def(id).rarity] = true
	var total := 0.0
	for r in tiers:
		total += rules.loose_weight(r)
	var rng := RandomNumberGenerator.new()
	rng.seed = 270
	var hits := {}
	var n := 10000
	for _i in n:
		var r := db.get_def(Market._draw(cands.duplicate(), rules, db, rng)).rarity
		hits[r] = int(hits.get(r, 0)) + 1
	for r in tiers:
		var want := rules.loose_weight(r) / total
		var got := float(hits.get(r, 0)) / n
		t.check(absf(got - want) <= 0.02, "稀有度 %d：%.3f（权重给 %.3f）" % [r, got, want])


static func run_refresh(t: TestCase) -> void:
	t.begin("270 §二.2：换货 40 / 60 / 80，扣钱、重抽；钱不够不换；回一局归零")
	var db := T110._db()
	var f := GameFlow.new(db, null, null, T110._meta())
	f.meta_path = FLOW_META
	f.tech_defs = GameFlow.load_techs()
	f.meta.tech_levels["bargain"] = 1
	f.derive_techs()
	f.restock_market()
	f.meta.funds = 180
	var costs: Array = []
	for _i in 3:
		costs.append(Market.refresh_cost(f.meta, f.market()))
		t.eq(f.refresh_market(), "", "换了")
	t.eq(costs, [40, 60, 80], "40 / 60 / 80")
	t.eq(f.meta.funds, 0, "钱扣了 180")
	t.eq(f.meta.market_refreshes, 3, "记了三次")
	var seed := f.meta.market_seed
	t.eq(f.refresh_market(), UiText.t("market.refresh_poor"), "钱不够：不换")
	t.eq(f.meta.market_seed, seed, "货没动")
	f.after_run_market()
	t.eq(f.meta.market_refreshes, 0, "回一局：换货价从头算")
	t.eq(Market.refresh_cost(f.meta, f.market()), 40, "又是 40")
	MetaSave.remove(FLOW_META)


static func run_locks(t: TestCase) -> void:
	t.begin("270 §二.2：锁着的格换货（花钱的、回一局免费的）都不动；买走解锁；卖掉的锁不上；锁着的不会再抽出一件重复的")
	ItemInstance.reset_uid_counter()
	var db := T110._db()
	var rules := Market.load_rules()
	var m := _meta(3)
	Market.restock(m, rules, db, BagPool.standard())
	t.check(Market.toggle_lock(m, 1) and Market.toggle_lock(m, 7), "锁上第 2 格和最后一格（包）")
	var keep1: String = m.market_stock[1]["id"]
	var keep7: String = m.market_stock[7]["id"]
	m.funds = 100000
	var moved := false
	for _i in 6:
		var before := m.market_stock.duplicate(true)
		t.check(Market.refresh(m, rules, db, BagPool.standard()), "花钱换货")
		moved = moved or before[0]["id"] != m.market_stock[0]["id"] or before[3]["id"] != m.market_stock[3]["id"]
	Market.restock(m, rules, db, BagPool.standard())     # 回一局的免费换货
	t.check(m.market_stock[1]["id"] == keep1 and Market.is_locked(m, 1), "锁着的第 2 格一直没动")
	t.check(m.market_stock[7]["id"] == keep7 and Market.is_locked(m, 7), "锁着的包一直没动")
	t.check(moved, "没锁的换了")
	var ids := m.market_stock.map(func(e: Dictionary) -> String: return String(e["id"]))
	t.eq(ids.count(keep1), 1, "锁着的那件没被再抽出来一件")
	t.not_null(Market.buy(m, rules, db, 1), "买锁着的那件")
	t.check(Market.is_sold(m, 1) and not Market.is_locked(m, 1), "买走就解锁")
	t.check(not Market.toggle_lock(m, 1) and not Market.is_locked(m, 1), "卖掉的锁不上")
	Market.restock(m, rules, db, BagPool.standard())
	t.check(not Market.is_sold(m, 1), "解了锁的格下回换货照换")


static func run_old_save(t: TestCase) -> void:
	t.begin("270 §四.5：老档 —— 货格没有 locked 当没锁、没有换货次数当 0、没记摊当空；存了读回一致")
	var db := T110._db()
	var m := _meta(2)
	Market.restock(m, Market.load_rules(), db, BagPool.standard())
	var d := m.to_dict()
	for row in d["market_stock"]:
		(row as Dictionary).erase("locked")
	d.erase("market_refreshes")
	d.erase("market_stall")
	var back := MetaState.from_dict(JSON.parse_string(JSON.stringify(d)), db, m.rules)
	t.check(back.market_stock.all(func(e: Dictionary) -> bool: return e.has("locked") and not bool(e["locked"])), "都当没锁")
	t.eq([back.market_refreshes, back.market_stall], [0, &""], "次数 0、没记摊")
	m.market_refreshes = 2
	m.market_stall = &"arms"
	Market.toggle_lock(m, 0)
	var again := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())), db, m.rules)
	t.eq([again.market_refreshes, again.market_stall, Market.is_locked(again, 0)], [2, &"arms", true], "次数、上回看的摊、锁都读回来")


static func frame_market_stalls(t: TestCase, root: Window) -> void:
	t.begin("270 §三：集市页左列六颗木牌；固定摊 = 通用底图 + 货格（每格一件、价签金币式），多于 21 件翻页；买了货单不减；散货摊多【换货】键、能锁；记住上回看的摊；字都不裸")
	ItemInstance.reset_uid_counter()
	var f := W178._flow()
	f.meta.tech_levels = {"bargain": 1, "warehouse": 1, "safe_box": 1, "pack": 1, "market": 2, "smithy": 0}
	f.derive_techs()
	f.meta.funds = 100000
	f.ensure_market()
	var s: Control = W178._screen(f, root)
	s.show_tab("market")
	var p = s.market_panel()
	t.eq(p.stall_id(), &"remedy", "第一次进：药铺")
	for id in [&"remedy", &"food", &"arms", &"armor", &"goods", &"loose"]:
		t.check(p.stall_key(id) is CatKey, "%s 是铁匠铺那套木牌" % id)
	t.check(p.stall_key(&"remedy").button_pressed and not p.stall_key(&"loose").button_pressed, "药铺那颗按下")
	var sv: StallView = p.stall_view()
	t.check(sv.visible and not p.stage().visible, "固定摊：通用底图那页，凉棚收着")
	var cat := Market.catalogue(f.market(), f.items, Market.stall(&"remedy"), 3)
	t.eq(sv.ids(), cat, "一格一件，就是货单")
	t.check(sv.views().all(func(v: InventoryView) -> bool: return BoardFrame.framed(v) and float(v.seams.get("seam_alpha", 1.0)) == 0.0), "格子透明、登记过（227）")
	var coins_ok := true
	for j in sv.prices().size():
		coins_ok = coins_ok and sv.prices()[j].coin == Market.price_of(f.market(), f.items.get_def(cat[j]))
	t.check(coins_ok, "价签金币式")
	t.eq(sv.title.text, "药铺", "挂牌写摊名")
	sv.size = Vector2(1100, 760)
	var box: Rect2 = sv.cell_rect(0)
	var v0 := sv.views()[0] as Control
	var k := sv.stage.scale_factor()
	t.check(absf(v0.position.y + v0.size.y - sv.stage.at(box.end).y) < 1.0 and v0.size.x <= box.size.x * k + 1.0, "货底对齐格底、缩进格里")
	var n := f.meta.warehouse.item_count()
	t.eq(p.buy_listed(cat[0]), "", "买第一件")
	t.eq(f.meta.warehouse.item_count(), n + 1, "进了仓库")
	t.eq(p.stall_view().ids(), cat, "货单不减")
	var act: ItemActions.Action = p._listed_action(cat[0])
	t.eq([act.label, act.coin], [UiText.t("act.buy_coin"), Market.price_of(f.market(), f.items.get_def(cat[0]))], "右键「买下」+ 金币价钱")
	p.show_stall(&"goods")
	var goods := Market.catalogue(f.market(), f.items, Market.stall(&"goods"), 3)
	t.eq(sv.page_count(), ceili(goods.size() / 21.0), "杂货铺 %d 件：%d 页" % [goods.size(), sv.page_count()])
	t.check(sv.tabs.visible and sv.tabs.get_child_count() == sv.page_count(), "页签在")
	sv.show_page(sv.page_count() - 1)
	t.eq(sv.views().size(), goods.size() - (sv.page_count() - 1) * 21, "最后一页剩下的")
	t.eq(Bare.audit(s, "market270_stall"), [] as Array[String], "固定摊没有裸字")
	p.show_stall(Market.LOOSE)
	t.check(p.stage().visible and not sv.visible, "散货摊：木凉棚")
	t.eq(p.stage().sign_text, "散货摊", "招牌写散货摊")
	var key: RefreshKey = p.refresh_key()
	t.eq([key.price, key.poor], [40, false], "【换货】40")
	var funds := f.meta.funds
	key.pressed.emit()
	t.eq(f.meta.funds, funds - 40, "换货扣 40")
	t.eq(p.refresh_key().price, 60, "下回 60")
	t.eq(p._lock_action(0).label, UiText.t("act.lock"), "右键有「锁定」")
	p._lock_action(0).run.call()
	t.check(Market.is_locked(f.meta, 0), "锁上了")
	var shown := (p.views()[0] as InventoryView).inventory.items()[0] as ItemInstance
	t.check(shown.is_locked_by_player(), "货上画小锁")
	t.eq(p._lock_action(0).label, UiText.t("act.unlock"), "再右键是「解锁」")
	var locked_id: String = f.meta.market_stock[0]["id"]
	p.refresh()
	t.eq(String(f.meta.market_stock[0]["id"]), locked_id, "锁着的没换")
	f.meta.funds = 10
	p.rebuild()
	t.check(p.refresh_key().poor and p.refresh_key().disabled, "钱不够：键压灰、点不了")
	t.eq(Bare.audit(s, "market270_loose"), [] as Array[String], "散货摊没有裸字")
	t.eq(f.meta.market_stall, Market.LOOSE, "记下了散货摊")
	s.queue_free()
	var s2: Control = W178._screen(f, root)
	s2.show_tab("market")
	t.eq(s2.market_panel().stall_id(), Market.LOOSE, "下回进集市还是散货摊")
	s2.queue_free()
	W178._cleanup()
