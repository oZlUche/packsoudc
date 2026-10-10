## 伤害结算管线：类型性质、护盾吸收、受伤前改写、护甲、流失（架构文档 4.6）。
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")


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
	t.eq(DamageTypes.get_def(DamageTypes.DRAIN).provokes, false,
		"流失不招致反应 —— 否则割自己一刀成了正收益")
	t.eq(DamageTypes.get_def(DamageTypes.POISON).provokes, false, "中毒不招致反应")
	t.eq(DamageTypes.get_def(DamageTypes.BLEED).provokes, false, "流血不招致反应")
	t.eq(DamageTypes.get_def(DamageTypes.REFLECT).provokes, false,
		"**反伤自己不招致反伤** —— 这是对轰在第一层就终止的真正原因，不是靠深度上限")
	t.eq(DamageTypes.get_def(DamageTypes.PHYSICAL).provokes, true, "直接攻击才招致反应")
	t.eq(DamageTypes.get_def(DamageTypes.DRAIN).shield_absorbable, false, "流失不吃护盾")

	# 内容可以追加类型，结算代码一行不改
	var corrode := DamageTypeDef.new()
	corrode.id = &"corrode"
	corrode.display_name = "腐蚀"
	corrode.shield_absorbable = true
	t.check(DamageTypes.register(corrode), "登记新类型")
	t.check(not DamageTypes.register(corrode), "重复 id 被拒，不覆盖")
	t.check(DamageTypes.has(&"corrode"), "登记后查得到")
	t.eq(DamageTypes.get_def(&"corrode").shield_absorbable, true, "新类型的性质生效")

	# 打错字不该静默变成无敌
	var unknown := DamageTypes.get_def(&"typo_here")
	t.eq(unknown.shield_absorbable, true, "未登记类型退回常规默认值")

	DamageTypes.reset_to_builtins()
	t.check(not DamageTypes.has(&"corrode"), "重置后只剩内置四种")
	t.eq(DamageTypes.ids().size(), 8, "内置八种（148 加了冰霜、闪电）")


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

	var ctx := H._battle(_attacker(20.0), _defender({"block": 5.0}))
	_run(ctx)
	t.eq(_hp(ctx, 1), 85, "护甲 5 点，20 → 15")

	# 106 第八节（作者定）：防护按**来源**生效，不按伤害类型 —— 武器直接打出的毒也算直接伤害，
	# 所以照样被防护减（真实内容里的中毒 / 流血都挂在 buff 上，见 run_direct_damage）
	var ctx2 := H._battle(_attacker(20.0, DamageTypes.POISON), _defender({"block": 5.0}))
	_run(ctx2)
	t.eq(_hp(ctx2, 1), 85, "武器直接打出的中毒也吃防护（106：按来源，不按类型）")

	# 护甲高于伤害时归零，不会倒扣成治疗
	var ctx3 := H._battle(_attacker(3.0), _defender({"block": 5.0}))
	_run(ctx3)
	t.eq(_hp(ctx3, 1), 100, "护甲高于伤害时归零，不倒扣")

	# 护盾先吃，护甲再挡余下的
	var ctx4 := H._battle(_attacker(20.0), _defender({"max_shield": 8.0, "block": 5.0}))
	_run(ctx4)
	t.eq(_shield(ctx4, 1), 0, "护盾吃掉 8")
	t.eq(_hp(ctx4, 1), 93, "余下 12 再被防护挡 5，实扣 7")


static func run_before_damage(t: TestCase) -> void:
	t.begin("伤害 · 受伤前改写")

	# --- 固定减伤 ---
	var flat := ModifyDamage.new()
	flat.flat = -8.0
	var ctx := H._battle(_attacker(20.0), _defender({}, _before_rule(flat)))
	_run(ctx)
	t.eq(_hp(ctx, 1), 88, "受伤前减免 8 点")
	var over := ModifyDamage.new()
	over.flat = -8.0
	var ctx_over := H._battle(_attacker(3.0), _defender({}, _before_rule(over)))
	_run(ctx_over)
	t.eq(_hp(ctx_over, 1), 100, "减伤减过头是 0，不是回血（作者反馈：塔盾对匕首显示成「回复」）")

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
	t.begin("伤害 · 深度上限（兜底，不是防线）")

	# 这里【故意】用 deal_damage(physical) 手写反伤，把类型配错。
	# physical 会招致反应，于是双方一层层对轰下去 —— 上限在这时兜住。
	# 正确的写法见下一组：用 reflect_damage，它在第一层就终止。
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


