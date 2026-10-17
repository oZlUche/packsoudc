## 103 第 4、6 条与 4e：标准轴、加时（鏖战，受到伤害轴的系统层）与衰竭、双双倒下的裁决、系统层不可解除、buff 栏日志自足。
extends RefCounted

const FX := preload("res://tests/battle/test_effect_system.gd")


static func _sec(v: float) -> int:
	return StatMath.from_float(v)


## 一个木桩：有血，没有任何道具
static func _dummy(hp: float) -> CombatantSpec:
	return FX._spec(hp, [])


## 每 cd 秒打 dmg 点的单位
static func _hitter(hp: float, dmg: float, cd: float) -> CombatantSpec:
	return FX._spec(hp, [FX._compiled(1, "w", {"damage": dmg}, [FX._rule(OnSchedule.new(), FX._cooldown(cd), [FX._damage()])])])


static func _ctx(a: CombatantSpec, b: CombatantSpec) -> BattleContext:
	var ctx := FX._battle(a, b)
	ctx.overtime = OvertimeRules.new()
	return ctx


static func run_stacking(t: TestCase) -> void:
	t.begin("103 · 加时：30 秒起每 5 秒一次，受到伤害轴的系统层 +4 层（每层 5% = +20%）；60 秒起每秒掉 5 点生命上限")
	var ctx := _ctx(_dummy(1000.0), _dummy(1000.0))
	FX._advance_to(ctx, 29.9)
	t.eq(ctx.sides[0].axis_total(StatAxes.DAMAGE_TAKEN), 0, "29.9 秒：0 层")
	FX._advance_to(ctx, 30.0)
	t.eq(ctx.sides[0].axis_system(StatAxes.DAMAGE_TAKEN), 4, "30 秒：系统层 4 层")
	t.eq(ctx.sides[0].axis_stacks(StatAxes.DAMAGE_TAKEN), 0, "内容层不动")
	t.eq(ctx.sides[1].axis_system(StatAxes.DAMAGE_TAKEN), 4, "双方一起叠")
	t.eq(ctx.sides[0].axis_factor(StatAxes.DAMAGE_TAKEN), _sec(1.2), "受伤倍率 ×1.2")
	FX._advance_to(ctx, 35.0)
	t.eq(ctx.sides[0].axis_system(StatAxes.DAMAGE_TAKEN), 8, "35 秒：8 层")
	t.eq(ctx.sides[0].axis_factor(StatAxes.DAMAGE_TAKEN), _sec(1.4), "受伤倍率 ×1.4")
	var hp0 := ctx.sides[0].resources.current(BattleStats.RES_HP)
	DamageResolver.deal(ctx, ctx.sides[0], _sec(10.0))
	t.eq(hp0 - ctx.sides[0].resources.current(BattleStats.RES_HP), _sec(14.0), "10 点伤害在 2 层下扣 14（定点精确）")
	var heal := DamagePacket.create(DamageTypes.PHYSICAL, _sec(10.0), ctx.sides[0], 1, 0)
	heal.inverted = true
	var before_heal := ctx.sides[0].resources.current(BattleStats.RES_HP)
	DamageResolver.resolve(ctx, heal)
	t.eq(ctx.sides[0].resources.current(BattleStats.RES_HP) - before_heal, _sec(10.0), "治疗不放大")
	FX._advance_to(ctx, 59.9)
	t.eq(ctx.sides[0].stacks_of(OvertimeRules.DECAY_ID), 0, "59.9 秒：还没衰竭")
	FX._advance_to(ctx, 62.0)
	t.eq(ctx.sides[0].stacks_of(OvertimeRules.DECAY_ID), 3, "60、61、62 秒各一层")
	t.eq(ctx.sides[0].resources.maximum(BattleStats.RES_HP), _sec(985.0), "生命上限 −15")
	var started := {}
	for e in ctx.log:
		if e.name == BattleEvent.OVERTIME_STACKED or e.name == BattleEvent.DECAY_STARTED:
			started[e.name] = int(started.get(e.name, 0)) + 1
	t.eq(started, {BattleEvent.OVERTIME_STACKED: 7, BattleEvent.DECAY_STARTED: 1}, "加时 30～60 秒叠 7 次、衰竭开始记一次")


