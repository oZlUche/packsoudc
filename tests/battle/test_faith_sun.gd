## 信仰重构 D（交接方案 §6.2；E 批缩短）：日神「周期」—— 第 2 秒起每 4 秒烈日 2 秒（半开区间）；窗口里每件武器头一下追加 20% 火焰；
## 一阶窗外出手蓄力（最多 3 次）；三阶每第 3 次 ×1.5；有追加的窗口按次给信力、封顶
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _me(tier: int, cd: float = 0.5, two: bool = false) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_blade", ["1"], 10.0, cd, ["weapon", "melee"])), Vector2i(0, 0), 0)
	if two:
		b.place(ItemInstance.create(Comp._weapon("t_bow", ["1"], 10.0, cd, ["weapon", "ranged"])), Vector2i(1, 0), 0)
	var rules: Array[AbilityRule] = [SunCyclePerk.new().rule_at(tier)]
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(5000.0), [] as Array[StatModifier], rules)


static func _mech(res: BattleResult, key: String) -> Array:
	var out: Array = []
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			out.append(e)
	return out


## 追加的火焰：[时刻, 量, 触发它的那一下的量]
static func _extras(res: BattleResult) -> Array:
	var out: Array = []
	var last_hit := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name != BattleEvent.DAMAGE or e.side != 1 or e.get_int(&"source_side", -1) != 0:
			continue
		if e.get_int(&"uid") != 0:
			last_hit = e.get_int(&"amount")
		elif String(e.payload.get("type", "")) == "fire":
			out.append([e.time, e.get_int(&"amount"), last_hit])
	return out


static func run_windows(t: TestCase) -> void:
	t.begin("信仰重构 D · 烈日：半开区间 [2 + 4k, 4 + 4k)；开、关写战记；窗口里每件武器只追加一次")
	var eff := SunCycle.new()
	t.eq(eff.window_at(StatMath.from_float(1.99)), 0, "第 2 秒之前没有")
	t.eq(eff.window_at(StatMath.from_float(2.0)), 1, "第 2 秒整：第 1 个窗口")
	t.eq(eff.window_at(StatMath.from_float(3.99)), 1, "3.99 秒还在")
	t.eq(eff.window_at(StatMath.from_float(4.0)), 0, "第 4 秒整：关了（半开）")
	t.eq(eff.window_at(StatMath.from_float(6.5)), 2, "6.5 秒：第 2 个")
	var r := BattleSim.run(_me(0), FX._spec(50000.0, []), _rng(1), 7.0)
	t.eq(_mech(r, "sun_open").size(), 2, "7 秒里开了两次（2、6）")
	t.eq(_mech(r, "sun_close").size(), 1, "关了一次（4）")
	var ex := _extras(r)
	t.eq(ex.size(), 2, "一件武器：每个窗口追加一次（%d）" % ex.size())
	var inside := true
	for x in ex:
		if eff.window_at(int(x[0])) == 0:
			inside = false
	t.check(inside, "追加都在窗口里")
	t.check(not ex.is_empty() and int(ex[0][1]) == StatMath.mul(int(ex[0][2]), StatMath.from_percent(20)), "追加 = 这一下的 20%")
	var two := BattleSim.run(_me(0, 0.5, true), FX._spec(50000.0, []), _rng(1), 3.5)
	t.eq(_extras(two).size(), 2, "两件武器：同一个窗口各追加一次")
	var again := BattleSim.run(_me(0), FX._spec(50000.0, []), _rng(1), 7.0)
	t.eq(again.log.size(), r.log.size(), "同种子同结果")


static func run_tiers(t: TestCase) -> void:
	t.begin("信仰重构 D · 烈日：一阶窗外蓄力（最多 3 次 × 10%）；三阶每第 3 个窗口 ×1.5")
	var one := _extras(BattleSim.run(_me(1), FX._spec(50000.0, []), _rng(2), 3.0))
	t.check(not one.is_empty() and int(one[0][1]) == StatMath.mul(int(one[0][2]), StatMath.from_percent(50)), "一阶：蓄满 3 次，追加 20% + 30%")
	var three := _extras(BattleSim.run(_me(3, 1.5), FX._spec(50000.0, []), _rng(2), 11.0))
	var strong := -1
	for x in three:
		if SunCycle.new().window_at(int(x[0])) == 3:
			strong = int(x[1])
	t.check(strong > 0, "三阶：第 3 个窗口也有追加")
	var base := 0
	for x in three:
		if SunCycle.new().window_at(int(x[0])) == 1:
			base = int(x[1])
	t.check(strong > base, "第 3 个窗口比第 1 个强（%d > %d）" % [strong, base])


static func run_ledger(t: TestCase) -> void:
	t.begin("信仰重构 D · 日神的信力：打赢 6；有追加的窗口每个 +2、最多 4；三阶 20 / 60 / 120")
	var def := load("res://data/faiths/sun.tres") as FaithDef
	var sum := func(mech: Dictionary, won: bool) -> int:
		var n := 0
		for d in def.deeds:
			n += (d as FaithDeed).gain(&"battle", {"won": won, "mechanic": mech, "dealt": {}, "taken": {}, "fired_items": []})
		return n
	t.eq(sum.call({"sun_window": 1}, true), 8, "一个窗口：6 + 2")
	t.eq(sum.call({"sun_window": 5}, true), 10, "五个窗口：封顶 4")
	t.eq(sum.call({"sun_window": 2}, false), 4, "输了保留已经做到的")
	t.eq(def.thresholds, [20, 60, 120] as Array[int], "三阶")
