## 244（作者 2026-10-24）：金银 —— 能进保险箱的钱。只有商店出（一次最多一格）、售价 = 面值 × 1.1 不吃任何倍率、
## 基地按面值全额回收、不算总分、不参战；「不参战」两处补正：不给也不受邻接、带回基地摘掉。
## 补充一（08:15）：休眠的也不给不受邻接；不参战标记局内挪来挪去都在；贵重品一类 —— 金银三级六件、外环银内环金；宝石并入魔晶石
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


const BULLION := [
	[&"gold_nugget", 2, 200, 1], [&"gold_bar", 3, 480, 2], [&"gold_ingot", 3, 800, 3],
	[&"silver_nugget", 1, 80, 1], [&"silver_bar", 2, 190, 2], [&"silver_ingot_large", 2, 320, 3],
]
const GEMS := [&"fire_crystal", &"ice_crystal", &"lightning_crystal", &"quartz_cluster", &"raw_amber"]


static func run_items(t: TestCase) -> void:
	t.begin("244 补充一 · 金银六件三级：只带「贵重品」「金银」；没有战斗、没有耐久、没有材质标签")
	var items := Economy._items()
	for row in BULLION:
		var d := items.get_def(row[0])
		t.not_null(d, "%s 在库里" % row[0])
		if d == null:
			continue
		t.eq(d.rarity, row[1], "%s 稀有度" % row[0])
		t.eq(ItemValue.of(d), row[2], "%s 面值" % row[0])
		t.eq(d.cell_count(), row[3], "%s 格数" % row[0])
		t.check(d.is_bullion() and d.is_valuable() and d.tags.size() == 2, "%s 只带贵重品与金银（%s）" % [row[0], d.tags])
		t.check(d.combat == null and d.wear == null and d.adjacency == null, "%s 不参战、不磨损" % row[0])
	for tag in [ItemDef.BULLION, ItemDef.VALUABLE]:
		t.check(TagRegistry.get_def(tag) != null and TagRegistry.category_of(tag) == "purpose", "%s 标签登记过、归用途" % tag)
	t.eq(items.get_def(&"silver_ingot").cell_count(), 1, "老的银锭（一格材料）不动")


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
	t.begin("244 补充一 · 商店：概率 1 每次恰一格金银、概率 0 没有；外环只出银与金块、内环只出金与大银锭；同一家店刷出来的一样")
	var items := Economy._items()
	var rules := Economy._rules()
	rules.bullion_slot_chance = 1.0
	var exact := true
	var seen := [{}, {}]
	for seed in 80:
		for k in 2:
			var s := ShopSession.new(Economy._shop_node(seed), rules, items, Wallet.new(0), float(k))
			if _bullion_slots(s) != 1 or s.stock.size() != rules.shop_slots:
				exact = false
			seen[k][String(s.stock[0]["id"])] = true
	t.check(exact, "概率 1：每次恰一格金银，货架格数不变")
	var shallow: Array = seen[0].keys()
	var deep: Array = seen[1].keys()
	shallow.sort()
	deep.sort()
	t.eq(shallow, ["gold_nugget", "silver_bar", "silver_ingot_large", "silver_nugget"], "外环：银三件与金块")
	t.eq(deep, ["gold_bar", "gold_ingot", "gold_nugget", "silver_ingot_large"], "内环：金三件与大银锭")
	var mid := rules.bullion_weights(0.5)
	t.check(is_equal_approx(float(mid[&"gold_nugget"]), 1.0) and is_equal_approx(float(mid[&"silver_nugget"]), 0.5) and is_equal_approx(float(mid[&"gold_ingot"]), 0.5),
		"中间按深度线性混合（%s）" % mid)
	var again := ShopSession.new(Economy._shop_node(7), rules, items, Wallet.new(0), 0.5)
	t.eq(ShopSession.new(Economy._shop_node(7), rules, items, Wallet.new(0), 0.5).stock, again.stock, "同一家店同一次刷新摆的一样")
	rules.bullion_slot_chance = 0.0
	var none := true
	for seed in 30:
		if _bullion_slots(ShopSession.new(Economy._shop_node(seed), rules, items, Wallet.new(0), 0.5)) != 0:
			none = false
	t.check(none, "概率 0：没有金银")


