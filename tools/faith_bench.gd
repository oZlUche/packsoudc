## 信仰重构 E（交接方案 §10.2）：六神配装对照台架 —— 同一批流派木桩（同一份道具、同样摆），只差奉哪位神、开到几阶；
## 对敌人池每一档各打 N 场固定种子，记胜率、时长、剩血、核心机制首次触发的时刻与次数、每场信力。
##
##     godot --headless --path . --script res://tools/faith_bench.gd -- [每格场数=12] [种子=1] [输出=docs/reports/testing/<日期>-faith-bench.md]
##
## 木桩 `archetypes.json`；流派 burst（重击）/ rapid（快攻）/ shield（防守）× 段 0（低预算）/ 段 2（中期）。
## 敌人池 standard_ruins，节点规则 standard（时限、加时同一局里的战斗）。机制参数用构件默认值（= 现在的数据）。
## 只打印，不改数
extends CliTool

const NODE_RULES := "standard"
const POOL := "standard_ruins"
const ARCHETYPES: Array[String] = ["burst", "rapid", "shield"]
const BRACKETS: Array[int] = [0, 2]
const GODS: Array[StringName] = [&"", &"skill", &"hunt", &"earth", &"brute", &"sun", &"nature"]
const TIERS: Array[int] = [0, 3]
## 开战那一刻就有、不算「触发」的战记
const OPENING_KEYS: Array[String] = ["hunt_mark", "sun_open", "sun_close", "earth_support"]
const BUFFS := {&"skill": &"skill_momentum", &"hunt": &"hunt_dismantle", &"brute": &"brute_rage", &"nature": &"nature_regrowth"}


func run() -> void:
	var split := split_args(OS.get_cmdline_user_args())
	var args: Array[String] = split["pos"]
	var fights := int(args[0]) if args.size() > 0 else 12
	var seed_ := int(args[1]) if args.size() > 1 else 1
	var date := Time.get_date_string_from_system()
	var out_path: String = args[2] if args.size() > 2 else "res://docs/reports/testing/%s-faith-bench.md" % date
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := ContentPaths.load_asset("enemy_pools", POOL) as EnemyPool
	var dummies := DummyBuilder.load_file(ArchetypeBuilder.DEFAULT_PATH)
	var rules := ContentPaths.load_asset("node_rules", NODE_RULES) as NodeRules
	var limit := rules.battle_time_limit if rules != null else BattleSim.DEFAULT_TIME_LIMIT
	var overtime: OvertimeRules = rules.overtime if rules != null else null
	var faiths := FaithDef.load_all()
	if pool == null or dummies.is_empty():
		print("没有敌人池或木桩")
		finish(1)
		return
	var node := MapNode.new()
	node.id = 0
	node.type = &"battle"
	var started := Time.get_ticks_msec()
	var lines: Array[String] = ["# 六神配装对照 %s" % date, "",
		"- git %s；木桩 `%s`；敌人池 `%s`；节点规则 `%s`（时限 %.0f 秒）；每格 %d 场，种子 %d。" % [_git_hash(), ArchetypeBuilder.DEFAULT_PATH, POOL, NODE_RULES, limit, fights, seed_],
		"- 每行一位神 × 阶 × 流派 × 段，对敌人池每一档合计。「无」= 不奉神（对照）。",
		"- 首触发：核心机制第一次真的发生（开战就写的那几句不算）的平均秒数，没发生的场不计；次数 = 每场平均。",
		"- 信力：按这位神的信力行为对每场战斗账算的平均（打赢 6 + 机制，封顶 10；不含献祭、置入）。", ""]
	var tiers := pool.strengths()
	var by_tier := {}     # 对照（不奉神）每一档：[场数, 胜, 时长合计, 超过 6 秒的场数]
	lines.append("| 神 | 阶 | 流派 | 段 | 场数 | 胜率 | 时长 | 剩血 | 首触发 | 次数 | 信力 |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
	for god in GODS:
		for tier in (TIERS if god != &"" else [0]):
			for a in ARCHETYPES:
				for k in BRACKETS:
					var snaps: Array = []
					for key in dummies:
						var d: Dictionary = dummies[key]
						if String(d.get("archetype", "")) == a and int(d.get("bracket", -1)) == k:
							snaps.append(d)
					if snaps.is_empty():
						continue
					var acc := {"n": 0, "win": 0, "dur": 0.0, "hp": 0.0, "first": 0.0, "first_n": 0, "count": 0, "devotion": 0}
					var specs: Array[CombatantSpec] = []
					for d in snaps:
						specs.append(_spec(d, items, god, tier))
					for strength in tiers:
						for i in fights:
							var rng := RandomNumberGenerator.new()
							rng.seed = hash("%d:%d:%d" % [seed_, strength, i])
							var entry := EnemyPlacer.pick(pool, enemies, node, strength, rng)
							if entry == null:
								continue
							var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, items, strength, rng).get("content", {})
							var enemy := EnemyKit.spec_of(content, enemies, pool, items)
							if enemy == null:
								continue
							var res := BattleSim.run(specs[i % specs.size()], enemy, rng, limit, overtime)
							_tally(acc, res, god, faiths.get(god, null) as FaithDef)
							if god == &"":
								var row: Array = by_tier.get_or_add(strength, [0, 0, 0.0, 0])
								row[0] = int(row[0]) + 1
								row[1] = int(row[1]) + (1 if res.winner == 0 else 0)
								row[2] = float(row[2]) + res.duration_sec()
								row[3] = int(row[3]) + (1 if res.duration_sec() >= 6.0 else 0)
					var n := maxi(1, int(acc["n"]))
					lines.append("| %s | %s | %s | %d | %d | %.0f%% | %.1f | %.0f%% | %s | %.1f | %.1f |" % [
						_god_name(god, faiths), str(tier) if god != &"" else "—", a, k, int(acc["n"]),
						100.0 * int(acc["win"]) / n, float(acc["dur"]) / n,
						100.0 * float(acc["hp"]) / maxi(1, int(acc["win"])),
						("%.1f" % (float(acc["first"]) / int(acc["first_n"]))) if int(acc["first_n"]) > 0 else "—",
						float(acc["count"]) / n, float(acc["devotion"]) / n])
	lines.append("")
	lines.append("## 对照（不奉神）按敌人档")
	lines.append("")
	lines.append("| 档 | 场数 | 胜率 | 平均时长 | 打到 6 秒以上 |")
	lines.append("|---|---|---|---|---|")
	for strength in tiers:
		var row: Array = by_tier.get(strength, [0, 0, 0.0, 0])
		var cnt := maxi(1, int(row[0]))
		lines.append("| %d | %d | %.0f%% | %.1f | %.0f%% |" % [strength, int(row[0]), 100.0 * int(row[1]) / cnt, float(row[2]) / cnt, 100.0 * int(row[3]) / cnt])
	lines.append("")
	lines.append("共用 %.0f 秒。" % ((Time.get_ticks_msec() - started) / 1000.0))
	var md := "\n".join(lines) + "\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	if not write_text(out_path, md):
		return
	print(md)
	print("写入 %s" % out_path)
	finish(0)


