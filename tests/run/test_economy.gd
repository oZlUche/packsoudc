## 经济（M4-5，架构文档 6.6）：钱包、打赢给多少、商店、付费撤离点、走管线。期望全从规则的数据推。
extends RefCounted


static func _ctx() -> ContentImporter.Context:
	return ContentImporter.Context.new()


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _chapter() -> ChapterDef:
	return load(ContentPaths.asset_file("chapters", "free_mode")) as ChapterDef


static func _rules() -> EconomyRules:
	var r := EconomyRules.new()
	r.id = &"t_econ"
	r.reward_base = 10
	r.reward_per_strength = 5
	r.reward_depth_gain = 1.0
	r.reward_difficulty_gain = 0.5
	r.shop_stock = 6
	r.paid_extracts = 1
	r.extract_fee = 50
	return r


static func _shop_node(p_seed: int = 5) -> MapNode:
	var n := MapNode.new()
	n.id = 1
	n.type = &"shop"
	n.content_seed = p_seed
	return n


static func run_wallet(t: TestCase) -> void:
	t.begin("经济 · 钱包：进账、花钱、不够一分不动、存档往返")

	var w := Wallet.new(10)
	var log_: Array = []
	w.changed.connect(func(b: int, d: int, r: StringName): log_.append([b, d, r]))
	t.eq(w.earn(5, &"battle"), 5, "进账 5")
	t.eq(w.balance, 15, "余额 15")
	t.eq(w.earn(-3), 0, "负数按 0")
	t.check(w.spend(15, &"shop"), "花 15")
	t.eq(w.balance, 0, "花光")
	t.check(not w.spend(1, &"shop"), "没钱花不了")
	t.eq(w.balance, 0, "一分不动")
	t.check(w.spend(0), "花 0 永远可以")
	t.check(not w.spend(-1), "花负数不行")
	t.eq(log_.size(), 2, "只有真变了才发信号（进 5、花 15）")
	t.eq(log_[1], [0, -15, &"shop"], "信号带余额、实际变化量、原因")
	t.eq(Wallet.from_dict(Wallet.new(42).to_dict()).balance, 42, "存档往返")
	t.eq(Wallet.new(-5).balance, 0, "负的起始按 0")


static func run_reward(t: TestCase) -> void:
	t.begin("经济 · 打赢给多少：档位、深度、难度各自往上推")

	var r := _rules()
	t.eq(r.battle_reward(0, 0.0, 0), r.reward_base, "最外、档位 0、难度 0 = 基础")
	t.eq(r.battle_reward(2, 0.0, 0), r.reward_base + 2 * r.reward_per_strength, "档位 2 加两份")
	t.eq(r.battle_reward(0, 1.0, 0), roundi(float(r.reward_base) * (1.0 + r.reward_depth_gain)), "最内乘 (1 + depth_gain)")
	t.eq(r.battle_reward(0, 0.0, 2), roundi(float(r.reward_base) * (1.0 + 2.0 * r.reward_difficulty_gain)), "难度 2 乘 (1 + 2 × difficulty_gain)")
	t.eq(r.battle_reward(1, 0.5, 1),
		roundi(float(r.reward_base + r.reward_per_strength) * (1.0 + 0.5 * r.reward_depth_gain) * (1.0 + r.reward_difficulty_gain)),
		"三者一起：按公式")
	t.check(r.battle_reward(3, 0.7, 1) >= r.battle_reward(2, 0.7, 1), "档位高的不少给")
	t.check(r.battle_reward(1, 0.9, 1) >= r.battle_reward(1, 0.2, 1), "深的不少给")
	t.check(r.battle_reward(1, 0.5, 3) >= r.battle_reward(1, 0.5, 0), "难的不少给")
	t.eq(r.battle_reward(-1, -1.0, -1), r.reward_base, "负的输入按 0")


