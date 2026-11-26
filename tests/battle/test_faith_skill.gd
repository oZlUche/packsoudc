## 396 第 B 批：技巧之神【连击】—— 每次武器攻击叠一层、每层急速；耐力不够没打出来清零；技巧之神的牌在战斗里的那一半
## （寻隙、架势、残心、破势、以攻待守、气功、锋芒、大巧若拙、化刚为巧；稳手、预备、流水、行云、招架、回气、气血、蓄势、识破）
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")
const Pipe := preload("res://tests/battle/test_damage_pipeline.gd")
const ID := SkillMomentum.BUFF_ID


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## 一件武器：伤害 [param dmg]、冷却 [param cd]；[param cost] > 0 每下付这么多耐力
static func _weapon(id: String, dmg: float, cd: float, cost: float = 0.0, crit: float = 0.0) -> ItemDef:
	var w := Comp._weapon(id, ["1"], dmg, cd, ["weapon", "melee"])
	if cost > 0.0:
		var c := ResourceCost.new()
		c.amount = cost
		w.combat.rules[0].costs = [c] as Array[Cost]
	if crit > 0.0:
		w.combat.base_stats["crit_chance"] = crit
	return w


## 带连击的我（[param tune] 改效果上的数，拿牌就是改这些）；[param combo] 假 = 不奉神
static func _me(tune: Dictionary = {}, cost: float = 0.0, combo: bool = true, crit: float = 0.0, armor: float = 0.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(_weapon("t_w", 10.0, 1.0, cost, crit)), Vector2i(0, 0), 0)
	b.place(ItemInstance.create(_weapon("t_w2", 10.0, 1.3, cost, crit)), Vector2i(2, 0), 0)
	if armor > 0.0:
		var s := Comp._item("t_armor", ["1"], ["armor"])
		var c := CombatProfile.new()
		c.base_stats = {"max_armor": armor}
		s.combat = c
		b.place(ItemInstance.create(s), Vector2i(0, 2), 0)
	var rules: Array[AbilityRule] = []
	if combo:
		var rule := SkillMomentumPerk.new().rule_for(null)
		var e := rule.effects[0] as SkillMomentum
		for k in tune:
			e.set(k, tune[k])
		rules.append(rule)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(1000.0), [] as Array[StatModifier], rules)


