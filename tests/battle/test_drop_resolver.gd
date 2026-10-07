## 掉落（M4-2，架构文档 6.1）：每件各掷、越稀有越难掉、难度 / 幸运 / 效果各加各的、珍宝、尸体容器、走管线。
##
## 期望全从规则的数据推：改 JSON 里的概率，这里跟着变。
extends RefCounted


static func _ctx() -> ContentImporter.Context:
	return ContentImporter.Context.new()


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _chapter() -> ChapterDef:
	return load(ContentPaths.asset_file("chapters", "free_mode")) as ChapterDef


static func _rule() -> DropRule:
	var r := DropRule.new()
	r.id = &"t_rule"
	r.base_chance = [0.8, 0.6, 0.4, 0.2, 0.1] as Array[float]
	r.difficulty_bonus = 0.05
	r.luck_bonus = 0.02
	r.treasure_chance = 0.1
	r.treasure_weights = {"3": 3, "4": 1}
	return r


static func _item(id: StringName, rarity: int, tags: Array[StringName] = [] as Array[StringName], bits: String = "1") -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	d.display_name = String(id)
	d.rarity = rarity
	d.tags = tags
	d.shape = ItemShape.from_bits(bits)
	return d


## 一个小道具库：普通到传说各一件敌人背的，再加两档珍宝
static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	for r in 5:
		db.register(_item(StringName("own_%d" % r), r))
	db.register(_item(&"gold_a", 3, [&"treasure"] as Array[StringName]))
	db.register(_item(&"gold_b", 3, [&"treasure", &"weapon"] as Array[StringName]))
	db.register(_item(&"red_a", 4, [&"treasure"] as Array[StringName], "11\n11"))
	db.register(_item(&"not_treasure", 4))
	return db


static func _content(ids: Array) -> Dictionary:
	var items: Array = []
	for i in ids.size():
		items.append({"id": String(ids[i]), "at": [i, 0], "rot": 0})
	return {"enemy": "t", "strength": 0, "board": [6, 2], "items": items}


static func run_chance(t: TestCase) -> void:
	t.begin("掉落 · 每件的概率：基础按稀有度递减，难度 / 幸运 / 效果各加各的")

	var rule := _rule()
	var db := _db()
	var ctx := LootContext.new()
	for r in 5:
		var def := db.get_def(StringName("own_%d" % r))
		t.eq(DropResolver.owned_chance(rule, ctx, def), rule.base_chance[r], "稀有度 %d 裸概率 = 表里的值" % r)
		if r > 0:
			t.check(DropResolver.owned_chance(rule, ctx, def) <= DropResolver.owned_chance(rule, ctx, db.get_def(StringName("own_%d" % (r - 1)))),
				"稀有度 %d 不比 %d 好掉" % [r, r - 1])
	var d0 := db.get_def(&"own_0")
	var d2 := db.get_def(&"own_2")

	ctx.difficulty = 2
	t.check(absf(DropResolver.owned_chance(rule, ctx, d2) - (rule.base_chance[2] + 2 * rule.difficulty_bonus)) < 1e-9,
		"难度 2：加两份 difficulty_bonus")
	ctx.difficulty = -3
	t.eq(DropResolver.owned_chance(rule, ctx, d2), rule.base_chance[2], "难度为负不扣 —— 难度只是正面加成")
	ctx.difficulty = 0

	ctx.luck = 5
	t.check(absf(DropResolver.owned_chance(rule, ctx, d2) - (rule.base_chance[2] + 5 * rule.luck_bonus)) < 1e-9, "幸运 +5 加五份 luck_bonus")
	ctx.luck = -5
	t.check(absf(DropResolver.owned_chance(rule, ctx, d2) - (rule.base_chance[2] - 5 * rule.luck_bonus)) < 1e-9, "幸运 -5 减五份 —— 减益就是负的幸运")
	ctx.luck = 0

	var eff := DropOwnedChance.new()
	eff.percent = 15
	eff.modify(ctx)
	t.check(absf(DropResolver.owned_chance(rule, ctx, d2) - (rule.base_chance[2] + 0.15)) < 1e-6, "道具效果「敌人掉落自身道具 +15%」加进来")

	ctx = LootContext.new()
	ctx.luck = 100
	t.eq(DropResolver.owned_chance(rule, ctx, d0), 1.0, "封顶 1")
	ctx.luck = -100
	t.eq(DropResolver.owned_chance(rule, ctx, d0), 0.0, "封底 0")

	ctx = LootContext.new()
	ctx.difficulty = 1
	t.check(absf(DropResolver.treasure_chance(rule, ctx) - (rule.treasure_chance + rule.difficulty_bonus)) < 1e-9, "珍宝概率默认也吃难度")
	rule.treasure_modified = false
	t.eq(DropResolver.treasure_chance(rule, ctx), rule.treasure_chance, "treasure_modified 关掉就只有基础值")

	t.eq(DropResolver.owned_chance(rule, LootContext.new(), db.get_def(&"red_a")), rule.base_chance[4], "稀有度 4 按表的第五档")
	rule.base_chance = [0.5, 0.25] as Array[float]
	t.eq(DropResolver.owned_chance(rule, LootContext.new(), db.get_def(&"own_4")), 0.25, "表只有两档时稀有度 4 按最后一档")


