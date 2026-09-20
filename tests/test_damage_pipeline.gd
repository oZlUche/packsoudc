## 伤害结算管线：类型性质、护盾吸收、受伤前改写、护甲、流失（架构文档 4.6）。
extends RefCounted

const H := preload("res://tests/test_effect_system.gd")


#region helper
static func _start(ctx: BattleContext) -> void:
	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()


static func _hp(ctx: BattleContext, side: int) -> int:
	return StatMath.to_int(ctx.sides[side].resources.current(BattleStats.RES_HP))


static func _shield(ctx: BattleContext, side: int) -> int:
	return StatMath.to_int(ctx.sides[side].resources.current(BattleStats.RES_SHIELD))


static func _hit(amount: float, type: StringName = DamageTypes.PHYSICAL) -> DealDamage:
	var e := DealDamage.new()
	e.damage_stat = &""
	e.amount = amount
	e.damage_type = type
	return e


static func _opener(effects: Array) -> AbilityRule:
	return H._rule(OnBattleStart.new(), Always.new(), effects)


## 攻击方：**1 秒时**打一下，不是开场就打。
##
## 派发顺序固定为先 side 0 后 side 1，开场就打会赶在防守方布好护盾、叠好格挡之前，
## 测到的就不是想测的东西。让攻击迟一拍，防守方的开场规则才有机会先跑完。
static func _attacker(amount: float, type: StringName = DamageTypes.PHYSICAL) -> CombatantSpec:
	var cd := CooldownCadence.new()
	cd.seconds = 1.0
	return H._spec(100.0, [H._compiled(1, "gun", {},
		[H._rule(OnSchedule.new(), cd, [_hit(amount, type)])])])


## 开场结算完，再推进到攻击落下之后
static func _run(ctx: BattleContext) -> void:
	_start(ctx)
	H._advance_to(ctx, 1.5)


## 防守方：可带护盾与护甲，可带一条受伤前规则
static func _defender(
	stats: Dictionary = {}, before: AbilityRule = null
) -> CombatantSpec:
	var rules: Array = []
	if before != null:
		rules.append(before)
	return H._spec(100.0, [H._compiled(2, "vest", stats, rules)])


static func _before_rule(
	effect: CombatEffect, type: StringName = &"", costs: Array = []
) -> AbilityRule:
	var t := OnBeforeDamage.new()
	t.direction = DamageTrigger.Direction.TAKEN
	t.damage_type = type
	return H._rule(t, Always.new(), [effect], costs)
#endregion


static func run(t: TestCase) -> void:
	t.begin("伤害 · 类型注册表")

	DamageTypes.reset_to_builtins()

	t.eq(DamageTypes.get_def(DamageTypes.PHYSICAL).shield_absorbable, true, "物理可被护盾吸收")
	t.eq(DamageTypes.get_def(DamageTypes.POISON).shield_absorbable, false, "中毒绕过护盾")
	t.eq(DamageTypes.get_def(DamageTypes.POISON).armor_applies, false, "中毒也无视护甲")
	t.eq(DamageTypes.get_def(DamageTypes.DRAIN).notifies, false,
		"流失不通知默认的受伤监听 —— 否则割自己一刀成了正收益")
	t.eq(DamageTypes.get_def(DamageTypes.DRAIN).shield_absorbable, false, "流失不吃护盾")

	# 内容可以追加类型，结算代码一行不改
	var corrode := DamageTypeDef.new()
	corrode.id = &"corrode"
	corrode.display_name = "腐蚀"
	corrode.shield_absorbable = true
	corrode.armor_applies = false
	t.check(DamageTypes.register(corrode), "登记新类型")
	t.check(not DamageTypes.register(corrode), "重复 id 被拒，不覆盖")
	t.check(DamageTypes.has(&"corrode"), "登记后查得到")
	t.eq(DamageTypes.get_def(&"corrode").armor_applies, false, "新类型的性质生效")

	# 打错字不该静默变成无敌
	var unknown := DamageTypes.get_def(&"typo_here")
	t.eq(unknown.shield_absorbable, true, "未登记类型退回常规默认值")

	DamageTypes.reset_to_builtins()
	t.check(not DamageTypes.has(&"corrode"), "重置后只剩内置四种")
	t.eq(DamageTypes.ids().size(), 4, "内置四种")


static func run_shield(t: TestCase) -> void:
	t.begin("伤害 · 护盾吸收")

	# max_shield 自动派生出 shield 资源，不需要为它改任何代码
	var ctx := H._battle(_attacker(20.0), _defender({"max_shield": 30.0}))
	_run(ctx)
	t.eq(_shield(ctx, 1), 10, "20 点被护盾吃下，护盾剩 10")
	t.eq(_hp(ctx, 1), 100, "血量没掉")

	# --- 溢出部分见血 ---
	var ctx2 := H._battle(_attacker(50.0), _defender({"max_shield": 30.0}))
	_run(ctx2)
	t.eq(_shield(ctx2, 1), 0, "护盾打空")
	t.eq(_hp(ctx2, 1), 80, "溢出的 20 点扣血")

	# --- 中毒绕过护盾 ---
	var ctx3 := H._battle(
		_attacker(20.0, DamageTypes.POISON), _defender({"max_shield": 30.0})
	)
	_run(ctx3)
	t.eq(_shield(ctx3, 1), 30, "护盾纹丝不动")
	t.eq(_hp(ctx3, 1), 80, "中毒直接见血")

	# --- 没有护盾资源的单位照常挨打 ---
	var ctx4 := H._battle(_attacker(20.0), _defender())
	_run(ctx4)
	t.eq(_hp(ctx4, 1), 80, "没配 max_shield 就没有护盾，不报错")