static func run_reflect(t: TestCase) -> void:
	t.begin("伤害 · 反伤靠类型终止，不靠深度上限")

	# 两件都用 reflect_damage 的道具互相反伤。
	# reflect 类型 provokes 为 false，所以 A 弹给 B 的那一下不会再引发 B 的反伤 ——
	# 对轰在第一层就结束，而不是撞到深度上限被截断。
	var ra := ReflectDamage.new()
	ra.percent = 50
	var rb := ReflectDamage.new()
	rb.percent = 50

	var side_a := H._spec(500.0, [
		H._compiled(1, "gun", {}, [_opener([_hit(20.0)])]),
		H._compiled(2, "thorns_a", {}, [_before_rule(ra)]),
	])
	var side_b := H._spec(500.0, [
		H._compiled(3, "thorns_b", {}, [_before_rule(rb)]),
	])

	var ctx := H._battle(side_a, side_b)
	_start(ctx)

	t.eq(_hp(ctx, 1), 480, "B 挨了 20")
	t.eq(_hp(ctx, 0), 490, "B 弹回 10，**A 的反伤没有再被点燃**")

	var overflowed := false
	for e in ctx.log:
		if (e as BattleEvent).name == BattleEvent.DISPATCH_OVERFLOW:
			overflowed = true
	t.check(not overflowed, "根本没碰到深度上限 —— 语义把它挡住了，兜底没出场")


static func run_indirect_damage_does_not_provoke(t: TestCase) -> void:
	t.begin("伤害 · 间接伤害不招致反应")

	# 持续伤害每秒跳一次。若它能招致反伤，一个中毒 buff 就把反伤刷成了主要输出，
	# 而玩家根本没在攻击。
	var thorns := ReflectDamage.new()
	thorns.percent = 100

	var make_victim := func() -> CombatantSpec:
		return H._spec(200.0, [H._compiled(2, "thorns", {}, [_before_rule(thorns)])])

	for case in [
		{"type": DamageTypes.POISON, "name": "中毒"},
		{"type": DamageTypes.BLEED, "name": "流血"},
		{"type": DamageTypes.DRAIN, "name": "流失"},
	]:
		var ctx := H._battle(_attacker(20.0, case["type"]), make_victim.call())
		_run(ctx)
		t.eq(_hp(ctx, 1), 180, "%s 照常造成伤害" % case["name"])
		t.eq(_hp(ctx, 0), 100, "%s 不招致反伤" % case["name"])

	# 直接攻击照样招致
	var ctx2 := H._battle(_attacker(20.0, DamageTypes.PHYSICAL), make_victim.call())
	_run(ctx2)
	t.eq(_hp(ctx2, 1), 180, "物理造成伤害")
	t.eq(_hp(ctx2, 0), 80, "物理招致 100% 反伤")

	# --- 逃生口：显式写下类型名就听得见 ---
	# 作者写下 poison，就表示他知道自己在监听什么
	var explicit := ReflectDamage.new()
	explicit.percent = 100
	var t_poison := OnBeforeDamage.new()
	t_poison.direction = DamageTrigger.Direction.TAKEN
	t_poison.damage_type = DamageTypes.POISON
	var ctx3 := H._battle(
		_attacker(20.0, DamageTypes.POISON),
		H._spec(200.0, [H._compiled(2, "spite", {},
			[H._rule(t_poison, Always.new(), [explicit])])])
	)
	_run(ctx3)
	t.eq(_hp(ctx3, 0), 80, "显式监听 poison 的道具照样弹得回去")


static func run_reflect_details(t: TestCase) -> void:
	t.begin("伤害 · 反伤的边界情况")

	var thorns := ReflectDamage.new()
	thorns.percent = 50

	# 自伤不反弹：没有可以弹回去的对象
	var self_hit := _hit(20.0)
	self_hit.target = CombatEffect.Target.SELF
	var ctx := H._battle(H._spec(200.0, [
		H._compiled(1, "toll", {}, [_opener([self_hit])]),
		H._compiled(2, "thorns", {}, [_before_rule(thorns)]),
	]), H._spec(200.0, []))
	_start(ctx)
	t.eq(_hp(ctx, 0), 180, "自伤 20")
	t.eq(_hp(ctx, 1), 200, "对手毫发无损 —— 自伤不反弹")

	# 反弹量按【护盾吸收之后】的待结算量算：护盾扛住的部分不算在内
	var ctx2 := H._battle(
		_attacker(20.0),
		H._spec(200.0, [H._compiled(2, "thorns", {"max_shield": 12.0},
			[_before_rule(thorns)])])
	)
	_run(ctx2)
	t.eq(_shield(ctx2, 1), 0, "护盾吃掉 12")
	t.eq(_hp(ctx2, 0), 96, "只弹余下 8 的一半 = 4")

	# 反伤本身会被对方的护甲减免 —— 它是一包普通伤害，走完整管线
	var ctx3 := H._battle(
		H._spec(200.0, [
			H._compiled(1, "gun", {"block": 3.0}, []),
			H._compiled(4, "sched", {}, [_opener([_hit(20.0)])]),
		]),
		H._spec(200.0, [H._compiled(2, "thorns", {}, [_before_rule(thorns)])])
	)
	_start(ctx3)
	t.eq(_hp(ctx3, 0), 193, "弹回 10，被攻击方自己的 3 点护甲挡掉 3")