static func run_roll(t: TestCase) -> void:
	t.begin("掉落 · 掷：只掉自己有的，同种子同结果，概率 0 / 1 两端")

	var rule := _rule()
	var db := _db()
	var content := _content([&"own_0", &"own_1", &"own_2", &"own_3", &"own_4"])
	var ctx := LootContext.new()

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var a := DropResolver.roll(content, rule, ctx, db, rng)
	rng.seed = 11
	var b := DropResolver.roll(content, rule, ctx, db, rng)
	t.eq(a["dropped"], b["dropped"], "同种子掉的一样")
	t.eq(a["treasure"], b["treasure"], "同种子珍宝一样")
	for id in a["dropped"]:
		t.check(DropResolver.carried_ids(content).has(id), "掉的 '%s' 是敌人自己有的" % id)

	rule.base_chance = [1.0, 1.0, 1.0, 1.0, 1.0] as Array[float]
	rule.treasure_chance = 0.0
	var all := DropResolver.roll(content, rule, ctx, db, rng)
	t.eq((all["dropped"] as Array).size(), 5, "概率全 1：五件全掉")
	t.eq((all["treasure"] as Array).size(), 0, "珍宝概率 0：没有珍宝")
	rule.base_chance = [0.0, 0.0, 0.0, 0.0, 0.0] as Array[float]
	var none := DropResolver.roll(content, rule, ctx, db, rng)
	t.eq((none["dropped"] as Array).size(), 0, "概率全 0：一件不掉")

	# 频率对得上概率：稀有度 0 按 0.8 掷一千次
	rule = _rule()
	var hits := 0
	var single := _content([&"own_0"])
	for i in 1000:
		if not (DropResolver.roll(single, rule, ctx, db, rng)["dropped"] as Array).is_empty():
			hits += 1
	t.check(hits > 740 and hits < 860, "概率 0.8 掷一千次掉了 %d 次" % hits)


