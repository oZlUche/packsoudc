## 效果系统骨架：资源池、buff、四层规则求值、事件掩码（架构文档 4.4 / 4.5）。
extends RefCounted

const TICK_HZ := 20


#region 构造helper
static func _mod(stat: StringName, category: int, percent: int, flat: float = 0.0) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.mult_category = category
	m.mult_percent = percent
	m.flat = flat
	return m


static func _compiled(uid: int, id: String, stats: Dictionary, rules: Array = []) -> CompiledItem:
	var it := CompiledItem.new()
	it.source_uid = uid
	it.def_id = StringName(id)
	it.stats = StatSet.new()
	for k in stats:
		it.stats.set_base(StringName(k), StatMath.from_float(float(stats[k])))
	var typed: Array[AbilityRule] = []
	for r in rules:
		typed.append(r)
	it.rules = typed
	return it


static func _spec(max_hp: float, items: Array) -> CombatantSpec:
	var s := CombatantSpec.new()
	s.max_hp = StatMath.from_float(max_hp)
	for it in items:
		s.add(it)
	return s


static func _rule(trigger: Trigger, cadence: Cadence, effects: Array, costs: Array = []) -> AbilityRule:
	var r := AbilityRule.new()
	r.trigger = trigger
	r.cadence = cadence
	var te: Array[Effect] = []
	for e in effects:
		te.append(e)
	r.effects = te
	var tc: Array[Cost] = []
	for c in costs:
		tc.append(c)
	r.costs = tc
	return r


static func _cooldown(seconds: float) -> CooldownCadence:
	var c := CooldownCadence.new()
	c.seconds = seconds
	return c


static func _damage(amount: float = 0.0) -> DealDamage:
	var e := DealDamage.new()
	if amount > 0.0:
		e.damage_stat = &""
		e.amount = amount
	return e


## 打自己。持续伤害类 debuff 用它 —— buff 挂在受害者身上，
## 它的规则就在受害者的 runtime 上跑，目标自然是 SELF 而不是 OPPONENT。
static func _self_damage(amount: float) -> DealDamage:
	var e := _damage(amount)
	e.target = DealDamage.Target.SELF
	return e


static func _battle(a: CombatantSpec, b: CombatantSpec, seed_value: int = 1) -> BattleContext:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return BattleContext.create(
		CombatantRuntime.from_spec(a, 0), CombatantRuntime.from_spec(b, 1), rng
	)


## 推进 n 帧。BattleSim 尚未实现，这里是它的最小等价物。
static func _run(ctx: BattleContext, ticks: int) -> void:
	for i in ticks:
		ctx.tick += 1
		RuleEngine.advance(ctx, StatMath.tick_delta(ctx.tick, TICK_HZ))
		ctx.emit(BattleEvent.TICK, -1, {})
		ctx.drain()
#endregion