static func run_shield_and_armor(t: TestCase) -> void:
	t.begin("103 · 加时放大的是最终伤害：护甲、格挡按原值算完，扛下来的部分再乘")
	var a := _dummy(100.0)
	a.baseline = StatSet.new()
	a.baseline.set_base(BattleStats.MAX_ARMOR, _sec(4.0))
	a.baseline.set_base(BattleStats.BLOCK, _sec(2.0))
	var ctx := _ctx(a, _dummy(100.0))
	FX._advance_to(ctx, 35.0)     # 2 层：×1.4
	var me := ctx.sides[0]
	var hp0 := me.resources.current(BattleStats.RES_HP)
	# 106：格挡只减直接伤害，所以这一下按「武器打来的」造包（deal 的最后一个参数）
	DamageResolver.deal(ctx, me, _sec(16.0), DamageTypes.PHYSICAL, 1, 9, true)
	t.eq(me.resources.current(BattleStats.RES_ARMOR), 0, "护甲吸掉 4（原值）")
	t.eq(hp0 - me.resources.current(BattleStats.RES_HP), _sec(14.0), "(16 − 4 盾 − 2 甲) × 1.4 = 14")

	# 106：同一下若是 buff 造成的（非直接），格挡不减它 —— (16 − 4) × 1.4 = 16.8
	var b := _dummy(100.0)
	b.baseline = StatSet.new()
	b.baseline.set_base(BattleStats.MAX_ARMOR, _sec(4.0))
	b.baseline.set_base(BattleStats.BLOCK, _sec(2.0))
	var ctx2 := _ctx(b, _dummy(100.0))
	FX._advance_to(ctx2, 35.0)
	var me2 := ctx2.sides[0]
	var hp2 := me2.resources.current(BattleStats.RES_HP)
	DamageResolver.deal(ctx2, me2, _sec(16.0))
	t.eq(hp2 - me2.resources.current(BattleStats.RES_HP), _sec(16.8), "非直接伤害不吃格挡：(16 − 4 护甲) × 1.4 = 16.8")


static func run_decay_death(t: TestCase) -> void:
	t.begin("103 · 衰竭：上限掉到 0 就倒下；蛮神的不死照常坚持；没有平局；同刻双倒按裁决")
	var r := BattleSim.run(_dummy(20.0), _dummy(100.0), RandomNumberGenerator.new())
	t.eq(r.winner, 1, "谁都不出手：上限先归零的一方倒下")
	t.eq(r.duration, _sec(63.0), "20 血：60、61、62、63 秒各掉 5，第 63 秒归零")
	t.check(not r.is_draw(), "不再有平局")
	var died := 0
	for e in r.log:
		if e.name == BattleEvent.DIED:
			died += 1
	t.eq(died, 1, "只倒一个")

	var tough := _dummy(20.0)
	tough.undying_sec = 3.0
	var r2 := BattleSim.run(tough, _dummy(40.0), RandomNumberGenerator.new())
	t.eq(r2.winner, 1, "蛮神不死：上限归零后坚持 3 秒，对手 40 血撑到 67 秒 → 我方 66 秒真倒下")
	t.eq(r2.duration, _sec(66.0), "63 秒归零 + 3 秒坚持 = 66 秒")

	var tie := BattleSim.run(_dummy(20.0), _dummy(20.0), RandomNumberGenerator.new())
	t.eq(tie.winner, 0, "同刻双倒、血量相同、都没打出伤害：判玩家胜")
	var ctx := _ctx(_dummy(20.0), _dummy(20.0))
	var dealt: Array[int] = [_sec(5.0), _sec(3.0)]
	ctx.log.append(BattleEvent.make(BattleEvent.DAMAGE, 0, 0, {"amount": _sec(3.0)}))
	ctx.log.append(BattleEvent.make(BattleEvent.DAMAGE, 0, 1, {"amount": _sec(5.0)}))
	t.eq(BattleSim.damage_dealt(ctx.log), dealt, "总伤害：受害方是对手")
	ctx.sides[0].dead = true
	ctx.sides[1].dead = true
	t.eq(BattleSim._winner(ctx, [_sec(1.0), _sec(2.0)] as Array[int]), 1, "先比倒下前的血量：多者胜")
	t.eq(BattleSim._winner(ctx, [_sec(2.0), _sec(2.0)] as Array[int]), 0, "血量一样比总伤害：side 0 打出 5 > 3")

	var stalemate := BattleSim.run(_dummy(100.0), _dummy(100.0), RandomNumberGenerator.new(), 5.0)
	t.check(stalemate.is_draw(), "只有打到安全上限才是平局")

	var fight := BattleSim.run(_hitter(100.0, 3.0, 1.0), _hitter(100.0, 3.0, 1.0), RandomNumberGenerator.new())
	t.check(fight.winner >= 0 and fight.duration < _sec(BattleSim.DEFAULT_TIME_LIMIT), "势均力敌也有胜负（%s）" % fight)


