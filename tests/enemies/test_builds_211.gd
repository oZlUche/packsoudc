## 211（作者定）：敌人的「套路」—— 写死的道具组合当骨架（好的成套、坏的拉胯），余数照抽；坏套路不补保底武器；
## `loose` 整盘不成组；内容记 `build`；`carry_mult` 让走私贩身上值钱货多
extends RefCounted

const FX := preload("res://tests/battle/test_effect_system.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["carry"])


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _ids(content: Dictionary, items: ItemDatabase, with_bags: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	for raw in content.get("items", []):
		var id := StringName(String((raw as Dictionary).get("id", "")))
		var d := items.get_def(id)
		if d != null and (with_bags or not d.is_bag) and not bool((raw as Dictionary).get("carried", false)):
			out.append(id)
	return out


static func _count(a: Array, id: StringName) -> int:
	var n := 0
	for x in a:
		if StringName(String(x)) == id:
			n += 1
	return n


## 只留一套、必掷中的副本（规则也是副本，不碰库里的）
static func _forced(def: EnemyDef, pool: EnemyPool, build_id: StringName) -> EnemyDef:
	var d: EnemyDef = def.duplicate()
	var rule: EnemyLoadout = (def.loadout if def.loadout != null else pool.loadout).duplicate()
	rule.build_chance = 1.0
	d.loadout = rule
	var only: Array[EnemyBuild] = [def.build_of(build_id)]
	d.builds = only
	return d


static func _build(def: EnemyDef, c: TestSupport.Content, strength: int, seed: int, carry: CarryRule = null) -> Dictionary:
	return EnemyPlacer.build_content(def, c.pool, c.items, strength, _rng(seed), carry)


static func _full_ctx(c: TestSupport.Content) -> ContentImporter.Context:
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.register_item(c.items.get_def(id))
	return ctx


static func run_import(t: TestCase) -> void:
	t.begin("211 · 导入校验：套路的道具得存在、档位区间合法、quality 只认 good / bad")
	var c := _content()
	var ctx := _full_ctx(c)
	var base := {"id": "t_211", "strength": 1, "schools": ["burst"], "item_tags": ["burst", "melee", "remedy"]}
	var cases := [
		[{"id": "ok", "strength": [0, 1], "quality": "bad", "items": ["warhammer", "warhammer"]}, true, "两把战锤"],
		[{"id": "x", "items": ["no_such_item"]}, false, "找不到道具"],
		[{"id": "x", "strength": [2, 1], "items": ["warhammer"]}, false, "区间反了"],
		[{"id": "x", "quality": "meh", "items": ["warhammer"]}, false, "quality 写错"],
		[{"id": "x", "items": ["bag_small"]}, false, "包"],
		[{"id": "x", "items": ["longbow"]}, false, "身份圈不住"],
		[{"id": "", "items": ["warhammer"]}, false, "没 id"],
	]
	for cs in cases:
		var data := base.duplicate()
		data["builds"] = [cs[0]]
		var r := ImportReport.new()
		var def := ContentImporter.import_enemy(data, ctx, r)
		t.eq(r.ok(), cs[1], "%s → %s" % [cs[2], "过" if cs[1] else "错"])
		if cs[1]:
			t.eq(def.builds.size(), 1, "读成一套")
			t.check(def.builds[0].is_bad() and def.builds[0].strength == Vector2i(0, 1), "quality / strength 读对")
	t.begin("211 · 导入校验：套路件超出档位稀有度上限 → 提醒、照样带（4.5）")
	for id in TestSupport.enemy_ids():
		ctx.register_enemy(c.enemies.enemy(id))
	var cap_ctx := ctx
	var e := base.duplicate()
	e["id"] = "t_211_cap"
	e["builds"] = [{"id": "fancy", "strength": [0, 0], "items": ["mithril_sword"]}]
	e["item_tags"] = ["burst", "melee"]
	var r := ImportReport.new()
	ContentImporter.import_enemy(e, cap_ctx, r)
	var pool_data := ContentExporter.export_enemy_pool(c.pool)
	pool_data["entries"] = [{"enemy": "t_211_cap"}]
	ContentImporter.import_enemy_pool(pool_data, cap_ctx, r)
	t.check(r.ok(), "只是提醒，不报错")
	t.check(r.to_text().contains("照样带"), "提醒了超上限")


static func run_pick(t: TestCase) -> void:
	t.begin("211 · 掷套路：必掷中 → 骨架在前；不掷 → 老路一模一样；坏套路权重减半（高档再减半）")
	var c := _content()
	var zerk := c.enemies.enemy(&"berserker")
	t.not_null(zerk, "狂战士在库里")
	if zerk == null:
		return
	var forced := _forced(zerk, c.pool, &"twin_hammers")
	var rule := forced.loadout
	var picks := EnemyPlacer.choose_items(forced, rule, c.items, 5, _rng(3), -1, 1, EnemyPlacer.pick_build(forced, rule, 1, _rng(3)))
	t.eq(picks.slice(0, 3), [&"scimitar", &"warhammer", &"warhammer"] as Array[StringName], "招牌在前，后面是两把锤")
	t.eq(picks.size(), 5, "余数照抽：5 件")
	var off: EnemyDef = forced.duplicate()
	off.loadout = rule.duplicate()
	off.loadout.build_chance = 0.0
	var plain: EnemyDef = zerk.duplicate()
	var empty: Array[EnemyBuild] = []
	plain.builds = empty
	plain.loadout = off.loadout
	for s in 6:
		t.eq(_build(off, c, 1, 50 + s), _build(plain, c, 1, 50 + s), "不掷套路：和没写套路的一样（种子 %d）" % s)
	t.eq(EnemyPlacer.pick_build(forced, rule, 3, _rng(1)), null, "档位 3 不在 twin_hammers 的区间：不掷")
	# 权重：同一档一好一坏、权重都写 1 → 坏的约为好的一半（档位 ≥ 2 约四分之一）
	var d := EnemyDef.new()
	d.id = &"t_211_w"
	var g := EnemyBuild.new()
	g.id = &"g"
	var b := EnemyBuild.new()
	b.id = &"b"
	b.quality = EnemyBuild.BAD
	var two: Array[EnemyBuild] = [g, b]
	d.builds = two
	var lr := EnemyLoadout.new()
	lr.build_chance = 1.0
	for st in [1, 2]:
		var bad := 0
		var good := 0
		for i in 600:
			var got := EnemyPlacer.pick_build(d, lr, st, _rng(7000 + i))
			if got == b:
				bad += 1
			elif got == g:
				good += 1
		var ratio := float(bad) / float(maxi(1, good))
		var want := 0.5 if st < 2 else 0.25
		t.check(absf(ratio - want) < 0.12, "档位 %d：坏 / 好 = %.2f（约 %.2f）" % [st, ratio, want])
	lr.build_chance = 0.6
	var hit := 0
	for i in 600:
		if EnemyPlacer.pick_build(d, lr, 1, _rng(9000 + i)) != null:
			hit += 1
	t.check(absf(hit / 600.0 - 0.6) < 0.07, "build_chance 0.6：掷中 %d / 600" % hit)


static func run_bad_no_weapon(t: TestCase) -> void:
	t.begin("211 · 坏套路不补保底武器（4.3）；好套路照旧有武器")
	var c := _content()
	var rag := c.enemies.enemy(&"ragpicker")
	t.not_null(rag, "拾破烂的在库里")
	if rag == null:
		return
	var bad := _forced(rag, c.pool, &"rags")
	var good := _forced(rag, c.pool, &"cleaver")
	for s in 10:
		var picks := EnemyPlacer.choose_items(bad, bad.loadout, c.items, 4, _rng(s), 1, 0, bad.builds[0])
		var weapons := 0
		for id in picks:
			if c.items.get_def(id).tags.has(&"weapon"):
				weapons += 1
		t.eq(weapons, 0, "一身纱布和吃的：没武器（种子 %d）" % s)
		var built := _build(good, c, 0, s)
		var has := false
		for id in _ids(built["content"], c.items):
			has = has or c.items.get_def(id).tags.has(&"weapon")
		t.check(has, "好套路有剁肉刀（种子 %d）" % s)


## 晶石落在法杖的装载格上没有
static func _crystal_loaded(content: Dictionary, c: TestSupport.Content) -> bool:
	var board := EnemyKit.board_of(content, c.items)
	var staff: ItemInstance = null
	for inst in board.items():
		if (inst as ItemInstance).def.id == &"magic_staff":
			staff = inst
	if staff == null:
		return false
	var p := staff.def.adjacency
	for uid in BattleCompiler._lit_neighbors(board, staff, p.load_cells, p.load_tags()):
		var other := board.get_item(uid)
		if other != null and other.def.tags.has(&"crystal"):
			return true
	return false


static func run_loose(t: TestCase) -> void:
	t.begin("211 · loose：学徒的坏套路整盘不成组，晶石多半不在杖的装载格上；好套路的晶石成组挨着杖")
	var c := _content()
	var mage := c.enemies.enemy(&"apprentice_mage")
	t.not_null(mage, "学徒法师在库里")
	if mage == null:
		return
	var loose := _forced(mage, c.pool, &"misplaced_crystals")
	var tidy := _forced(mage, c.pool, &"two_crystals")
	var loaded_loose := 0
	var loaded_tidy := 0
	for s in 60:
		var a := _build(loose, c, 2, 300 + s)
		t.eq(int(a["ungrouped"]), 0, "不成组：也就没有拆散的组")
		if _crystal_loaded(a["content"], c):
			loaded_loose += 1
		if _crystal_loaded(_build(tidy, c, 2, 300 + s)["content"], c):
			loaded_tidy += 1
	t.check(loaded_tidy >= 30, "好套路：%d / 60 次晶石在装载格上（包里挤不下时组会拆）" % loaded_tidy)
	t.check(loaded_loose < loaded_tidy, "坏套路：%d / 60 次碰巧挨着（好套路 %d）" % [loaded_loose, loaded_tidy])


static func run_content(t: TestCase) -> void:
	t.begin("211 · 内容记 build；余数照抽且受稀有度上限；没套路的内容没有 build 键")
	var c := _content()
	var zerk := c.enemies.enemy(&"berserker")
	var forced := _forced(zerk, c.pool, &"twin_hammers")
	var built := _build(forced, c, 1, 21)
	var content: Dictionary = built["content"]
	t.eq(String(content.get("build", "")), "twin_hammers", "content.build")
	var ids := _ids(content, c.items)
	t.eq(_count(ids, &"warhammer"), 2, "两把锤都摆上了")
	var cap := EnemyPlacer.rarity_cap_of(forced.loadout, c.pool.tier_of(1))
	var skeleton: Array[StringName] = [&"scimitar", &"warhammer", &"warhammer"]
	for id in ids:
		if skeleton.has(id):
			skeleton.erase(id)
			continue
		t.check(cap < 0 or c.items.get_def(id).rarity <= cap, "抽的 %s 不超上限" % id)
	var back = JSON.parse_string(JSON.stringify(content))
	t.eq(String((back as Dictionary).get("build", "")), "twin_hammers", "存档往返（JSON）保留")
	var plain: EnemyDef = zerk.duplicate()
	var empty: Array[EnemyBuild] = []
	plain.builds = empty
	t.check(not (_build(plain, c, 1, 21)["content"] as Dictionary).has("build"), "没套路：没有 build 键")
	t.check(not EnemyKit.summary(content, c.enemies, c.pool, c.items).contains("twin_hammers"), "摘要里不写套路名（4.4）")


static func run_stamina(t: TestCase) -> void:
	t.begin("211 · 两把战锤真的喘不过气：10 秒里耐力不够跳过 ≥ 2 次")
	var c := _content()
	var zerk := _forced(c.enemies.enemy(&"berserker"), c.pool, &"twin_hammers")
	var content: Dictionary = _build(zerk, c, 1, 21)["content"]
	var spec := EnemyKit.spec_of(content, c.enemies, c.pool, c.items)
	t.not_null(spec, "编得出来")
	if spec == null:
		return
	var r := BattleSim.run(spec, FX._spec(5000.0, []), _rng(1), 10.0)
	var skipped := 0
	for e in r.log:
		if e.side == 0 and e.name == BattleEvent.ITEM_SKIPPED:
			skipped += 1
	t.check(skipped >= 2, "跳过 %d 次" % skipped)


static func run_carry_mult(t: TestCase) -> void:
	t.begin("211 · carry_mult：走私贩携带品约为倍率 1 的两倍")
	var c := _content()
	var smug := c.enemies.enemy(&"smuggler")
	t.not_null(smug, "走私贩在库里")
	if smug == null or c.carry == null:
		return
	t.eq(smug.carry_mult, 2.0, "倍率 2")
	t.eq(c.carry.count_range(3, 2.0), c.carry.count_range(3) * 2, "区间两端乘 2")
	var one: EnemyDef = smug.duplicate()
	one.carry_mult = 1.0
	var n2 := 0
	var n1 := 0
	for s in 60:
		n2 += _carried(_build(smug, c, 3, 500 + s, c.carry)["content"])
		n1 += _carried(_build(one, c, 3, 500 + s, c.carry)["content"])
	t.check(n2 > n1 * 1.4, "倍率 2：%d 件 vs 倍率 1：%d 件" % [n2, n1])


static func _carried(content: Dictionary) -> int:
	var n := 0
	for raw in content.get("items", []):
		if bool((raw as Dictionary).get("carried", false)):
			n += 1
	return n


static func run_all_builds_fit(t: TestCase) -> void:
	t.begin("211 · 数据：池里每个敌人的每套套路，在它的档位区间里骨架都摆得上棋盘（招牌摆不摆得下是档位表的事，不在这里）")
	var c := _content()
	var pools: Array[EnemyPool] = []
	for pid in TestSupport.pool_ids():
		pools.append(c.enemies.pool(pid))
	for pool in pools:
		for e in pool.entries:
			var def := c.enemies.enemy(e.enemy)
			if def == null:
				continue
			for b in def.builds:
				var forced := _forced(def, pool, b.id)
				for st in range(maxi(b.strength.x, 0), mini(b.strength.y, 3) + 1):
					var worst := 0
					for s in 6:
						var got := EnemyPlacer.build_content(forced, pool, c.items, st, _rng(800 + s))
						var ids := _ids(got["content"], c.items)
						var missing := 0
						var need := b.items.duplicate()
						for id in need:
							if ids.has(id):
								ids.erase(id)
							else:
								missing += 1
						worst = maxi(worst, missing)
					t.eq(worst, 0, "%s / %s / %s 档 %d：骨架都摆上" % [pool.id, def.id, b.id, st])
