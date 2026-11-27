## 大地之神（作者牌表 11-26）：核心【天地】按摆放分大地 / 穹顶 / 支柱；大地之神的牌在战斗里的那一半
## （磐石、天光、冲撞、万钧、玉石俱焚、厚实、反震、擎天一柱、层峦）
extends RefCounted

const Comp := preload("res://tests/battle/test_compiler.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## 8×6 的棋盘：(0,0) 一件两格的武器（大地），(1,1) 一格（支柱），(3,2) 一件两格（穹顶）
static func _board() -> GridInventory:
	var b := GridInventory.new(Vector2i(8, 6), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_edge", ["11"], 10.0, 1.0, ["weapon", "melee"])), Vector2i(0, 0), 0)
	b.place(ItemInstance.create(Comp._item("t_mid", ["1"], ["trinket"])), Vector2i(1, 1), 0)
	b.place(ItemInstance.create(Comp._item("t_top", ["11"], ["trinket"])), Vector2i(3, 2), 0)
	return b


static func _me(tune: Dictionary = {}, ranges_pure: bool = false) -> CombatantSpec:
	var b := _board()
	var rule := EarthHeavenPerk.new().rule_for(null, b)
	(rule.trigger as FaithMechanicTrigger).sees_pure = ranges_pure
	var e := rule.effects[0] as EarthHeaven
	for k in tune:
		e.set(k, tune[k])
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(1000.0), [] as Array[StatModifier], [rule] as Array[AbilityRule])


static func _hitter(dmg: float, cd: float = 1.0) -> CombatantSpec:
	var b := GridInventory.new(Vector2i(4, 4), 1, false)
	b.place(ItemInstance.create(Comp._weapon("t_foe", ["1"], dmg, cd, ["weapon", "melee"])), Vector2i(0, 0), 0)
	return BattleCompiler.compile_board(b, CombatantBaseline.with_hp(50000.0))


static func _mech(res: BattleResult, key: String) -> int:
	var n := 0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED and e.side == 0 and String(e.payload.get("effect", "")) == SkillMomentum.MECHANIC and String(e.payload.get("key", "")) == key:
			n += 1
	return n


## 开战那一刻（0 秒）打到敌人身上的：[合计, 真实伤害合计]
static func _opening(res: BattleResult) -> Array:
	var all := 0.0
	var pure := 0.0
	for raw in res.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.time == 0:
			var n := StatMath.to_float(maxi(0, e.get_int(&"amount")))
			all += n
			if e.get_bool(&"pure"):
				pure += n
	return [all, pure]


static func run_roles(t: TestCase) -> void:
	t.begin("大地之神 · 天地：贴边的是大地，中央那一圈的是穹顶，夹在中间的是支柱；缺格也算边；包不算")
	var b := _board()
	var got := EarthHeaven.roles(b)
	var uid_of := {}
	for raw in b.items():
		uid_of[String((raw as ItemInstance).def.id)] = (raw as ItemInstance).uid
	t.eq(got[uid_of["t_edge"]], EarthHeaven.GROUND, "贴着最外一圈：大地")
	t.eq(got[uid_of["t_mid"]], EarthHeaven.PILLAR, "第二圈：支柱")
	t.eq(got[uid_of["t_top"]], EarthHeaven.DOME, "中央那一圈：穹顶")
	var d := EarthHeaven.depths(b)
	t.eq([int(d[Vector2i(0, 0)]), int(d[Vector2i(1, 1)]), int(d[Vector2i(3, 2)]), int(d[Vector2i(4, 3)])], [0, 1, 2, 2], "离边界几圈")
	# 中间挖一个缺格：挨着它的就算贴边
	var holed := GridInventory.new(Vector2i(8, 6), 1, false)
	holed.set_blocked(Vector2i(5, 2), true)
	holed.place(ItemInstance.create(Comp._item("t_by_hole", ["11"], ["trinket"])), Vector2i(3, 2), 0)
	t.eq(EarthHeaven.roles(holed).values(), [EarthHeaven.GROUND], "挨着缺格：大地")
	# 标了不参战：分层照算，打仗的时候不算
	(b.get_item(uid_of["t_top"]) as ItemInstance).set_benched(true)
	t.eq(EarthHeaven.roles(b, true).size(), 2, "不参战的不进战斗那一份")
	t.eq(EarthHeaven.roles(b).size(), 3, "地图上照算")


static func run_opening(t: TestCase) -> void:
	t.begin("大地之神 · 开战：磐石给护甲、天光打真实伤害、冲撞 / 万钧 / 玉石俱焚打伤害、擎天一柱给敌人元素")
	var plain := BattleSim.run(_me(), FX._spec(5000.0, []), _rng(1), 0.1)
	t.eq(_mech(plain, "earth_ground"), 1, "写战记：有大地")
	t.eq(_mech(plain, "earth_dome"), 1, "写战记：有穹顶")
	var e := EarthHeavenPerk.effect_for(null, _board())
	t.eq([e.ground, e.dome, e.pillar], [1, 1, 1], "一件大地、一件穹顶、一件支柱")
	var sky := BattleSim.run(_me({"sky_true": 10}), FX._spec(5000.0, []), _rng(1), 0.1)
	t.check(is_equal_approx(float(_opening(sky)[1]), 10.0), "天光：开战 10 点真实伤害（%s）" % _opening(sky)[1])
	var hits := BattleSim.run(_me({"ram": 3, "heavy": 7, "jade": 20}), FX._spec(5000.0, []), _rng(1), 0.1)
	t.check(is_equal_approx(float(_opening(hits)[0]), 30.0) and is_equal_approx(float(_opening(hits)[1]), 0.0), "冲撞 3 + 万钧 7 + 玉石俱焚 20，不是真实伤害（%s）" % _opening(hits)[0])
	var arm := BattleSim.run(_me({"armor_gain": 16}), _hitter(5.0), _rng(1), 3.0)
	var absorbed := 0
	for raw in arm.log:
		var ev := raw as BattleEvent
		if ev.name == BattleEvent.RESOURCE_CHANGED and ev.side == 0 and ev.get_name(&"key") == BattleStats.RES_ARMOR and ev.get_int(&"delta") < 0:
			absorbed += -ev.get_int(&"delta")
	t.check(absorbed > 0, "磐石：护甲吸收了伤害（%s）" % StatMath.to_float(absorbed))
	var el := BattleSim.run(_me({"elements": 3}), FX._spec(5000.0, []), _rng(1), 0.1)
	var stacks := 0
	for raw in el.log:
		var ev2 := raw as BattleEvent
		if ev2.name == BattleEvent.STATUS_STACKED and ev2.side == 1 and SkillMomentum.ELEMENTS.has(ev2.get_name(&"buff")):
			stacks += ev2.get_int(&"delta")
	t.check(stacks >= 1, "擎天一柱：敌人身上有随机元素（%d 层；两种元素相遇会起反应）" % stacks)
	var one := BattleSim.run(_me({"elements": 1}), FX._spec(5000.0, []), _rng(1), 0.1)
	var n1 := 0
	for raw in one.log:
		var ev3 := raw as BattleEvent
		if ev3.name == BattleEvent.STATUS_STACKED and ev3.side == 1 and SkillMomentum.ELEMENTS.has(ev3.get_name(&"buff")):
			n1 += ev3.get_int(&"delta")
	t.eq(n1, 1, "一件支柱：一层")


static func run_defence(t: TestCase) -> void:
	t.begin("大地之神 · 挨打：厚实是格挡来源（只挡直接伤害）；层峦抵挡几次攻击（真实伤害也挡）；反震还真实伤害、有冷却")
	var thick := BattleSim.run(_me({"thick": 4}), _hitter(5.0), _rng(1), 3.0)
	var blocked := 0
	for raw in thick.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0 and e.get_bool(&"direct"):
			blocked = maxi(blocked, e.get_int(&"block"))
	t.check(StatMath.to_float(blocked) >= 3.9, "厚实：每下挡 4 点（%s）" % StatMath.to_float(blocked))
	var rng_ := BattleSim.run(_me({"ranges": 2}, true), _hitter(5.0, 1.0), _rng(1), 5.5)
	var cancelled := 0
	var landed := 0
	for raw in rng_.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 0:
			if e.get_bool(&"cancelled"):
				cancelled += 1
			elif e.get_int(&"amount") > 0:
				landed += 1
	t.eq(cancelled, 2, "层峦两次：头两下攻击当作没发生")
	t.check(landed > 0, "之后照常挨打")
	var trig := FaithMechanicTrigger.new()
	trig.sees_pure = true
	var ev := BattleEvent.make(BattleEvent.BEFORE_DAMAGE, 0, 0, {"pure": true})
	t.check(trig.matches(null, ev), "拿了层峦：受伤前也听真实伤害（抵挡攻击连真实伤害一起挡）")
	trig.sees_pure = false
	t.check(not trig.matches(null, ev), "没拿：神的机制照旧碰不到真实伤害")
	var quake := BattleSim.run(_me({"quake": 3, "quake_cd": 6.0}), _hitter(1.0, 0.5), _rng(1), 7.0)
	t.eq(_mech(quake, "earth_quake"), 2, "反震：7 秒里挨了十几下，冷却 6 秒只还两次")
	var pure := 0.0
	for raw in quake.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == 1 and e.get_bool(&"pure"):
			pure += StatMath.to_float(e.get_int(&"amount"))
	t.check(is_equal_approx(pure, 6.0), "每次 3 点真实伤害（%s）" % pure)
