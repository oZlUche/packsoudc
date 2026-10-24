## 敌人池（M4-1，架构文档 5.10 / 6.0）：配置表走管线、按节点挑档位与人、组装棋盘、编译预览。
##
## 期望全从数据推：件数范围来自档位表、档位来自规则、流派道具的数量来自组装规则。
## 改一份 JSON，这里跟着变，不用改测试。
extends RefCounted


static func _ctx() -> ContentImporter.Context:
	return ContentImporter.Context.new()


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _enemies() -> EnemyDatabase:
	var db := EnemyDatabase.new()
	db.load_all()
	return db


static func _chapter() -> ChapterDef:
	return load(ContentPaths.asset_file("chapters", "free_mode")) as ChapterDef


## 上下文里装满真道具与真敌人，好让「对着别的东西查」的校验生效
static func _full_ctx(items: ItemDatabase, enemies: EnemyDatabase) -> ContentImporter.Context:
	var ctx := _ctx()
	for id in items.ids():
		ctx.register_item(items.get_def(id))
	for id in TestSupport.enemy_ids():
		ctx.register_enemy(enemies.enemy(id))
	for id in TestSupport.pool_ids():
		ctx.register_pool(enemies.pool(id))
	return ctx


static func _node(type: StringName, tier: int, danger: int = 0, kind: String = "") -> MapNode:
	var n := MapNode.new()
	n.type = type
	n.tier = tier
	n.danger = danger
	n.content_seed = 7
	if kind != "":
		n.layout["kind"] = kind
	return n


static func _sample_pool() -> EnemyPool:
	var pool := EnemyPool.new()
	pool.id = &"t_pool"
	for s in 3:
		var t := StrengthTier.new()
		t.strength = s
		t.item_count = Vector2i(2 + s, 3 + s)
		t.board = Vector2i(5, 4)
		t.stat_scale = {"max_hp": 1.0 + 0.5 * s}
		pool.tiers.append(t)
	pool.strength_rule = StrengthRule.new()
	pool.strength_rule.by_depth = Vector2i(0, 2)
	pool.strength_rule.type_bonus = {"elite": 1, "core": 1}
	pool.loadout = EnemyLoadout.new()
	pool.loadout.common_tags = [&"gear", &"remedy"] as Array[StringName]
	var a := EnemyPoolEntry.new()
	a.enemy = &"t_low"
	a.weight = 2.0
	var b := EnemyPoolEntry.new()
	b.enemy = &"t_high"
	b.node_types = [&"elite", &"core"] as Array[StringName]
	pool.entries = [a, b] as Array[EnemyPoolEntry]
	return pool


static func _sample_enemy(id: StringName, strength: int, schools: Array[StringName]) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = id
	e.display_name = String(id)
	e.strength = strength
	e.schools = schools
	e.base_stats = {"max_hp": 30.0}
	return e


