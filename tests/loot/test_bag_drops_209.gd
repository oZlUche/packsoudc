## 209（作者 21:30 夜间六条之三，待定按推荐）：掉落两段 —— 先照旧掷「掉哪些东西」（身上的包不再必掉），
## 再按包池掷「用哪些包装它们」；敌人开战背的包也从包池抽；商店一个包槽
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode")


static func _pool() -> BagPool:
	return load(ContentPaths.asset_file("bag_pools", "standard"))


static func _rolled(ids: Array) -> Dictionary:
	var out: Array[StringName] = []
	for id in ids:
		out.append(StringName(id))
	return {"dropped": out, "treasure": [] as Array[StringName]}


static func run_pool(t: TestCase) -> void:
	t.begin("209 · ⑥ 包池：导得进；章节默认引用 standard，序章不掷包；行都是包")
	var c := _content()
	var pool := _pool()
	t.not_null(pool, "standard 包池在")
	if pool == null:
		return
	t.eq(pool.entries.size(), 14, "十四个包")
	for e in pool.entries:
		t.check(c.items.get_def(e.bag) != null and c.items.get_def(e.bag).is_bag and e.weight > 0.0, "%s 是包、权重 > 0" % e.bag)
	t.eq(c.chapter.bag_pool, &"standard", "第一章用 standard")
	t.eq(c.prologue.bag_pool, &"", "序章不掷包")
	var bad := ImportReport.new()
	var ctx := ContentImporter.Context.new()
	ctx.items = {&"knife": c.items.get_def(&"knife")}
	ContentImporter.import_bag_pool({"id": "t", "entries": [{"bag": "knife", "weight": 1.0}, {"bag": "nope", "weight": 0.0}]}, ctx, bad)
	t.check(bad.to_text().contains("不是包") and bad.to_text().contains("找不到") and bad.to_text().contains("权重"), "校验：不是包、找不到、权重（%s）" % bad.to_text())


static func run_roll_bags(t: TestCase) -> void:
	t.begin("209 · ⑦ 第二段：掉 10 格东西、fill_target 0.8 → 容量够 13 格或到上限才停；一件没掉不掉包；敌人自己的包更常出现")
	var c := _content()
	var pool := _pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# iron_ore 2 格 × 5 = 10 格
	var rolled := _rolled(["iron_ore", "iron_ore", "iron_ore", "iron_ore", "iron_ore"])
	for i in 50:
		var bags := DropResolver.roll_bags(rolled, {}, pool, -1, c.items, rng)
		var room := 0
		for b in bags:
			room += c.items.get_def(b).cell_count()
		t.check(bags.size() >= 1 and bags.size() <= pool.max_bags, "第 %d 次：1～%d 个包（%s）" % [i, pool.max_bags, bags])
		var stopped_early := bags.size() < pool.max_bags and room < 13
		t.check(room >= 13 or bags.size() == pool.max_bags or stopped_early, "第 %d 次：容量 %d" % [i, room])
	t.eq(DropResolver.roll_bags(_rolled([]), {}, pool, -1, c.items, rng), [] as Array[StringName], "一件没掉：不掉包")
	var capped := 0
	for i in 100:
		for b in DropResolver.roll_bags(rolled, {}, pool, 1, c.items, rng):
			capped = maxi(capped, c.items.get_def(b).rarity)
	t.check(capped <= 1, "稀有度上限 1：抽不到蓝包以上")
	# 敌人自己背着长条包：200 次里它出现得比没背时多
	var own := {"items": [{"id": "bag_long", "at": [0, 0], "rot": 0}]}
	var with_own := 0
	var without := 0
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	for i in 200:
		with_own += DropResolver.roll_bags(rolled, own, pool, -1, c.items, r1).count(&"bag_long")
		without += DropResolver.roll_bags(rolled, {}, pool, -1, c.items, r2).count(&"bag_long")
	t.check(with_own > without, "自己的包权重 ×2：%d > %d" % [with_own, without])


