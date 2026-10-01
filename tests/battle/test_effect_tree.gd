## 统一效果树的新增面：伤害类型、增减资源、移除层数、双向目标，
## 以及三个状态条件型扳机（层数、资源、伤害）。见架构文档 4.4 与第 9 节。
extends RefCounted

const H := preload("res://tests/battle/test_effect_system.gd")


#region 构造 helper
## 只把战斗推到「开场规则全部结算完」这一刻。
##
## [b]注意结算顺序[/b]：一次派发里，被命中的规则会把自己的效果全部执行完
## （资源当场就改了），它们发出的事件排在队列尾，之后才轮到派发。
## 因此「同一条规则里先打两下」与「打一下、对方反应、再打一下」不是一回事，
## 下面凡是要观察反应的用例都把两下拆进不同的战斗。
static func _start(ctx: BattleContext) -> void:
	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()


static func _hp(ctx: BattleContext, side: int) -> int:
	return StatMath.to_int(ctx.sides[side].resources.current(BattleStats.RES_HP))


static func _buff(id: String, max_stacks: int = 0, duration: float = 0.0) -> BuffDef:
	var b := BuffDef.new()
	b.id = StringName(id)
	b.display_name = id
	b.max_stacks = max_stacks
	b.duration_sec = duration
	return b


## 一条「开场给自己叠 N 层」的规则，用来给状态扳机铺前置条件
static func _seed_stacks(def: BuffDef, n: int) -> AbilityRule:
	var e := ApplyStatus.new()
	e.target = CombatEffect.Target.SELF
	e.buff = def
	e.stacks = n
	return H._rule(OnBattleStart.new(), Always.new(), [e])


static func _flat_damage(amount: float, target: int = CombatEffect.Target.OPPONENT) -> DealDamage:
	var e := DealDamage.new()
	e.damage_stat = &""
	e.amount = amount
	e.target = target
	return e


static func _opener(effects: Array) -> AbilityRule:
	return H._rule(OnBattleStart.new(), Always.new(), effects)
#endregion


static func run(t: TestCase) -> void:
	t.begin("效果 · 增减资源与移除层数")

	# --- ChangeResource：正负同一条路径 ---
	var heal := ChangeResource.new()
	heal.resource_key = BattleStats.RES_HP
	heal.amount = 12.0
	var siphon := ChangeResource.new()
	siphon.resource_key = BattleStats.RES_HP
	siphon.amount = -5.0
	siphon.target = CombatEffect.Target.OPPONENT

	var ctx := H._battle(
		H._spec(100.0, [H._compiled(1, "vial", {}, [_opener([heal, siphon])])]),
		H._spec(100.0, [])
	)
	_start(ctx)
	t.eq(_hp(ctx, 1), 95, "负数 amount 就是扣除，不需要另写一个效果类")
	t.eq(_hp(ctx, 0), 100, "满血时治疗被上限截断")

	# 先受伤再治疗，验证正向
	var ctx2 := H._battle(
		H._spec(100.0, [H._compiled(1, "vial", {},
			[_opener([_flat_damage(30.0, CombatEffect.Target.SELF), heal])])]),
		H._spec(100.0, [])
	)
	_start(ctx2)
	t.eq(_hp(ctx2, 0), 82, "先扣 30 再回 12")

	# --- RemoveStatus ---
	var rage := _buff("rage", 10)
	var ctx3 := H._battle(
		H._spec(100.0, [H._compiled(1, "totem", {}, [_seed_stacks(rage, 5)])]),
		H._spec(100.0, [])
	)
	_start(ctx3)
	t.eq(ctx3.sides[0].stacks_of(&"rage"), 5, "先铺 5 层")

	var rc := RuleContext.new()
	rc.battle = ctx3
	rc.owner = ctx3.sides[0]

	var partial := RemoveStatus.new()
	partial.buff_id = &"rage"
	partial.stacks = 2
	partial.apply(rc)
	t.eq(ctx3.sides[0].stacks_of(&"rage"), 3, "移除 2 层")

	var purge := RemoveStatus.new()
	purge.buff_id = &"rage"
	purge.stacks = 0  # 0 = 全部
	purge.apply(rc)
	t.eq(ctx3.sides[0].stacks_of(&"rage"), 0, "stacks = 0 表示全部移除")
	purge.apply(rc)
	t.eq(ctx3.sides[0].stacks_of(&"rage"), 0, "没有层数时移除是安全的空操作")