static func run_paid_extracts(t: TestCase) -> void:
	t.begin("经济 · 付费撤离点：最深的那几个，费用来自规则，核心不算")

	var r := _rules()
	var g := MapGraph.new()
	for i in 6:
		var n := MapNode.new()
		n.id = i
		n.type = &"extract" if i < 4 else (&"core" if i == 4 else &"battle")
		n.tier = [1, 3, 3, 2, 9, 9][i]
		g.add_node(n)
	var paid := PaidExtracts.mark(g, r)
	t.eq(paid, [1] as Array[int], "只标了一个：最深（tier 3）里 id 小的那个")
	t.eq(PaidExtracts.fee_of(g.get_node(1)), r.extract_fee, "费用是规则里的数")
	t.eq(PaidExtracts.fee_of(g.get_node(2)), 0, "没标的免费")
	t.eq(PaidExtracts.fee_of(g.get_node(4)), 0, "核心不收")

	r.paid_extracts = 3
	var g2 := MapGraph.new()
	for i in 6:
		g2.add_node(MapNode.from_dict(g.get_node(i).to_dict()))
		g2.get_node(i).content = {}
	t.eq(PaidExtracts.mark(g2, r), [1, 2, 3] as Array[int], "标三个：按深度再按 id")
	r.paid_extracts = 10
	var g3 := MapGraph.new()
	for i in 6:
		g3.add_node(MapNode.from_dict(g.get_node(i).to_dict()))
		g3.get_node(i).content = {}
	t.eq(PaidExtracts.mark(g3, r).size(), 4, "要的比有的多：有几个标几个")
	r.paid_extracts = 0
	t.eq(PaidExtracts.mark(g3, r).size(), 0, "0 = 不收费")
	t.eq(PaidExtracts.mark(null, r).size(), 0, "没图不炸")

	# 第一章真图：正好一个、是 tier 最高的撤离点、跟着图存
	var chapter := _chapter()
	var rules: EconomyRules = load(ContentPaths.asset_file("economy_rules", String(chapter.economy_rules)))
	var real := chapter.map_source.resolve(1)
	var marked := PaidExtracts.mark(real, rules)
	t.eq(marked.size(), rules.paid_extracts, "第一章标了 paid_extracts 个")
	var best := -1
	for id in real.node_ids():
		if real.get_node(id).type == &"extract":
			best = maxi(best, real.get_node(id).tier)
	for id in marked:
		t.eq(real.get_node(id).tier, best, "标的是最深的撤离点")
	var back := MapGraph.from_dict(real.to_dict())
	t.eq(PaidExtracts.fee_of(back.get_node(marked[0])), rules.extract_fee, "费用跟着图存")


## 290：商店的买卖、开张、存档挪到 tests/run/test_shop_barter_290.gd


static func run_pipeline(t: TestCase) -> void:
	t.begin("经济 · 规则走管线：往返、校验、仓库文件、章节引用")

	var r := _rules()
	var text := ContentExporter.to_json(ContentExporter.export_economy_rules(r))
	var rep := ImportReport.new()
	var back := ContentImporter.import_economy_rules(JSON.parse_string(text), _ctx(), rep)
	t.check(rep.ok(), "导得回来：%s" % rep.to_text())
	t.eq(back.extract_fee, 50, "费用")
	t.eq(back.shop_rarity_weights, r.shop_rarity_weights, "权重表")
	t.eq(ContentExporter.to_json(ContentExporter.export_economy_rules(back)), text, "再导出逐字节相同")

	var base := ContentExporter.export_economy_rules(r)
	for bad in [["extract_fee", -1], ["shop_stock", 0], ["shop_purse_base", -1], ["shop_price_mult", 0.0], ["reward_depth_gain", -0.5], ["paid_extracts", -1]]:
		var d_ := base.duplicate(true)
		d_[bad[0]] = bad[1]
		rep = ImportReport.new()
		ContentImporter.import_economy_rules(d_, _ctx(), rep)
		t.check(not rep.ok(), "%s = %s → 错" % [bad[0], bad[1]])
	var noweight := base.duplicate(true)
	noweight["shop_rarity_weights"] = [0, 0]
	rep = ImportReport.new()
	ContentImporter.import_economy_rules(noweight, _ctx(), rep)
	t.check(not rep.ok(), "没有一档能上架 → 错")
	var typo := base.duplicate(true)
	typo["extract_fe"] = 1
	rep = ImportReport.new()
	ContentImporter.import_economy_rules(typo, _ctx(), rep)
	t.check(not rep.ok(), "打错字段名 → 错")

	var dir: String = ContentPaths.KINDS["economy_rules"][0]
	var d := DirAccess.open(dir)
	t.not_null(d, "有 %s" % dir)
	var ctx := _ctx()
	var count := 0
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			count += 1
			var id := f.get_basename()
			var file_text := FileAccess.get_file_as_string(dir + "/" + f)
			rep = ImportReport.new()
			var res := ContentImporter.import_economy_rules(JSON.parse_string(file_text), ctx, rep)
			t.check(rep.ok(), "economy_rules/%s 导得进：%s" % [id, rep.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_economy_rules(res)), file_text, "economy_rules/%s 是导出器的格式" % id)
			var asset := ContentPaths.asset_file("economy_rules", id)
			t.check(ResourceLoader.exists(asset), "有资产 %s" % asset)
			if ResourceLoader.exists(asset):
				t.eq(ContentExporter.export_economy_rules(load(asset)), ContentExporter.export_economy_rules(res), "资产与作者数据一致")
	t.check(count >= 1, "至少一份经济规则")

	var chapter := _chapter()
	t.check(chapter != null and chapter.economy_rules != &"", "第一章有经济规则")
	if chapter != null:
		t.check(ctx.economy_rules.has(chapter.economy_rules), "第一章的规则 '%s' 在仓库里" % chapter.economy_rules)
		var ch := ContentExporter.export_chapter(chapter)
		ch["economy_rules"] = "no_such"
		rep = ImportReport.new()
		ContentImporter.import_chapter(ch, ctx, rep)
		t.check(not rep.ok(), "章节指向不存在的经济规则 → 错")


