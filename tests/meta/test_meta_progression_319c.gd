## 319 C 批：讨价只管买价、精英 / BOSS 额外奖励（有放回池、不往低一档退、随机数另起一条）、局内商店换一批货（一家一次、卖进来的不动、钱袋不动、失败不收钱）
extends RefCounted

const Shop := preload("res://tests/run/test_shop_barter_290.gd")


static func _ctx_of(buff_ids: Array) -> RunContext:
	var ctx := RunContext.new()
	for id in buff_ids:
		var def := load(ContentPaths.asset_file("run_buffs", id)) as RunBuffDef
		for e in def.effects:
			(e as RunEffect).modify(ctx)
	return ctx


static func run_bargain_buy_only(t: TestCase) -> void:
	t.begin("319 · 讨价只改买价：买 ×0.9，卖给商人按原价的出售比例；买进卖出不会多出钱")
	var db := Shop._items()
	var ctx := _ctx_of(["tech_bargain_1"])
	t.eq(ctx.shop_price_mult, 0.9, "讨价 1 级：买价 ×0.9")
	var plain := ShopSession.new(Shop._node(), Shop._rules(), db, Wallet.new(0), 0.3)
	var cheap := ShopSession.new(Shop._node(), Shop._rules(), db, Wallet.new(0), 0.3, ctx.shop_price_mult)
	var def := db.get_def(&"knife")
	t.check(cheap.price_of(def) < plain.price_of(def), "买价便宜了")
	t.eq(cheap.sell_price_of(def), plain.sell_price_of(def), "卖价不变")
	t.check(cheap.sell_price_of(def) < cheap.price_of(def), "打了折买进来再卖回去仍然亏")


static func run_bounty_pools(t: TestCase) -> void:
	t.begin("319 · 额外奖励池：每份掉落规则的精英 / BOSS 都有合格道具；稀有度在下限以上、不出神话；不含包、金银、信物、红武、券、素材")
	var db := Shop._items()
	for res in ContentPaths.load_typed(ContentPaths.dirs_of("drop_rules")[1], DropRule):
		var rule := res as DropRule
		for kind in [&"elite", &"core"]:
			var rarities := rule.bounty_rarities(kind)
			t.check(not rarities.is_empty(), "%s / %s 配了档位" % [rule.id, kind])
			var n := 0
			for r in rarities:
				t.check(r >= (2 if kind == &"elite" else 3) and r <= 4, "%s / %s：稀有度 %d 在范围内" % [rule.id, kind, r])
				for id in DropResolver.bounty_candidates(rule, db, r):
					n += 1
					var d := db.get_def(id)
					if d.is_bag or d.is_bullion() or d.is_anchor() or d.is_unique() or d.is_ticket() or d.tags.has(&"material") or d.is_no_random_source():
						t.check(false, "%s 不该进池" % id)
			t.check(n > 0, "%s / %s 有合格道具（%d 件）" % [rule.id, kind, n])


static func run_bounty_pick(t: TestCase) -> void:
	t.begin("319 · 额外奖励：科技 buff 开对应的点；同一个种子抽出来一样（读档不重抽）；有放回（抽很多次会重复）；空池不降档、报空")
	var db := Shop._items()
	t.eq(_ctx_of(["tech_elite_bounty_1"]).bounty, [&"elite"] as Array[StringName], "精英奖励开精英")
	t.eq(_ctx_of(["tech_boss_bounty_1"]).bounty, [&"core"] as Array[StringName], "首领奖励开 BOSS")
	var rule := load(ContentPaths.asset_file("drop_rules", "standard")) as DropRule
	var a := RandomNumberGenerator.new()
	a.seed = 7
	var b := RandomNumberGenerator.new()
	b.seed = 7
	var first := DropResolver.bounty_pick(rule, db, &"core", a)
	t.eq(DropResolver.bounty_pick(rule, db, &"core", b), first, "同一个种子同一件")
	t.check(db.get_def(first).rarity >= 3, "BOSS 那件史诗及以上")
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var draws := 200
	for i in draws:
		var id := DropResolver.bounty_pick(rule, db, &"elite", rng)
		if db.get_def(id).rarity < 2:
			t.check(false, "精英那件稀有及以上（%s）" % id)
		seen[id] = true
	t.check(seen.size() < draws, "有放回：%d 次里有重复（%d 种）" % [draws, seen.size()])
	var empty := DropRule.new()
	empty.id = &"t_empty"
	empty.bounty_weights = {"elite": {"4": 1}}
	var none := ItemDatabase.new()
	t.eq(DropResolver.bounty_pick(empty, none, &"elite", rng), &"", "一件合格的都没有：空（不往低一档找）")


static func _sell_in(s: ShopSession, inst: ItemInstance) -> void:
	s.home_board.try_add(inst)
	Shop._give(s, inst)
	if s.his_coins == 0:
		s.toggle_his_coins()
	s.deal()


