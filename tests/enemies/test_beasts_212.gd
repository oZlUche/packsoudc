## 212（作者 21:30 夜间六条之六，待定按推荐）：魔兽 —— 没有包，身上长着自己的「道具」（wild 那一面）；
## 不揣携带品；地图上的悬浮窗写魔兽那一面
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["carry"])


static func _build(c: TestSupport.Content, enemy: StringName, strength: int, seed: int, carry: CarryRule = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return EnemyPlacer.build_content(c.enemies.enemy(enemy), c.pool, c.items, strength, rng, carry)


static func _ids(content: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for raw in content.get("items", []):
		out.append(StringName(String((raw as Dictionary).get("id", ""))))
	return out


const BEASTS: Array[StringName] = [&"flame_wolf", &"frost_toad", &"shock_eel", &"pit_viper", &"cave_bear"]


static func run_defs(t: TestCase) -> void:
	t.begin("212 · ⑤ 五种魔兽：种族 beast、没有包、只背兽材；都进了标准池")
	var c := _content()
	var in_pool := {}
	for e in c.pool.entries:
		in_pool[(e as EnemyPoolEntry).enemy] = true
	for id in BEASTS:
		var d := c.enemies.enemy(id)
		t.check(d != null and d.species == &"beast" and d.bagless and d.is_wild(), "%s：魔兽、没有包" % id)
		if d == null:
			continue
		t.eq(d.item_tags, [&"beast_part"] as Array[StringName], "%s：身份篓子只有兽材" % id)
		t.check(in_pool.has(id), "%s 在标准池里" % id)
	t.check(not c.enemies.enemy(&"butcher").is_wild(), "屠夫是人")


static func run_assembly(t: TestCase) -> void:
	t.begin("212 · ⑥ 焰狼 1 档：棋盘不要包、身上没有包、招牌四件都在、不换成武器；2 档多出来的是带火的兽材")
	var c := _content()
	for seed in 6:
		var built := _build(c, &"flame_wolf", 1, 40 + seed)
		var content: Dictionary = built["content"]
		var ids := _ids(content)
		t.check(bool(content.get("wild", false)), "内容记着是魔兽（种子 %d）" % seed)
		var bags := ids.filter(func(id): return c.items.get_def(id).is_bag)
		t.eq(bags, [], "没有包（种子 %d）" % seed)
		var board := EnemyKit.board_of(content, c.items)
		t.check(not board.requires_bag and bool(board.get_meta(EnemyKit.WILD_META, false)), "棋盘不要求包、带魔兽标记（种子 %d）" % seed)
		for sid in [&"beast_fang", &"fire_gland", &"beast_hide"]:
			t.check(ids.has(sid), "招牌 %s 在（种子 %d：%s）" % [sid, seed, ids])
		t.eq(ids.count(&"beast_fang"), 2, "两颗兽牙（种子 %d）" % seed)
	var extra := 0
	for seed in 10:
		var ids := _ids(_build(c, &"flame_wolf", 2, 90 + seed)["content"])
		for id in ids:
			var d := c.items.get_def(id)
			t.check(d.tags.has(&"beast_part"), "2 档：%s 是兽材" % id)
		extra += maxi(0, ids.size() - 4)
		for i in range(4, ids.size()):
			t.check(c.items.get_def(ids[i]).tags.has(&"fire") or [&"beast_fang", &"beast_hide", &"fire_gland"].has(ids[i]), "多出来的 %s 带火" % ids[i])
	t.check(extra > 0, "2 档多背了几件（共 %d）" % extra)


static func run_no_carry(t: TestCase) -> void:
	t.begin("212 · ⑦ 魔兽不揣携带品（126）；人照旧揣")
	var c := _content()
	if c.carry == null:
		t.check(false, "自由模式没有携带规则")
		return
	var carried := 0
	for seed in 30:
		for id in BEASTS:
			for raw in (_build(c, id, c.enemies.enemy(id).strength, 300 + seed, c.carry)["content"] as Dictionary)["items"]:
				if bool((raw as Dictionary).get("carried", false)):
					carried += 1
	t.eq(carried, 0, "五种魔兽 × 30 个种子：一件携带品都没有")


static func run_spec(t: TestCase) -> void:
	t.begin("212 · ⑧ 编译：魔兽的棋盘用 wild 面 —— 焰狼的腺体自己出手，兽皮加生命；预览与真打同一份")
	var c := _content()
	var content: Dictionary = _build(c, &"flame_wolf", 1, 7)["content"]
	var spec := EnemyKit.spec_of(content, c.enemies, c.pool, c.items)
	t.not_null(spec, "编得出来")
	if spec == null:
		return
	var firing := 0
	var hide_hp := 0
	for it in spec.items:
		var item := it as CompiledItem
		if item.def_id == &"fire_gland" or item.def_id == &"beast_fang":
			t.check(not item.rules.is_empty(), "%s 自己出手" % item.def_id)
			firing += 1
		if item.def_id == &"beast_hide":
			hide_hp = StatMath.to_int(item.stats.total_of(BattleStats.MAX_HP))
	t.check(firing >= 3, "会咬的三件都出手（%d）" % firing)
	t.eq(hide_hp, 15, "兽皮：生命 +15")
	var tier := c.pool.tier_of(1)
	var base := EnemyKit.baseline_of(c.enemies.enemy(&"flame_wolf"), tier, content).value_of(BattleStats.MAX_HP, 0.0)
	t.eq(spec.max_hp_int(), int(round(base)) + 15, "生命 = 基线 + 兽皮")


static func run_tooltip(t: TestCase) -> void:
	t.begin("212 · ⑨ 悬浮窗：焰狼身上的火焰腺写「魔兽的器官」与它咬人那一面；自己背包里的写玩家面")
	var c := _content()
	var content: Dictionary = _build(c, &"flame_wolf", 1, 7)["content"]
	var board := EnemyKit.board_of(content, c.items)
	var gland: ItemInstance = null
	for inst in board.items():
		if (inst as ItemInstance).def.id == &"fire_gland":
			gland = inst
	t.not_null(gland, "焰狼身上有火焰腺")
	if gland == null:
		return
	var wild := Glossary.strip_bbcode(ItemTooltip.describe(gland, board))
	t.check(wild.contains("魔兽的器官") and wild.contains("灼伤") and wild.contains("耐力"), "魔兽面：器官、出手、灼伤（%s）" % wild)
	var mine := Glossary.strip_bbcode(ItemTooltip.describe(ItemInstance.create(gland.def)))
	t.check(not mine.contains("魔兽的器官") and mine.contains("灼伤"), "玩家面：给相邻武器挂灼伤（%s）" % mine)


static func run_reaction(t: TestCase) -> void:
	t.begin("212 · ⑩ 反应：焰狼的腺体施加的灼伤打在已中毒的对手身上 → 爆燃（和法杖打出来的同一张反应表）")
	var R := load("res://tests/battle/test_reactions_175.gd")
	var c := _content()
	var spec := EnemyKit.spec_of(_build(c, &"flame_wolf", 1, 7)["content"], c.enemies, c.pool, c.items)
	var scorch: ApplyStatus = null
	for it in spec.items:
		if (it as CompiledItem).def_id != &"fire_gland":
			continue
		for r in (it as CompiledItem).rules:
			for e in (r as AbilityRule).effects:
				if e is ApplyStatus and String((e as ApplyStatus).buff.id) == "scorch":
					scorch = e
	t.not_null(scorch, "腺体打中施加灼伤")
	if scorch == null:
		return
	var ctx: BattleContext = R._run([])
	ctx.sides[1].apply_buff(R._b("poison"), 2, ctx.now)
	scorch.apply(R._rc(ctx))
	t.eq(R._reactions(ctx), [&"fire_poison"] as Array[StringName], "引发爆燃")


static func run_species_error(t: TestCase) -> void:
	t.begin("212 · ⑪ 导入：种族写错报错")
	var rep := ImportReport.new()
	ContentImporter.import_enemy({"id": "t_bad_species", "species": "dragon", "strength": 0}, ContentImporter.Context.new(), rep)
	t.check(not rep.ok(), "species dragon：报错（%s）" % rep.to_text())
