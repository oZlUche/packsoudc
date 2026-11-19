## 信仰重构 D（交接方案 §6.3）：自然之神「恢复存量」—— 每 6 秒回 2% 生命；实际回的 20% 存进生息（上限 15%）；满血不存；
## 一阶低血放出（隔 6 秒，放出的不再存）；二阶食物加容量（最多 3 件）；三阶进加时给守护
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")
const ID := NatureRegrowth.BUFF_ID


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func _me(tier: int, hp: float = 1000.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_stick", ["1"], 1.0, 2.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	var rules: Array[AbilityRule] = [NatureRegrowthPerk.new().rule_at(tier)]
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


static func _top(res: BattleResult) -> int:
	var top := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if (e.name == BattleEvent.STATUS_STACKED or e.name == BattleEvent.STATUS_UNSTACKED) and e.side == 0 and e.get_name(&"buff") == ID:
			top = maxi(top, e.get_int(&"stacks"))
	return top


static func run_store(t: TestCase) -> void:
	t.begin("信仰重构 D · 生息：周期治疗回 2%、实际回的 20% 存进去、满血不存、存量封顶")
	var r := BattleSim.run(_me(0), _hitter(30.0), _rng(1), 13.0)
	var heals := 0
	for raw in r.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.payload.get("key", "")) == "hp" and String(e.payload.get("reason", "")) == "heal" and e.get_int(&"delta") > 0:
			heals += 1
	t.eq(heals, 2, "13 秒里周期治疗两次（6、12）")
	t.eq(_top(r), 8, "两次各回 20，存 20% = 8 点生息")
	var full := BattleSim.run(_me(0), FX._spec(50000.0, []), _rng(1), 13.0)
	t.eq(_top(full), 0, "一直满血：治疗没回上来，也就不存")
	var long := BattleSim.run(_me(0), _hitter(30.0), _rng(1), 120.0)
	t.check(_top(long) <= 150, "存量不超过最大生命的 15%%（%d）" % _top(long))
	var again := BattleSim.run(_me(0), _hitter(30.0), _rng(1), 13.0)
	t.eq(again.log.size(), r.log.size(), "同种子同结果")


static func run_release(t: TestCase) -> void:
	t.begin("信仰重构 D · 生息：基础不放；一阶低血放出、两次至少隔 6 秒、放出的不再存")
	var zero := BattleSim.run(_me(0, 300.0), _hitter(25.0), _rng(2), 30.0)
	t.eq(_mech(zero, "nature_release").size(), 0, "基础：不放")
	var one := BattleSim.run(_me(1, 300.0), _hitter(25.0), _rng(2), 30.0)
	var rel := _mech(one, "nature_release")
	t.check(not rel.is_empty(), "一阶：低血放出生息（%d 次）" % rel.size())
	var gap_ok := true
	for i in range(1, rel.size()):
		if (rel[i] as BattleEvent).time - (rel[i - 1] as BattleEvent).time < StatMath.from_float(6.0):
			gap_ok = false
	t.check(gap_ok, "两次至少隔 6 秒")
	t.check(not UiText.t("log.nature_release").is_empty() and UiText.t("log.nature_release") != "log.nature_release", "战记那句在字表里")


static func run_food_and_guard(t: TestCase) -> void:
	t.begin("信仰重构 D · 生息：二阶食物加容量（最多 3 件）；棋盘数食物不数不参战的；三阶进加时给守护")
	var b := GridInventory.new(Vector2i(6, 4), 1, false)
	for i in 4:
		b.place(ItemInstance.create(Comp._weapon("t_food%d" % i, ["1"], 0.0, 9.0, ["food"])), Vector2i(i, 0), 0)
	t.eq(NatureRegrowthPerk.food_on(b), 4, "棋盘上 4 件食物")
	(b.items()[0] as ItemInstance).set_benched(true)
	t.eq(NatureRegrowthPerk.food_on(b), 3, "标了不参战的不算")
	var spec := FX._spec(1000.0, [])
	var rt := CombatantRuntime.from_spec(spec, 0)
	var eff := NatureRegrowth.new()
	eff.food = 5
	eff.tier = 1
	var c1 := eff.capacity(rt)
	t.eq(c1, StatMath.from_float(150.0), "一阶：容量 15%")
	eff.tier = 2
	t.eq(eff.capacity(rt), c1 + StatMath.from_float(60.0), "二阶：5 件按 3 件算，+6%")
	var guard := BattleSim.run(_me(3), FX._spec(500000.0, []), _rng(3), 32.0)
	var got := false
	for raw in guard.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 0 and e.get_name(&"buff") == NatureRegrowth.GUARD_ID:
			got = e.time >= StatMath.from_float(30.0)
	t.check(got, "进加时（30 秒）得到守护")
	t.eq(_mech(guard, "nature_guard").size(), 1, "一场一次")
	var two := BattleSim.run(_me(2), FX._spec(500000.0, []), _rng(3), 32.0)
	t.eq(_mech(two, "nature_guard").size(), 0, "二阶没有")


static func run_ledger(t: TestCase) -> void:
	t.begin("信仰重构 D · 自然的信力：打赢 6；治疗够数 +2；放出过生息 +2；三阶 20 / 60 / 120")
	var def := load("res://data/faiths/nature.tres") as FaithDef
	var n := 0
	for d in def.deeds:
		n += (d as FaithDeed).gain(&"battle", {"won": true, "mechanic": {"nature_heal": 1, "nature_release": 2}, "dealt": {}, "taken": {}, "fired_items": [], "healed": 0.0})
	t.eq(n, 10, "6 + 2 + 2")
	t.eq(def.thresholds, [20, 60, 120] as Array[int], "三阶")