static func run_treasure(t: TestCase) -> void:
	t.begin("掉落 · 珍宝：自身没有的、带珍宝标签的、只在表里的稀有度；没定义就记一笔不掉")

	var rule := _rule()
	rule.treasure_chance = 1.0
	rule.base_chance = [0.0, 0.0, 0.0, 0.0, 0.0] as Array[float]
	var db := _db()
	var ctx := LootContext.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var content := _content([&"own_0", &"gold_a"])
	var seen := {}
	var first := DropResolver.roll(content, rule, ctx, db, rng)
	t.eq((first["treasure"] as Array).size(), 1, "珍宝概率 1、一次尝试：正好一件")
	for i in 300:
		var r := DropResolver.roll(content, rule, ctx, db, rng)
		for id in r["treasure"]:
			if seen.has(id):
				continue
			seen[id] = true
			var def := db.get_def(id)
			t.check(def.tags.has(rule.treasure_tag), "珍宝 '%s' 带珍宝标签" % id)
			t.check(rule.treasure_rarities().has(def.rarity), "珍宝 '%s' 的稀有度在表里" % id)
			t.check(not DropResolver.carried_ids(content).has(id), "珍宝 '%s' 不是敌人自己有的" % id)
	t.check(not seen.has(&"gold_a"), "敌人自己背着的 gold_a 不当珍宝掉")
	t.check(not seen.has(&"not_treasure"), "没有珍宝标签的传说品不当珍宝掉")
	t.check(seen.has(&"gold_b") and seen.has(&"red_a"), "金、红两档都出现过（%s）" % str(seen.keys()))

	# 权重：金 3 红 1 → 红大约四分之一
	var red := 0
	for i in 1000:
		var r := DropResolver.roll(content, rule, ctx, db, rng)
		if (r["treasure"] as Array)[0] == &"red_a":
			red += 1
	t.check(red > 180 and red < 320, "金 3 : 红 1，一千次里红 %d 次" % red)

	# rarity_bias 把红推上去
	var biased := LootContext.new()
	biased.add_rarity_bias(4, 30)
	red = 0
	for i in 1000:
		if (DropResolver.roll(content, rule, biased, db, rng)["treasure"] as Array)[0] == &"red_a":
			red += 1
	t.check(red > 800, "稀有度 4 权重 +30 之后红 %d 次" % red)

	# category_bias 偏向带 weapon 的 gold_b
	var cat := LootContext.new()
	cat.add_category_bias(&"weapon", 300)
	cat.add_rarity_bias(4, -100)   # 只看金
	var b_hits := 0
	for i in 1000:
		if (DropResolver.roll(content, rule, cat, db, rng)["treasure"] as Array)[0] == &"gold_b":
			b_hits += 1
	t.check(b_hits > 700, "weapon 类 +300%% 之后 gold_b %d 次" % b_hits)

	# rolls = 尝试次数
	var more := LootContext.new()
	more.add_rolls(2)
	t.eq((DropResolver.roll(content, rule, more, db, rng)["treasure"] as Array).size(), 3, "rolls 3 → 三件珍宝")

	# 珍宝还没定义（作者留空）：中了也不掉，记下次数
	var bare := ItemDatabase.new()
	bare.register(_item(&"own_0", 0))
	var r := DropResolver.roll(_content([&"own_0"]), rule, ctx, bare, rng)
	t.eq((r["treasure"] as Array).size(), 0, "没有珍宝道具：不掉")
	t.eq(int(r["treasure_missing"]), 1, "记下「中了却没得掉」一次")
	t.check(DropResolver.expected_count(_content([&"own_0"]), rule, ctx, bare) <= 1.0, "期望件数里也不算掉不出来的珍宝（最多就身上那一件）")

	# 这一档没有就看另一档
	var only_red := ItemDatabase.new()
	only_red.register(_item(&"own_0", 0))
	only_red.register(_item(&"red_a", 4, [&"treasure"] as Array[StringName]))
	var gold_only := LootContext.new()
	gold_only.add_rarity_bias(4, -100)
	r = DropResolver.roll(_content([&"own_0"]), rule, gold_only, only_red, rng)
	t.eq(r["treasure"], [&"red_a"] as Array[StringName], "抽到金但只有红：退到红")