static func run_events(t: TestCase) -> void:
	t.begin("经济 · 接进节点事件：打赢进账、商店开会话、付费撤离点先付钱")

	var items := _items()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var chapter := _chapter()
	var pool := enemies.pool(chapter.enemy_pool)
	var node_rules: NodeRules = load(ContentPaths.asset_file("node_rules", String(chapter.node_rules)))
	var economy: EconomyRules = load(ContentPaths.asset_file("economy_rules", String(chapter.economy_rules)))

	var g := MapGraph.new()
	var spawn := MapNode.new()
	spawn.id = 0
	spawn.type = &"spawn"
	g.add_node(spawn)
	var specs := {1: &"battle", 2: &"shop", 3: &"extract", 4: &"extract"}
	for id in specs:
		var n := MapNode.new()
		n.id = id
		n.type = specs[id]
		n.tier = 2 if id == 3 else 1
		n.content_seed = 4000 + id
		g.add_node(n)
		g.connect_nodes(0, id)
	EnemyPlacer.fill(g, pool, enemies, items, 0, &"")
	var paid := PaidExtracts.mark(g, economy)
	t.eq(paid, [3] as Array[int], "深的那个撤离点收费")

	var travel := MapTravel.new(g, ActionClock.new())
	travel.start_at(0)
	var wallet := Wallet.new(20)     # 256：经济规则不再有开局钱（钱全由玩家自己带）
	var events := NodeEvents.new(g)
	events.vitality = Vitality.new(5)
	events.rules = node_rules
	events.pool = pool
	events.enemies = enemies
	events.items = items
	events.wallet = wallet
	events.economy = economy
	events.difficulty = chapter.difficulty
	var board := GridInventory.new(Vector2i(8, 4), 0, false)
	for id in [&"longsword", &"shortsword", &"round_shield"]:
		board.try_add(ItemInstance.create(items.get_def(id), 0), true)
	var wealthy := CombatantBaseline.with_hp(10000.0)
	wealthy.base_stats["regen_stamina"] = 100.0     # 只验进账：别让耐力耗尽把这一场拖成平局
	var spec := BattleCompiler.compile_board(board, wealthy)
	events.hooks.register(&"player_spec", func() -> CombatantSpec: return spec)
	events.bind(travel)

	var rewards: Array = []
	events.rewarded.connect(func(n: MapNode, amount: int): rewards.append([n.id, amount]))
	var before := wallet.balance
	travel.step_to(1)
	t.eq(rewards.size(), 1, "打赢了进账")
	if not rewards.is_empty():
		var depth: float = EnemyPlacer.depths_of(g)[1]
		var want := economy.battle_reward(int(g.get_node(1).content["strength"]), depth, chapter.difficulty)
		t.eq(rewards[0][1], want, "进账 = 规则按档位、深度、难度算的")
		t.eq(wallet.balance, before + want, "钱包多了这么多")

	# 商店
	travel.step_to(0)
	var opened: Array = []
	events.shop_opened.connect(func(n: MapNode, s: ShopSession): opened.append([n.id, s]))
	var closed: Array = []
	events.shop_closed.connect(func(n: MapNode): closed.append(n.id))
	travel.step_to(2)
	t.eq(opened.size(), 1, "商店开门")
	if not opened.is_empty():
		var s: ShopSession = opened[0][1]
		t.not_null(s, "有会话")
		t.check(events.current_shop == s, "当前商店")
		t.check(not g.get_node(2).is_visited(), "还在店里：点没用过")
		var cash := wallet.balance
		var cheapest: ItemInstance = null
		for v in s.board.items():
			if cheapest == null or s.tag_price(v) < s.tag_price(cheapest):
				cheapest = v
		var bag := GridInventory.new(Vector2i(8, 8), 1, false)
		s.home_board = bag
		if cheapest != null and wallet.can_afford(s.tag_price(cheapest)):
			var price := s.tag_price(cheapest)
			s.board.remove(cheapest.uid)
			bag.try_add(cheapest, true)
			s.sync()
			s.toggle_my_coins()
			t.check(s.deal(), "买最便宜的那件")
			t.eq(wallet.balance, cash - price, "钱包扣了售价")
		s.leave()
		t.eq(closed, [2], "关门发信号")
		t.check(g.get_node(2).is_visited(), "走了才算用过")
		t.check(events.current_shop == null, "当前商店清了")

	# 撤离点：免费的直接过，付费的要钱
	travel.step_to(0)
	var reached: Array = []
	events.extract_reached.connect(func(n: MapNode, fee: int): reached.append([n.id, fee]))
	travel.step_to(4)
	t.eq(reached, [[4, 0]], "免费撤离点：fee 0")
	t.check(events.pay_extract_fee(g.get_node(4)), "免费的直接过")
	travel.step_to(0)
	travel.step_to(3)
	t.eq(reached.size(), 2, "到了付费撤离点")
	if reached.size() == 2:
		t.eq(reached[1], [3, economy.extract_fee], "带着费用")
	t.eq(events.extract_fee(g.get_node(3)), economy.extract_fee, "问得到费用")
	var rich := wallet.balance
	wallet.spend(rich, &"test")
	t.check(not events.pay_extract_fee(g.get_node(3)), "没钱付不了")
	wallet.earn(economy.extract_fee + 3, &"test")
	t.check(events.pay_extract_fee(g.get_node(3)), "钱够就付")
	t.eq(wallet.balance, 3, "扣了正好的费用")

	# 没有钱包：不算钱，别的照旧
	var g2 := MapGraph.new()
	var sp2 := MapNode.new()
	sp2.id = 0
	sp2.type = &"spawn"
	g2.add_node(sp2)
	var b2 := MapNode.new()
	b2.id = 1
	b2.type = &"battle"
	b2.content_seed = 4321
	g2.add_node(b2)
	g2.connect_nodes(0, 1)
	EnemyPlacer.fill(g2, pool, enemies, items, 0, &"")
	var t2 := MapTravel.new(g2, ActionClock.new())
	t2.start_at(0)
	var e2 := NodeEvents.new(g2)
	e2.rules = node_rules
	e2.pool = pool
	e2.enemies = enemies
	e2.items = items
	e2.hooks.register(&"player_spec", func() -> CombatantSpec: return spec)
	e2.bind(t2)
	var r2: Array = []
	e2.rewarded.connect(func(_n: MapNode, _a: int): r2.append(1))
	var f2: Array = []
	e2.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): f2.append(won))
	t2.step_to(1)
	t.eq(f2, [true], "没钱包照样打、照样赢")
	t.eq(r2.size(), 0, "没钱包就不进账")
