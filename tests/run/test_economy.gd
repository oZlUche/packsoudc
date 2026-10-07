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
	r.starting_balance = 30
	r.reward_base = 10
	r.reward_per_strength = 5
	r.reward_depth_gain = 1.0
	r.reward_difficulty_gain = 0.5
	r.shop_slots = 3
	r.shop_refresh_cost = 10
	r.shop_refresh_step = 5
	r.paid_extracts = 1
	r.extract_fee = 50
	return r


static func _shop_node(seed: int = 5) -> MapNode:
	var n := MapNode.new()
	n.id = 1
	n.type = &"shop"
	n.content_seed = seed
	return n


static func run_wallet(t: TestCase) -> void:
	t.begin("经济 · 钱包：进账、花钱、不够一分不动、存档往返")

	var w := Wallet.new(10)
	var log: Array = []
	w.changed.connect(func(b: int, d: int, r: StringName): log.append([b, d, r]))
	t.eq(w.earn(5, &"battle"), 5, "进账 5")
	t.eq(w.balance, 15, "余额 15")
	t.eq(w.earn(-3), 0, "负数按 0")
	t.check(w.spend(15, &"shop"), "花 15")
	t.eq(w.balance, 0, "花光")
	t.check(not w.spend(1, &"shop"), "没钱花不了")
	t.eq(w.balance, 0, "一分不动")
	t.check(w.spend(0), "花 0 永远可以")
	t.check(not w.spend(-1), "花负数不行")
	t.eq(log.size(), 2, "只有真变了才发信号（进 5、花 15）")
	t.eq(log[1], [0, -15, &"shop"], "信号带余额、实际变化量、原因")
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