static func _hitter(dmg: float, cd: float = 1.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_foe", ["1"], dmg, cd, ["weapon", "melee"])), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(50000.0))


static func _dummy() -> CombatantSpec:
	return FX._spec(50000.0, [])


static func _mech(res: BattleResult, key: String) -> int:
	var n := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			n += 1
	return n


## [最高几层, 我方武器出手几次]
static func _combo(res: BattleResult, buff: StringName = ID) -> Array:
	var top := 0
	var fired := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.side != 0:
			continue
		if e.name == BattleEvent.STATUS_STACKED and e.get_name(&"buff") == buff:
			top = maxi(top, e.get_int(&"stacks"))
		if e.name == BattleEvent.ITEM_FIRED:
			fired += 1
	return [top, fired]


static func _dealt(res: BattleResult) -> float:
	var n := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_int(&"source_side", -1) == 0:
			n += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	return n


static func _taken(res: BattleResult) -> float:
	var n := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			n += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	return n


static func run_core(t: TestCase) -> void:
	t.begin("396 · 连击核心：每次武器攻击叠一层、不封顶；层数越多出手越多；耐力不够没打出来就清零；不奉神没有")
	var r := BattleSim.run(_me(), _dummy(), _rng(1), 20.0)
	var c := _combo(r)
	t.check(int(c[0]) > 0 and int(c[0]) == int(c[1]), "每出手一次一层（%d 层，出手 %d 次）" % [int(c[0]), int(c[1])])
	t.check(int(c[0]) > 30, "不封顶（%d 层）" % int(c[0]))
	var plain := BattleSim.run(_me({}, 0.0, false), _dummy(), _rng(1), 20.0)
	t.check(int(_combo(plain)[1]) < int(c[1]), "每层急速：出手更多（%d > %d）" % [int(c[1]), int(_combo(plain)[1])])
	t.eq(int(_combo(plain)[0]), 0, "不奉神：没有连击")
	# 耐力不够：一下 40 耐力，付不起那一下清零
	var tired := BattleSim.run(_me({}, 40.0), _dummy(), _rng(1), 20.0)
	t.check(_mech(tired, "skill_reset") > 0, "耐力不够没出手：清零（%d 次）" % _mech(tired, "skill_reset"))
	var again := BattleSim.run(_me(), _dummy(), _rng(1), 20.0)
	t.eq(again.log.size(), r.log.size(), "同种子同结果")


static func run_reset_cards(t: TestCase) -> void:
	t.begin("396 · 清零时的牌：稳手留几层、残心额外攻击、大巧若拙真实伤害、回气、气血；预备开战给几层")
	var tune := {"keep_on_reset": 2, "zanshin": 1, "clumsy_pct": 100.0, "breath_per": 0.2, "vigor_per": 0.2}
	var r := BattleSim.run(_me(tune, 40.0), _hitter(5.0), _rng(2), 20.0)
	t.check(_mech(r, "skill_reset") > 0, "清零了")
	t.check(_mech(r, "skill_zanshin") > 0, "残心：额外攻击 %d 次" % _mech(r, "skill_zanshin"))
	var free := 0
	var pure := 0
	var low := 99
	for raw in r.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0 and e.get_bool(&"free"):
			free += 1
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_bool(&"pure"):
			pure += 1
		if e.name == BattleEvent.STATUS_UNSTACKED and e.side == 0 and e.get_name(&"buff") == ID:
			low = mini(low, e.get_int(&"stacks"))
	t.check(free > 0, "残心那一下不耗耐力（free）")
	t.check(pure > 0, "大巧若拙：打了真实伤害（%d 下）" % pure)
	t.eq(low, 2, "稳手：清零后还留 2 层")
	var ready := BattleSim.run(_me({"opening": 3}), _dummy(), _rng(2), 0.5)
	t.eq(int(_combo(ready)[0]), 3, "预备：开战 3 层")


static func run_stack_cards(t: TestCase) -> void:
	t.begin("396 · 往上堆的牌：寻隙穿透增伤、破势附固定伤害、锋芒加暴击、招架给护甲、流水清零不掉、行云省耐力")
	var base := _dealt(BattleSim.run(_me(), _dummy(), _rng(3), 10.0))
	t.check(_dealt(BattleSim.run(_me({"press_pct": 30.0}), _dummy(), _rng(3), 10.0)) > base, "破势：打得更痛")
	var gap := BattleSim.run(_me({"gap_every": 4, "gap_pct": 50.0}), _dummy(), _rng(3), 10.0)
	t.check(_mech(gap, "skill_gap") > 0, "寻隙：攒够层数的下一下（%d 次）" % _mech(gap, "skill_gap"))
	t.check(_dealt(gap) > base, "寻隙：增伤")
	var edge := BattleSim.run(_me({"edge_crit": 5.0}), _dummy(), _rng(3), 10.0)
	var crits := 0
	for raw in edge.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_bool(&"crit"):
			crits += 1
	t.check(crits > 0, "锋芒：层数上来就暴击（%d 次）" % crits)
	# 招架（作者 11-26 09:54）：每 10 层回复防具护甲上限的 3%；没穿防具没有
	var parry := BattleSim.run(_me({"parry_every": 10, "parry_pct": 3.0}, 0.0, true, 0.0, 100.0), _hitter(20.0), _rng(3), 10.0)
	var bare := BattleSim.run(_me({"parry_every": 10, "parry_pct": 3.0}), _hitter(20.0), _rng(3), 10.0)
	var restored := [0, 0]
	var biggest := 0
	for pair in [[parry, 0], [bare, 1]]:
		for raw in (pair[0] as BattleResult).log:
			var e := raw as BattleEvent
			if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 0 and String(e.payload.get("key", "")) == "armor" and e.get_int(&"delta") > 0:
				restored[pair[1]] += 1
				biggest = maxi(biggest, e.get_int(&"delta")) if pair[1] == 0 else biggest
	t.check(restored[0] > 0 and biggest <= StatMath.from_float(3.0) * 2, "招架：穿着 100 护甲的防具，被打掉后每次回 3 点（回了 %d 次，最多 %.1f）" % [restored[0], StatMath.to_float(biggest)])
	t.eq(restored[1], 0, "招架：没穿防具就没有")
	var flow := BattleSim.run(_me({"flow_per": 0.5}, 40.0), _dummy(), _rng(3), 20.0)
	var flow_drop := false
	for raw in flow.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_UNSTACKED and e.side == 0 and e.get_name(&"buff") == SkillMomentum.FLOW_ID:
			flow_drop = true
	t.check(int(_combo(flow, SkillMomentum.FLOW_ID)[0]) > 0 and flow_drop, "流水：叠起来，清零时一起清掉（作者 11-26）")
	var cloud := BattleSim.run(_me({"light_at": 3, "light_pct": 50.0}, 20.0), _dummy(), _rng(3), 20.0)
	t.check(int(_combo(cloud)[1]) > int(_combo(BattleSim.run(_me({}, 20.0), _dummy(), _rng(3), 20.0))[1]), "行云：耐力省了，出手更多")


static func run_defense_cards(t: TestCase) -> void:
	t.begin("396 · 挨打的牌：以攻待守固定减伤（可以减到 0）、减到 0 / 护甲吃光算挡住（架势叠层）；识破无视固定减伤")
	var guard := BattleSim.run(_me({"guard_at": 0, "guard_flat": 10.0}), _hitter(8.0), _rng(4), 10.0)
	var through := 0
	var stopped := 0
	for raw in guard.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0 and not e.get_bool(&"crit"):
			if e.get_int(&"amount") > 0:
				through += 1
			else:
				stopped += 1
	t.check(through == 0 and stopped > 0, "以攻待守 10：8 点一下减到 0（挡住 %d 下，漏 %d 下；暴击的 12 点不算）" % [stopped, through])
	var stance := BattleSim.run(_me({"guard_at": 0, "guard_flat": 10.0, "stance": 2}), _hitter(8.0), _rng(4), 6.0)
	var plain := BattleSim.run(_me({"guard_at": 0, "guard_flat": 10.0}), _hitter(8.0), _rng(4), 6.0)
	t.check(int(_combo(stance)[0]) > int(_combo(plain)[0]), "架势：挡住一下多叠层（%d > %d）" % [int(_combo(stance)[0]), int(_combo(plain)[0])])
	var armored := BattleSim.run(_me({"stance": 1}, 0.0, true, 0.0, 500.0), _hitter(8.0), _rng(4), 6.0)
	t.check(int(_combo(armored)[0]) > int(_combo(BattleSim.run(_me({}, 0.0, true, 0.0, 500.0), _hitter(8.0), _rng(4), 6.0))[0]), "护甲吃光那一下也算挡住")
	# 识破：格挡 10 的木桩，每层无视 1 点
	var ctx := FX._battle(Pipe._attacker(10.0), Pipe._defender({"block": 10.0}))
	Pipe._start(ctx)
	var p := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), ctx.sides[1], 0, 0, true)
	p.ignore_flat = StatMath.from_float(6.0)
	DamageResolver.resolve(ctx, p)
	t.eq(Pipe._hp(ctx, 1), 84, "格挡 10、识破 6：只挡 4，20 打成 16")