static func run_two_stage(t: TestCase) -> void:
	t.begin("209 · ⑧ 两段：标准规则下身上的包不进第一段；guaranteed_drops 里的包仍掉；尸体里东西优先在包里")
	var c := _content()
	var rule: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	var content := {"enemy": "raider", "strength": 1, "board": [6, 4],
		"items": [{"id": "bag_leather", "at": [0, 0], "rot": 0}, {"id": "knife", "at": [0, 0], "rot": 0}, {"id": "salve", "at": [1, 0], "rot": 0}]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 20:
		var got: Array = DropResolver.roll(content, rule, LootContext.new(), c.items, rng)["dropped"]
		t.check(not got.has(&"bag_leather"), "第 %d 次：身上的包不在第一段" % i)
	var g := content.duplicate(true)
	g["guaranteed_drops"] = ["bag_leather"]
	t.check((DropResolver.roll(g, rule, LootContext.new(), c.items, rng)["dropped"] as Array).has(&"bag_leather"), "写进 guaranteed_drops 的包照掉")
	var rolled := _rolled(["knife", "salve"])
	rolled["bags"] = [&"bag_leather"] as Array[StringName]
	var corpse := DropResolver.corpse_of(content, rolled, c.items)
	t.check(corpse.requires_bag, "有包：尸体按包摆")
	var knife_in := false
	for inst in corpse.items():
		var it := inst as ItemInstance
		if it.def.id == &"knife":
			knife_in = corpse.bag_of(it.uid) != GridInventory.EMPTY_UID
			t.eq(it.origin, Vector2i(0, 0), "自己的包掉了：东西回原位")
	t.check(knife_in, "匕首在包里")
	var none := DropResolver.corpse_of(content, _rolled(["knife"]), c.items)
	t.check(not none.requires_bag, "没有包：自由容器")


static func run_enemy_bags(t: TestCase) -> void:
	t.begin("209 · ⑨ 敌人开战：标准池按 bag_count 抽包、稀有度不超档位上限、挑好的东西都摆得下；神射手照旧写死的包")
	var c := _content()
	var pool := _pool()
	for strength in 4:
		var tier := c.pool.tier_of(strength)
		for seed in 8:
			var rng := RandomNumberGenerator.new()
			rng.seed = 100 * strength + seed
			var built := EnemyPlacer.build_content(c.enemies.enemy(&"raider"), c.pool, c.items, strength, rng, null, pool)
			var bags: Array = (built["content"]["items"] as Array).filter(func(e): return c.items.get_def(StringName(String(e["id"]))).is_bag)
			t.check(bags.size() >= tier.bag_count.x, "%d 档种子 %d：至少 %d 个包（%d）" % [strength, seed, tier.bag_count.x, bags.size()])
			for e in bags:
				var d := c.items.get_def(StringName(String(e["id"])))
				t.check(tier.rarity_cap < 0 or d.rarity <= tier.rarity_cap, "%d 档：%s 稀有度不超上限" % [strength, d.id])
			t.eq(int(built["dropped"]), 0, "%d 档种子 %d：件数凑够" % [strength, seed])
	var mk := c.enemies.enemy(&"marksman")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var ids: Array = (EnemyPlacer.build_content(mk, c.pool, c.items, mk.strength, rng2, null, pool)["content"]["items"] as Array) \
		.filter(func(e): return c.items.get_def(StringName(String(e["id"]))).is_bag).map(func(e): return StringName(String(e["id"])))
	ids.sort()
	var want: Array = mk.bags.duplicate()
	want.sort()
	t.eq(ids, want, "神射手：写死的包")


static func run_shop(t: TestCase) -> void:
	t.begin("209 · ⑩ 商店：包槽概率 1 → 必有一格是包；0 → 没有；没有包池 → 没有")
	var c := _content()
	var econ: EconomyRules = (load(ContentPaths.asset_file("economy_rules", "standard")) as EconomyRules).duplicate()
	var node := MapNode.new()
	node.content_seed = 17
	var w := Wallet.new()
	econ.shop_bag_slot_chance = 1.0
	var s1 := ShopSession.new(node, econ, c.items, w, 0.0, 1.0, _pool())
	t.eq(s1.stock.filter(func(e): return c.items.get_def(StringName(String(e["id"]))).is_bag).size(), 1, "概率 1：一格是包")
	t.eq(s1.stock.size(), econ.shop_slots, "格数不变")
	econ.shop_bag_slot_chance = 0.0
	var s0 := ShopSession.new(node, econ, c.items, w, 0.0, 1.0, _pool())
	t.eq(s0.stock.filter(func(e): return c.items.get_def(StringName(String(e["id"]))).is_bag).size(), 0, "概率 0：没有包")
	econ.shop_bag_slot_chance = 1.0
	var sn := ShopSession.new(node, econ, c.items, w)
	t.eq(sn.stock.filter(func(e): return c.items.get_def(StringName(String(e["id"]))).is_bag).size(), 0, "没有包池：没有包")


static func run_bagless(t: TestCase) -> void:
	t.begin("209 · ⑪ 魔兽（212）与机关（210）不掉包；人照常掷；没有包池不掷")
	var c := _content()
	var cw := TestSupport.load_content("clockwork_hourglass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var rolled := _rolled(["iron_ore", "iron_ore"])
	t.eq(DropResolver.bags_for(rolled, {"enemy": "flame_wolf", "strength": 1}, c.enemies, c.pool, _pool(), c.items, rng), [] as Array[StringName], "焰狼：不掉包")
	t.eq(DropResolver.bags_for(rolled, {"enemy": "gear_golem", "strength": 2}, cw.enemies, cw.pool, _pool(), c.items, rng), [] as Array[StringName], "齿轮傀儡：不掉包")
	t.check(not DropResolver.bags_for(rolled, {"enemy": "raider", "strength": 1}, c.enemies, c.pool, _pool(), c.items, rng).is_empty(), "掠夺者：掷包")
	t.eq(DropResolver.bags_for(rolled, {"enemy": "raider", "strength": 1}, c.enemies, c.pool, null, c.items, rng), [] as Array[StringName], "没有包池：不掷")