static func run_system_buffs(t: TestCase) -> void:
	t.begin("103 · 系统层 / 系统 buff 不可解除：净化、消耗层数都对它无效")
	var ctx := _ctx(_dummy(1000.0), _dummy(1000.0))
	FX._advance_to(ctx, 62.0)
	var me := ctx.sides[0]
	me.shift_axis(StatAxes.DAMAGE_TAKEN, 2)
	t.eq(me.axis_system(StatAxes.DAMAGE_TAKEN), 28, "系统层 28 层（7 次 × 4）")
	t.eq(me.remove_buff_stacks(OvertimeRules.DECAY_ID, 99), 0, "衰竭：remove_buff_stacks 挡住")
	var purge := RemoveStatus.new()
	purge.buff_id = OvertimeRules.DECAY_ID
	purge.stacks = 0
	purge.apply(RuleContext.create(ctx, me, RuleRuntime.create(null, 0, null, 0)))
	t.eq(me.stacks_of(OvertimeRules.DECAY_ID), 3, "净化全部：衰竭还是 3 层")
	var cost := StatusStackCost.new()
	cost.buff_id = OvertimeRules.DECAY_ID
	cost.stacks = 1
	t.check(not cost.can_pay(RuleContext.create(ctx, me, RuleRuntime.create(null, 0, null, 0))), "不能拿衰竭层数当消耗")
	var ot := OvertimeRules.or_default(null)
	t.check(ot.decay_buff().system and ot.decay_buff().is_debuff, "衰竭是系统减益")
	t.check(ot.decay_buff().is_stackable() and ot.decay_buff().is_permanent(), "不限层、永续（默认形态）")