static func run_round_trip(t: TestCase) -> void:
	t.begin("敌人池 · 敌人与池走管线，导出再导入逐字节一致")

	var enemy := _sample_enemy(&"t_low", 0, [&"rapid"] as Array[StringName])
	enemy.signature = [&"knife"] as Array[StringName]
	enemy.loadout = EnemyLoadout.new()
	enemy.loadout.school_share = 0.8
	var dumped := ContentExporter.export_enemy(enemy)
	t.eq(String(dumped.get("id", "")), "t_low", "id 导出了")
	t.check(not dumped.has("strength"), "默认值（档位 0）不写")
	t.check(dumped.has("loadout") and (dumped["loadout"] as Dictionary).has("school_share"), "覆盖的组装规则导出了")
	var text := ContentExporter.to_json(dumped)
	var r := ImportReport.new()
	var back := ContentImporter.import_enemy(JSON.parse_string(text), _ctx(), r)
	t.check(r.ok(), "导得回来：%s" % r.to_text())
	t.eq(back.schools, enemy.schools, "流派是 StringName 数组")
	t.eq(back.signature, enemy.signature, "招牌道具")
	t.eq(back.loadout.school_share, 0.8, "覆盖的组装规则")
	t.eq(ContentExporter.to_json(ContentExporter.export_enemy(back)), text, "敌人再导出逐字节相同")

	var pool := _sample_pool()
	var pd := ContentExporter.export_enemy_pool(pool)
	var ptext := ContentExporter.to_json(pd)
	r = ImportReport.new()
	var pback := ContentImporter.import_enemy_pool(JSON.parse_string(ptext), _ctx(), r)
	t.check(r.ok(), "池导得回来：%s" % r.to_text())
	t.eq(pback.tiers.size(), 3, "三档")
	t.eq(pback.tiers[2].item_count, Vector2i(4, 5), "Vector2i 读回来一样")
	t.eq(pback.tiers[1].stat_scale, {"max_hp": 1.5}, "字典里的浮点没变整数")
	t.eq(pback.strength_rule.type_bonus, {"elite": 1, "core": 1}, "字典里的整数没变浮点")
	t.eq(pback.entries[1].node_types, pool.entries[1].node_types, "条目的节点类型过滤")
	t.eq(ContentExporter.to_json(ContentExporter.export_enemy_pool(pback)), ptext, "池再导出逐字节相同")


static func run_validation(t: TestCase) -> void:
	t.begin("敌人池 · 校验比引擎严格")

	var items := _items()
	var enemies := _enemies()
	var ctx := _full_ctx(items, enemies)

	var e := ContentExporter.export_enemy(_sample_enemy(&"t_x", 0, [&"no_such_school"] as Array[StringName]))
	var r := ImportReport.new()
	ContentImporter.import_enemy(e, ctx, r)
	t.check(not r.ok(), "流派没有任何道具带这个标签 → 错")
	t.check(r.to_text().contains("no_such_school"), "报错说得出是哪个流派")

	e = ContentExporter.export_enemy(_sample_enemy(&"t_x", 0, [&"rapid"] as Array[StringName]))
	e["signature"] = ["no_such_item"]
	r = ImportReport.new()
	ContentImporter.import_enemy(e, ctx, r)
	t.check(not r.ok(), "招牌道具不存在 → 错")

	e = ContentExporter.export_enemy(_sample_enemy(&"t_x", 0, [&"rapid"] as Array[StringName]))
	e["signature"] = ["bag_small"]
	r = ImportReport.new()
	ContentImporter.import_enemy(e, ctx, r)
	t.check(not r.ok(), "招牌道具是个包 → 错")

	e = ContentExporter.export_enemy(_sample_enemy(&"t_x", 0, [&"rapid"] as Array[StringName]))
	e["strenght"] = 2
	r = ImportReport.new()
	ContentImporter.import_enemy(e, ctx, r)
	t.check(not r.ok(), "打错字段名 → 错")

	# 上下文是空的（单独导一个敌人）：对着道具查的那几条跳过，其余照旧
	e = ContentExporter.export_enemy(_sample_enemy(&"t_x", 0, [&"no_such_school"] as Array[StringName]))
	r = ImportReport.new()
	ContentImporter.import_enemy(e, _ctx(), r)
	t.check(r.ok(), "上下文里没有道具时不判流派 —— 单独导一个敌人也导得进")

	var base := ContentExporter.export_enemy_pool(_sample_pool())
	r = ImportReport.new()
	ContentImporter.import_enemy_pool(base, ctx, r)
	t.check(not r.ok(), "池指向不存在的敌人（t_low 不在库里）→ 错")

	var ok_pool := base.duplicate(true)
	(ok_pool["entries"] as Array)[0]["enemy"] = "raider"
	(ok_pool["entries"] as Array)[1]["enemy"] = "brute"
	r = ImportReport.new()
	ContentImporter.import_enemy_pool(ok_pool, ctx, r)
	t.check(r.ok(), "指向存在的敌人 → 过：%s" % r.to_text())

	var dup := ok_pool.duplicate(true)
	((dup["tiers"] as Array)[1] as Dictionary)["strength"] = 0
	r = ImportReport.new()
	ContentImporter.import_enemy_pool(dup, ctx, r)
	t.check(not r.ok(), "档位重复 → 错")

	var no_rule := ok_pool.duplicate(true)
	no_rule.erase("strength_rule")
	r = ImportReport.new()
	ContentImporter.import_enemy_pool(no_rule, ctx, r)
	t.check(not r.ok(), "没有档位规则 → 错")

	var bad_type := ok_pool.duplicate(true)
	((bad_type["entries"] as Array)[1] as Dictionary)["node_types"] = ["search"]
	r = ImportReport.new()
	ContentImporter.import_enemy_pool(bad_type, ctx, r)
	t.check(not r.ok(), "条目限定在池不放敌人的节点类型里 → 错（永远不会出现）")

	var ch := ContentExporter.export_chapter(_chapter())
	ch["enemy_pool"] = "no_such_pool"
	r = ImportReport.new()
	ContentImporter.import_chapter(ch, ctx, r)
	t.check(not r.ok(), "章节指向不存在的池 → 错")
	ch["enemy_pool"] = ""
	r = ImportReport.new()
	ContentImporter.import_chapter(ch, ctx, r)
	t.check(r.ok(), "章节可以没有敌人池（战斗点空着）")