static func run_armor(t: TestCase) -> void:
	t.begin("伤害 · 护甲")

	var ctx := H._battle(_attacker(20.0), _defender({"armor": 5.0}))
	_run(ctx)
	t.eq(_hp(ctx, 1), 85, "护甲 5 点，20 → 15")

	# 护甲挡不住中毒
	var ctx2 := H._battle(_attacker(20.0, DamageTypes.POISON), _defender({"armor": 5.0}))
	_run(ctx2)
	t.eq(_hp(ctx2, 1), 80, "中毒无视护甲")

	# 护甲高于伤害时归零，不会倒扣成治疗
	var ctx3 := H._battle(_attacker(3.0), _defender({"armor": 5.0}))
	_run(ctx3)
	t.eq(_hp(ctx3, 1), 100, "护甲高于伤害时归零，不倒扣")

	# 护盾先吃，护甲再挡余下的
	var ctx4 := H._battle(_attacker(20.0), _defender({"max_shield": 8.0, "armor": 5.0}))
	_run(ctx4)
	t.eq(_shield(ctx4, 1), 0, "护盾吃掉 8")
	t.eq(_hp(ctx4, 1), 93, "余下 12 再被护甲挡 5，实扣 7")


static func run_before_damage(t: TestCase) -> void:
	t.begin("伤害 · 受伤前改写")

	# --- 固定减伤 ---
	var flat := ModifyDamage.new()
	flat.flat = -8.0
	var ctx := H._battle(_attacker(20.0), _defender({}, _before_rule(flat)))
	_run(ctx)
	t.eq(_hp(ctx, 1), 88, "受伤前减免 8 点")

	# --- 百分比减伤 ---
	var half := ModifyDamage.new()
	half.percent = -50
	var ctx2 := H._battle(_attacker(20.0), _defender({}, _before_rule(half)))
	_run(ctx2)
	t.eq(_hp(ctx2, 1), 90, "减半")

	# --- 完全免疫 ---
	var immune := ModifyDamage.new()
	immune.cancel = true
	var ctx3 := H._battle(_attacker(50.0), _defender({}, _before_rule(immune)))
	_run(ctx3)
	t.eq(_hp(ctx3, 1), 100, "取消这一次，一点不掉")

	# --- 反转：解毒剂让中毒变治疗 ---
	var antidote := ModifyDamage.new()
	antidote.invert = true
	var self_cut := _hit(40.0)
	self_cut.target = CombatEffect.Target.SELF
	var healer := H._spec(100.0, [
		H._compiled(2, "cut", {}, [_opener([self_cut])]),          # 开场自伤，腾出血量
		H._compiled(3, "antidote", {}, [_before_rule(antidote, DamageTypes.POISON)]),
	])
	var ctx4 := H._battle(_attacker(30.0, DamageTypes.POISON), healer)
	_run(ctx4)
	t.eq(_hp(ctx4, 1), 90, "自伤 40 之后，30 点中毒被反转成 30 点治疗")

	# --- 减伤只对指定类型生效 ---
	var fire_ward := ModifyDamage.new()
	fire_ward.cancel = true
	var ctx5 := H._battle(
		_attacker(20.0, DamageTypes.PHYSICAL),
		_defender({}, _before_rule(fire_ward, DamageTypes.FIRE))
	)
	_run(ctx5)
	t.eq(_hp(ctx5, 1), 80, "只挡火焰的护符挡不住物理")


static func run_conditional_mitigation(t: TestCase) -> void:
	t.begin("伤害 · 有条件的减伤（消耗层）")

	# 「消耗 2 层格挡减免 10 点」—— 前置条件由消耗层表达，
	# 这正是减伤不能写成一个固定属性的原因。
	var block := BuffDef.new()
	block.id = &"block"
	block.max_stacks = 10

	var seed := ApplyStatus.new()
	seed.target = CombatEffect.Target.SELF
	seed.buff = block
	seed.stacks = 2

	var cost := StatusStackCost.new()
	cost.buff_id = &"block"
	cost.stacks = 2

	var mitigate := ModifyDamage.new()
	mitigate.flat = -10.0

	var make_defender := func(stacks: int) -> CombatantSpec:
		var s := ApplyStatus.new()
		s.target = CombatEffect.Target.SELF
		s.buff = block
		s.stacks = stacks
		return H._spec(100.0, [
			H._compiled(2, "brace", {}, [_opener([s])]),
			H._compiled(3, "guard", {}, [_before_rule(mitigate, &"", [cost])]),
		])

	# 层数够：减免生效，层数被扣掉
	var ctx := H._battle(_attacker(20.0), make_defender.call(2))
	_run(ctx)
	t.eq(_hp(ctx, 1), 90, "消耗 2 层，减免 10 点")
	t.eq(ctx.sides[1].stacks_of(&"block"), 0, "层数被扣掉")

	# 层数不够：全额挨打，层数不被白吃
	var ctx2 := H._battle(_attacker(20.0), make_defender.call(1))
	_run(ctx2)
	t.eq(_hp(ctx2, 1), 80, "层数不够，减免不生效")
	t.eq(ctx2.sides[1].stacks_of(&"block"), 1, "付不起就不扣，1 层留着")