static func run_crit_cards(t: TestCase) -> void:
	t.begin("396 · 化刚为巧：暴击不加伤害、改为再打一下原本几成；蓄势按时间涨暴击率、暴击后清掉；气功给敌人附随机元素")
	var soft := BattleSim.run(_me({"soft_pct": 50.0}, 0.0, true, 1.0), _dummy(), _rng(5), 6.0)
	var hits := []
	for raw in soft.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_bool(&"crit"):
			hits.append(e.get_int(&"amount"))
	t.check(not hits.is_empty() and hits.all(func(a: int) -> bool: return a <= StatMath.from_float(10.5)), "暴击那一下不乘暴击伤害（%s）" % str(hits.slice(0, 3)))
	t.check(_mech(soft, "skill_soft") == hits.size(), "每次暴击再打一下（%d 下）" % _mech(soft, "skill_soft"))
	var poise := BattleSim.run(_me({"poise_sec": 1.0, "poise_pct": 50.0}), _dummy(), _rng(5), 10.0)
	var got := false
	var spent := false
	for raw in poise.log:
		var e := raw as BattleEvent
		if e.side == 0 and e.get_name(&"buff") == SkillMomentum.POISE_ID:
			got = got or e.name == BattleEvent.STATUS_STACKED
			spent = spent or e.name == BattleEvent.STATUS_UNSTACKED
	t.check(got and spent, "蓄势：涨了、暴击后清掉")
	var qi := BattleSim.run(_me({"qigong_every": 3, "qigong_stacks": 2}), _dummy(), _rng(5), 10.0)
	var elems := 0
	for raw in qi.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.STATUS_STACKED and e.side == 1 and SkillMomentum.ELEMENTS.has(e.get_name(&"buff")):
			elems += 1
	t.check(elems > 0, "气功：敌人挂上了元素（%d 次）" % elems)


static func run_batch_1126(t: TestCase) -> void:
	t.begin("作者 11-26：大巧若拙（升级）让中断连击的武器补打一次、不叠连击；收式每 10 秒让下一次攻击按清零结算、层数不丢")
	var tune := {"clumsy_pct": 100.0}
	var plain := BattleSim.run(_me(tune, 40.0), _hitter(5.0), _rng(2), 20.0)
	tune["clumsy_refire"] = true
	var refire := BattleSim.run(_me(tune, 40.0), _hitter(5.0), _rng(2), 20.0)
	t.check(_mech(refire, "skill_refire") > 0 and _mech(refire, "skill_refire") == _mech(refire, "skill_reset"), "每次清零补打一次（%d / %d）" % [_mech(refire, "skill_refire"), _mech(refire, "skill_reset")])
	t.eq(_mech(plain, "skill_refire"), 0, "没升级不补打")
	var free := 0
	for raw in refire.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0 and e.get_bool(&"free"):
			free += 1
	t.eq(free, _mech(refire, "skill_refire"), "补的那一下不耗耐力（free）")
	t.check(int(_combo(refire)[0]) <= int(_combo(plain)[0]) + 1, "补的那一下不叠连击")
	var fin := BattleSim.run(_me({"finish_sec": 2.0, "zanshin": 1}), _dummy(), _rng(2), 10.0)
	var zs := _mech(fin, "skill_zanshin")
	t.check(zs >= 4 and zs <= 5, "收式：10 秒里每 2 秒一次按清零结算（残心 %d 次）" % zs)
	t.eq(_mech(fin, "skill_reset"), 0, "收式不是真清零")
	t.check(int(_combo(fin)[0]) >= 10, "层数不丢（最高 %d 层）" % int(_combo(fin)[0]))
