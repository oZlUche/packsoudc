## 210（作者 21:30 夜间六条之四，待定按推荐）：机关敌人 —— 没有包、天生格挡 + 护板（固定减伤）、免疫流血 / 中毒、掉齿轮；
## 五件零件两面（玩家面 / 机关面）
extends RefCounted

const R := preload("res://tests/battle/test_reactions_175.gd")
const Prebattle := preload("res://ui/game/prebattle_screen.gd")

const CONSTRUCTS: Array[StringName] = [&"clockwork_sentry", &"steam_turret", &"gear_golem", &"pendulum_warden", &"great_clock"]


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("clockwork_hourglass", ["carry"])


static func _build(c: TestSupport.Content, enemy: StringName, seed: int, carry: CarryRule = null) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var def := c.enemies.enemy(enemy)
	return EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng, carry)["content"]


static func _spec(c: TestSupport.Content, content: Dictionary) -> CombatantSpec:
	return EnemyKit.spec_of(content, c.enemies, c.pool, c.items)


static func run_defs(t: TestCase) -> void:
	t.begin("210 · ④ 五种机关：种族 construct、没有包、只背机关零件、天生格挡、免疫流血 / 中毒；两种人照旧")
	var c := _content()
	for id in CONSTRUCTS:
		var d := c.enemies.enemy(id)
		t.check(d != null and d.species == &"construct" and d.bagless and d.is_wild(), "%s：机关、没有包" % id)
		if d == null:
			continue
		t.eq(d.item_tags, [&"clockwork"] as Array[StringName], "%s：只背机关零件" % id)
		t.check(float(d.base_stats.get("block", 0)) > 0, "%s：天生格挡" % id)
		t.check(d.immune_buffs.has(&"bleed") and d.immune_buffs.has(&"poison"), "%s：免疫流血、中毒" % id)
		t.eq(d.loot_filler, [&"brass_gear"] as Array[StringName], "%s：掉齿轮" % id)
	for id in [&"tinker_apprentice", &"clock_keeper"]:
		var d := c.enemies.enemy(id)
		t.check(d != null and not d.is_wild() and not d.bagless and d.immune_buffs.is_empty(), "%s 是人" % id)


static func run_block(t: TestCase) -> void:
	t.begin("210 · ⑤ 固定减伤：哨兵棋盘不要包；傀儡天生 4 + 两块护板 2 → 三层、生效 4；哨兵天生 2 与护板 2 一样高")
	var c := _content()
	var sentry := _build(c, &"clockwork_sentry", 5)
	var board := EnemyKit.board_of(sentry, c.items)
	t.check(not board.requires_bag, "哨兵棋盘不要求包")
	var golem := CombatantRuntime.from_spec(_spec(c, _build(c, &"gear_golem", 5)), 1)
	t.eq(golem.block_layers.size(), 3, "傀儡：两块护板 + 天生一层")
	t.eq(golem.block_layers[0]["id"], &"innate", "生效的是高的那层：天生（2 档再乘档位倍率）")
	t.check(StatMath.to_int(golem.block_effective_layer()) >= 4, "天生 ≥ 4（%d）" % StatMath.to_int(golem.block_effective_layer()))
	var rs := CombatantRuntime.from_spec(_spec(c, sentry), 1)
	t.eq(StatMath.to_int(rs.block_effective_layer()), 2, "哨兵：格挡 2")
	var bare := sentry.duplicate(true)
	bare["items"] = (bare["items"] as Array).filter(func(e): return String(e["id"]) != "brass_plating")
	var rb := CombatantRuntime.from_spec(_spec(c, bare), 1)
	t.eq([rb.block_layers.size(), StatMath.to_int(rb.block_effective_layer())], [1, 2], "拿掉护板：只剩天生那一层 2")


static func run_immune(t: TestCase) -> void:
	t.begin("210 · ⑥ 免疫：流血 / 中毒不叠、不发事件；灼伤照常；身上有灼伤时中毒打上来不引发爆燃；燃血不叠；悬浮读数写「免疫」")
	var c := _content()
	var spec := _spec(c, _build(c, &"gear_golem", 5))
	t.check(spec.immune_buffs.has(&"bleed") and spec.immune_buffs.has(&"scorched_blood"), "编译进了免疫表")
	var ctx: BattleContext = R._run([])
	ctx.sides[1].immune_buffs = spec.immune_buffs
	var before := ctx.log.size()
	R._apply("bleed", 2).apply(R._rc(ctx))
	R._apply("poison", 2).apply(R._rc(ctx))
	t.eq([ctx.sides[1].stacks_of(&"bleed"), ctx.sides[1].stacks_of(&"poison")], [0, 0], "流血、中毒都没叠上")
	var stacked := 0
	for i in range(before, ctx.log.size()):
		if (ctx.log[i] as BattleEvent).name == BattleEvent.STATUS_STACKED:
			stacked += 1
	t.eq(stacked, 0, "不发 STATUS_STACKED")
	R._apply("scorch", 2).apply(R._rc(ctx))
	t.eq(ctx.sides[1].stacks_of(&"scorch"), 2, "灼伤照常")
	R._apply("poison", 2).apply(R._rc(ctx))
	t.check(R._reactions(ctx).is_empty() and ctx.sides[1].stacks_of(&"scorch") == 2, "中毒打不上，也就不引发爆燃")
	t.eq(ctx.sides[1].apply_buff(R._b("scorched_blood"), 3, ctx.now), 0, "燃血不叠")
	var line := Prebattle.immune_text(spec)
	t.check(line.contains("免疫") and line.contains("流血") and line.contains("中毒"), "读数：%s" % line)
	t.eq(Prebattle.immune_text(_spec(c, _build(c, &"clock_keeper", 5))), "", "人没有免疫行")