static func run_buff_bar(t: TestCase) -> void:
	t.begin("103 · buff 栏：上过身的 buff 都在 result.buffs；栏里系统 → 减益 → 增益 → 常驻；不可叠层不画 ×1")
	var poison := BuffDef.new()
	poison.id = &"t_poison"
	poison.is_debuff = true
	var single := BuffDef.new()
	single.id = &"t_once"
	single.display_name = "专注"
	single.stackable = false
	var apply_poison := ApplyStatus.new()
	apply_poison.buff = poison
	var apply_single := ApplyStatus.new()
	apply_single.buff = single
	apply_single.target = CombatEffect.Target.SELF
	var a := FX._spec(100.0, [FX._compiled(1, "w", {"damage": 1.0}, [FX._rule(OnSchedule.new(), FX._cooldown(2.0), [FX._damage(), apply_poison, apply_single])])])
	var r := BattleSim.run(a, _dummy(60.0), RandomNumberGenerator.new())
	var missing: Array = []
	for e in r.log:
		if e.name == BattleEvent.STATUS_STACKED and not r.buffs.has(e.get_name(&"buff")):
			missing.append(e.get_name(&"buff"))
	t.check(missing.is_empty(), "日志里叠过的每个 buff 都有定义（缺 %s）" % [missing])
	t.check(r.buffs.has(&"t_poison") and r.buffs.has(OvertimeRules.DECAY_ID), "对手给的、系统给的都在")

	var panel := CombatantPanel.new()
	panel.buff_defs = r.buffs
	panel.passives = [PassiveNote.make(&"faith:x", "信仰：自然之神", 3)]
	panel.set_stacks("t_once", 1)
	panel.set_stacks("t_poison", 4)
	panel.set_overtime(2)
	panel.set_axis("attack_speed", 5)
	panel.set_axis("damage_dealt", -2)
	t.eq(panel.ordered_ids(), ["system:overtime", "t_poison", "axis:damage_dealt", "t_once", "axis:attack_speed", "passive:0"], "系统 → 减益 → 增益（组内按上身先后）→ 常驻")
	t.eq(panel.chip_text("axis:attack_speed"), "加 ×5", "轴格：正层用正名")
	t.eq(panel.chip_text("axis:damage_dealt"), "虚 ×2", "轴格：负层用负名、画绝对值")
	t.eq(panel.chip_text("t_once"), "专", "不可叠层不画 ×1")
	t.eq(panel.chip_text("t_poison"), "t ×4", "可叠层画层数")
	t.eq(panel.chip_text("passive:0"), "信 ×3", "常驻格画阶数")
	panel.free()

	var view := BattleView.new()
	view.label_font = UiPalette.cjk_font()
	view._ready()
	r.passives = [[PassiveNote.make(&"set:x", "猎人套装 3 件", 1, [FX._mod(BattleStats.DAMAGE, 10)])], []]
	view.play(r, ["我", "敌"])
	var ot := Glossary.strip_bbcode(view.buff_tip(CombatantPanel.OVERTIME_CHIP))
	t.check(ot.contains("鏖战") and ot.contains("系统") and ot.contains("受到的最终伤害") and not ot.contains("不可解除"), "鏖战的悬浮窗：名字行 + 合计，不写内部说明（185）：%s" % ot)
	var pv := Glossary.strip_bbcode(view.buff_tip("passive:0", 0))
	t.check(pv.contains("常驻") and pv.contains("10%"), "常驻格的悬浮窗列出它的加成：%s" % pv)
	view.free()


static func run_general_only(t: TestCase) -> void:
	t.begin("103 · buff 栏只放通用 buff：作用于角色本身的信仰效果进栏，只给某件 / 某类道具的不进")
	var low := LowHpEmpowerPerk.new()
	t.check(low.battle_note(null) != "", "所有伤害按血量增伤：进栏")
	var base := StatModPerk.new()
	base.mods.append(FX._mod(BattleStats.REGEN_HP, 0, 1.0))
	t.check(base.battle_note(null) != "", "基线回血：进栏")
	var tagged := StatModPerk.new()
	tagged.target = "items"
	tagged.item_tag = &"weapon"
	t.eq(tagged.battle_note(null), "", "只给带武器标签的道具：不进")
	t.eq(EnchantWeaponsPerk.new().battle_note(null), "", "随机几把武器附魔：不进")
	t.eq(FoodDoublePerk.new().battle_note(null), "", "食物翻倍：不进")
	t.eq(OvertimeRegenPerk.new().battle_note(null), "", "加时回春：上身时以回血轴显示，不另开常驻格")
	t.eq(BattlePassives.of(null).size(), 0, "没有一局：没有常驻格")