static func run_both_target(t: TestCase) -> void:
	t.begin("效果 · 目标可同时指向双方")

	var ctx := H._battle(
		H._spec(100.0, [H._compiled(1, "nova", {},
			[_opener([_flat_damage(10.0, CombatEffect.Target.BOTH)])])]),
		H._spec(100.0, [])
	)
	_start(ctx)
	t.eq(_hp(ctx, 0), 90, "BOTH：自己也吃这 10 点")
	t.eq(_hp(ctx, 1), 90, "BOTH：对手同样")


static func run_damage_type(t: TestCase) -> void:
	t.begin("扳机 · 受到某类伤害时")

	# 伤害类型只是伤害事件上的一个标签，**不与任何乘区绑定** ——
	# 「火焰伤害」与「强化类乘区」是两件事，绑在一起就写不出
	# 「强化影响全部伤害」这种最常见的加成。
	var reprisal := OnDamage.new()
	reprisal.direction = OnDamage.Direction.TAKEN
	reprisal.damage_type = &"fire"
	reprisal.min_amount = 15.0

	var make_defender := func() -> CombatantSpec:
		return H._spec(100.0, [H._compiled(2, "ember_ward", {},
			[H._rule(reprisal, Always.new(), [_flat_damage(3.0)])])])

	var make_attacker := func(amount: float, type: StringName) -> CombatantSpec:
		var d := _flat_damage(amount)
		d.damage_type = type
		return H._spec(100.0, [H._compiled(1, "torch", {}, [_opener([d])])])

	# 火焰 20：类型对上、点数够，反击 3
	var ctx := H._battle(make_attacker.call(20.0, &"fire"), make_defender.call())
	_start(ctx)
	t.eq(_hp(ctx, 1), 80, "防守方吃了 20 点")
	t.eq(_hp(ctx, 0), 97, "火焰且 ≥15，反击生效")

	# 物理 20：点数够但类型不对
	var ctx2 := H._battle(make_attacker.call(20.0, &"physical"), make_defender.call())
	_start(ctx2)
	t.eq(_hp(ctx2, 0), 100, "类型不匹配，不反击")

	# 火焰 5：类型对但没到门槛
	var ctx3 := H._battle(make_attacker.call(5.0, &"fire"), make_defender.call())
	_start(ctx3)
	t.eq(_hp(ctx3, 0), 100, "5 点没到 15 点门槛，不反击")

	# 不限类型：damage_type 留空
	var any_type := OnDamage.new()
	any_type.direction = OnDamage.Direction.TAKEN
	var ctx4 := H._battle(
		make_attacker.call(20.0, &"physical"),
		H._spec(100.0, [H._compiled(2, "ward", {},
			[H._rule(any_type, Always.new(), [_flat_damage(3.0)])])])
	)
	_start(ctx4)
	t.eq(_hp(ctx4, 0), 97, "damage_type 留空表示不限类型")


static func run_damage_dealt(t: TestCase) -> void:
	t.begin("扳机 · 造成伤害时（吸血）")

	var dealt := OnDamage.new()
	dealt.direction = OnDamage.Direction.DEALT
	var lifesteal := ChangeResource.new()
	lifesteal.resource_key = BattleStats.RES_HP
	lifesteal.amount = 4.0

	# 先自伤 30 空出血量，再打对手 10 —— 自伤不该被算成「造成伤害」
	var ctx := H._battle(H._spec(100.0, [
		H._compiled(1, "toll", {}, [_opener([_flat_damage(30.0, CombatEffect.Target.SELF)])]),
		H._compiled(2, "fang", {}, [_opener([_flat_damage(10.0)])]),
		H._compiled(3, "sigil", {}, [H._rule(dealt, Always.new(), [lifesteal])]),
	]), H._spec(100.0, []))
	_start(ctx)
	t.eq(_hp(ctx, 1), 90, "对手挨了 10 点")
	t.eq(_hp(ctx, 0), 74, "自伤 30 后只吸回 4 —— 打到自己不算造成伤害")