static func run_expected_and_corpse(t: TestCase) -> void:
	t.begin("掉落 · 期望件数与尸体容器")

	var rule := _rule()
	var db := _db()
	var ctx := LootContext.new()
	var content := _content([&"own_0", &"own_1", &"own_2"])
	var want := rule.base_chance[0] + rule.base_chance[1] + rule.base_chance[2] + rule.treasure_chance
	var got := DropResolver.expected_count(content, rule, ctx, db)
	t.check(absf(got - want) < 0.35, "期望 ≈ 各件概率之和 + 珍宝概率（%.2f vs %.2f）" % [got, want])
	# 140：就是固定种子掷 64 次的均值 —— 手算一遍
	var rng := RandomNumberGenerator.new()
	rng.seed = DropResolver.EXPECT_SEED
	var n := 0
	for i in DropResolver.EXPECT_SAMPLES:
		var r := DropResolver.roll(content, rule, ctx, db, rng)
		n += (r["dropped"] as Array).size() + (r["treasure"] as Array).size()
	t.eq(got, float(n) / DropResolver.EXPECT_SAMPLES, "= 固定种子掷 %d 次的均值" % DropResolver.EXPECT_SAMPLES)
	t.eq(DropResolver.expected_count(content, rule, ctx, db), got, "同样的输入每次给同一个数")
	# 保底：真掷的时候会补，预估也跟着算进去（原来的公式算不准）
	var floor_rule := _rule()
	floor_rule.min_drops = 2
	t.check(DropResolver.expected_count(content, floor_rule, ctx, db) >= 2.0, "至少掉两件的规则：预估不少于 2")
	ctx.add_rolls(1)
	t.check(DropResolver.expected_count(content, rule, ctx, db) >= got - 0.2, "多一次珍宝尝试，预估不会变少多少")

	var rolled := {"dropped": [&"own_0", &"own_2"] as Array[StringName], "treasure": [&"red_a"] as Array[StringName]}
	var corpse := DropResolver.corpse_of(content, rolled, db)
	t.eq(corpse.item_count(), 3, "容器里正好是掉下来的三件")
	var ids := {}
	for inst in corpse.items():
		ids[(inst as ItemInstance).def.id] = true
	t.check(ids.has(&"own_0") and ids.has(&"own_2") and ids.has(&"red_a"), "是那三件")
	t.eq(corpse.size, Vector2i(6, 2), "容器照敌人的棋盘大小")

	# 塞不下就加高
	var tiny := _content([&"own_0"])
	tiny["board"] = [1, 1]
	var big := DropResolver.corpse_of(tiny, {"dropped": [] as Array[StringName], "treasure": [&"red_a"] as Array[StringName]}, db)
	t.check(big.size.y > 1, "2×2 的珍宝塞不进 1×1，容器加高到 %s" % str(big.size))


