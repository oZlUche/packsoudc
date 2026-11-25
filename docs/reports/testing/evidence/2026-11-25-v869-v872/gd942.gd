extends SceneTree
## 测试 v8.71（PR #942）无头：A 野兽战利品掉率（build_content 的 spoils + DropResolver.roll）；B 腺体：每次攻击敌我各叠一层
func _init() -> void:
	var c := TestSupport.load_content("free_mode")
	var rule := load(ContentPaths.asset_file("drop_rules", String(c.chapter.drop_rule))) as DropRule
	var ctx := LootContext.new(); ctx.difficulty = c.chapter.difficulty
	for e in ([] if OS.get_environment("ONLYB") != "" else [&"cave_bear", &"flame_wolf", &"pit_viper", &"frost_toad", &"tusk_boar", &"shock_eel", &"frost_mane", &"molten_lizard", &"thunder_vulture", &"miasma_spider"]):
		var def = c.enemies.enemy(e)
		var N := 2000
		var sp := {}; var dr := {}; var on_board := 0; var short := 0
		for i in N:
			var rng := RandomNumberGenerator.new(); rng.seed = 94200 + i
			var b: Dictionary = EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng)
			var content: Dictionary = b["content"]
			short += int(b.get("carry_short", content.get("carry_short", 0)))
			for x in content["items"]:
				if def.loot_chance.has(String(x["id"])) or def.loot_chance.has(StringName(String(x["id"]))): on_board += 1
			for s in content.get("spoils", []): sp[String(s)] = int(sp.get(String(s), 0)) + 1
			var r2 := RandomNumberGenerator.new(); r2.seed = 7000 + i
			var r := DropResolver.roll(content, rule, ctx, c.items, r2)
			var seen := {}
			for d in r["dropped"]:
				if def.loot_chance.has(String(d)) or def.loot_chance.has(StringName(String(d))):
					if not seen.has(String(d)): dr[String(d)] = int(dr.get(String(d), 0)) + 1
					seen[String(d)] = 1
		var parts := []
		for k in def.loot_chance:
			parts.append("%s 表 %.0f%% 掷中 %.1f%% 实掉 %.1f%%" % [String(k), float(def.loot_chance[k]) * 100.0, 100.0 * int(sp.get(String(k), 0)) / N, 100.0 * int(dr.get(String(k), 0)) / N])
		print("GD942A %s（%s，棋盘 %s）%d 场：%s；战利品摆在它棋盘上 %d 件；战斗道具没摆下 %d 件" % [String(e), Names.of(def), str(def.board), N, "；".join(parts), on_board, short])
	# B：腺体
	for t in [{}, {&"scorch": 1}, {&"chill": 1}, {&"poison": 1}, {&"poison": 2}, {&"scorch": 1, &"chill": 1}]:
		var board := GridInventory.new(Vector2i(6, 6))
		TestSupport.put(board, c.items.get_def(&"knife"))
		var input := CompileInput.new()
		OrganTraits.apply_values(input, t)
		var me := BattleCompiler.compile(board, input)
		me.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); me.max_hp = me.baseline.total_of(BattleStats.MAX_HP)
		var foe := CombatantSpec.new(); foe.baseline = StatSet.new(); foe.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(99999.0)); foe.max_hp = foe.baseline.total_of(BattleStats.MAX_HP)
		var rng := RandomNumberGenerator.new(); rng.seed = 942
		var br := BattleSim.run(me, foe, rng, 10.0)
		var fired := 0; var added := {}; var first := []; var reacts := 0; var names := {}; var dmg := {0: 0.0, 1: 0.0}
		for e in br.log:
			if e.name == BattleEvent.ITEM_FIRED and e.side == 0: fired += 1
			if e.name == BattleEvent.STATUS_STACKED and e.get_int(&"delta") > 0:
				var k := "%s@%s" % [String(e.payload.get("buff", "")), "我" if e.side == 0 else "敌"]
				added[k] = int(added.get(k, 0)) + e.get_int(&"delta")
				if first.size() < 4: first.append("%.2fs %s +%d=%d" % [StatMath.to_float(e.time) if "time" in e else 0.0, k, e.get_int(&"delta"), e.get_int(&"stacks")])
			names[String(e.name)] = int(names.get(String(e.name), 0)) + 1
			if String(e.name).contains("react"): reacts += 1
			if e.name == BattleEvent.DAMAGE: dmg[e.side] = float(dmg.get(e.side, 0.0)) + StatMath.to_float(e.get_int(&"amount"))
		print("GD942B 特性 %s：10 秒我方武器出手 %d 次；叠上去的层数 %s；反应事件 %d；前几条 %s；受到伤害 我 %.1f 敌 %.1f；特性一行 %s；事件 %s" % [str(t), fired, str(added), reacts, str(first), float(dmg.get(0, 0.0)), float(dmg.get(1, 0.0)), str(OrganTraits.lines(t)), str(names)])
	quit(0)
