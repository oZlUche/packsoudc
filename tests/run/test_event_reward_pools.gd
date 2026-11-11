## 事件方案 2026-11-11 §8.4：主题奖励池 —— 有放回、永不抽空；权重 = 基础 × 深度 × 难度；结果按事件实例冻结在节点内容里，
## 重进、读档、换选项不重抽；钱买和材料换共用一份；没有合格候选时选项灰掉、不扣代价；锁定 / 独一的不被事件拿走（§2.6）；导入器校验
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["events", "node_rules"])


static func _pool(rows: Array) -> RewardPool:
	var p := RewardPool.new()
	p.id = &"t_pool"
	for r in rows:
		var e := RewardPoolEntry.new()
		e.item = StringName(String(r[0]))
		e.weight = float(r[1])
		if r.size() > 2:
			for k in (r[2] as Dictionary):
				if k == "chapters":
					e.chapters.assign(r[2][k])
				else:
					e.set(k, r[2][k])
		p.entries.append(e)
	return p


static func run_draw_rules(t: TestCase) -> void:
	t.begin("奖励池 · 有放回：单候选抽 50 次 50 件都是它；概率按 基础 × 深度 × 难度 归一化；最浅深度、章节、道具库筛候选；没候选抽空数组")
	var c := _content()
	var one := _pool([["ration", 1.0]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var got := one.draw(c.items, &"free_mode", 0.0, 0, rng, 50)
	t.eq(got.size(), 50, "抽数大于候选数照样足额")
	t.check(got.all(func(id): return id == &"ration"), "全是那一件（不删候选）")
	var p := _pool([["ration", 3.0], ["salve", 1.0, {"deep_mult": 3.0, "hard_mult": 2.0}], ["steel_ingot", 1.0, {"min_depth": 0.5}], ["no_such_item", 5.0]])
	var shallow := p.probabilities(c.items, &"free_mode", 0.0, 0)
	t.eq(shallow.keys().size(), 2, "浅处：太深的那件、道具库里没有的不进候选")
	t.check(absf(float(shallow[&"ration"]) - 0.75) < 0.0001, "3 : 1")
	var deep := p.probabilities(c.items, &"free_mode", 1.0, 1)
	# ration 3；salve 1 × 3（深度 1）× 2（难度 1）= 6；steel 1
	t.check(absf(float(deep[&"salve"]) - 0.6) < 0.0001, "深度、难度倍率乘上去：6 / 10")
	t.check(absf(float(deep[&"steel_ingot"]) - 0.1) < 0.0001, "够深了进候选")
	var ch := _pool([["ration", 1.0, {"chapters": [&"clockwork_hourglass"]}]])
	t.eq(ch.draw(c.items, &"free_mode", 0.0, 0, rng, 3).size(), 0, "章节不对：抽不出东西（空，不是报错）")
	t.eq(ch.draw(c.items, &"clockwork_hourglass", 0.0, 0, rng, 3).size(), 3, "对的章节抽得出")
	# 同一种子同一结果；配置在抽样前后不变
	var before := JSON.stringify(p.probabilities(c.items, &"free_mode", 0.6, 2))
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	t.eq(p.draw(c.items, &"free_mode", 0.6, 2, r1, 2000), p.draw(c.items, &"free_mode", 0.6, 2, r2, 2000), "同种子同结果")
	t.eq(JSON.stringify(p.probabilities(c.items, &"free_mode", 0.6, 2)), before, "抽 2000 次后池子的概率一点没变（不记库存）")


static func run_sampling(t: TestCase) -> void:
	t.begin("奖励池 · 真实池抽 10,000 次：每件的命中率落在理论概率 ±4 个标准差里；池的配置摘要抽前抽后相同")
	var c := _content()
	var pools := RewardPool.load_all()
	t.check(pools.has(&"medicine"), "药品池导进来了")
	var p: RewardPool = pools.get(&"medicine", null)
	if p == null:
		return
	var digest := var_to_str(p.entries.map(func(e): return [e.item, e.weight, e.deep_mult, e.hard_mult, e.min_depth, e.chapters]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	var n := 10000
	var hits := {}
	for id in p.draw(c.items, &"free_mode", 0.5, 1, rng, n):
		hits[id] = int(hits.get(id, 0)) + 1
	var probs := p.probabilities(c.items, &"free_mode", 0.5, 1)
	var bad: Array = []
	for id in probs:
		var q := float(probs[id])
		var sd := sqrt(q * (1.0 - q) / float(n))
		var obs := float(hits.get(id, 0)) / float(n)
		if absf(obs - q) > 4.0 * sd + 0.0001:
			bad.append("%s 理论 %.3f 实际 %.3f" % [id, q, obs])
	t.eq(bad, [], "没有偏离理论概率的")
	t.eq(hits.keys().size(), probs.keys().size(), "每个合格候选都抽到过、没抽到不合格的")
	var after := var_to_str(p.entries.map(func(e): return [e.item, e.weight, e.deep_mult, e.hard_mult, e.min_depth, e.chapters]))
	t.eq(after, digest, "配置摘要不变")


## 出生点旁边的事件点挂上 [param def]
static func _run_with(c: TestSupport.Content, def: EventDef, seed_from: int = 1) -> Dictionary:
	for seed_ in range(seed_from, seed_from + 80):
		var s := RunState.start(c.chapter, seed_, c.items, c.enemies, c.sets, [&"bag_leather", &"shortsword", &"knife"] as Array[StringName])
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == &"event":
					s.event_defs = c.events.duplicate()
					s.event_defs[def.id] = def
					s.pick_spawn(entry)
					s.map.get_node(nid).content["event"] = String(def.id)
					return {"run": s, "next": nid}
	return {}


static func _herbalist() -> EventDef:
	var def := EventDef.new()
	def.id = &"t_herbalist"
	def.title = "药摊"
	var buy := EventOption.new()
	buy.label = "买{reward_name}（{reward_price}）"
	var afford := CanAfford.new()
	afford.reward_key = &"med"
	buy.requires = [afford] as Array[EventCondition]
	var pay := ChangeMoney.new()
	pay.reward_key = &"med"
	var give := GivePoolItem.new()
	give.pool = &"medicine"
	give.key = &"med"
	var say := Say.new()
	say.text = "他把{reward_name}放到你面前。"
	buy.outcomes = [pay, give, say] as Array[EventOutcome]
	var swap := EventOption.new()
	swap.label = "用草药换{reward_name}"
	var has := HasItem.new()
	has.item = &"dried_herbs"
	has.count = 2
	has.takeable = true
	swap.requires = [has] as Array[EventCondition]
	var lose := LoseItem.new()
	lose.item = &"dried_herbs"
	lose.count = 2
	var give2 := GivePoolItem.new()
	give2.pool = &"medicine"
	give2.key = &"med"
	swap.outcomes = [lose, give2] as Array[EventOutcome]
	var leave := EventOption.new()
	leave.label = "不买"
	def.options = [buy, swap, leave] as Array[EventOption]
	return def


static func run_freeze_and_trade(t: TestCase) -> void:
	t.begin("奖励冻结 · 挂起时抽好写进节点内容；读档后同一件；钱买按冻结那件的定价扣、给的就是预览的那件；材料换给同一件；锁定的草药不算数")
	var c := _content()
	var def := _herbalist()
	var f := _run_with(c, def)
	t.check(not f.is_empty(), "找得到出生点旁边的事件点")
	if f.is_empty():
		return
	var s: RunState = f["run"]
	var n := int(f["next"])
	s.wallet.earn(500, &"test")
	s.step_to(n)
	t.eq(String(s.events.pending_event().id), "t_herbalist", "停在药摊")
	var node := s.map.get_node(n)
	var frozen := EventRewards.frozen(node, &"med")
	t.eq(frozen.size(), 1, "挂起时就抽好了一件")
	var med: StringName = frozen[0] if not frozen.is_empty() else &""
	t.check(RewardPool.load_all()[&"medicine"].entries.any(func(e): return e.item == med), "抽的是药品池里的")
	var params := EventRewards.params(node, def.options[0], c.items)
	var price := ShopSession.price_for(c.items.get_def(med), null) if med != &"" else 0
	t.eq(int(params.get("reward_price", -1)), maxi(1, ItemValue.of(c.items.get_def(med))) if med != &"" else -1, "{reward_price} = 那件的定价 × 1")
	t.check(String(params.get("reward_name", "")).contains(Names.of(c.items.get_def(med))) if med != &"" else false, "{reward_name} 是那件的名字")
	t.check(price > 0, "定价是正的")
	# 读档：同一件，不重抽
	var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.eq(EventRewards.frozen(back.map.get_node(n), &"med"), frozen, "读档回来还是那一件")
	# 再冻一次（重进同一屏）也不变
	back.events.set_pending(back.map.get_node(n), def, &"event")
	t.eq(EventRewards.frozen(back.map.get_node(n), &"med"), frozen, "重新挂起不重抽")
	# 钱买
	var money0 := s.wallet.balance
	var resolved: Array = []
	s.events.event_resolved.connect(func(_n: MapNode, _o: StringName, got_d: Dictionary): resolved.append(got_d))
	t.check(bool(s.events.option_state(0)["ok"]), "钱够：能买")
	t.check(not bool(s.events.option_state(1)["ok"]), "没有草药：换不了")
	s.events.choose(0)
	t.eq(s.wallet.balance, money0 - EventRewards.price_of(node, def.options[0].outcomes[0], c.items), "扣的是预览的价")
	var d: Dictionary = resolved[0] if not resolved.is_empty() else {}
	t.eq(d.get("items", []), [String(med)], "给的就是预览的那件")
	t.check(String((d.get("log", [""]) as Array)[0]).contains("{item:%s}" % med), "结果那句里的 {reward_name} 换成了那件")
	# 材料换：同一件；锁定的草药不算
	var f2 := _run_with(c, def)
	var s2: RunState = f2["run"]
	var n2 := int(f2["next"])
	s2.step_to(n2)
	var herbs: Array[ItemInstance] = []
	for i in 2:
		var inst := ItemInstance.create(c.items.get_def(&"dried_herbs"), 0)
		s2.storage.admit(inst)     # 地上（走过来以后再放：离开一个点时地上的会清掉）
		herbs.append(inst)
	herbs[0].set_locked(true)
	t.check(not bool(s2.events.option_state(1)["ok"]), "一束锁着：可拿走的只有一束，换不了")
	herbs[0].set_locked(false)
	t.check(bool(s2.events.option_state(1)["ok"]), "解锁后能换")
	var want := EventRewards.frozen(s2.map.get_node(n2), &"med")
	var got2: Array = []
	s2.events.event_resolved.connect(func(_n: MapNode, _o: StringName, dd: Dictionary): got2.append(dd))
	s2.events.choose(1)
	t.eq((got2[0] as Dictionary).get("items", []), want.map(func(x): return String(x)), "材料换给的是同一份")
	t.eq(s2.events._event_ctx(s2.map.get_node(n2)).count_item(&"dried_herbs"), 0, "两束草药交掉了")


static func run_empty_pool_blocks(t: TestCase) -> void:
	t.begin("奖励池 · 没有合格候选：冻结的是空的，选项灰掉、写原因，选了也不扣代价")
	var c := _content()
	var def := EventDef.new()
	def.id = &"t_empty"
	def.title = "空"
	var opt := EventOption.new()
	opt.label = "拆"
	var wait := PassTime.new()
	var give := GivePoolItem.new()
	give.pool = &"no_such_pool"
	opt.outcomes = [wait, give] as Array[EventOutcome]
	var leave := EventOption.new()
	leave.label = "走"
	def.options = [opt, leave] as Array[EventOption]
	var f := _run_with(c, def)
	if f.is_empty():
		return
	var s: RunState = f["run"]
	s.step_to(int(f["next"]))
	var st := s.events.option_state(0)
	t.check(not bool(st["ok"]), "灰掉")
	t.eq(String(st["why"]), UiText.t("cond.reward_empty"), "写了原因")
	var clock := s.travel.clock.total
	t.check(not s.events.choose(0), "选不了")
	t.eq(s.travel.clock.total, clock, "没耗时间")
	t.check(bool(s.events.option_state(1)["ok"]), "离开照样能走")


static func run_takeable(t: TestCase) -> void:
	t.begin("§2.6 · 事件拿得走的：锁定、独一、包不拿；最值钱那档跳过锁定的；没开 takeable 的 has_item 照旧算锁定的（教程门禁不受影响）")
	var c := _content()
	var ctx := EventContext.new()
	var ground := GridInventory.new(Vector2i(10, 10))
	ctx.storage = ground
	var axe := ItemInstance.create(c.items.get_def(&"steel_axe"), 0)
	var knife := ItemInstance.create(c.items.get_def(&"knife"), 0)
	ground.admit(axe)
	ground.admit(knife)
	axe.set_locked(true)
	var has := HasItem.new()
	has.item = &"steel_axe"
	t.check(has.check(ctx), "普通 has_item：锁着也算有")
	has.takeable = true
	t.check(not has.check(ctx), "takeable：锁着的不算")
	var lose := LoseItem.new()
	lose.pick = LoseItem.Pick.MOST_VALUABLE
	lose.where = LoseItem.Where.STORAGE
	lose.apply(ctx)
	t.check(ground.items().has(axe), "锁着的钢斧还在")
	t.check(not ground.items().has(knife), "拿走的是没锁的匕首")
	t.check(not EventContext.takeable(ItemInstance.create(c.items.get_def(&"bag_leather"), 0)), "包默认不拿")
	t.check(EventContext.takeable(ItemInstance.create(c.items.get_def(&"bag_leather"), 0), true), "include_bags 时包可以拿")


static func run_importer(t: TestCase) -> void:
	t.begin("导入器 · 奖励池：空池、权重 ≤ 0、负倍率、深度越界、找不到 / 包 / 金银 / 独一的道具都报错；事件引用不存在的池、按奖励定价却没有那份奖励、失去道具没有 takeable 挡着都报错")
	var c := _content()
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.register_item(c.items.get_def(id))
	var bad := ImportReport.new()
	ContentImporter.import_reward_pool({"id": "t", "entries": [
		{"item": "ration", "weight": 0.0}, {"item": "nope", "weight": 1.0}, {"item": "bag_leather", "weight": 1.0},
		{"item": "gold_bar", "weight": 1.0}, {"item": "chana", "weight": 1.0}, {"item": "salve", "weight": 1.0, "deep_mult": -1.0, "min_depth": 2.0}]}, ctx, bad)
	t.eq(bad.errors.size(), 7, "七处错：权重、找不到、包、金银、独一、负倍率、深度越界")
	var empty := ImportReport.new()
	ContentImporter.import_reward_pool({"id": "e", "entries": []}, ctx, empty)
	t.check(not empty.errors.is_empty(), "空池报错")
	var good := ImportReport.new()
	ContentImporter.import_reward_pool({"id": "ok", "entries": [{"item": "ration", "weight": 1.0}]}, ctx, good)
	t.eq(good.errors.size(), 0, "合法的池不报错")
	var ev := ImportReport.new()
	ContentImporter.import_event({"id": "t_ev", "title": "t", "options": [
		{"label": "a", "outcomes": [{"type": "give_pool_item", "pool": "nope"}]},
		{"label": "b", "outcomes": [{"type": "change_money", "reward_key": "missing"}]},
		{"label": "c", "requires": [{"type": "has_item", "item": "rope_coil"}], "outcomes": [{"type": "lose_item", "item": "rope_coil"}]},
		{"label": "d", "requires": [{"type": "has_item", "item": "rope_coil", "takeable": true}], "outcomes": [{"type": "lose_item", "item": "rope_coil"}, {"type": "give_pool_item", "pool": "ok"}]},
		{"label": "走"}]}, ctx, ev)
	t.eq(ev.errors.size(), 3, "三处错：不存在的池、没有那份奖励、失去道具没有 takeable；d 合法")