static func run_parts(t: TestCase) -> void:
	t.begin("210 · ⑦ 零件两面：护板在玩家手里是一层格挡 2 的小盾；齿轮臂玩家面给相邻武器加急速、机关面自己出手；蒸汽阀机关面打火伤施加灼伤")
	var db := ItemDatabase.new()
	db.load_dir()
	var board := GridInventory.new(Vector2i(3, 3), 0, false)
	var knife := ItemInstance.create(db.get_def(&"knife"))
	var arm := ItemInstance.create(db.get_def(&"gear_arm"))
	var plate := ItemInstance.create(db.get_def(&"brass_plating"))
	board.place(knife, Vector2i(0, 0), 0)
	board.place(arm, Vector2i(1, 0), 0)
	board.place(plate, Vector2i(2, 0), 0)
	var mine := BattleCompiler.compile(board, CompileInput.new())
	var rt := CombatantRuntime.from_spec(mine, 0)
	t.eq([rt.block_layers.size(), StatMath.to_int(rt.block_effective_layer())], [1, 2], "护板：一层格挡 2")
	t.check(db.get_def(&"brass_plating").tags.has(&"shield") and db.get_def(&"brass_plating").tags.has(&"heavy"), "护板是盾、重")
	var plain := GridInventory.new(Vector2i(3, 3), 0, false)
	var k2 := ItemInstance.create(db.get_def(&"knife"))
	plain.place(k2, Vector2i(0, 0), 0)
	var base_haste := BattleCompiler.compile(plain, CompileInput.new()).item_of(k2.uid).stats.total_of(BattleStats.HASTE)
	t.check(mine.item_of(knife.uid).stats.total_of(BattleStats.HASTE) > base_haste, "齿轮臂挨着匕首：匕首急速更高")
	t.eq(mine.item_of(arm.uid).rules.size(), 0, "玩家面：齿轮臂自己不出手")
	var inp := CompileInput.new()
	inp.wild = true
	var wild := BattleCompiler.compile(board, inp)
	t.eq(wild.item_of(knife.uid).stats.total_of(BattleStats.HASTE), base_haste, "机关面：不跑邻接")
	t.check(not wild.item_of(arm.uid).rules.is_empty(), "机关面：齿轮臂自己出手")
	t.eq(wild.item_of(arm.uid).stats.total_of(BattleStats.DAMAGE), StatMath.from_float(10.0), "打 10")
	var vent := db.get_def(&"steam_vent")
	t.check(vent.wild_applies.size() == 1 and String(vent.wild_applies[0].buff.id) == "scorch", "蒸汽阀：机关面施加灼伤")
	t.check(vent.tags.has(&"crafted") and not vent.tags.has(&"nature") and not vent.tags.has(&"magic"), "零件是【工艺】")
	t.eq(db.get_def(&"mainspring").wild.base_stats.get("regen_stamina", 0.0), 2.0, "主发条：机关面回耐力")


static func run_loot(t: TestCase) -> void:
	t.begin("210 · ⑧ 掉落：机关不揣携带品，改带 1～2 个齿轮（标 carried 必掉）；人照旧掷携带品")
	var c := _content()
	for seed in 12:
		for id in CONSTRUCTS:
			var gears := 0
			var other_carried := 0
			for raw in _build(c, id, 100 + seed, c.carry)["items"]:
				if bool((raw as Dictionary).get("carried", false)):
					if String(raw["id"]) == "brass_gear":
						gears += 1
					else:
						other_carried += 1
			t.check(gears >= 1 and gears <= 2, "%s（种子 %d）：带 %d 个齿轮" % [id, seed, gears])
			t.eq(other_carried, 0, "%s（种子 %d）：没有别的携带品" % [id, seed])
	var ok := ImportReport.new()
	ContentImporter.import_enemy({"id": "t_filler_human", "strength": 0, "loot_filler": ["brass_gear"]}, ContentImporter.Context.new(), ok)
	t.check(ok.to_text().contains("替身"), "人写替身：提醒（%s）" % ok.to_text())