static func run_shop_refresh(t: TestCase) -> void:
	t.begin("319 · 换一批货：没科技不能换；秤上有东西不能换；钱不够不能换；换一次扣钱、卖进来的原位不动、钱袋不动；一家一次；离店读档次数还在；同一局刷出来一样")
	var db := Shop._items()
	var wallet := Wallet.new(500)
	var node := Shop._node(9)
	var s := Shop._shop(db, wallet, node)
	t.eq(s.refresh_reason(), UiText.t("shop.refresh_locked"), "没科技：不能换")
	s.refreshes = _ctx_of(["tech_shop_refresh_1"]).shop_refreshes
	t.eq(s.refreshes, 1, "科技给一次")
	var mine := ItemInstance.create(db.get_def(&"knife"))
	_sell_in(s, mine)
	t.check(mine.state.has(ShopSession.SOLD_IN_KEY), "卖进去的带记号")
	var at := mine.origin
	var purse := s.purse
	var stock_before: Array = []
	for v in s.board.items():
		if v != mine:
			stock_before.append((v as ItemInstance).uid)
	var one := s.board.items().filter(func(i: ItemInstance) -> bool: return i != mine)[0] as ItemInstance
	Shop._take(s, one)
	t.eq(s.refresh_reason(), UiText.t("shop.refresh_table"), "秤上有东西：不能换")
	s.cancel_table()
	var poor := Wallet.new(s.refresh_price() - 1)
	s.wallet = poor
	t.eq(s.refresh_reason(), UiText.t("shop.refresh_poor"), "钱不够：不能换")
	s.wallet = wallet
	var cash := wallet.balance
	t.check(s.refresh(), "换了")
	t.eq(wallet.balance, cash - s.refresh_price(), "扣了 %d" % s.refresh_price())
	t.eq(s.purse, purse, "商人的钱袋不动")
	t.check(s.board.has_item(mine.uid) and s.board.get_item(mine.uid).origin == at, "卖进来的原位不动")
	var survivors := stock_before.filter(func(uid: int) -> bool: return s.board.has_item(uid))
	t.eq(survivors.size(), 0, "原来的货都换掉了")
	t.check(s.board.items().size() > 1, "摆上了新货")
	t.eq(s.refresh_reason(), UiText.t("shop.refresh_used"), "一家一次")
	t.check(not s.refresh(), "再换不了")
	var layout := _ids_at(s.board)
	var again := Shop._shop(db, wallet, node)
	again.refreshes = 1
	t.eq(again.refreshed, 1, "离店读档：次数还在")
	t.eq(_ids_at(again.board), layout, "读回来还是换过的那批")
	t.check(again.board.get_item(mine.uid) != null and again.board.get_item(mine.uid).state.has(ShopSession.SOLD_IN_KEY), "记号跟着存档")
	# 同一局同一家店刷出来一样
	var node2 := Shop._node(9)
	var s2 := Shop._shop(db, Wallet.new(500), node2)
	s2.refreshes = 1
	var s3 := Shop._shop(db, Wallet.new(500), Shop._node(9))
	s3.refreshes = 1
	s2.refresh()
	s3.refresh()
	t.eq(_ids_at(s2.board), _ids_at(s3.board), "同一个种子换出来同一批")


static func run_shop_refresh_atomic(t: TestCase) -> void:
	t.begin("319 · 换货失败一样都不改：棋盘摆满了卖进来的东西、新货摆不上 → 不收钱、不记次数、原来的货原位放回")
	var db := Shop._items()
	var wallet := Wallet.new(500)
	var r := Shop._rules(0)     # 货量 0：开张空摊、刷新也抽不出新货
	var s := Shop._shop(db, wallet, Shop._node(3), r)
	s.refreshes = 1
	var old := ItemInstance.create(db.get_def(&"knife"))
	s.board.try_add(old)
	s._commit_owned()
	var at := old.origin
	var cash := wallet.balance
	t.check(not s.refresh(), "摆不出新货：失败")
	t.eq(wallet.balance, cash, "没收钱")
	t.eq(s.refreshed, 0, "没记次数")
	t.check(s.board.has_item(old.uid) and old.origin == at, "原来的货原位放回")


static func _ids_at(board: GridInventory) -> Array:
	var out: Array = []
	for v in board.items():
		var inst := v as ItemInstance
		out.append([String(inst.def.id), inst.origin])
	out.sort_custom(func(a, b): return str(a) < str(b))
	return out


static func run_shop_refresh_keeps_bag_bullion(t: TestCase) -> void:
	t.begin("319 · 换货不动包和金银那一格（测试 v6.22 回归：大银锭换完没了）")
	var db := Shop._items()
	var r := Shop._rules()
	r.bullion_slot_chance = 1.0
	var s := Shop._shop(db, Wallet.new(500), Shop._node(9), r)
	s.refreshes = 1
	var gold: ItemInstance = null
	for v in s.board.items():
		if (v as ItemInstance).def.is_bullion():
			gold = v
	t.not_null(gold, "开张有一件金银")
	if gold == null:
		return
	var at := gold.origin
	t.check(s.refresh(), "换了")
	t.check(s.board.has_item(gold.uid) and gold.origin == at, "金银原位还在")
	var bag := ItemInstance.create(db.get_def(&"bag_leather"))
	var s2 := Shop._shop(db, Wallet.new(500), Shop._node(4))
	s2.refreshes = 1
	t.check(s2.board.try_add(bag), "摊上摆一个包")
	s2._commit_owned()
	t.check(s2.refresh(), "换了")
	t.check(s2.board.has_item(bag.uid), "包还在")
