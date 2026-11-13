## 难度候选 D4（报告 303，材料与难度方案 §7.2）：处决武器按对手的生命阶段看。
##
## 焰纹处刑巨刃的第二条规则只在对手生命不高于 29% 时多打一下。打不死的木桩（[PowerBench]）的生命永远在高位，
## 这一条从来不出手，所以木桩 DPS 看不出它值多少。这里让巨刃单独对真实敌人打：敌人开场先掉到指定的生命阶段，
## 同一场有处决 / 去掉处决各打一遍，逐场配对出打死比例和打死用时的差。玩家这边打不死（只量武器，不量生存），只出表，不改数。
## 命令行外壳 `tools/execution_phase.gd`
class_name ExecutionPhase
extends RefCounted

const WEAPON := &"flame_execution_blade"
## 敌人开场的生命比例：满血、中段、已在处决线以下
const PHASES: Array[float] = [1.0, 0.6, 0.29]
## 玩家这一方的基础属性：耐力同木桩的段 3 那一份，生命打不死（[constant PowerBench.UNDYING_HP]）
const BASELINE := {"max_hp": PowerBench.UNDYING_HP, "max_stamina": 65.0, "regen_stamina": 5.0}


## 只带这一件武器的玩家；[param execute] 关掉就把对手生命触发的那条（出手后再判）去掉
static func player(items: ItemDatabase, execute: bool, weapon: StringName = WEAPON) -> CombatantSpec:
	var snap := {"board_size": [8, 6], "requires_bag": false, "baseline": BASELINE,
		"layout": [{"id": String(weapon), "origin": [0, 0], "rot": 0}]}
	var spec := DummyBuilder.compile(snap, items)
	if not execute:
		for it in spec.items:
			var c := it as CompiledItem
			var kept: Array[AbilityRule] = []
			for r in c.rules:
				if not ((r as AbilityRule).trigger is OnItemFired):
					kept.append(r)
			c.rules = kept
	return spec


## 跑一遍。[param ctx]：pool、enemies、items、fights（每个敌人每档）、seed、time_limit、overtime。
## 返回行：{tier, phase, n, win_on, win_off, win_diff, dur_on, dur_off, dur_diff}（win = 时限内打死；时长只算打死的场）
static func run(ctx: Dictionary) -> Array:
	var pool: EnemyPool = ctx["pool"]
	var enemies: EnemyDatabase = ctx["enemies"]
	var items: ItemDatabase = ctx["items"]
	var fights := maxi(1, int(ctx.get("fights", 50)))
	var p_seed := int(ctx.get("seed", 1))
	var limit := float(ctx.get("time_limit", BattleSim.DEFAULT_TIME_LIMIT))
	var overtime: OvertimeRules = ctx.get("overtime", null)
	var targets := BalanceExperiment.coverage_targets(pool, enemies)
	var me_on := player(items, true)
	var me_off := player(items, false)
	var rows: Array = []
	for tier in pool.strengths():
		for phase in PHASES:
			var win: Array = []
			var dur: Array = []
			var won_on: Array = []
			var won_off: Array = []
			var d_on: Array = []
			var d_off: Array = []
			for target in targets:
				for i in fights:
					var s := BalanceExperiment.case_seed(p_seed, tier, i, target)
					var r0 := RandomNumberGenerator.new()
					r0.seed = s
					var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(target), pool, items, tier, r0).get("content", {})
					if content.is_empty():
						continue
					var on := _fight(me_on, content, ctx, phase, r0.state, s, limit, overtime)
					var off := _fight(me_off, content, ctx, phase, r0.state, s, limit, overtime)
					if on.is_empty() or off.is_empty():
						continue
					win.append([on["win"], off["win"]])
					won_on.append(on["win"])
					won_off.append(off["win"])
					var a: Variant = on["duration"] if on["win"] > 0.0 else null
					var b: Variant = off["duration"] if off["win"] > 0.0 else null
					d_on.append(a)
					d_off.append(b)
					if a != null and b != null:
						dur.append([a, b])
			rows.append({"tier": tier, "phase": phase, "n": win.size(),
				"win_on": BalanceStatistics.mean(won_on), "win_off": BalanceStatistics.mean(won_off),
				"win_diff": BalanceStatistics.paired_bootstrap(win),
				"dur_on": BalanceStatistics.quantiles(d_on).get("p50"), "dur_off": BalanceStatistics.quantiles(d_off).get("p50"),
				"dur_diff": BalanceStatistics.paired_bootstrap(dur)})
	return rows