static func run(t: TestCase) -> void:
	t.begin("资源池")

	var pool := ResourcePool.new()
	pool.define(BattleStats.RES_HP, StatMath.from_float(100.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_HP)), 100, "定义后充满")
	t.eq(StatMath.to_int(pool.maximum(BattleStats.RES_HP)), 100, "上限正确")

	# --- 实际变化量而非请求量 ---
	var actual := pool.change(BattleStats.RES_HP, StatMath.from_float(-30.0), BattleEvent.REASON_DAMAGE)
	t.eq(StatMath.to_int(actual), -30, "扣 30 实际扣 30")
	actual = pool.change(BattleStats.RES_HP, StatMath.from_float(-999.0), BattleEvent.REASON_DAMAGE)
	t.eq(StatMath.to_int(actual), -70, "打到 0 封顶：请求 999 实际只扣 70")
	t.eq(pool.current(BattleStats.RES_HP), 0, "生命归零")
	t.eq(pool.change(BattleStats.RES_HP, StatMath.from_float(-10.0), &"x"), 0, "已经 0 了再扣无变化")

	pool.change(BattleStats.RES_HP, StatMath.from_float(500.0), BattleEvent.REASON_HEAL)
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_HP)), 100, "超上限截断")

	# --- 上限增加时当前值同量增加 ---
	var log: Array = []
	pool.changed.connect(func(k, d, r): log.append([String(k), StatMath.to_int(d), String(r)]))

	pool.change(BattleStats.RES_HP, StatMath.from_float(-40.0), BattleEvent.REASON_DAMAGE)
	log.clear()
	pool.set_max(BattleStats.RES_HP, StatMath.from_float(130.0))
	t.eq(StatMath.to_int(pool.maximum(BattleStats.RES_HP)), 130, "上限升到 130")
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_HP)), 90, "当前值 60 同量 +30 变成 90")
	t.eq(log.size(), 1, "上限联动只发一条事件")
	t.eq(log[0][2], String(BattleEvent.REASON_MAX_CHANGED), "原因是 max_changed 而非 heal")

	# --- 上限降低时截断 ---
	log.clear()
	pool.set_max(BattleStats.RES_HP, StatMath.from_float(50.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_HP)), 50, "上限降到 50，当前值被截断")
	t.eq(log[0][2], String(BattleEvent.REASON_MAX_CHANGED), "同样记为 max_changed")

	t.check(pool.can_afford(BattleStats.RES_HP, StatMath.from_float(50.0)), "刚好付得起")
	t.check(not pool.can_afford(BattleStats.RES_HP, StatMath.from_float(51.0)), "差一点付不起")


static func run_runtime(t: TestCase) -> void:
	t.begin("战斗单位运行时")

	var B := StatMath.Buff

	# 资源由 max_* 属性自动派生
	var spec := _spec(50.0, [
		_compiled(1, "flask", {"max_stamina": 100.0, "max_mana": 30.0}),
	])
	var rt := CombatantRuntime.from_spec(spec, 0)
	t.check(rt.resources.has(BattleStats.RES_HP), "max_hp 派生出 hp 资源")
	t.check(rt.resources.has(BattleStats.RES_STAMINA), "max_stamina 派生出 stamina 资源")
	t.check(rt.resources.has(BattleStats.RES_MANA), "max_mana 派生出 mana 资源")
	t.eq(StatMath.to_int(rt.resources.maximum(BattleStats.RES_STAMINA)), 100, "耐力上限")
	t.eq(rt.stat_int(BattleStats.MAX_HP), 50, "生命上限来自 spec")

	# --- buff 改属性，且每层一份 ---
	var strong := BuffDef.new()
	strong.id = &"strong"
	strong.mods = [_mod(BattleStats.MAX_HP, B.EMPOWER, 0, 20.0)] as Array[StatModifier]
	strong.max_stacks = 3

	rt.apply_buff(strong, 1)
	t.eq(rt.stat_int(BattleStats.MAX_HP), 70, "强壮 1 层：生命上限 +20")
	t.eq(StatMath.to_int(rt.resources.current(BattleStats.RES_HP)), 70,
		"上限增加时当前值同量增加")

	rt.apply_buff(strong, 2)
	t.eq(rt.stacks_of(&"strong"), 3, "叠到 3 层")
	t.eq(rt.stat_int(BattleStats.MAX_HP), 110, "3 层共 +60")

	rt.apply_buff(strong, 5)
	t.eq(rt.stacks_of(&"strong"), 3, "max_stacks = 3，超出部分被挡住")

	# --- 减层 ---
	t.eq(rt.remove_buff_stacks(&"strong", 2), 2, "移除 2 层")
	t.eq(rt.stacks_of(&"strong"), 1, "剩 1 层")
	t.eq(rt.stat_int(BattleStats.MAX_HP), 70, "属性随之回落")
	rt.remove_buff_stacks(&"strong", 9)
	t.eq(rt.stacks_of(&"strong"), 0, "层数归零后 buff 消失")
	t.eq(rt.stat_int(BattleStats.MAX_HP), 50, "回到初始上限")
	t.eq(StatMath.to_int(rt.resources.current(BattleStats.RES_HP)), 50, "当前值被新上限截断")

	# --- 时长与过期 ---
	var brief := BuffDef.new()
	brief.id = &"brief"
	brief.duration_ticks = 3
	rt.apply_buff(brief, 1)
	t.eq(rt.advance_buffs().size(), 0, "第 1 帧未过期")
	rt.advance_buffs()
	t.eq(rt.advance_buffs().size(), 1, "第 3 帧过期")
	t.eq(rt.stacks_of(&"brief"), 0, "过期后移除")

	# --- 按物品粒度的属性：磨刀石只影响它旁边那把 ---
	var sharp_spec := _spec(50.0, [
		_compiled(1, "sword_buffed", {"damage": 15.0}),
		_compiled(2, "sword_plain", {"damage": 10.0}),
	])
	var sharp_rt := CombatantRuntime.from_spec(sharp_spec, 0)
	t.eq(sharp_rt.item_stat_int(1, BattleStats.DAMAGE), 15, "被磨刀石加成的那把 15")
	t.eq(sharp_rt.item_stat_int(2, BattleStats.DAMAGE), 10, "另一把仍是 10")
	t.ne(sharp_rt.item_stat(1, BattleStats.DAMAGE), sharp_rt.item_stat(2, BattleStats.DAMAGE),
		"属性必须按物品保留粒度，不能并成单位级")