static func run_stacks_trigger(t: TestCase) -> void:
	t.begin("扳机 · 拥有 N 层时（激活型 / 消耗型）")

	var charge := _buff("charge", 10)

	# --- 激活型：层数够就触发，层数留着 ---
	var act := OnStacksAtLeast.new()
	act.buff_id = &"charge"
	act.stacks = 3
	act.consume = false
	t.eq(act.implied_costs().size(), 0, "激活型不追加任何消耗")

	var ctx := H._battle(H._spec(100.0, [
		H._compiled(1, "coil", {}, [_seed_stacks(charge, 3)]),
		H._compiled(2, "bolt", {}, [H._rule(act, Always.new(), [_flat_damage(9.0)])]),
	]), H._spec(100.0, []))
	_start(ctx)
	t.eq(ctx.sides[0].stacks_of(&"charge"), 3, "激活型不吃层数")
	t.eq(_hp(ctx, 1), 91, "打出 9 点")

	# --- 消耗型：扳机隐式追加一条 StatusStackCost ---
	var con := OnStacksAtLeast.new()
	con.buff_id = &"charge"
	con.stacks = 3
	con.consume = true
	var implied := con.implied_costs()
	t.eq(implied.size(), 1, "消耗型隐式追加一条消耗")
	t.check(implied[0] is StatusStackCost, "追加的是层数消耗")
	t.eq((implied[0] as StatusStackCost).stacks, 3, "消耗层数与门槛一致")

	var rule := H._rule(con, Always.new(), [_flat_damage(9.0)])
	t.eq(rule.costs.size(), 0, "作者没手写任何消耗")
	t.eq(rule.effective_costs().size(), 1,
		"求值时才把扳机隐含的消耗并进来 —— 四层结构不破，作者只勾了一个框")

	var ctx2 := H._battle(H._spec(100.0, [
		H._compiled(1, "coil", {}, [_seed_stacks(charge, 3)]),
		H._compiled(2, "bolt", {}, [rule]),
	]), H._spec(100.0, []))
	_start(ctx2)
	t.eq(ctx2.sides[0].stacks_of(&"charge"), 0, "消耗型触发后层数被扣掉")
	t.eq(_hp(ctx2, 1), 91, "打出 9 点")

	# --- 层数不够：不触发，也不该吃掉已有的层 ---
	var ctx3 := H._battle(H._spec(100.0, [
		H._compiled(1, "coil", {}, [_seed_stacks(charge, 2)]),
		H._compiled(2, "bolt", {}, [H._rule(con, Always.new(), [_flat_damage(9.0)])]),
	]), H._spec(100.0, []))
	_start(ctx3)
	t.eq(ctx3.sides[0].stacks_of(&"charge"), 2, "只有 2 层，不触发")
	t.eq(_hp(ctx3, 1), 100, "没打出伤害")

	# --- 另一条消耗付不起时，层数同样不该被吃掉 ---
	# 这正是「扳机自己不扣层数」的理由：消耗必须发生在所有条件都通过之后，
	# 否则「攒够 3 层但耐力不够」会把 3 层白吃掉。
	var too_rich := ResourceCost.new()
	too_rich.resource_key = BattleStats.RES_HP
	too_rich.amount = 9999.0
	var ctx4 := H._battle(H._spec(100.0, [
		H._compiled(1, "coil", {}, [_seed_stacks(charge, 3)]),
		H._compiled(2, "bolt", {}, [H._rule(con, Always.new(), [_flat_damage(9.0)], [too_rich])]),
	]), H._spec(100.0, []))
	_start(ctx4)
	t.eq(ctx4.sides[0].stacks_of(&"charge"), 3, "付不起另一条消耗，3 层不会被白白吃掉")
	t.eq(_hp(ctx4, 1), 100, "效果也没执行")


static func run_resource_trigger(t: TestCase) -> void:
	t.begin("扳机 · 资源降到阈值以下时")

	var second_wind := ChangeResource.new()
	second_wind.resource_key = BattleStats.RES_HP
	second_wind.amount = 40.0

	var make := func(trigger: Trigger, self_damage: float) -> CombatantSpec:
		return H._spec(100.0, [
			H._compiled(1, "cut", {},
				[_opener([_flat_damage(self_damage, CombatEffect.Target.SELF)])]),
			H._compiled(2, "charm", {}, [H._rule(trigger, Always.new(), [second_wind])]),
		])

	# --- 比例阈值 ---
	var low := OnResourceBelow.new()
	low.resource_key = BattleStats.RES_HP
	low.percent = 30

	var ctx := H._battle(make.call(low, 25.0), H._spec(100.0, []))
	_start(ctx)
	t.eq(_hp(ctx, 0), 75, "75 还在 30% 之上，不触发")

	var ctx2 := H._battle(make.call(low, 75.0), H._spec(100.0, []))
	_start(ctx2)
	t.eq(_hp(ctx2, 0), 65, "跌到 25（≤ 30%）触发，回 40")

	# --- 绝对值阈值：percent 为 0 时改看 absolute ---
	var abs_low := OnResourceBelow.new()
	abs_low.resource_key = BattleStats.RES_HP
	abs_low.percent = 0
	abs_low.absolute = 80.0

	var ctx3 := H._battle(make.call(abs_low, 25.0), H._spec(100.0, []))
	_start(ctx3)
	t.eq(_hp(ctx3, 0), 100, "75 ≤ 80 触发，回 40 后被上限截断")

	# 回血本身也会发出 resource_changed，但那时已高于阈值，不会自激
	t.check(ctx2.pending() == 0, "结算干净，没有残留事件（回血不自激）")
