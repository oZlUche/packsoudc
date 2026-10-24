## 244（作者 2026-10-24）：金块 / 金条 —— 能进保险箱的钱。只有商店出（一次最多一格）、售价 = 面值 × 1.1 不吃任何倍率、
## 基地按面值全额回收、不算总分、不参战；「不参战」两处补正：不给也不受邻接、带回基地摘掉
extends RefCounted

const Economy := preload("res://tests/run/test_economy.gd")
const Grid := preload("res://tests/meta/test_meta_grid.gd")
const Comp := preload("res://tests/battle/test_compiler.gd")


static func _bullion_slots(s: ShopSession) -> int:
	var n := 0
	for slot in s.stock:
		var d := s.items.get_def(StringName(String(slot["id"])))
		if d != null and d.is_bullion():
			n += 1
	return n


static func run_items(t: TestCase) -> void:
	t.begin("244 · 金块一格、金条一乘二；只带「金银」：没有战斗、没有耐久、没有材料三标签")
	var items := Economy._items()
	for row in [[&"gold_nugget", 1, 60, 1], [&"gold_bar", 2, 150, 2]]:
		var d := items.get_def(row[0])
		t.not_null(d, "%s 在库里" % row[0])
		if d == null:
			continue
		t.eq(d.rarity, row[1], "%s 稀有度" % row[0])
		t.eq(ItemValue.of(d), row[2], "%s 面值" % row[0])
		t.eq(d.cell_count(), row[3], "%s 格数" % row[0])
		t.check(d.is_bullion() and d.tags.size() == 1, "%s 只带金银（%s）" % [row[0], d.tags])
		t.check(d.combat == null and d.wear == null and d.adjacency == null, "%s 不参战、不磨损" % row[0])
	t.check(TagRegistry.get_def(ItemDef.BULLION) != null and TagRegistry.category_of(ItemDef.BULLION) == "purpose", "金银标签登记过、归用途")


static func run_sources(t: TestCase) -> void:
	t.begin("244 · 只有商店出：商店权重池、搜索、敌人装备、赠礼都不含金银")
	var items := Economy._items()
	var rules := Economy._rules()
	t.check(not ShopSession.candidates(rules, items).any(func(id: StringName) -> bool: return items.get_def(id).is_bullion()), "商店权重池不含金银（另开一格）")
	var search := SearchRules.new()
	t.check(not SearchSession.candidates(search, items).any(func(id: StringName) -> bool: return items.get_def(id).is_bullion()), "搜索的候选不含金银")
	var pool := EnemyPlacer._item_pool(items, -1, null, func(_d: ItemDef) -> bool: return true)
	t.check(not pool.any(func(id: StringName) -> bool: return items.get_def(id).is_bullion()), "敌人装备的池不含金银")


static func run_shelf(t: TestCase) -> void:
	t.begin("244 · 商店：概率 1 每次恰一格金银、概率 0 没有；越深越多金条；同一家店刷出来的一样")
	var items := Economy._items()
	var rules := Economy._rules()
	rules.bullion_slot_chance = 1.0
	var exact := true
	var bars := [0, 0]
	for seed in 60:
		for k in 2:
			var s := ShopSession.new(Economy._shop_node(seed), rules, items, Wallet.new(0), float(k))
			if _bullion_slots(s) != 1 or s.stock.size() != rules.shop_slots:
				exact = false
			if String(s.stock[0]["id"]) == "gold_bar":
				bars[k] += 1
	t.check(exact, "概率 1：每次恰一格金银，货架格数不变")
	t.check(bars[1] > bars[0], "最内的金条比最外多（%d / %d，共 60 次）" % [bars[0], bars[1]])
	var again := ShopSession.new(Economy._shop_node(7), rules, items, Wallet.new(0), 0.5)
	t.eq(ShopSession.new(Economy._shop_node(7), rules, items, Wallet.new(0), 0.5).stock, again.stock, "同一家店同一次刷新摆的一样")
	rules.bullion_slot_chance = 0.0
	var none := true
	for seed in 30:
		if _bullion_slots(ShopSession.new(Economy._shop_node(seed), rules, items, Wallet.new(0), 0.5)) != 0:
			none = false
	t.check(none, "概率 0：没有金银")
	t.check(is_equal_approx(EconomyRules.new().bullion_bar_share(0.5), 0.5), "金条占比按深度插：中间五成")