static func run_pipeline(t: TestCase) -> void:
	t.begin("掉落 · 规则走管线：往返、校验、仓库文件、章节引用")

	var rule := _rule()
	var text := ContentExporter.to_json(ContentExporter.export_drop_rule(rule))
	var r := ImportReport.new()
	var back := ContentImporter.import_drop_rule(JSON.parse_string(text), _ctx(), r)
	t.check(r.ok(), "导得回来：%s" % r.to_text())
	t.eq(back.base_chance, rule.base_chance, "概率表")
	t.eq(back.treasure_weights, rule.treasure_weights, "珍宝权重（键是字符串）")
	t.eq(ContentExporter.to_json(ContentExporter.export_drop_rule(back)), text, "再导出逐字节相同")

	var base := ContentExporter.export_drop_rule(rule)
	var up := base.duplicate(true)
	up["base_chance"] = [0.5, 0.6, 0.4]
	r = ImportReport.new()
	ContentImporter.import_drop_rule(up, _ctx(), r)
	t.check(not r.ok(), "稀有度 1 比稀有度 0 好掉 → 错（越稀有该越难掉）")

	var over := base.duplicate(true)
	over["base_chance"] = [1.2, 0.5]
	r = ImportReport.new()
	ContentImporter.import_drop_rule(over, _ctx(), r)
	t.check(not r.ok(), "概率 > 1 → 错")

	var badkey := base.duplicate(true)
	badkey["treasure_weights"] = {"gold": 1}
	r = ImportReport.new()
	ContentImporter.import_drop_rule(badkey, _ctx(), r)
	t.check(not r.ok(), "珍宝档位的键不是稀有度 → 错")

	var badw := base.duplicate(true)
	badw["treasure_weights"] = {"4": 0}
	r = ImportReport.new()
	ContentImporter.import_drop_rule(badw, _ctx(), r)
	t.check(not r.ok(), "权重 0 → 错")

	var typo := base.duplicate(true)
	typo["luck_bonu"] = 0.1
	r = ImportReport.new()
	ContentImporter.import_drop_rule(typo, _ctx(), r)
	t.check(not r.ok(), "打错字段名 → 错")

	# 仓库文件
	var dir: String = ContentPaths.KINDS["drop_rules"][0]
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
			var rep := ImportReport.new()
			var res := ContentImporter.import_drop_rule(JSON.parse_string(file_text), ctx, rep)
			t.check(rep.ok(), "drop_rules/%s 导得进：%s" % [id, rep.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_drop_rule(res)), file_text, "drop_rules/%s 是导出器的格式" % id)
			var asset := ContentPaths.asset_file("drop_rules", id)
			t.check(ResourceLoader.exists(asset), "有资产 %s" % asset)
			if ResourceLoader.exists(asset):
				t.eq(ContentExporter.export_drop_rule(load(asset)), ContentExporter.export_drop_rule(res), "资产与作者数据一致")
	t.check(count >= 1, "至少一份掉落规则")

	var chapter := _chapter()
	t.check(chapter != null and chapter.drop_rule != &"", "第一章有掉落规则")
	if chapter != null:
		t.check(ctx.drop_rules.has(chapter.drop_rule), "第一章的规则 '%s' 在仓库里" % chapter.drop_rule)
		var ch := ContentExporter.export_chapter(chapter)
		ch["drop_rule"] = "no_such_rule"
		r = ImportReport.new()
		ContentImporter.import_chapter(ch, ctx, r)
		t.check(not r.ok(), "章节指向不存在的规则 → 错")


static func run_first_chapter(t: TestCase) -> void:
	t.begin("掉落 · 第一章真敌人真掉：掉的都是它背的，珍宝还没定义所以没有")

	var items := _items()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var chapter := _chapter()
	var rule := load(ContentPaths.asset_file("drop_rules", String(chapter.drop_rule))) as DropRule
	var pool := enemies.pool(chapter.enemy_pool)
	if rule == null or pool == null:
		t.check(false, "规则或池不在")
		return
	var g := chapter.map_source.resolve(1)
	EnemyPlacer.fill(g, pool, enemies, items, chapter.difficulty, &"")
	var ctx := LootContext.new()
	ctx.difficulty = chapter.difficulty
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var fights := 0
	var total_dropped := 0
	var total_expected := 0.0
	for id in g.node_ids():
		var c := g.get_node(id).content
		if not EnemyKit.has_enemy(c):
			continue
		fights += 1
		var r := DropResolver.roll(c, rule, ctx, items, rng)
		var carried := DropResolver.carried_ids(c)
		for did in r["dropped"]:
			t.check(carried.has(did), "点 %d 掉的 '%s' 是它背的" % [id, did])
		t.eq((r["treasure"] as Array).size(), 0, "点 %d：珍宝道具还没定义，掉不出珍宝" % id)
		total_dropped += (r["dropped"] as Array).size()
		total_expected += DropResolver.expected_count(c, rule, ctx, items)
		var corpse := DropResolver.corpse_of(c, r, items)
		t.eq(corpse.item_count(), (r["dropped"] as Array).size(), "点 %d：尸体容器装下了全部掉落" % id)
	t.check(fights > 0, "打了 %d 场" % fights)
	t.check(total_dropped > 0, "一整张图总有东西掉（%d 件，期望 %.1f）" % [total_dropped, total_expected])
	t.check(absf(float(total_dropped) - total_expected) < maxf(6.0, total_expected * 0.5),
		"掉的总数 %d 跟期望 %.1f 差得不离谱" % [total_dropped, total_expected])
