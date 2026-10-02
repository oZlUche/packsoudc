## 侵蚀本体（5.7，069 第 5 步，报告 075）：时间表、预警、逐层向内、绝不封路、效果构件的四道门、三种效果、存档、难度装进一局。
## 期望从数据推：机制里写了第几步开始就断言第几步。
extends RefCounted

const SAVE := "user://test_erosion_run.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var difficulties: Array[DifficultyDef]


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.difficulties = GameFlow.load_difficulties()
	return c


## 一份只开侵蚀的难度，参数由用例给
static func _difficulty(first: int, interval: int, warn: int, effects: Array) -> DifficultyDef:
	var d := DifficultyDef.new()
	d.id = &"probe_erosion"
	var m := ErosionMechanic.new()
	m.first_at_action = first
	m.interval_actions = interval
	m.warn_lead_actions = warn
	for e in effects:
		m.effects.append(e)
	d.mechanics.append(m)
	return d


static func _start(c: Content, diff: DifficultyDef, kit: Array[StringName] = [&"bag_leather", &"rifle", &"pistol"] as Array[StringName]) -> RunState:
	for seed in range(1, 40):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit, {}, [] as Array[StringName], null, [], diff)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


static func _field(s: RunState) -> ErosionField:
	return s.travel.erosion as ErosionField


## 走一步（挑第一个能走的），走完关掉会话、跳过事件
static func _step(s: RunState) -> bool:
	if s.is_over():
		return false
	if not s.events.pending.is_empty():
		s.events.choose(0)
	var moves := s.travel.available_moves()
	if moves.is_empty():
		return false
	var ok := s.step_to(moves[0])
	s.close_sessions()
	return ok


static func _max_band(s: RunState) -> int:
	var m := 0
	for id in s.map.node_ids():
		m = maxi(m, s.map.get_node(id).erosion_band)
	return m


static func run_schedule(t: TestCase) -> void:
	t.begin("侵蚀 · 时间表：第 first 行动点开始、每 interval 推进一层、提前 warn 预警一次；逐层向内直到终局；绝不封路")
	var c := _content()
	var s := _start(c, _difficulty(3, 2, 1, []))
	t.not_null(s, "开局")
	if s == null:
		return
	var f := _field(s)
	t.not_null(f, "难度装了侵蚀场到 travel.erosion")
	t.check(s.mechanic_tags.has(&"erosion"), "留了记号")
	t.eq(f.eroded_bands, -1, "还没开始")
	t.check(not f.started() and not f.is_total(), "既没开始也没终局")
	t.eq(f.max_band, _max_band(s), "最内一档 = 图上最大的 erosion_band（%d）" % f.max_band)
	var warns: Array = []
	var advances: Array = []
	s.erosion_warned.connect(func(band: int, left: int): warns.append([band, left]))
	s.erosion_advanced.connect(func(bands: int): advances.append(bands))
	# 逐步走，按行动点检查
	var guard := 0
	while not f.is_total() and guard < 60 and _step(s):
		guard += 1
		var total := s.travel.clock.total
		var expected := -1 if total < 3 else (total - 3) / 2
		expected = mini(expected, f.max_band)
		t.eq(f.eroded_bands, expected, "第 %d 行动点：侵蚀了 %d 档" % [total, expected])
		# 绝不封路：每个点都还能走到（可走的点集合只由图决定）
		t.check(not s.travel.available_moves().is_empty() or s.is_over(), "还有路可走")
	t.check(f.is_total() or s.is_over() or guard >= 60, "走到终局（或一局结束）")
	t.check(advances.size() >= 1, "推进发过信号（%d 次）" % advances.size())
	for i in range(1, advances.size()):
		t.eq(int(advances[i]), int(advances[i - 1]) + 1, "每次推进一层")
	t.check(warns.size() >= 1, "预警发过（%d 次）" % warns.size())
	for w in warns:
		t.check(int(w[1]) >= 1 and int(w[1]) <= 1, "预警时距推进 %d 步（提前量 1）" % int(w[1]))
	var seen_bands := {}
	for w in warns:
		t.check(not seen_bands.has(w[0]), "每一档只预警一次")
		seen_bands[w[0]] = true
	# is_eroded / depth_of 按带
	if f.started():
		for id in s.map.node_ids():
			var n := s.map.get_node(id)
			t.eq(f.is_eroded(n), n.erosion_band <= f.eroded_bands, "点 %d（带 %d）被侵蚀了没" % [id, n.erosion_band])
			if f.is_eroded(n):
				t.eq(f.depth_of(n), f.eroded_bands - n.erosion_band, "深度 = 侵蚀档数 - 带")
			else:
				t.eq(f.depth_of(n), -1, "没被侵蚀深度 -1")
	# 没有难度 = 没有侵蚀
	var plain := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets)
	t.is_null(plain.travel.erosion, "普通难度没有侵蚀")