static func run_axes(t: TestCase) -> void:
	t.begin("103 4e · 标准轴：带符号层数、增减相抵、公式最后一步、固定值轴、按上限回血、改轴效果与扳机")
	var a := _hitter(100.0, 10.0, 1.0)
	var ctx := _ctx(a, _dummy(1000.0))
	var me := ctx.sides[0]
	var haste0 := me.item_stat(1, BattleStats.HASTE)
	me.shift_axis(StatAxes.ATTACK_SPEED, 3)
	me.shift_axis(StatAxes.ATTACK_SPEED, -1)
	t.eq(me.axis_stacks(StatAxes.ATTACK_SPEED), 2, "3 层加速 + 1 层减速 = +2")
	t.eq(me.item_stat(1, BattleStats.HASTE), StatMath.mul(haste0, _sec(1.06)), "攻速 × (1 + 2 × 3%)")
	me.shift_axis(StatAxes.DAMAGE_DEALT, 10)
	t.eq(me.item_stat(1, BattleStats.DAMAGE), _sec(13.0), "伤害 10 × 1.3")
	me.shift_axis(StatAxes.DAMAGE_DEALT, -50)
	t.eq(me.item_stat(1, BattleStats.DAMAGE), 0, "因子低于 0 钳到 0")
	me.shift_axis(StatAxes.REGEN_HP, 3)
	t.eq(me.stat(BattleStats.REGEN_HP), _sec(3.0), "回血轴是固定值：+3 / 秒")
	me.shift_axis(StatAxes.REGEN_HP_PCT, 2)
	t.eq(me.stat(BattleStats.REGEN_HP), _sec(5.0), "按上限回血：100 × 2% = +2 / 秒")
	t.eq(StatAxes.name_of(StatAxes.ATTACK_SPEED, 1), "加速", "正名")
	t.eq(StatAxes.name_of(StatAxes.ATTACK_SPEED, -1), "减速", "负名")

	var shift := ShiftAxis.new()
	shift.axis = StatAxes.DAMAGE_TAKEN
	shift.delta = -2
	shift.target = CombatEffect.Target.OPPONENT
	var trig := OnAxisAtLeast.new()
	trig.axis = StatAxes.DAMAGE_TAKEN
	trig.stacks = -2
	trig.on_self = true
	var b := FX._spec(100.0, [FX._compiled(1, "w", {"damage": 1.0}, [FX._rule(OnSchedule.new(), FX._cooldown(1.0), [shift])])])
	var watcher := FX._spec(100.0, [FX._compiled(1, "w", {"damage": 1.0}, [FX._rule(trig, Always.new(), [FX._damage(7.0)])])])
	var ctx2 := _ctx(b, watcher)
	FX._advance_to(ctx2, 1.0)
	t.eq(ctx2.sides[1].axis_stacks(StatAxes.DAMAGE_TAKEN), -2, "shift_axis 给对手 −2 层（坚韧）")
	var shifted := 0
	for e in ctx2.log:
		if e.name == BattleEvent.AXIS_SHIFTED:
			shifted += 1
	t.eq(shifted, 1, "记一条 axis_shifted")
	t.check(ctx2.sides[0].resources.current(BattleStats.RES_HP) < _sec(100.0), "on_axis_at_least（−2）命中：对手回击")
	t.eq(DamageResolver.deal(ctx2, ctx2.sides[1], _sec(10.0)), _sec(9.0), "坚韧 2 层：受到伤害 × 0.9")

	var warn := ImportReport.new()
	ContentImporter.import_buff({"id": "t_fast", "mods": [{"stat": "haste", "mode": "MULT", "amount": 5}]}, ContentImporter.Context.new(), warn)
	t.check(warn.to_text().contains("shift_axis"), "只有一条攻速 mod 的 buff：提示改用轴（%s）" % warn.to_text())
