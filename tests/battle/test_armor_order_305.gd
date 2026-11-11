## 305（作者 2026-11-11 17:12 / 17:13）：护甲是血量的延伸 —— 减伤、格挡、易伤都算完、扣血之前才吸；
## 伤害包的穿透只跳过护甲；格挡品质每档 +1（整数），导入拒绝格挡乘算与小数
extends RefCounted

const P := preload("res://tests/battle/test_damage_pipeline.gd")
const H := preload("res://tests/battle/test_effect_system.gd")


static func _pierce(amount: float) -> CombatantSpec:
	var hit := P._hit(amount)
	hit.penetration = true
	var cd := CooldownCadence.new()
	cd.seconds = 1.0
	return H._spec(100.0, [H._compiled(1, "awl", {}, [H._rule(OnSchedule.new(), cd, [hit])])])


static func run_order(t: TestCase) -> void:
	t.begin("305 · 先格挡后护甲：20 点打 格挡 5 + 护甲 30 → 护甲吃 15、血不掉；溢出照样见血")
	var ctx := H._battle(P._attacker(20.0), P._defender({"max_armor": 30.0, "block": 5.0}))
	P._run(ctx)
	t.eq(P._shield(ctx, 1), 15, "护甲吃的是格挡之后的 15")
	t.eq(P._hp(ctx, 1), 100, "血不掉")
	var ctx2 := H._battle(P._attacker(50.0), P._defender({"max_armor": 30.0, "block": 5.0}))
	P._run(ctx2)
	t.eq(P._shield(ctx2, 1), 0, "护甲打空")
	t.eq(P._hp(ctx2, 1), 85, "50 − 格挡 5 − 护甲 30 = 15 见血")
	var ctx3 := H._battle(P._attacker(20.0, DamageTypes.POISON), P._defender({"max_armor": 30.0}))
	P._run(ctx3)
	t.eq(P._shield(ctx3, 1), 30, "中毒照旧不碰护甲")
	t.eq(P._hp(ctx3, 1), 80, "中毒直接见血")


static func run_penetration(t: TestCase) -> void:
	t.begin("305 · 穿透：只跳过护甲，格挡照算；DamagePacket.create 的 is_penetration 参数")
	var ctx := H._battle(_pierce(20.0), P._defender({"max_armor": 30.0, "block": 5.0}))
	P._run(ctx)
	t.eq(P._shield(ctx, 1), 30, "护甲不动")
	t.eq(P._hp(ctx, 1), 85, "格挡照挡 5，15 见血")
	var pk := DamagePacket.create(DamageTypes.PHYSICAL, 10, null, -1, 0, true, true)
	t.check(pk.penetration and pk.direct, "接口参数：直接 + 穿透")
	t.eq(DamagePacket.create(DamageTypes.PHYSICAL, 10, null).penetration, false, "默认不穿透")


static func run_pending(t: TestCase) -> void:
	t.begin("305 · 受伤前效果看到的是这一下原本多重（护甲还没吸）")
	var pk := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(12.0), null)
	t.eq(pk.pending(), StatMath.from_float(12.0), "pending = raw")


static func run_quality_block(t: TestCase) -> void:
	t.begin("305 · 品质给格挡每档 +1（整数）；伤害仍 ×1.1")
	var profile := CombatProfile.new()
	profile.base_stats = {"block": 5.0, "damage": 10.0}
	for q in [1, 2]:
		var into := StatSet.new()
		into.set_base(BattleStats.BLOCK, StatMath.from_float(5.0))
		into.set_base(BattleStats.DAMAGE, StatMath.from_float(10.0))
		BattleCompiler.quality_stats(into, profile, q)
		t.eq(into.ensure(BattleStats.BLOCK).base, StatMath.from_float(5.0 + q), "品质 %d：格挡 %d" % [q, 5 + q])
		t.eq(into.ensure(BattleStats.DAMAGE).base, StatMath.from_float(10.0 * (1.0 + 0.1 * q)), "品质 %d：伤害照旧 ×%.1f" % [q, 1.0 + 0.1 * q])


static func run_import_rejects(t: TestCase) -> void:
	t.begin("305 · 导入：格挡乘算、带小数的格挡报错；整数加算与现有内容都过")
	var ctx := ContentImporter.Context.new()
	var bad := ItemDef.new()
	bad.id = &"bad_shield"
	bad.combat = CombatProfile.new()
	bad.combat.base_stats = {"block": 2.5}
	var buff := BuffDef.new()
	buff.id = &"bad_buff"
	buff.mods = [StatModifier.make(BattleStats.BLOCK, StatModifier.Mode.MULT, 20.0)] as Array[StatModifier]
	var ok := BuffDef.new()
	ok.id = &"ok_buff"
	ok.mods = [StatModifier.make(BattleStats.BLOCK, StatModifier.Mode.ADD, 3.0)] as Array[StatModifier]
	ctx.items[bad.id] = bad
	ctx.buffs[buff.id] = buff
	ctx.buffs[ok.id] = ok
	var report := ImportReport.new()
	ContentImporter.validate_block_integer(ctx, report)
	t.eq(report.errors.size(), 2, "两条错：小数基础格挡、格挡乘算（%s）" % str(report.errors))
	var c := TestSupport.load_content()
	var real := ContentImporter.Context.new()
	for id in c.items.all_ids():
		real.items[StringName(id)] = c.items.get_def(StringName(id))
	var r2 := ImportReport.new()
	ContentImporter.validate_block_integer(real, r2)
	t.eq(r2.errors.size(), 0, "现有道具全过（%s）" % str(r2.errors))