static func run_gates_and_effects(t: TestCase) -> void:
	t.begin("侵蚀 · 效果的四道门（开关 / 起始层 / 仅终局 / 概率）都不写死；扣体力随深度递增、损坏最值钱的一件、丢钱")
	var c := _content()
	var ctx := ErosionContext.new()
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = 1
	var e := ErodeSpendVitality.new()
	t.check(e.applies(ctx), "默认：开、第 0 层起、不限终局、概率 1 → 生效")
	e.enabled = false
	t.check(not e.applies(ctx), "关了不生效")
	e.enabled = true
	e.from_depth = 2
	ctx.depth = 1
	t.check(not e.applies(ctx), "深度不够不生效")
	ctx.depth = 2
	t.check(e.applies(ctx), "到了起始层生效")
	e.only_total = true
	t.check(not e.applies(ctx), "仅终局：没终局不生效")
	ctx.total = true
	t.check(e.applies(ctx), "终局了生效")
	e.only_total = false
	e.chance = 0.0
	t.check(not e.applies(ctx), "概率 0 不生效")
	e.chance = 0.5
	var hits := 0
	for i in 400:
		if e.applies(ctx):
			hits += 1
	t.check(hits > 120 and hits < 280, "概率 0.5：400 次里生效 %d 次" % hits)
	t.check(e.gate_text().contains("50%") and e.gate_text().contains("第 2 层起"), "门写在 describe 里：%s" % e.describe())

	# 三种效果对着一局做事
	var s := _start(c, _difficulty(1, 1, 1, []))
	t.not_null(s, "开局")
	if s == null:
		return
	ctx = ErosionContext.new()
	ctx.run = s
	ctx.rng = RandomNumberGenerator.new()
	ctx.depth = 2
	var sv := ErodeSpendVitality.new()
	sv.amount = 1
	sv.per_depth = 1
	var v := s.vitality.current
	sv.apply(ctx)
	t.eq(s.vitality.current, v - 3, "扣体力 1 + 1×深度 2 = 3")
	t.eq(ctx.vitality_spent, 3, "账上记了 3")

	var most: ItemDef = null
	for inst in s.board.items():
		var d := (inst as ItemInstance).def
		if not d.is_bag and (most == null or ItemValue.of(d) > ItemValue.of(most)):
			most = d
	t.not_null(most, "棋盘上有非包道具")
	var count := s.board.item_count()
	var di := ErodeDamageItem.new()
	di.apply(ctx)
	t.eq(s.board.item_count(), count - 1, "损坏了一件")
	t.eq(ctx.items_lost, [most.display_name], "是最值钱的那件（%s）" % most.display_name)
	var bags := 0
	for inst in s.board.items():
		if (inst as ItemInstance).def.is_bag:
			bags += 1
	t.check(bags > 0, "包没被选中（默认不含包）")
	var storage_before := s.storage.item_count()
	s.storage.admit(ItemInstance.create(c.items.get_def(&"ration"), 0))
	var ds := ErodeDamageItem.new()
	ds.target = ErodeDamageItem.Target.STORAGE
	ds.pick = ErodeDamageItem.Pick.RANDOM
	ds.apply(ctx)
	t.eq(s.storage.item_count(), storage_before, "暂存区那件被损坏了")

	var money := s.wallet.balance
	var dm := ErodeDrainMoney.new()
	dm.amount = 5
	dm.per_depth = 1
	dm.apply(ctx)
	t.eq(s.wallet.balance, maxi(0, money - 7), "丢钱 5 + 1×2 = 7（不超过余额）")
	t.check(ctx.happened(), "账上有东西")
	t.check(ctx.detail()["items"].size() == 2 and int(ctx.detail()["money"]) == money - s.wallet.balance, "detail 记全了")


