## 396（作者 11-26）：【真实伤害】只受来源影响、只有免疫伤害能挡；【格挡】固定减伤，只对直接、非真实伤害，不同来源只取最高
extends RefCounted

const Pipe := preload("res://tests/battle/test_damage_pipeline.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")


static func run_true_damage(t: TestCase) -> void:
	t.begin("396 · 真实伤害：护甲、格挡、减伤、易伤、预先写上的增减都不碰，原值落血")
	var ctx := FX._battle(Pipe._attacker(10.0), Pipe._defender({"max_armor": 10.0, "block": 5.0}))
	Pipe._start(ctx)
	ctx.sides[1].shift_axis(StatAxes.DAMAGE_TAKEN, -10)     # 坚韧 10 层：减伤 50%
	var p := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx.sides[1], 0, 0, true)
	p.pure = true
	p.percent = -StatMath.from_float(0.5)     # 有人预先写了减伤
	p.flat = -StatMath.from_float(3.0)
	DamageResolver.resolve(ctx, p)
	t.eq(Pipe._hp(ctx, 1), 90, "10 点真实伤害：落血 10（护甲、格挡、坚韧、预写的减伤都不算）")
	t.eq(Pipe._shield(ctx, 1), 10, "护甲没动")
	var ctx2 := FX._battle(Pipe._attacker(10.0), Pipe._defender())
	Pipe._start(ctx2)
	ctx2.sides[1].shift_axis(StatAxes.DAMAGE_TAKEN, 10)     # 易伤 10 层
	var p2 := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx2.sides[1], 0, 0, true)
	p2.pure = true
	p2.percent = StatMath.from_float(1.0)     # 预写的增伤
	DamageResolver.resolve(ctx2, p2)
	t.eq(Pipe._hp(ctx2, 1), 90, "易伤、预写的增伤也不算：还是 10")


static func _cut(cancel: bool) -> ModifyDamage:
	var m := ModifyDamage.new()
	if cancel:
		m.cancel = true
	else:
		m.percent = -50
	return m


static func run_true_damage_immunity(t: TestCase) -> void:
	t.begin("396 · 真实伤害（作者 11-26 14:14）：别的减伤不碰它，只有【免疫伤害】能免疫")
	var ctx := FX._battle(Pipe._attacker(10.0), Pipe._defender({}, Pipe._before_rule(_cut(false))))
	Pipe._start(ctx)
	var p := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx.sides[1], 0, 0, true)
	p.pure = true
	DamageResolver.resolve(ctx, p)
	t.eq(Pipe._hp(ctx, 1), 90, "受伤前减半：真实伤害照扣 10")
	var plain := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx.sides[1], 0, 0, true)
	DamageResolver.resolve(ctx, plain)
	t.eq(Pipe._hp(ctx, 1), 85, "普通伤害照样减半（扣 5）")
	var ctx2 := FX._battle(Pipe._attacker(10.0), Pipe._defender({}, Pipe._before_rule(_cut(true))))
	Pipe._start(ctx2)
	var p2 := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(10.0), ctx2.sides[1], 0, 0, true)
	p2.pure = true
	DamageResolver.resolve(ctx2, p2)
	t.check(p2.cancelled and Pipe._hp(ctx2, 1) == 100, "免疫伤害：真实伤害也免疫")


static func run_block_sources(t: TestCase) -> void:
	t.begin("396 · 格挡（作者 11-26 17:03）：不同来源只取最高（盾 6 + 以攻待守 10 = 10），只挡直接、非真实伤害")
	var ctx := FX._battle(Pipe._attacker(10.0), Pipe._defender({"block": 6.0}))
	Pipe._start(ctx)
	var me: CombatantRuntime = ctx.sides[1]
	me.set_block_layer(SkillMomentum.GUARD_LAYER, StatMath.from_float(10.0))
	DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), me, 0, 0, true))
	t.eq(Pipe._hp(ctx, 1), 90, "20 点直接伤害：格挡取 10（不是 16），落血 10")
	DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), me, 0, 0, false))
	t.eq(Pipe._hp(ctx, 1), 70, "非直接伤害不吃格挡：落血 20")
	var tp := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), me, 0, 0, true)
	tp.pure = true
	DamageResolver.resolve(ctx, tp)
	t.eq(Pipe._hp(ctx, 1), 50, "真实伤害不吃格挡：落血 20")
	me.set_block_layer(SkillMomentum.GUARD_LAYER, 0)
	DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), me, 0, 0, true))
	t.eq(Pipe._hp(ctx, 1), 36, "拿掉以攻待守：只剩盾的 6，落血 14")
	# 确认台 56（作者 11-27 选 A）：【弹开】（加固 8）加在最高那一层上
	ShiftAxis.shift(ctx, me, StatAxes.BLOCK, 8, false)
	DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), me, 0, 0, true))
	t.eq(Pipe._hp(ctx, 1), 30, "弹开加固 8 + 盾 6：落血 6")
	me.set_block_layer(SkillMomentum.GUARD_LAYER, StatMath.from_float(10.0))
	DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(20.0), me, 0, 0, true))
	t.eq(Pipe._hp(ctx, 1), 28, "弹开加固 8 + 最高一层 10（以攻待守）：落血 2")