## 106 第八节（作者定）：直接 / 非直接看**来源** —— 武器造成的是直接（吃防护），buff 造成的不是（不吃）。
## 另有 `direct_override` 的「另行说明」口子
static func run_direct_damage(t: TestCase) -> void:
	t.begin("106 第八节 · 直接伤害按来源定：武器出手吃防护、buff 每秒掉血不吃、override 能两边强制")

	# 武器出手：uid 非 0、不来自 buff → 直接伤害，防护减得动
	var ctx := H._battle(_attacker(10.0), _defender({"block": 3.0}))
	_run(ctx)
	t.eq(_hp(ctx, 1), 93, "武器 10 点，防护 3 → 扣 7")

	# buff 每秒掉血：规则来自 buff → 非直接，防护不减（真实内容里的中毒 / 流血都是这一类：
	# 武器出手时 apply_status 挂一个 buff，掉血的那条规则属于 buff 而不是武器）
	var burn := BuffDef.new()
	burn.id = &"poison_test"
	burn.display_name = "中毒"
	burn.is_debuff = true
	var tick := CooldownCadence.new()
	tick.seconds = 1.0
	var self_tick := _hit(5.0, DamageTypes.POISON)
	self_tick.target = CombatEffect.Target.SELF
	var typed: Array[AbilityRule] = [H._rule(OnSchedule.new(), tick, [self_tick])]
	burn.rules = typed

	var poisoner := ApplyStatus.new()
	poisoner.target = ApplyStatus.Target.OPPONENT
	poisoner.buff = burn
	var attacker := H._spec(100.0, [H._compiled(1, "vial", {}, [_opener([poisoner])])])
	var ctx2 := H._battle(attacker, _defender({"block": 3.0}))
	_start(ctx2)
	H._advance_to(ctx2, 1.5)
	t.eq(_hp(ctx2, 1), 95, "buff 每秒 5 点毒伤不吃防护（非直接 —— 它来自 buff，不是武器）")

	# override：强制非直接 —— 武器打出的也不吃防护
	var soft := _hit(10.0)
	soft.direct_override = 0
	var cd := CooldownCadence.new()
	cd.seconds = 1.0
	var gun := H._spec(100.0, [H._compiled(1, "gun", {}, [H._rule(OnSchedule.new(), cd, [soft])])])
	var ctx5 := H._battle(gun, _defender({"block": 3.0}))
	_run(ctx5)
	t.eq(_hp(ctx5, 1), 90, "direct_override = 0：武器打出的也不吃防护（「另行说明」的口子）")


## 106 第六节（作者定）：防护为负（破绽）倒贴 —— 10 点打成 13
static func run_negative_armor(t: TestCase) -> void:
	t.begin("106 · 格挡 / 破绽轴：+3 层 10 点打成 7，−3 层打成 13，中毒（来自 buff）不受影响")

	var ctx := H._battle(_attacker(10.0), _defender())
	ctx.sides[1].shift_axis(StatAxes.BLOCK, 3)
	_run(ctx)
	t.eq(_hp(ctx, 1), 93, "格挡 3 层：10 点打出 7")

	var ctx2 := H._battle(_attacker(10.0), _defender())
	ctx2.sides[1].shift_axis(StatAxes.BLOCK, -3)
	_run(ctx2)
	t.eq(_hp(ctx2, 1), 87, "破绽 3 层：10 点打出 13（作者定：负防护倒贴）")

	# 破绽不会把治疗变成伤害，也不会把伤害放成负数：它只是加在伤害上
	var ctx3 := H._battle(_attacker(1.0), _defender())
	ctx3.sides[1].shift_axis(StatAxes.BLOCK, 10)
	_run(ctx3)
	t.eq(_hp(ctx3, 1), 100, "格挡高于伤害时归零，不倒扣成治疗")