static func run_shop(t: TestCase) -> void:
	t.begin("经济 · 商店：随机稀有度的货架、价 = 价值 × 倍数、买了就没了、刷新花钱且越刷越贵、同种子同货")

	var items := _items()
	var r := _rules()
	var wallet := Wallet.new(1000)
	var node := _shop_node()
	var s := ShopSession.new(node, r, items, wallet, 0.3)
	t.eq(s.stock.size(), r.shop_slots, "摆了 shop_slots 件")
	t.eq(s.available().size(), r.shop_slots, "全在架上")
	var cands := ShopSession.candidates(r, items)
	var seen := {}
	for i in s.stock.size():
		var id := StringName(String(s.stock[i]["id"]))
		t.check(cands.has(id), "'%s' 能上架" % id)
		t.check(not seen.has(id), "'%s' 不重复" % id)
		seen[id] = true
		var def := items.get_def(id)
		t.check(not def.is_bag, "不卖包")
		for tag in r.shop_exclude_tags:
			t.check(not def.tags.has(tag), "不卖带 %s 的" % tag)
		t.eq(int(s.stock[i]["price"]), maxi(1, roundi(float(ItemValue.of(def)) * r.shop_price_mult)), "价 = 价值 × 倍数")

	# 买
	var bought: Array = []
	s.bought.connect(func(def: ItemDef, price: int, inst: ItemInstance): bought.append([def.id, price, inst]))
	# 087：栏位是小棋盘，商品按真实尺寸摆在 (0,0)
	t.eq(s.shelves.size(), r.shop_slots, "每格一块栏位棋盘")
	for i in s.shelves.size():
		var grid: GridInventory = s.shelves[i]
		var def := items.get_def(StringName(String(s.stock[i]["id"])))
		var size := def.shape.size_rotated(0)
		t.check(grid.size.x >= ShopSession.SLOT_MIN.x and grid.size.y >= ShopSession.SLOT_MIN.y and grid.size.x >= size.x and grid.size.y >= size.y, "栏位至少 3×4、装得下商品")
		var inst := s.item_at(i)
		t.check(inst != null and inst.def == def and inst.origin == Vector2i.ZERO and s.slot_of(inst.uid) == i, "第 %d 格摆着商品" % i)
	var price0 := int(s.stock[0]["price"])
	var shelf_inst := s.item_at(0)
	var got := s.buy(0)
	t.not_null(got, "买到了")
	t.eq(wallet.balance, 1000 - price0, "扣了标价")
	t.eq(bought.size(), 1, "发了 bought")
	t.check(not bought.is_empty() and bought[0][2] == shelf_inst and s.item_at(0) == null, "交出来的就是栏位上那件，栏位空了")
	t.check(not s.can_buy(0) and s.buy(0) == null, "同一格买不了第二次")
	t.eq(s.available().size(), r.shop_slots - 1, "架上少一件")
	t.eq(str(node.content["shop"]["sold"]), "[0]", "卖掉的格子记进节点内容")

	# 087：拖着买 —— 拖拽层先把商品挪走，再 pay_for 结账
	var slot1_inst := s.item_at(1)
	var price1 := int(s.stock[1]["price"])
	s.shelves[1].remove(slot1_inst.uid)     # 拖拽层做的事
	var before_pay := wallet.balance
	t.check(s.pay_for(1), "结账")
	t.eq(wallet.balance, before_pay - price1, "扣了标价")
	t.check(s.sold.has(1) and not s.can_buy(1) and not s.pay_for(1), "记成卖掉了，不能再结一次")
	t.check(bought.size() == 2 and bought[1][2] == null, "拖着买的 bought 里 inst 为 null（东西已经在玩家手里）")
	# 087：卖 —— 回定价的一半
	var sword := ItemInstance.create(items.get_def(&"longsword"))
	t.check(s.sell_box.place(sword, Vector2i.ZERO, 0), "拖进出售区")
	var sold_sig: Array = []
	s.sold_item.connect(func(def: ItemDef, gain: int): sold_sig.append([def.id, gain]))
	var before_sell := wallet.balance
	var gain := s.sell(sword)
	t.eq(gain, floori(float(s.price_of(sword.def)) * r.shop_sell_ratio), "得定价 × 出售比例")
	t.eq(gain, s.sell_price_of(sword.def), "= sell_price_of")
	t.eq(wallet.balance, before_sell + gain, "进账")
	t.check(not s.sell_box.has_item(sword.uid), "出售区清了")
	t.eq(sold_sig.size(), 1, "发了 sold_item")

	# 钱不够
	var poor := Wallet.new(0)
	var sp := ShopSession.new(_shop_node(), r, items, poor, 0.3)
	t.check(not sp.can_buy(0) and sp.buy(0) == null, "没钱买不了")
	t.check(not sp.pay_for(0), "拖着买也结不了账")
	t.eq(poor.balance, 0, "一分不动")
	t.check(not sp.can_refresh() and not sp.refresh(), "没钱刷不了")

	# 刷新
	t.eq(s.refresh_cost(), r.refresh_cost_at(0), "第一次刷新的价")
	var changed: Array = []
	s.stock_changed.connect(func(): changed.append(1))
	var before := wallet.balance
	var old_ids := s.stock.duplicate(true)
	t.check(s.refresh(), "刷得动")
	t.eq(wallet.balance, before - r.refresh_cost_at(0), "扣了刷新费")
	t.eq(s.refreshes, 1, "刷了一次")
	t.eq(s.refresh_cost(), r.refresh_cost_at(1), "第二次更贵（step %d）" % r.shop_refresh_step)
	t.check(s.refresh_cost() > r.refresh_cost_at(0) or r.shop_refresh_step == 0, "越刷越贵")
	t.eq(changed.size(), 1, "发了 stock_changed")
	t.eq(s.available().size(), r.shop_slots, "刷新后满架，卖掉的格子清了")
	t.check(s.item_at(0) != null and s.item_at(1) != null, "刷新后栏位重新摆满")
	t.check(s.stock != old_ids, "货换了")
	t.eq(int(node.content["shop"]["refreshes"]), 1, "刷新次数记进节点内容")

	# 同种子同货；读档接着来
	var s2 := ShopSession.new(_shop_node(), r, items, Wallet.new(0), 0.3)
	t.eq(s2.stock, old_ids, "同一个点第 0 次的货架永远一样")
	var s3 := ShopSession.new(node, r, items, Wallet.new(0), 0.3)
	t.eq(s3.refreshes, 1, "读档：刷新过一次")
	t.eq(s3.stock, s.stock, "读档：货架就是刷新后那一批")

	# 深度把稀有度往上推
	var sum_out := 0.0
	var sum_in := 0.0
	var n := 0
	for seed in 300:
		for slot in ShopSession.new(_shop_node(seed), r, items, Wallet.new(0), 0.0).stock:
			sum_out += items.get_def(StringName(String(slot["id"]))).rarity
			n += 1
	var m := 0
	for seed in 300:
		for slot in ShopSession.new(_shop_node(seed), r, items, Wallet.new(0), 1.0).stock:
			sum_in += items.get_def(StringName(String(slot["id"]))).rarity
			m += 1
	if r.shop_depth_gain > 0.0:
		t.check(sum_in / m > sum_out / n, "最内的货架（平均稀有度 %.2f）比最外（%.2f）好" % [sum_in / m, sum_out / n])

	# 关门
	var closed: Array = []
	s.closed.connect(func(): closed.append(1))
	s.leave()
	s.leave()
	t.eq(closed.size(), 1, "关门只发一次")
	t.check(not s.can_buy(1) and not s.can_refresh(), "关了门买不了刷不了")


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
	for bad in [["extract_fee", -1], ["shop_slots", 0], ["shop_price_mult", 0.0], ["reward_depth_gain", -0.5], ["paid_extracts", -1]]:
		var d := base.duplicate(true)
		d[bad[0]] = bad[1]
		rep = ImportReport.new()
		ContentImporter.import_economy_rules(d, _ctx(), rep)
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
	var wallet := Wallet.new(economy.starting_balance)
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
	for id in [&"sniper", &"rifle", &"pistol", &"armor"]:
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
		var cheapest := -1
		for i in s.available():
			if cheapest < 0 or int(s.stock[i]["price"]) < int(s.stock[cheapest]["price"]):
				cheapest = i
		if cheapest >= 0 and s.can_buy(cheapest):
			t.not_null(s.buy(cheapest), "买最便宜的那件")
			t.eq(wallet.balance, cash - int(s.stock[cheapest]["price"]), "钱包扣了标价")
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


