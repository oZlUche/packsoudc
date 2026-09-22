## 节点规则（M4-3 / M4-4，架构文档 5.4 / 6.2 / 7.1）：走管线、校验、随机点与事件的抽法。
extends RefCounted


static func _ctx() -> ContentImporter.Context:
	return ContentImporter.Context.new()


static func _chapter() -> ChapterDef:
	return load(ContentPaths.asset_file("chapters", "chapter_01")) as ChapterDef


static func _rules() -> NodeRules:
	var r := NodeRules.new()
	r.id = &"t_rules"
	r.random_weights = {"battle": 3, "search": 1}
	r.search = SearchRules.new()
	r.search.encounter_curve = [0.2, 0.4] as Array[float]
	r.search.items_per_search = Vector2i(1, 3)
	r.loss_cost = {"battle": 1, "elite": 2, "search": 1}
	return r


static func run_round_trip(t: TestCase) -> void:
	t.begin("节点规则 · 走管线，导出再导入逐字节一致")

	var rules := _rules()
	var dumped := ContentExporter.export_node_rules(rules)
	t.check(dumped.has("search") and (dumped["search"] as Dictionary).has("encounter_curve"), "嵌套的搜索规则导出了")
	var text := ContentExporter.to_json(dumped)
	var r := ImportReport.new()
	var back := ContentImporter.import_node_rules(JSON.parse_string(text), _ctx(), r)
	t.check(r.ok(), "导得回来：%s" % r.to_text())
	t.eq(back.random_weights, {"battle": 3, "search": 1}, "随机点权重（整数没变浮点）")
	t.eq(back.search.encounter_curve, rules.search.encounter_curve, "遭遇曲线")
	t.eq(back.search.items_per_search, Vector2i(1, 3), "Vector2i")
	t.eq(back.loss_cost, rules.loss_cost, "扣体力表")
	t.eq(ContentExporter.to_json(ContentExporter.export_node_rules(back)), text, "再导出逐字节相同")


static func run_validation(t: TestCase) -> void:
	t.begin("节点规则 · 校验比引擎严格")

	var base := ContentExporter.export_node_rules(_rules())

	var elite := base.duplicate(true)
	elite["random_weights"] = {"battle": 1, "elite": 1}
	var r := ImportReport.new()
	ContentImporter.import_node_rules(elite, _ctx(), r)
	t.check(not r.ok(), "随机点变成精英 → 错（5.4：不会变成精英或 BOSS）")

	var core := base.duplicate(true)
	core["loss_cost"] = {"battle": 1, "core": 5}
	r = ImportReport.new()
	ContentImporter.import_node_rules(core, _ctx(), r)
	t.check(not r.ok(), "给 core 配扣体力 → 错（BOSS 输了直接战败，7.1）")

	var down := base.duplicate(true)
	(down["search"] as Dictionary)["encounter_curve"] = [0.5, 0.2]
	r = ImportReport.new()
	ContentImporter.import_node_rules(down, _ctx(), r)
	t.check(not r.ok(), "遭遇概率递减 → 错（每搜一次该更险）")

	var over := base.duplicate(true)
	(over["search"] as Dictionary)["encounter_curve"] = [0.5, 1.2]
	r = ImportReport.new()
	ContentImporter.import_node_rules(over, _ctx(), r)
	t.check(not r.ok(), "概率 > 1 → 错")

	var no_search := base.duplicate(true)
	no_search.erase("search")
	r = ImportReport.new()
	ContentImporter.import_node_rules(no_search, _ctx(), r)
	t.check(not r.ok(), "没有搜索规则 → 错")

	var bad_event := base.duplicate(true)
	bad_event["event_weights"] = {"jackpot": 1}
	r = ImportReport.new()
	ContentImporter.import_node_rules(bad_event, _ctx(), r)
	t.check(not r.ok(), "认不得的事件结果 → 错")

	var neg := base.duplicate(true)
	neg["rest_restore"] = -1
	r = ImportReport.new()
	ContentImporter.import_node_rules(neg, _ctx(), r)
	t.check(not r.ok(), "回负的体力 → 错")

	var typo := base.duplicate(true)
	typo["rest_restor"] = 1
	r = ImportReport.new()
	ContentImporter.import_node_rules(typo, _ctx(), r)
	t.check(not r.ok(), "打错字段名 → 错")

	r = ImportReport.new()
	ContentImporter.import_node_rules(base, _ctx(), r)
	t.check(r.ok(), "合法的过：%s" % r.to_text())


static func run_authoring_file(t: TestCase) -> void:
	t.begin("节点规则 · 仓库文件导得进、与资产一致、第一章引用得到")

	var dir: String = ContentPaths.KINDS["node_rules"][0]
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
			var text := FileAccess.get_file_as_string(dir + "/" + f)
			var r := ImportReport.new()
			var res := ContentImporter.import_node_rules(JSON.parse_string(text), ctx, r)
			t.check(r.ok(), "node_rules/%s 导得进：%s" % [id, r.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_node_rules(res)), text, "node_rules/%s 是导出器的格式" % id)
			var asset := ContentPaths.asset_file("node_rules", id)
			t.check(ResourceLoader.exists(asset), "有资产 %s" % asset)
			if ResourceLoader.exists(asset):
				t.eq(ContentExporter.export_node_rules(load(asset)), ContentExporter.export_node_rules(res), "资产与作者数据一致")
	t.check(count >= 1, "至少一份节点规则")

	var chapter := _chapter()
	t.check(chapter != null and chapter.node_rules != &"", "第一章有节点规则")
	if chapter != null:
		t.check(ctx.node_rules.has(chapter.node_rules), "第一章的规则 '%s' 在仓库里" % chapter.node_rules)
		var ch := ContentExporter.export_chapter(chapter)
		ch["node_rules"] = "no_such"
		var r := ImportReport.new()
		ContentImporter.import_chapter(ch, ctx, r)
		t.check(not r.ok(), "章节指向不存在的节点规则 → 错")


static func run_picks(t: TestCase) -> void:
	t.begin("节点规则 · 随机点按权重变、只变成允许的类型；事件结果同理")

	var rules := _rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var tally := {}
	for i in 2000:
		var p := rules.random_pick(rng)
		if not tally.has(p):
			t.check(NodeRules.RANDOM_ALLOWED.has(p), "'%s' 是允许的类型" % p)
		tally[p] = int(tally.get(p, 0)) + 1
	var total := 0.0
	for k in rules.random_weights:
		total += float(rules.random_weights[k])
	for k in rules.random_weights:
		var want := float(rules.random_weights[k]) / total
		var got := float(tally.get(StringName(String(k)), 0)) / 2000.0
		t.check(absf(got - want) < 0.05, "'%s' 占 %.2f，权重说该是 %.2f" % [k, got, want])
	t.eq(tally.size(), rules.random_weights.size(), "只出现权重表里的类型")

	rules.random_weights = {"search": 0}
	t.eq(rules.random_pick(rng), &"battle", "权重全 0 退回 battle —— 随机点总得是点什么")

	var ev := {}
	for i in 300:
		ev[rules.event_pick(rng)] = true
	for k in ev:
		t.check(NodeRules.EVENT_OUTCOMES.has(k), "事件结果 '%s' 在清单里" % k)
	t.eq(ev.size(), 3, "三种结果都出现过")

	t.eq(rules.loss_cost_of(&"elite"), 2, "精英输了扣表里的数")
	t.eq(rules.loss_cost_of(&"core"), 0, "core 没配 → 0（反正它直接战败）")