static func run_rule_layers(t: TestCase) -> void:
	t.begin("四层规则求值")

	# --- 冷却按时触发 ---
	var attacker := _spec(100.0, [
		_compiled(1, "sword", {"damage": 10.0},
			[_rule(OnTick.new(), _cooldown(1.0), [_damage()])]),
	])
	var ctx := _battle(attacker, _spec(100.0, []))
	var defender := ctx.sides[1]

	_run(ctx, 19)
	t.eq(StatMath.to_int(defender.resources.current(BattleStats.RES_HP)), 100,
		"冷却 1 秒，第 19 帧还没到")
	_run(ctx, 1)
	t.eq(StatMath.to_int(defender.resources.current(BattleStats.RES_HP)), 90,
		"第 20 帧（1 秒）出手一次")
	_run(ctx, 20)
	t.eq(StatMath.to_int(defender.resources.current(BattleStats.RES_HP)), 80, "再一秒再出一次")

	# --- 开局触发 ---
	var opener := _spec(100.0, [
		_compiled(1, "bomb", {"damage": 30.0},
			[_rule(OnBattleStart.new(), Always.new(), [_damage()])]),
	])
	var ctx2 := _battle(opener, _spec(100.0, []))
	ctx2.emit(BattleEvent.BATTLE_START, -1, {})
	ctx2.drain()
	t.eq(StatMath.to_int(ctx2.sides[1].resources.current(BattleStats.RES_HP)), 70,
		"开局立刻打一次")

	# --- 每 N 次：没执行的那几次也要计数 ---
	var burst := EveryNth.new()
	burst.n = 3
	var counter := _spec(100.0, [
		_compiled(1, "tri", {"damage": 5.0},
			[_rule(OnTick.new(), burst, [_damage()])]),
	])
	var ctx3 := _battle(counter, _spec(100.0, []))
	_run(ctx3, 2)
	t.eq(StatMath.to_int(ctx3.sides[1].resources.current(BattleStats.RES_HP)), 100,
		"前两帧只计数不执行")
	_run(ctx3, 1)
	t.eq(StatMath.to_int(ctx3.sides[1].resources.current(BattleStats.RES_HP)), 95,
		"第 3 帧执行")
	_run(ctx3, 3)
	t.eq(StatMath.to_int(ctx3.sides[1].resources.current(BattleStats.RES_HP)), 90,
		"再 3 帧再执行一次")