## 木桩照 [method CalibrationRecorder.compile] 编，另外按 [param god] 的 [param tier] 阶放进信仰机制（构件默认值）
static func _spec(snap: Dictionary, items: ItemDatabase, god: StringName, tier: int) -> CombatantSpec:
	var input := CompileInput.of(CalibrationRecorder.baseline_of(snap))
	input.scoped.append_array(CalibrationRecorder.scoped_of(snap))
	var axes: Dictionary = snap.get("axes", {})
	for axis in axes:
		input.shift_axis(StringName(String(axis)), int(axes[axis]))
	var board := CalibrationRecorder.board_of(snap, items)
	input.faith = FaithState.assembled_tag(board)
	match god:
		&"skill":
			input.rules.append(SkillMomentumPerk.new().rule_at(tier))
		&"hunt":
			input.rules.append(HuntDismantlePerk.new().rule_at(tier))
		&"earth":
			EarthSupportPerk.new().compile_at(input, board, tier)
		&"brute":
			BruteRagePerk.new().compile_at(input, tier)
		&"sun":
			input.rules.append(SunCyclePerk.new().rule_at(tier))
		&"nature":
			input.rules.append(NatureRegrowthPerk.new().rule_at(tier, NatureRegrowthPerk.food_on(board)))
	return BattleCompiler.compile(board, input)


static func _tally(acc: Dictionary, res: BattleResult, god: StringName, def: FaithDef) -> void:
	acc["n"] = int(acc["n"]) + 1
	acc["dur"] = float(acc["dur"]) + res.duration_sec()
	var won := res.winner == 0
	if won:
		acc["win"] = int(acc["win"]) + 1
		var left: Variant = BattleMetrics.hp_ratio(res, 0)
		acc["hp"] = float(acc["hp"]) + (float(left) if left != null else 0.0)
	if god == &"":
		return
	var first := -1
	var count := 0
	var buff: StringName = BUFFS.get(god, &"")
	for raw in res.log:
		var e := raw as BattleEvent
		var hit := false
		if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC:
			hit = not OPENING_KEYS.has(String(e.payload.get("key", "")))
			if god == &"earth" and String(e.payload.get("key", "")) == "earth_support" and int(e.payload.get("count", 0)) > 0:
				hit = true     # 大地是静态的：开战有大件受承托就算
		elif buff != &"" and e.name == BattleEvent.STATUS_STACKED and e.get_name(&"buff") == buff and e.get_int(&"delta") > 0 and e.time > 0:
			hit = true
		if hit:
			count += 1
			if first < 0:
				first = e.time
	acc["count"] = int(acc["count"]) + count
	if first >= 0:
		acc["first"] = float(acc["first"]) + StatMath.to_float(first)
		acc["first_n"] = int(acc["first_n"]) + 1
	if def != null:
		var summary := RunState.battle_summary(res, won, null)
		var pts := 0
		for d in def.deeds:
			pts += (d as FaithDeed).gain(&"battle", summary)
		acc["devotion"] = int(acc["devotion"]) + pts


static func _god_name(god: StringName, faiths: Dictionary) -> String:
	if god == &"":
		return "无"
	return Names.of(faiths[god]) if faiths.has(god) else String(god)


static func _git_hash() -> String:
	var out: Array = []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], out)
	return String(out[0]).strip_edges() if not out.is_empty() else "?"