## 一场：敌人开场生命先降到 [param phase]，其余照常。返回 {win: 1.0 / 0.0, duration}；造不出敌人返回空
static func _fight(me: CombatantSpec, content: Dictionary, ctx: Dictionary, phase: float, state: int, s: int, limit: float,
		overtime: OvertimeRules) -> Dictionary:
	var foe := EnemyKit.spec_of(content, ctx["enemies"], ctx["pool"], ctx["items"])
	if foe == null:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	rng.state = state
	var bctx := BattleContext.create(CombatantRuntime.from_spec(me, 0), CombatantRuntime.from_spec(foe, 1), rng)
	bctx.overtime = OvertimeRules.or_default(overtime)
	if phase < 1.0:
		var res: ResourcePool = bctx.sides[1].resources
		var cut := res.current(BattleStats.RES_HP) - int(res.maximum(BattleStats.RES_HP) * phase)
		res.change(BattleStats.RES_HP, -cut, BattleEvent.REASON_DAMAGE)
	var result := BattleSim.run_context(bctx, limit)
	return {"win": 1.0 if BattleMetrics.outcome_of(result, limit) == BattleMetrics.WIN else 0.0, "duration": result.duration_sec()}


## 打不死的木桩上量一遍（[PowerBench.measure]，中档对手）：有处决 / 去掉处决各一个 DPS
static func dummy_dps(items: ItemDatabase) -> Array[float]:
	var w := PowerWeights.load_from()
	var def := items.get_def(WEAPON)
	var bare := def.duplicate(false) as ItemDef
	bare.combat = def.combat.duplicate(false) as CombatProfile
	var kept: Array[AbilityRule] = []
	for r in def.combat.rules:
		if not ((r as AbilityRule).trigger is OnItemFired):
			kept.append(r)
	bare.combat.rules = kept
	return [PowerBench.measure([def] as Array[ItemDef], w.opponent_dps, w.horizon_sec, 3, w),
		PowerBench.measure([bare] as Array[ItemDef], w.opponent_dps, w.horizon_sec, 3, w)]


static func _pct(v: Variant) -> String:
	return "—" if v == null else "%.0f%%" % (float(v) * 100.0)


static func _diff(d: Dictionary, scale: float, fmt: String) -> String:
	if d.get("diff") == null:
		return "—"
	return fmt % [float(d["diff"]) * scale, float(d["lo"]) * scale, float(d["hi"]) * scale]


static func _s(v: Variant) -> String:
	return "—" if v == null else "%.2f" % float(v)


static func markdown(rows: Array, dps: Array[float], header: Array[String]) -> String:
	var lines: Array[String] = ["## D4", ""]
	lines.append_array(header)
	lines.append("")
	lines.append("打不死的木桩（[PowerBench]，中档对手）：有处决 %.1f / 去掉处决 %.1f 每秒。" % [dps[0], dps[1]])
	lines.append("")
	lines.append("玩家打不死，只量武器。差值为逐场配对的平均差（有处决 − 去掉处决），括号里是 95% 区间；用时只算两边都打死的场。")
	lines.append("")
	lines.append("| 档 | 敌人开场生命 | 场数 | 有处决打死 | 去掉处决打死 | 打死比例差（百分点） | 有处决用时中位 | 去掉处决用时中位 | 用时差（秒） |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for row in rows:
		var r := row as Dictionary
		lines.append("| %d | %d%% | %d | %s | %s | %s | %s | %s | %s |" % [r["tier"], roundi(float(r["phase"]) * 100.0), r["n"],
			_pct(r["win_on"]), _pct(r["win_off"]), _diff(r["win_diff"], 100.0, "%+.1f（%+.1f～%+.1f）"),
			_s(r["dur_on"]), _s(r["dur_off"]), _diff(r["dur_diff"], 1.0, "%+.2f（%+.2f～%+.2f）")])
	return "\n".join(lines) + "\n"