static func run_cost_semantics(t: TestCase) -> void:
	t.begin("消耗语义：付不起则跳过效果，冷却照走")

	var cost := ResourceCost.new()
	cost.resource_key = BattleStats.RES_STAMINA
	cost.amount = 10.0

	var spec := _spec(100.0, [
		_compiled(1, "heavy", {"damage": 20.0, "max_stamina": 15.0},
			[_rule(OnTick.new(), _cooldown(1.0), [_damage()], [cost])]),
	])
	var ctx := _battle(spec, _spec(100.0, []))
	var me := ctx.sides[0]
	var foe := ctx.sides[1]

	t.eq(StatMath.to_int(me.resources.current(BattleStats.RES_STAMINA)), 15, "初始耐力 15")

	_run(ctx, 20)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 80, "第一次出手成功")
	t.eq(StatMath.to_int(me.resources.current(BattleStats.RES_STAMINA)), 5, "扣掉 10 点耐力")

	_run(ctx, 20)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 80,
		"耐力只剩 5，付不起，效果被跳过")

	# 关键：冷却确实被消耗了。补满耐力后不应立刻出手 ——
	# 若冷却没走，武器会在耐力回满那一瞬间立刻打出，耐力不足就毫无代价
	me.resources.change(BattleStats.RES_STAMINA, StatMath.from_float(15.0), BattleEvent.REASON_REGEN)
	t.eq(StatMath.to_int(me.resources.current(BattleStats.RES_STAMINA)), 15, "耐力补满")
	_run(ctx, 1)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 80,
		"补满耐力后不会立刻出手 —— 证明失败那次冷却已被消耗")
	_run(ctx, 19)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 60,
		"再等满一个冷却才出手")

	# --- 消耗层内部仍然原子：多条消耗全过才逐个扣 ---
	var charge := BuffDef.new()
	charge.id = &"charge"
	var stack_cost := StatusStackCost.new()
	stack_cost.buff_id = &"charge"
	stack_cost.stacks = 2
	var res_cost := ResourceCost.new()
	res_cost.resource_key = BattleStats.RES_STAMINA
	res_cost.amount = 5.0

	var combo := _spec(100.0, [
		_compiled(1, "combo", {"damage": 9.0, "max_stamina": 50.0},
			[_rule(OnTick.new(), _cooldown(1.0), [_damage()], [stack_cost, res_cost])]),
	])
	var ctx2 := _battle(combo, _spec(100.0, []))
	var me2 := ctx2.sides[0]
	me2.apply_buff(charge, 1)          # 只有 1 层，不够 2 层
	var stamina_before := me2.resources.current(BattleStats.RES_STAMINA)
	_run(ctx2, 20)
	t.eq(StatMath.to_int(ctx2.sides[1].resources.current(BattleStats.RES_HP)), 100,
		"层数不够，效果不执行")
	t.eq(me2.resources.current(BattleStats.RES_STAMINA), stamina_before,
		"层数不够时耐力也不能扣 —— 消耗层内部必须原子，不许半付款")
	t.eq(me2.stacks_of(&"charge"), 1, "层数也没被扣")