static func run_prices(t: TestCase) -> void:
	t.begin("244 · 价钱：售价 = 面值 × 1.1，不随商店倍率与 buff 变；局内回购五成；基地回收按面值全额")
	var items := Economy._items()
	var nugget := items.get_def(&"gold_nugget")
	var bar := items.get_def(&"gold_bar")
	var rules := Economy._rules()
	rules.shop_price_mult = 2.0
	var cheap := ShopSession.new(Economy._shop_node(), rules, items, Wallet.new(0), 0.0, 0.5)
	var dear := ShopSession.new(Economy._shop_node(), rules, items, Wallet.new(0), 0.0, 3.0)
	t.eq(cheap.price_of(nugget), 66, "金块 60 × 1.1 = 66（打五折的 buff 不管用）")
	t.eq(dear.price_of(bar), 165, "金条 150 × 1.1 = 165（涨价的 buff 也不管用）")
	t.eq(cheap.sell_price_of(nugget), 33, "局内回购照常五成")
	t.eq(MetaState.sell_price(nugget, 0.5), 60, "基地回收：金块按面值")
	t.eq(MetaState.sell_price(bar, 0.2), 150, "基地回收：金条按面值，比例不生效")
	t.check(MetaState.sell_price(bar, 0.5) <= cheap.price_of(bar), "买价 ≥ 回收价：没有白来的钱")


static func run_score(t: TestCase) -> void:
	t.begin("244 · 结算：带出来的金银照样回仓库，但不算总分")
	var c := Grid._content()
	var s := Grid._extracted(c, 31, Grid._kit(c))
	var base := RunResult.settle(s).value
	var nugget := ItemInstance.create(c.items.get_def(&"gold_nugget"))
	t.check(s.board.try_add(nugget), "棋盘上放得下一块金块")
	var r := RunResult.settle(s)
	t.eq(r.value, base, "总分不变（%d）" % base)
	t.check(r.carried.any(func(i: ItemInstance) -> bool: return i.uid == nugget.uid), "金块在带回的东西里")


static func run_bench(t: TestCase) -> void:
	t.begin("244 · 不参战 = 不在场：受益的邻居标了不参战就不算点亮；带回基地摘掉标记")
	ItemInstance.reset_uid_counter()
	var lunch := Comp._weapon("t_lunch", ["1"], 10.0, 2.0)
	var lb := AdjacencyProfile.new()
	lb.receive_cells = [Vector2i(1, 0)] as Array[Vector2i]
	lb.receive_mods = [Comp._mod(BattleStats.DAMAGE, 0, 20.0)] as Array[StatModifier]
	lunch.adjacency = lb
	var dot := Comp._item("t_dot", ["1"])
	var board := GridInventory.new(Vector2i(4, 2), 1, false)
	var a := ItemInstance.create(lunch)
	var b := ItemInstance.create(dot)
	board.place(a, Vector2i(0, 0), 0)
	board.place(b, Vector2i(1, 0), 0)
	var dmg := func() -> int: return BattleCompiler.compile_board(board, CombatantBaseline.with_hp(25.0)).stats_of(a.uid).total_int_of(BattleStats.DAMAGE)
	t.eq(dmg.call(), 30, "邻居在场：受益一份 10 → 30")
	b.set_benched(true)
	t.eq(dmg.call(), 10, "邻居标了不参战：不算点亮")
	b.set_benched(false)

	var meta := MetaState.new()
	var inst := ItemInstance.create(dot)
	inst.set_benched(true)
	t.check(meta._adopt(inst), "收进局外")
	t.check(not inst.is_benched() and not inst.state.has(ItemInstance.BENCHED_KEY), "带回基地：不参战摘掉、不留键")