static func run_settle_save_and_pipeline(t: TestCase) -> void:
	t.begin("侵蚀 · 走进被侵蚀的点才结算（顺序：推进在惩罚前）；跟着存档；难度文件里的侵蚀走管线、门都可调")
	var c := _content()
	var sv := ErodeSpendVitality.new()
	sv.amount = 1
	var diff := _difficulty(1, 100, 1, [sv])     # 第 1 行动点起最外一档被侵蚀，之后很久不推进
	var s := _start(c, diff)
	t.not_null(s, "开局")
	if s == null:
		return
	var f := _field(s)
	var applied: Array = []
	s.erosion_applied.connect(func(node: MapNode, detail: Dictionary): applied.append([node.id, detail]))
	var v := s.vitality.current
	t.check(_step(s), "走一步")
	t.eq(f.eroded_bands, 0, "这一步推进了（在惩罚之前）")
	var here := s.current_node()
	if f.is_eroded(here):
		t.eq(s.vitality.current, v - 1, "走进被侵蚀的点：扣了 1（推进在惩罚之前，刚被侵蚀的点这一步就有代价）")
		t.eq(applied.size(), 1, "结算发了信号")
	else:
		t.eq(s.vitality.current, v, "没走进被侵蚀的点：不扣")
		t.eq(applied.size(), 0, "没结算")
	# 存档
	var d := s.to_dict()
	t.eq(int((d["erosion"] as Dictionary)["eroded_bands"]), f.eroded_bands, "存档记着侵蚀了几档")
	var s2 := RunState.from_dict(d, c.chapter, c.items, c.enemies, c.sets)
	t.is_null(s2.travel.erosion, "读回来先没有场（等机制装）")
	s2.difficulty = diff
	s2.install_modules()
	var f2 := _field(s2)
	t.not_null(f2, "装了机制就有")
	t.eq([f2.eroded_bands, f2.next_at_action], [f.eroded_bands, f.next_at_action], "状态读回来一样")
	s2.install_modules()
	t.eq(s2.travel.erosion, f2, "装两次幂等")

	# 作者数据：进阶难度的侵蚀机制带效果清单，门都在 JSON 里
	var hard: DifficultyDef = null
	for dd in c.difficulties:
		for m in dd.mechanics:
			if m is ErosionMechanic and not (m as ErosionMechanic).effects.is_empty():
				hard = dd
	t.not_null(hard, "作者数据里有一档带侵蚀效果的难度")
	if hard != null:
		var em: ErosionMechanic = null
		for m in hard.mechanics:
			if m is ErosionMechanic:
				em = m
		t.check(em.warn_lead_actions >= 1, "预警提前量 ≥ 1（导入器要求）")
		var text := ContentExporter.to_json(ContentExporter.export_difficulty(hard))
		var back := ContentImporter.import_difficulty(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
		t.eq(ContentExporter.to_json(ContentExporter.export_difficulty(back)), text, "带侵蚀效果的难度往返逐字节相同")
		var kinds := {}
		var any_gate := false
		for e in em.effects:
			kinds[ContentSchema.registry_name_of(e)] = true
			var ee := e as ErosionEffect
			if not ee.enabled or ee.from_depth > 0 or ee.only_total or ee.chance < 1.0:
				any_gate = true
		t.check(kinds.size() >= 2, "效果不止一种：%s" % str(kinds.keys()))
		t.check(any_gate, "有效果配了门（开关 / 起始层 / 仅终局 / 概率），都在数据里")
		t.check(em.describe().contains("侵蚀"), "describe：%s" % em.describe())
	var bad := ImportReport.new()
	ContentImporter.import_difficulty({"id": "x", "mechanics": [{"type": "erosion", "warn_lead_actions": 0}]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "不预警的侵蚀导不进（5.7 的硬约束）")
	var bad2 := ImportReport.new()
	ContentImporter.import_difficulty({"id": "x", "mechanics": [{"type": "erosion", "effects": [{"type": "spend_vitality", "chance": 1.5}]}]}, ContentImporter.Context.new(), bad2)
	t.check(not bad2.ok(), "概率超界导不进")
	var bad3 := ImportReport.new()
	ContentImporter.import_difficulty({"id": "x", "mechanics": [{"type": "erosion", "effects": [{"type": "no_such"}]}]}, ContentImporter.Context.new(), bad3)
	t.check(not bad3.ok(), "认不得的效果导不进")