static func run_shop_rollback(t: TestCase) -> void:
	t.begin("经济 · 商店 · 拖走了就结账，结不成放回架上（101 第 6 刀：这条规则原来写在商店屏里）")
	var items := _items()
	var r := _rules()
	var node := _shop_node()
	# 钱刚好够第 0 格，第 1 格买不起
	var s0 := ShopSession.new(node, r, items, Wallet.new(100000), 0.3)
	var price0 := int(s0.stock[0]["price"])
	var wallet := Wallet.new(price0)
	var s := ShopSession.new(node, r, items, wallet, 0.3)
	t.eq(int(s.stock[0]["price"]), price0, "同种子同货：第 0 格还是那个价")
	var board := GridInventory.new(Vector2i(8, 8), 1, false)
	# 买得起的那一格：拖拽层先把东西挪进棋盘，结账成功
	var inst := s.item_at(0)
	t.not_null(inst, "第 0 格有货")
	s.shelves[0].remove(inst.uid)
	t.check(board.try_add(inst, true), "拖进棋盘")
	t.check(s.pay_or_return(0, inst.uid, [board]), "钱够：结账成功")
	t.eq(wallet.balance, 0, "钱花掉了")
	t.check(board.has_item(inst.uid) and s.item_at(0) == null, "东西留在棋盘上，架上空了")
	# 买不起的那一格：东西从棋盘拿回来、原样回到架上，钱不变
	var second := s.item_at(1)
	t.not_null(second, "第 1 格有货")
	if second == null:
		return
	s.shelves[1].remove(second.uid)
	t.check(board.try_add(second, true), "也拖进棋盘")
	t.check(not s.pay_or_return(1, second.uid, [board]), "钱不够：结不成")
	t.check(not board.has_item(second.uid), "从玩家那边拿回来了")
	t.check(s.item_at(1) != null and s.item_at(1).uid == second.uid, "原样回到第 1 格")
	t.eq(wallet.balance, 0, "钱没动")
	t.check(s.available().has(1), "第 1 格还在架上（没记成卖出）")
	# 地上的也找得回来（拖到棋盘外 = 地上，084）
	var stash := ItemStash.new(2, 0)
	var third := s.item_at(2)
	if third != null:
		s.shelves[2].remove(third.uid)
		stash.admit(third)
		t.check(not s.pay_or_return(2, third.uid, [board, stash]), "钱不够：结不成")
		t.check(not stash.has_item(third.uid) and s.item_at(2) != null, "从地上拿回来、回到架上")