static func run_prices(t: TestCase) -> void:
	t.begin("244 · 价钱：售价 = 面值 × 1.1，不随商店倍率与 buff 变；局内回购五成；基地回收贵重品按面值全额")
	var items := Economy._items()
	var nugget := items.get_def(&"gold_nugget")
	var bar := items.get_def(&"gold_bar")
	var rules := Economy._rules()
	rules.shop_price_mult = 2.0
	var cheap := ShopSession.new(Economy._shop_node(), rules, items, Wallet.new(0), 0.0, 0.5)
	var dear := ShopSession.new(Economy._shop_node(), rules, items, Wallet.new(0), 0.0, 3.0)
	t.eq(cheap.price_of(nugget), 220, "金块 200 × 1.1 = 220（打五折的 buff 不管用）")
	t.eq(dear.price_of(bar), 528, "金条 480 × 1.1 = 528（涨价的 buff 也不管用）")
	t.eq(cheap.sell_price_of(nugget), 110, "局内回购照常五成")
	t.eq(MetaState.sell_price(nugget, 0.5), 200, "基地回收：金块按面值")
	t.eq(MetaState.sell_price(bar, 0.2), 480, "基地回收：金条按面值，比例不生效")
	t.eq(MetaState.sell_price(items.get_def(&"fire_crystal"), 0.5), 150, "补充一：魔晶石也是贵重品，按面值")
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

	var other := GridInventory.new(Vector2i(4, 2), 1, false)
	board.remove(b.uid)
	other.place(b, Vector2i(0, 0), 0)
	t.check(b.is_benched(), "补充一：从棋盘拿出来、放到别处（地上、保险箱同理），标记还在")
	other.remove(b.uid)
	board.place(b, Vector2i(1, 0), 0)
	b.set_benched(false)

	# 补充一：休眠 = 不存在。邻居是信仰道具、棋盘上没有激活它的信物 → 休眠；留着通用效果的自己照打
	var relic := Comp._weapon("t_relic", ["1"], 4.0, 2.0, ["faith", "faith:sun"])
	var c := ItemInstance.create(relic)
	board.remove(b.uid)
	board.place(c, Vector2i(1, 0), 0)
	var spec := BattleCompiler.compile_board(board, CombatantBaseline.with_hp(25.0))
	t.eq(spec.stats_of(a.uid).total_int_of(BattleStats.DAMAGE), 10, "休眠的邻居：不算点亮")
	t.not_null(spec.item_of(c.uid), "休眠的件自己还参战（dormant_keeps_combat）")

	var meta := MetaState.new()
	var inst := ItemInstance.create(dot)
	inst.set_benched(true)
	t.check(meta._adopt(inst), "收进局外")
	t.check(not inst.is_benched() and not inst.state.has(ItemInstance.BENCHED_KEY), "带回基地：不参战摘掉、不留键")


static func run_gems(t: TestCase) -> void:
	t.begin("244 补充一 · 宝石并入魔晶石：五件都是【魔法】不是【自然】、稀有、贵重品；供给 +9、能用四场；清明魔晶石 / 琥珀魔晶哪把法杖都吃")
	var items := Economy._items()
	for id in GEMS:
		var d := items.get_def(id)
		t.check(d.tags.has(&"magic") and d.tags.has(&"crystal") and d.is_valuable() and not d.tags.has(&"nature"), "%s：魔法、晶石、贵重品，没有自然（%s）" % [id, d.tags])
		t.eq(d.rarity, 2, "%s 稀有" % id)
		t.check(d.adjacency != null and d.adjacency.has_feed() and is_equal_approx((d.adjacency.feed_mods[0] as StatModifier).amount, 9.0), "%s 供给 +9" % id)
		t.eq(d.wear.max_charges if d.wear != null else -1, 4, "%s 能供给四场" % id)
	t.eq(ItemValue.of(items.get_def(&"quartz_cluster")), 320, "清明魔晶石 320")
	t.eq(ItemValue.of(items.get_def(&"crystal_shards")), 30, "碎晶 30")
	t.check(items.get_def(&"quartz_cluster").adjacency.feed_rules.is_empty(), "清明魔晶石不带属性")
	ItemInstance.reset_uid_counter()
	var staff := ItemInstance.create(items.get_def(&"magic_staff"))
	var board := GridInventory.new(Vector2i(6, 3), 1, false)
	board.place(staff, Vector2i(1, 0), 0)
	var amber := ItemInstance.create(items.get_def(&"raw_amber"))
	t.check(board.place(amber, Vector2i(0, 0), 0), "琥珀魔晶放进法杖的装载格")
	var quartz := ItemInstance.create(items.get_def(&"quartz_cluster"))
	t.check(board.place(quartz, Vector2i(2, 0), 0), "清明魔晶石放进另一边的装载格")
	var loads := BattleCompiler.load_assignments(board)
	t.check(int(loads.get(amber.uid, -1)) == staff.uid and int(loads.get(quartz.uid, -1)) == staff.uid, "两块都供给法杖（%s）" % loads)
	t.eq(BattleCompiler.compile_board(board, CombatantBaseline.with_hp(25.0)).fed_uids.size(), 2, "这一场两块都算供给了")