static func run_event_mask(t: TestCase) -> void:
	t.begin("事件掩码")

	var make_spec := func() -> CombatantSpec:
		return _spec(100.0, [
			_compiled(1, "sword", {"damage": 7.0},
				[_rule(OnTick.new(), _cooldown(0.5), [_damage()])]),
		])

	# --- 掩码只影响派发，不影响日志 ---
	var masked := _battle(make_spec.call(), _spec(100.0, []))
	masked.mask_enabled = true
	_run(masked, 60)

	var full := _battle(make_spec.call(), _spec(100.0, []))
	full.mask_enabled = false
	_run(full, 60)

	t.eq(masked.snapshot(), full.snapshot(), "掩码开与全开的最终状态必须完全相同")
	t.eq(masked.log.size(), full.log.size(), "两条路径的日志条数必须相同")
	var a_lines: Array = []
	var b_lines: Array = []
	for e in masked.log:
		a_lines.append(str(e))
	for e in full.log:
		b_lines.append(str(e))
	t.eq(a_lines, b_lines, "两条路径的日志必须逐条相同 —— 掩码是纯优化，不得影响语义")

	# --- 没人订阅的事件不进队列 ---
	var quiet := _battle(_spec(100.0, []), _spec(100.0, []))
	t.check(not quiet.is_listening(BattleEvent.TICK), "无人订阅 tick")
	quiet.emit(BattleEvent.TICK, -1, {})
	t.eq(quiet.pending(), 0, "无人听且非回放事件，不入队")
	t.eq(quiet.log.size(), 0, "也不进日志")

	# --- 回放需要的事件即便没人订阅也照记 ---
	quiet.emit(BattleEvent.DIED, 1, {})
	t.eq(quiet.log.size(), 1, "DIED 是回放事件，无人订阅也要记账")

	# --- 施加带规则的 buff 后掩码必须重算 ---
	var burn := BuffDef.new()
	burn.id = &"burn"
	burn.rules = [
		_rule(OnTick.new(), _cooldown(1.0), [_self_damage(3.0)])
	] as Array[AbilityRule]

	var igniter := ApplyStatus.new()
	igniter.target = ApplyStatus.Target.OPPONENT
	igniter.buff = burn
	igniter.stacks = 1

	# 施法者自己不订阅 tick，所以开战时 tick 不在掩码里
	var caster := _spec(100.0, [
		_compiled(1, "torch", {},
			[_rule(OnBattleStart.new(), Always.new(), [igniter])]),
	])
	var ctx := _battle(caster, _spec(100.0, []))
	t.check(not ctx.is_listening(BattleEvent.TICK), "开战前没有任何规则订阅 tick")

	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()
	t.eq(ctx.sides[1].stacks_of(&"burn"), 1, "灼烧已施加")
	t.check(ctx.is_listening(BattleEvent.TICK),
		"buff 带来了订阅 tick 的规则，掩码必须已重算 —— 否则灼烧会静默失效")

	_run(ctx, 20)
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP)), 97,
		"灼烧每秒掉 3 点，且 BattleSim 里没有为它写任何特例")


static func run_chain_and_guard(t: TestCase) -> void:
	t.begin("连带触发与派发保护")

	# --- 连带触发：不是特例，只是订阅 item_fired ---
	var chained := OnItemFired.new()
	chained.same_side = true
	chained.include_self = false

	var spec := _spec(100.0, [
		_compiled(1, "trigger_src", {"damage": 4.0},
			[_rule(OnTick.new(), _cooldown(1.0), [_damage()])]),
		_compiled(2, "follower", {"damage": 6.0},
			[_rule(chained, Always.new(), [_damage()])]),
	])
	var ctx := _battle(spec, _spec(100.0, []))
	_run(ctx, 20)
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP)), 90,
		"主武器 4 点 + 连带触发 6 点 = 10 点")

	# --- 自我循环被派发上限挡住，不会栈溢出 ---
	var loopy := OnItemFired.new()
	loopy.same_side = true
	loopy.include_self = true          # 故意制造自循环
	var bad := _spec(100.0, [
		_compiled(1, "loop", {"damage": 0.0},
			[_rule(loopy, Always.new(), [_damage(0.0)])]),
	])
	var ctx2 := _battle(bad, _spec(100.0, []))
	ctx2.max_chain = 32
	ctx2.emit(BattleEvent.ITEM_FIRED, 0, {"uid": 1})
	ctx2.drain()
	t.eq(ctx2.pending(), 0, "超限后队列被清空，不会无限循环")
	var overflowed := false
	for e in ctx2.log:
		if e.name == BattleEvent.DISPATCH_OVERFLOW:
			overflowed = true
	t.check(overflowed, "应记下一条 DISPATCH_OVERFLOW 便于定位内容配错")
