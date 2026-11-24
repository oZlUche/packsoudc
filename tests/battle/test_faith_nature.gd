## 388 第 3 批：自然之神【枯萎】/【新生】—— 敌人每失去 1 点生命 +1 层枯萎、我每回 1 点生命 +1 层新生；
## 自然之神的牌在战斗里的那一半（凋零、护佑、收割、丰饶、轮回、回春、毒气、求生本能）
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## 带自然核心的我：[param tune] 改效果上的数；[param regen] 每秒回血；[param hp_now] 开战时的生命（空 = 满）
static func _me(tune: Dictionary = {}, regen: float = 0.0, hp: float = 1000.0, dmg: float = 10.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_blade", ["1"], dmg, 1.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	var rule := NatureCyclePerk.new().rule_for(null)
	var e := rule.effects[0] as NatureCycle
	for k in tune:
		e.set(k, tune[k])
	var base := CombatantBaseline.with_hp(hp)
	if regen > 0.0:
		base.base_stats["regen_hp"] = regen
	var rules: Array[AbilityRule] = [rule]
	return BattleCompiler.compile_board(b, base, [] as Array[StatModifier], rules)


static func _hitter(dmg: float, cd: float = 1.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_foe", ["1"], dmg, cd, ["weapon", "melee"])), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(50000.0))


static func _final(res: BattleResult, side: int, id: StringName) -> int:
	return int((((res.final.get("sides", [{}, {}]) as Array)[side] as Dictionary).get("buffs", {}) as Dictionary).get(String(id), 0))


static func _max_hp(res: BattleResult, side: int) -> float:
	var r: Dictionary = (((res.final.get("sides", [{}, {}]) as Array)[side] as Dictionary).get("resources", {}))
	var hp = r.get(String(BattleStats.RES_HP), r.get(BattleStats.RES_HP, {}))
	if hp is Array:
		return float((hp as Array)[1])     # 快照里是整点
	return 0.0


static func _lost(res: BattleResult, side: int) -> float:
	var n := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == side:
			n += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	return n


static func _mech(res: BattleResult, key: String) -> int:
	var n := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			n += 1
	return n


static func run_core(t: TestCase) -> void:
	t.begin("388 · 枯萎 / 新生：敌人失去几点生命就几层枯萎（整点），我回几点就几层新生（每秒回复也算）")
	var r := BattleSim.run(_me({}, 3.0, 1000.0), _hitter(5.0), _rng(1), 6.0)
	var lost := _lost(r, 1)
	t.check(lost > 0.0, "敌人掉了血（%.1f）" % lost)
	t.eq(_final(r, 1, NatureCycle.WITHER), floori(lost), "枯萎 = 敌人失去的整点生命")
	t.check(_final(r, 0, NatureCycle.RENEWAL) > 0, "回血积了新生（%d）" % _final(r, 0, NatureCycle.RENEWAL))
	t.check(_mech(r, "nature_heal") <= 1 and _mech(r, "nature_wither") <= 1, "经验值的记号一场最多一次")
	var again := BattleSim.run(_me({}, 3.0, 1000.0), _hitter(5.0), _rng(1), 6.0)
	t.eq(again.log.size(), r.log.size(), "同种子同结果")


static func run_cards(t: TestCase) -> void:
	t.begin("388 · 自然之神的牌（战斗里）：凋零扣敌人上限、护佑把新生换成护甲、收割斩杀、丰饶溢出加上限、轮回互给、回春、毒气、求生本能")
	# 凋零
	var plain := BattleSim.run(_me(), FX._spec(500.0, []), _rng(2), 5.0)
	var decay := BattleSim.run(_me({"decay_percent": 50.0}), FX._spec(500.0, []), _rng(2), 5.0)
	var w := _final(decay, 1, NatureCycle.WITHER)
	t.check(w > 0, "敌人有枯萎（%d）" % w)
	t.check(is_equal_approx(_max_hp(decay, 1), _max_hp(plain, 1) - w * 0.5) or _max_hp(decay, 1) < _max_hp(plain, 1), "凋零 50%%：敌人上限少了（%.1f < %.1f）" % [_max_hp(decay, 1), _max_hp(plain, 1)])
	# 护佑：第 10 秒新生清零、给护甲
	var guard := BattleSim.run(_me({"guard_every": 10.0, "guard_percent": 100.0}, 5.0, 1000.0), _hitter(8.0), _rng(3), 10.5)
	t.eq(_mech(guard, "nature_guard_armor"), 1, "第 10 秒换了一次护甲")
	t.check(_final(guard, 0, NatureCycle.RENEWAL) < 5, "新生清零后只剩半秒积的（%d）" % _final(guard, 0, NatureCycle.RENEWAL))
	# 收割：第 10 秒按枯萎给收割，敌人生命不高于它就死
	var reap := BattleSim.run(_me({"harvest_at": 10.0, "harvest_percent": 100.0}, 0.0, 1000.0, 40.0), FX._spec(500.0, []), _rng(4), 20.0)
	t.eq(_mech(reap, "nature_reap"), 1, "收割斩了一次")
	t.eq(reap.winner, 0, "敌人死了")
	var no_reap := BattleSim.run(_me({}, 0.0, 1000.0, 40.0), FX._spec(500.0, []), _rng(4), 20.0)
	t.check(no_reap.duration > reap.duration, "比不拿收割早结束（%.1f < %.1f）" % [StatMath.to_float(reap.duration), StatMath.to_float(no_reap.duration)])
	# 丰饶：满血时回复溢出 → 上限加等量
	var bounty := BattleSim.run(_me({"bounty": true}, 5.0, 1000.0), FX._spec(50000.0, []), _rng(5), 4.0)
	t.check(_final(bounty, 0, NatureCycle.BOUNTY) >= 15, "满血 4 秒溢出约 20 点：【丰饶】%d 层" % _final(bounty, 0, NatureCycle.BOUNTY))
	t.check(_max_hp(bounty, 0) > 1000.0, "上限涨了（%.1f）" % _max_hp(bounty, 0))
	# 轮回：敌人每 5 层枯萎给我 1 层新生
	var cyc := BattleSim.run(_me({"cycle_stacks": 1}), FX._spec(5000.0, []), _rng(6), 6.0)
	t.check(_final(cyc, 0, NatureCycle.RENEWAL) > 0, "没回血也有新生（轮回给的 %d）" % _final(cyc, 0, NatureCycle.RENEWAL))
	t.eq(_final(cyc, 0, NatureCycle.RENEWAL), floori(_final(cyc, 1, NatureCycle.WITHER) / 5.0), "每 5 层枯萎 1 层新生（给的新生不再回给枯萎）")
	# 毒气：每 2 秒给敌人 1 层中毒
	var gas := BattleSim.run(_me({"poison": 1}), FX._spec(5000.0, []), _rng(7), 4.5)
	var poisoned := 0
	for raw in gas.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and e.get_name(&"buff") == &"poison" and e.get_int(&"delta") > 0:
			poisoned += e.get_int(&"delta")
	t.eq(poisoned, 2, "第 2、4 秒各一层")
	# 求生本能：第一次低于一半回一成
	var hurt := BattleSim.run(_me({"survive_percent": 10.0}, 0.0, 100.0), _hitter(30.0), _rng(8), 3.5)
	t.eq(_mech(hurt, "nature_survive"), 1, "低于一半时触发一次")


static func run_ledger(t: TestCase) -> void:
	t.begin("388 · 自然的经验值：新生到最大生命一成 +2、枯萎到敌人最大生命一成 +2；三阶 42 / 117 / 217")
	var def := load("res://data/faiths/nature.tres") as FaithDef
	var n := 0
	for d in def.deeds:
		n += (d as FaithDeed).gain(&"battle", {"won": true, "mechanic": {"nature_heal": 1, "nature_wither": 1}, "dealt": {}, "taken": {}, "fired_items": [], "healed": 0.0})
	t.eq(n, 4, "2 + 2")
	t.eq(def.thresholds, [42, 117, 217] as Array[int], "三阶")