static func run_authoring_files(t: TestCase) -> void:
	t.begin("敌人池 · 仓库里的敌人与池导得进、与资产一致、第一章引用得到")

	var items := _items()
	var enemies := _enemies()
	t.check(TestSupport.enemy_ids().size() >= 3, "至少三种敌人（实际 %d）" % TestSupport.enemy_ids().size())
	t.check(TestSupport.pool_ids().size() >= 1, "至少一个池")
	var ctx := _full_ctx(items, enemies)

	for kind in ["enemies", "enemy_pools"]:
		var dir: String = ContentPaths.KINDS[kind][0]
		var d := DirAccess.open(dir)
		t.not_null(d, "有 %s" % dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			var id := f.get_basename()
			var text := FileAccess.get_file_as_string(dir + "/" + f)
			var r := ImportReport.new()
			var res: Resource = null
			var again := ""
			if kind == "enemies":
				res = ContentImporter.import_enemy(JSON.parse_string(text), ctx, r)
				again = ContentExporter.to_json(ContentExporter.export_enemy(res))
			else:
				res = ContentImporter.import_enemy_pool(JSON.parse_string(text), ctx, r)
				again = ContentExporter.to_json(ContentExporter.export_enemy_pool(res))
			t.check(r.ok(), "%s/%s 导得进：%s" % [kind, id, r.to_text()])
			t.eq(again, text, "%s/%s 作者数据就是导出器的格式（跑 tools/normalize_content.gd）" % [kind, id])
			var asset := ContentPaths.asset_file(kind, id)
			t.check(ResourceLoader.exists(asset), "有资产 %s" % asset)
			if ResourceLoader.exists(asset):
				var loaded: Resource = load(asset)
				var lhs: Dictionary = ContentExporter.export_enemy(loaded) if kind == "enemies" else ContentExporter.export_enemy_pool(loaded)
				var rhs: Dictionary = ContentExporter.export_enemy(res) if kind == "enemies" else ContentExporter.export_enemy_pool(res)
				t.eq(lhs, rhs, "%s/%s 资产与作者数据一致 —— 改了 JSON 忘了导入，这条会红" % [kind, id])

	var chapter := _chapter()
	t.not_null(chapter, "第一章在")
	if chapter == null:
		return
	t.check(chapter.enemy_pool != &"", "第一章有敌人池")
	t.not_null(enemies.pool(chapter.enemy_pool), "第一章的池 '%s' 在库里" % chapter.enemy_pool)

	# 池里每种流派在每一档的稀有度上限下都得有道具，而且流派道具得能打 —— 不然「按流派挑」挑出来的是个空架子
	var pool := enemies.pool(chapter.enemy_pool)
	for id in TestSupport.enemy_ids():
		var def := enemies.enemy(id)
		if def.is_wild():
			# 212：魔兽的流派键是它器官的元素；篓子只有兽材，没有「武器」—— 只要求流派池里有会自己出手的器官（wild 面）
			for s in def.schools:
				var organs := EnemyPlacer.school_items([s] as Array[StringName], items, -1, def)
				t.check(organs.any(func(iid): return not BattleCompiler.profile_of(items.get_def(iid), true).rules.is_empty()),
					"魔兽 / 机关 %s 流派 '%s'：有会自己出手的" % [id, s])
			continue
		for s in def.schools:
			var pool_items := EnemyPlacer.school_items([s] as Array[StringName], items, -1)
			t.check(pool_items.size() >= 2, "流派 '%s' 至少两件道具（实际 %d）—— 一件就没得抽" % [s, pool_items.size()])
			# 流派按信仰分之后（8-4）池里也有护甲与零件，但至少得有一件会打的 —— 组装时保证每个敌人至少一件武器（EnemyLoadout.min_weapons）
			var armed := false
			for iid in pool_items:
				armed = armed or items.get_def(iid).tags.has(pool.loadout.weapon_tag if pool != null and pool.loadout != null else &"weapon")
			t.check(armed, "流派 '%s' 的池里至少一件会打的" % s)
			if pool != null:
				for tier in pool.tiers:
					var cap := EnemyPlacer.rarity_cap_of(pool.loadout, tier)
					t.check(not EnemyPlacer.school_items([s] as Array[StringName], items, cap).is_empty(),
						"流派 '%s' 在档位 %d（稀有度 ≤ %d）下还有道具可抽" % [s, tier.strength, cap])


static func run_strength(t: TestCase) -> void:
	t.begin("敌人池 · 哪个点该多强：深度、危险、类型、难度、规模各加各的")

	var pool := _sample_pool()
	var rule := pool.strength_rule
	var outer := _node(&"battle", 0)
	var inner := _node(&"battle", 5)
	var lo := EnemyPlacer.wanted_strength(pool, outer, 0.0, 0, &"")
	var hi := EnemyPlacer.wanted_strength(pool, inner, 1.0, 0, &"")
	t.eq(lo, rule.by_depth.x, "最外 = by_depth.x")
	t.eq(hi, rule.by_depth.y, "最内 = by_depth.y")
	t.check(hi >= lo, "越深越强")

	var elite := _node(&"elite", 0)
	t.eq(EnemyPlacer.wanted_strength(pool, elite, 0.0, 0, &""), lo + int(rule.type_bonus["elite"]),
		"精英加 type_bonus.elite")
	var hot := _node(&"battle", 0, 2)
	t.eq(EnemyPlacer.wanted_strength(pool, hot, 0.0, 0, &""), lo + 2 * rule.danger_bonus,
		"高危区（danger 2）加两次 danger_bonus")
	t.eq(EnemyPlacer.wanted_strength(pool, outer, 0.0, 1, &""), lo + rule.difficulty_bonus, "难度 +1 加 difficulty_bonus")
	rule.by_scale = {"large": 1}
	t.eq(EnemyPlacer.wanted_strength(pool, outer, 0.0, 0, &"large"), lo + 1, "大图加 by_scale.large")
	t.eq(EnemyPlacer.wanted_strength(pool, outer, 0.0, 0, &"small"), lo, "没列的规模不加")
	t.eq(EnemyPlacer.wanted_strength(pool, inner, 1.0, 9, &"large"), pool.strengths()[pool.strengths().size() - 1],
		"再高也夹进档位表的最高档")

	# 探索度：只对踩上去才造的敌人（调用方传进来），每 N 步 / 每 N 次搜索加一档，各有上限；不传就不加
	rule.by_scale = {}
	rule.steps_per_tier = 10
	rule.steps_max_bonus = 2
	rule.searches_per_tier = 3
	rule.searches_max_bonus = 1
	t.eq(EnemyPlacer.wanted_strength(pool, outer, 0.0, 0, &""), lo, "不传探索度：不加")
	t.eq(rule.exploration_bonus({"steps": 9, "searches": 2}), 0, "不够一档不加")
	t.eq(rule.exploration_bonus({"steps": 10}), 1, "十步一档")
	t.eq(rule.exploration_bonus({"steps": 25}), 2, "二十五步两档")
	t.eq(rule.exploration_bonus({"steps": 99}), rule.steps_max_bonus, "步数封顶")
	t.eq(rule.exploration_bonus({"searches": 3}), 1, "三次搜索一档")
	t.eq(rule.exploration_bonus({"searches": 30}), rule.searches_max_bonus, "搜索封顶")
	t.eq(rule.exploration_bonus({"steps": 10, "searches": 3}), 2, "两项相加")
	t.eq(EnemyPlacer.wanted_strength(pool, outer, 0.0, 0, &"", {"steps": 10, "searches": 3}),
		pool.clamp_strength(lo + 2), "想要的档位 = 原来的 + 探索度，夹进档位表")
	rule.steps_per_tier = 0
	rule.searches_per_tier = 0
	t.eq(rule.exploration_bonus({"steps": 999, "searches": 999}), 0, "都是 0 = 不算探索度")

	# 深度：形态无关，只看 tier 在全图里的位置
	var g := MapGraph.new()
	for i in 4:
		var n := _node(&"battle", i)
		n.id = i + 1
		g.add_node(n)
	var depth := EnemyPlacer.depths_of(g)
	t.eq(depth[1], 0.0, "tier 最低 = 深度 0")
	t.eq(depth[4], 1.0, "tier 最高 = 深度 1")
	t.check(absf(float(depth[2]) - 1.0 / 3.0) < 1e-6, "中间按比例")


static func run_candidates(t: TestCase) -> void:
	t.begin("敌人池 · 挑人：过滤 + 容差内取，容差内没有取最近")

	var pool := _sample_pool()
	var db := EnemyDatabase.new()
	db.register_enemy(_sample_enemy(&"t_low", 0, [&"rapid"] as Array[StringName]))
	db.register_enemy(_sample_enemy(&"t_high", 3, [&"burst"] as Array[StringName]))
	var tol := pool.strength_rule.tolerance

	var battle := _node(&"battle", 0)
	var c := EnemyPlacer.candidates(pool, db, battle, 0)
	t.eq(c.size(), 1, "battle 点只有 t_low 能出（t_high 限定 elite/core）")
	t.eq(c[0].enemy, &"t_low", "是 t_low")

	var elite := _node(&"elite", 0)
	c = EnemyPlacer.candidates(pool, db, elite, 0)
	t.eq(c.size(), 1, "想要 0：只有本色 0 在容差 %d 内" % tol)
	c = EnemyPlacer.candidates(pool, db, elite, 3)
	t.eq(c.size(), 1, "想要 3：只有本色 3 在容差内")
	t.eq(c[0].enemy, &"t_high", "是 t_high")
	c = EnemyPlacer.candidates(pool, db, elite, 2)
	t.eq(c.size(), 1, "想要 2：0 差 2 超容差，3 差 1 在容差内 → 只有 t_high")
	c = EnemyPlacer.candidates(pool, db, elite, 9)
	t.eq(c.size(), 1, "想要 9：谁都不在容差内 → 取最近的")
	t.eq(c[0].enemy, &"t_high", "最近的是 t_high")

	# 环种类过滤：地图类型
	pool.entries[0].kinds = [&"ruins"] as Array[StringName]
	t.check(EnemyPlacer.candidates(pool, db, _node(&"battle", 0, 0, "ruins"), 0).size() == 1, "在 ruins 出")
	t.check(EnemyPlacer.candidates(pool, db, _node(&"battle", 0, 0, "depths"), 0).is_empty(), "不在 depths 出")
	t.check(EnemyPlacer.candidates(pool, db, _node(&"battle", 0), 0).is_empty(), "没有 kind 的点（手绘图）也不出")

	# 危险等级过滤
	pool.entries[0].kinds = [] as Array[StringName]
	pool.entries[0].min_danger = 2
	t.check(EnemyPlacer.candidates(pool, db, _node(&"battle", 0, 1), 0).is_empty(), "danger 1 < 2 不出")
	t.check(EnemyPlacer.candidates(pool, db, _node(&"battle", 0, 2), 0).size() == 1, "danger 2 出")

	# 权重：抽一千次，重的那个明显多（容差放宽到两个都在候选里）
	pool.entries[0].min_danger = 0
	pool.entries[1].node_types = [] as Array[StringName]
	pool.strength_rule.tolerance = 5
	pool.entries[0].weight = 9.0
	pool.entries[1].weight = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var heavy := 0
	for i in 1000:
		if EnemyPlacer.pick(pool, db, _node(&"battle", 0), 1, rng).enemy == &"t_low":
			heavy += 1
	t.check(heavy > 800 and heavy < 980, "权重 9:1，重的抽到 %d/1000" % heavy)


static func run_placement(t: TestCase) -> void:
	t.begin("敌人池 · 第一章：每个战斗点都定好了敌人，件数、流派、招牌、位置都对得上")

	var items := _items()
	var enemies := _enemies()
	var chapter := _chapter()
	var pool := enemies.pool(chapter.enemy_pool)
	if pool == null:
		t.check(false, "第一章没有池")
		return
	var rule := pool.loadout
	var seeds := [1, 2, 3, 4, 5]
	var combat_seen := 0
	var strengths_seen := {}
	var enemies_seen := {}
	for seed in seeds:
		var g := chapter.map_source.resolve(seed)
		if g == null:
			t.check(false, "种子 %d 生成不出图" % seed)
			continue
		var depth := EnemyPlacer.depths_of(g)
		var done := EnemyPlacer.fill(g, pool, enemies, items, chapter.difficulty, &"")
		t.check((done["skipped"] as Array).is_empty(), "种子 %d：每个战斗点都挑到了人（没挑到：%s）" % [seed, str(done["skipped"])])
		t.eq(int(done["dropped"]), 0, "种子 %d：换着抽之后每个敌人都凑够了件数（档位表的棋盘够宽裕）差件的点：%s"
			% [seed, str(done["short"])])
		for id in g.node_ids():
			var n := g.get_node(id)
			var c := n.content
			if not pool.combat_types.has(n.type):
				t.check(not EnemyKit.has_enemy(c), "种子 %d 点 %d（%s）不是战斗点，没有敌人" % [seed, id, n.type])
				continue
			combat_seen += 1
			if not EnemyKit.has_enemy(c):
				continue
			var def := enemies.enemy(StringName(String(c["enemy"])))
			t.not_null(def, "点 %d 的敌人 '%s' 在库里" % [id, c["enemy"]])
			if def == null:
				continue
			enemies_seen[def.id] = true
			var s := int(c["strength"])
			strengths_seen[s] = true
			t.eq(s, EnemyPlacer.wanted_strength(pool, n, float(depth[id]), chapter.difficulty, &""),
				"点 %d 记的档位就是规则算出来的" % id)
			t.check(TestSupport.pool_entry(pool, def.id).fits(n), "点 %d：条目的过滤（环种类 / 节点类型 / 危险）对得上" % id)
			var tier := pool.tier_of(s)
			var cap := EnemyPlacer.rarity_cap_of(def.loadout if def.loadout != null else rule, tier)
			var sig := def.signature_at(s)
			var placed: Array = c["items"]
			# 084：敌人也背包（档位表的 bags），包不计入件数；道具全在包里
			var bag_n := 0
			for raw in placed:
				var bdef := items.get_def(StringName(String(raw["id"])))
				if bdef != null and bdef.is_bag:
					bag_n += 1
			var goods := placed.size() - bag_n
			var want_bags: Array[StringName] = def.bags if not def.bags.is_empty() else tier.bags
			if def.bagless:
				t.eq(bag_n, 0, "点 %d：魔兽 / 机关没有包" % id)     # 212
			elif not want_bags.is_empty():
				t.eq(bag_n, want_bags.size(), "点 %d：背着写死的 %d 个包" % [id, want_bags.size()])
			else:
				# 209：从包池抽 bag_count 个（兜底最多各补 BAG_TOPUP 个；摆不下的少一个），稀有度不超档位上限
				t.check(bag_n >= 1 and bag_n <= tier.bag_count.y + 2 * EnemyPlacer.BAG_TOPUP, "点 %d：包池抽的 %d 个包在 [1, %d]" % [id, bag_n, tier.bag_count.y + 2 * EnemyPlacer.BAG_TOPUP])
				for raw in placed:
					var bd := items.get_def(StringName(String(raw["id"])))
					if bd != null and bd.is_bag:
						t.check(tier.rarity_cap < 0 or bd.rarity <= tier.rarity_cap, "点 %d：包 %s 的稀有度不超档位上限" % [id, bd.id])
			var most := maxi(tier.item_count.y, sig.size()) if def.is_wild() else tier.item_count.y     # 212：魔兽的招牌一件不少
			t.check(goods >= tier.item_count.x and goods <= most,
				"点 %d：%d 件（不含包）在档位 %d 的 [%d, %d] 里" % [id, goods, s, tier.item_count.x, most])
			var rebuilt := EnemyKit.board_of(c, items)
			t.check(rebuilt.requires_bag == (bag_n > 0), "点 %d：有包就和玩家一样 requires_bag" % id)
			var school_n := 0
			var ids: Array[StringName] = []
			for raw in placed:
				var iid := StringName(String(raw["id"]))
				ids.append(iid)
				var idef := items.get_def(iid)
				t.not_null(idef, "点 %d 背的 '%s' 在道具库里" % [id, iid])
				if idef != null and not idef.is_bag:
					# 招牌不受稀有度上限（choose_items 先占位）；211 套路是设计者写的，超了也照样带（导入器只警告）
					var build := def.build_of(StringName(String(c.get("build", "")))) if c.has("build") else null
					t.check(cap < 0 or idef.rarity <= cap or sig.has(iid) or (build != null and build.items.has(iid)),
						"点 %d：%s 的 %s 稀有度 %d 不超这一档的上限 %d" % [id, def.id, iid, idef.rarity, cap])
					if EnemyPlacer._shares_tag(idef.tags, def.schools):
						school_n += 1
			var available := EnemyPlacer.school_items(def.schools, items, cap)
			var want_school := mini(rule.min_school, placed.size()) if not available.is_empty() else 0
			t.check(school_n >= want_school, "点 %d：至少 %d 件流派道具（实际 %d）" % [id, want_school, school_n])
			for sid in def.signature:
				t.check(ids.has(sid), "点 %d：招牌道具 '%s' 在" % [id, sid])
			# 位置：按记的位置重建，每件都落在记的地方、彼此不重叠（GridInventory 不让重叠）
			var board := EnemyKit.board_of(c, items)
			t.eq(board.item_count(), placed.size(), "点 %d：棋盘重建出 %d 件" % [id, placed.size()])
			var spec := EnemyKit.spec_of(c, enemies, pool, items)
			t.check(spec != null and spec.max_hp_int() > 0, "点 %d：编译得出，有血" % id)
			if spec != null and school_n > 0:
				t.check(spec.rough_dps() > 0.0, "点 %d：有流派道具就有 DPS" % id)
			var line := EnemyKit.summary(c, enemies, pool, items)
			t.check(line.contains(def.display_name), "点 %d：摘要里有名字" % id)

		# 同一个种子再来一遍，内容逐字相同
		var g2 := chapter.map_source.resolve(seed)
		EnemyPlacer.fill(g2, pool, enemies, items, chapter.difficulty, &"")
		var same := true
		for id in g.node_ids():
			if JSON.stringify(g.get_node(id).content) != JSON.stringify(g2.get_node(id).content):
				same = false
		t.check(same, "种子 %d：再放一遍，每个点的敌人与棋盘逐字相同" % seed)

	t.check(combat_seen > 0, "看到了 %d 个战斗点" % combat_seen)
	t.check(strengths_seen.size() >= 2, "五张图里出现了 %d 种档位（%s）—— 深浅有别" % [strengths_seen.size(), str(strengths_seen.keys())])
	t.check(enemies_seen.size() >= 3, "五张图里出现了 %d 种敌人（%s）" % [enemies_seen.size(), str(enemies_seen.keys())])

	# 难度抬档：同一张图，难度 +1，每个战斗点的档位不低于原来
	var g0 := chapter.map_source.resolve(1)
	var g1 := chapter.map_source.resolve(1)
	EnemyPlacer.fill(g0, pool, enemies, items, 0, &"")
	EnemyPlacer.fill(g1, pool, enemies, items, 1, &"")
	var raised := 0
	for id in g0.node_ids():
		var a := g0.get_node(id).content
		var b := g1.get_node(id).content
		if EnemyKit.has_enemy(a) and EnemyKit.has_enemy(b):
			t.check(int(b["strength"]) >= int(a["strength"]), "点 %d：难度高了档位不降" % id)
			if int(b["strength"]) > int(a["strength"]):
				raised += 1
	t.check(raised > 0 or pool.strength_rule.difficulty_bonus == 0, "难度 +1 至少抬高了一个点（%d 个）" % raised)


static func run_kit(t: TestCase) -> void:
	t.begin("敌人池 · 内容 → 棋盘 → 战斗单位是纯函数")

	var items := _items()
	var enemies := _enemies()
	var pool := enemies.pool(_chapter().enemy_pool)
	var def := enemies.enemy(&"butcher")
	if def == null or pool == null:
		t.check(false, "屠夫或池不在")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var built := EnemyPlacer.build_content(def, pool, items, 1, rng)
	var c: Dictionary = built["content"]
	t.eq(String(c["enemy"]), "butcher", "记的是谁")
	t.eq(int(c["strength"]), 1, "记的档位是传进去的")
	var tier := pool.tier_of(1)
	t.eq(c["board"], [tier.board.x, tier.board.y], "棋盘尺寸来自档位表")
	var a := EnemyKit.spec_of(c, enemies, pool, items)
	var b := EnemyKit.spec_of(c, enemies, pool, items)
	t.eq(a.max_hp_int(), b.max_hp_int(), "两次编译生命相同")
	t.eq(a.rough_dps(), b.rough_dps(), "两次编译 DPS 相同")
	var base := EnemyKit.baseline_of(def, tier)
	t.eq(base.value_of(&"max_hp"), float(def.base_stats["max_hp"]) * float(tier.stat_scale.get("max_hp", 1.0)), "基线 = 敌人覆盖 × 档位倍率")
	t.eq(base.value_of(&"max_stamina"), CombatantBaseline.DEFAULT_STATS["max_stamina"], "没覆盖的键用默认")
	t.check(a.max_hp_int() >= int(base.value_of(&"max_hp")), "编译出的生命至少是基线（道具只加不减）")

	# 内容过一趟 JSON（跟着图存）再重建，一样
	var round: Dictionary = MapGraph.normalize(JSON.parse_string(JSON.stringify(c)))
	t.eq(EnemyKit.board_of(round, items).item_count(), EnemyKit.board_of(c, items).item_count(), "过一趟 JSON 重建件数不变")
	t.eq(EnemyKit.spec_of(round, enemies, pool, items).rough_dps(), a.rough_dps(), "过一趟 JSON 编译结果不变")
