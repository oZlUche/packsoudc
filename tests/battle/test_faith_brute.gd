## 信仰重构 D（交接方案 §6.1）：蛮神「承压反击」—— 受对手的伤按掉的血积怒气（上限 5）；下一下武器伤害用掉、每层加伤；
## 一阶用得多穿透护甲；二阶低血积得快；三阶不屈 3 秒；低血打赢记进战斗账；秒杀不记战斗信力
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")
const ID := BruteRage.BUFF_ID


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _me(tier: int, hp: float = 1000.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_club", ["1"], 10.0, 2.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	var rules: Array[AbilityRule] = []
	if tier >= 0:
		rules.append(BruteRagePerk.new().rule_at(tier))
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(hp), [] as Array[StatModifier], rules)


static func _hitter(dmg: float) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_foe", ["1"], dmg, 1.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(50000.0))


static func _mech(res: BattleResult, key: String) -> Array:
	var out: Array = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			out.append(e)
	return out


static func _gained(res: BattleResult) -> Array:
	var n := 0
	var top := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and e.get_name(&"buff") == ID and e.get_int(&"delta") > 0:
			n += e.get_int(&"delta")
			top = maxi(top, e.get_int(&"stacks"))
	return [n, top]


static func _lost(res: BattleResult) -> float:
	var n := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0 and e.get_int(&"source_side", -1) == 1:
			n += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	return n


static func run_gather_and_spend(t: TestCase) -> void:
	t.begin("信仰重构 D · 怒气：按掉的血积（每 5% 一层、上限 5）、木桩不打人就没有、反击写战记")
	var r := BattleSim.run(_me(0), _hitter(30.0), _rng(1), 12.0)
	var g := _gained(r)
	t.check(int(g[0]) > 0, "挨打积了怒气（%d 层）" % int(g[0]))
	t.check(int(g[0]) <= floori(_lost(r) / 50.0), "积的层数不超过掉的血 / 5%%（%d ≤ %d）" % [int(g[0]), floori(_lost(r) / 50.0)])
	t.check(int(g[1]) <= 5, "任何时候不超过 5 层（最多 %d）" % int(g[1]))
	t.check(not _mech(r, "brute_strike").is_empty(), "武器打出去用掉怒气，战记写了反击")
	t.check(not UiText.t("log.brute_strike").is_empty() and UiText.t("log.brute_strike") != "log.brute_strike", "战记那句在字表里")
	var calm := BattleSim.run(_me(0), FX._spec(5000.0, []), _rng(1), 12.0)
	t.eq(int(_gained(calm)[0]), 0, "对手不打人：没有怒气")
	var again := BattleSim.run(_me(0), _hitter(30.0), _rng(1), 12.0)
	t.eq(again.log.size(), r.log.size(), "同种子同结果")


static func run_tiers(t: TestCase) -> void:
	t.begin("信仰重构 D · 怒气：基础不穿甲、一阶攒够那一下穿甲；二阶低血积得快；三阶不屈 3 秒")
	var pierce0 := 0
	var pierce1 := 0
	for pair in [[0, BattleSim.run(_me(0), _hitter(60.0), _rng(3), 12.0)], [1, BattleSim.run(_me(1), _hitter(60.0), _rng(3), 12.0)]]:
		for raw in (pair[1] as BattleResult).log:
			var e := raw as BattleEvent
			if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_bool(&"penetration"):
				if int(pair[0]) == 0:
					pierce0 += 1
				else:
					pierce1 += 1
	t.eq(pierce0, 0, "基础：用多少怒气都不穿甲")
	t.check(pierce1 > 0, "一阶：用掉 3 层以上那一下穿甲（%d 下）" % pierce1)
	var low1 := BattleSim.run(_me(1, 400.0), _hitter(30.0), _rng(4), 12.0)
	var low2 := BattleSim.run(_me(2, 400.0), _hitter(30.0), _rng(4), 12.0)
	t.check(int(_gained(low2)[0]) > int(_gained(low1)[0]), "二阶：低血积得快（%d > %d）" % [int(_gained(low2)[0]), int(_gained(low1)[0])])
	var perk := BruteRagePerk.new()
	var in2 := CompileInput.of(CombatantBaseline.with_hp(100.0))
	perk.compile_at(in2, 2)
	t.eq(in2.undying_sec, 0.0, "二阶没有不屈")
	var in3 := CompileInput.of(CombatantBaseline.with_hp(100.0))
	perk.compile_at(in3, 3)
	t.eq(in3.undying_sec, 3.0, "三阶不屈 3 秒（封顶，不随信力涨）")
	t.eq(in3.rules.size(), 1, "只放一条规则")


static func run_ledger(t: TestCase) -> void:
	t.begin("信仰重构 D · 蛮神的战斗账：低血打赢记一笔、没打赢不记；打赢 6 + 反击 2 + 低血 2")
	var r := BattleResult.new()
	var hp := BattleEvent.make(BattleEvent.RESOURCE_CHANGED, 100, 0, {"key": "hp", "delta": -10, "reason": "damage", "current": StatMath.from_float(20.0), "max": StatMath.from_float(100.0)})
	var strike := BattleEvent.make(BattleEvent.EFFECT_RESOLVED, 50, 0, {"effect": SkillMomentum.MECHANIC, "key": "brute_strike", "count": 3})
	r.log = [strike, hp]
	var won := RunState.battle_summary(r, true, null)
	t.eq(int((won["mechanic"] as Dictionary).get("low_hp_won", 0)), 1, "打赢时 20% 生命：低血打赢")
	t.eq(int((RunState.battle_summary(r, false, null)["mechanic"] as Dictionary).get("low_hp_won", 0)), 0, "输了不算")
	var def := load("res://data/faiths/brute.tres") as FaithDef
	var sum := 0
	for d in def.deeds:
		sum += (d as FaithDeed).gain(&"battle", won)
	t.eq(sum, 10, "打赢 6 + 反击 2 + 低血打赢 2 = 每场上限 10")
	t.eq(def.thresholds, [20, 60, 120] as Array[int], "三阶 20 / 60 / 120")