static func run_drain(t: TestCase) -> void:
	t.begin("伤害 · 流失也走管线")

	# 超频：以血换速。扣血走管线，类型是流失
	var bleed := ChangeResource.new()
	bleed.resource_key = BattleStats.RES_HP
	bleed.amount = -20.0

	# --- 流失不点亮吸血 ---
	var leech := ChangeResource.new()
	leech.resource_key = BattleStats.RES_HP
	leech.amount = 5.0
	var any_damage := OnDamage.new()
	any_damage.direction = DamageTrigger.Direction.TAKEN

	var ctx := H._battle(H._spec(100.0, [
		H._compiled(1, "overclock", {}, [_opener([bleed])]),
		H._compiled(2, "sigil", {}, [H._rule(any_damage, Always.new(), [leech])]),
	]), H._spec(100.0, []))
	_start(ctx)
	t.eq(_hp(ctx, 0), 80, "自伤 20")
	t.eq(ctx.sides[0].resources.current(BattleStats.RES_HP),
		StatMath.from_float(80.0), "受伤效果没有被点亮，没有回那 5 点")

	# --- 但显式指定流失就听得见：留给未来联动效果的口子 ---
	var on_drain := OnDamage.new()
	on_drain.direction = DamageTrigger.Direction.TAKEN
	on_drain.damage_type = DamageTypes.DRAIN
	var ctx2 := H._battle(H._spec(100.0, [
		H._compiled(1, "overclock", {}, [_opener([bleed])]),
		H._compiled(2, "sigil", {}, [H._rule(on_drain, Always.new(), [leech])]),
	]), H._spec(100.0, []))
	_start(ctx2)
	t.eq(_hp(ctx2, 0), 85, "显式监听流失，回了 5 点")

	# --- 流失不吃护盾，但吃得到受伤前减伤 ---
	var soften := ModifyDamage.new()
	soften.percent = -50
	var before := OnBeforeDamage.new()
	before.direction = DamageTrigger.Direction.TAKEN
	before.damage_type = DamageTypes.DRAIN
	var ctx3 := H._battle(H._spec(100.0, [
		H._compiled(1, "overclock", {"max_shield": 30.0}, [_opener([bleed])]),
		H._compiled(2, "damper", {}, [H._rule(before, Always.new(), [soften])]),
	]), H._spec(100.0, []))
	_start(ctx3)
	t.eq(_shield(ctx3, 0), 30, "流失绕过护盾")
	t.eq(_hp(ctx3, 0), 90, "但减伤对它照样生效 —— 这正是让它走管线的理由")

	# --- 非血量资源不走管线 ---
	var spend := ChangeResource.new()
	spend.resource_key = BattleStats.RES_STAMINA
	spend.amount = -10.0
	var ctx4 := H._battle(H._spec(100.0, [
		H._compiled(1, "pump", {"max_stamina": 50.0}, [_opener([spend])]),
	]), H._spec(100.0, []))
	_start(ctx4)
	t.eq(StatMath.to_int(ctx4.sides[0].resources.current(BattleStats.RES_STAMINA)), 40,
		"耐力照常直接扣，管线只管血量")


static func run_nesting_guard(t: TestCase) -> void:
	t.begin("伤害 · 嵌套深度上限")

	# 两件互相反伤的道具：受伤前效果自己又造成伤害，会一层层套下去
	var reflect_a := _hit(5.0)
	var reflect_b := _hit(5.0)
	var side_a := H._spec(500.0, [
		H._compiled(1, "gun", {}, [_opener([_hit(10.0)])]),
		H._compiled(2, "thorns_a", {}, [_before_rule(reflect_a)]),
	])
	var side_b := H._spec(500.0, [
		H._compiled(3, "thorns_b", {}, [_before_rule(reflect_b)]),
	])

	var ctx := H._battle(side_a, side_b)
	_start(ctx)

	# 关键断言：跑得完，没有栈溢出
	t.check(true, "互相反伤没有把栈打穿")
	var overflowed := false
	for e in ctx.log:
		if (e as BattleEvent).name == BattleEvent.DISPATCH_OVERFLOW:
			overflowed = true
	t.check(overflowed, "达到上限时记了一条 dispatch_overflow，便于内容配错时定位")
	t.check(_hp(ctx, 0) < 500 and _hp(ctx, 1) < 500, "双方都实际挨了打，不是被整条跳过")
