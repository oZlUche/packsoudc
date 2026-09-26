## 效果系统骨架：资源池、buff、四层规则求值、事件掩码（架构文档 4.4 / 4.5）。
extends RefCounted

## 定点秒的便捷写法
static func _sec(v: float) -> int:
	return StatMath.from_float(v)


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
	var te: Array[CombatEffect] = []
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


## 把战斗推进到 t 秒。没有帧 —— 直接跳到各个事件时刻。
static func _advance_to(ctx: BattleContext, t: float) -> void:
	var limit := _sec(t)
	while ctx.now < limit:
		var next := BattleSim._next_instant(ctx)
		if next < 0 or next > limit:
			break
		ctx.now = maxi(ctx.now, next)
		BattleSim._resolve_instant(ctx)
	ctx.now = maxi(ctx.now, limit)
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
	brief.duration_sec = 0.5
	brief.max_stacks = 1     # 不可叠层的才会过期（085 作者定：可叠层的永续）
	rt.apply_buff(brief, 1, _sec(1.0))
	t.eq(rt.expire_buffs(_sec(1.4)).size(), 0, "1.4 秒时未过期")
	t.eq(rt.next_expiry(), _sec(1.5), "到期时刻记为绝对时间，可直接排进时间轮")
	t.eq(rt.expire_buffs(_sec(1.5)).size(), 1, "1.5 秒时过期")
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
			[_rule(OnSchedule.new(), _cooldown(1.0), [_damage()])]),
	])
	var ctx := _battle(attacker, _spec(100.0, []))
	var defender := ctx.sides[1]

	_advance_to(ctx, 0.999)
	t.eq(StatMath.to_int(defender.resources.current(BattleStats.RES_HP)), 100,
		"冷却 1 秒，0.999 秒时还没到")
	_advance_to(ctx, 1.0)
	t.eq(StatMath.to_int(defender.resources.current(BattleStats.RES_HP)), 90,
		"恰好 1 秒时出手一次")
	_advance_to(ctx, 2.0)
	t.eq(StatMath.to_int(defender.resources.current(BattleStats.RES_HP)), 80, "再一秒再出一次")

	# 小数冷却：分辨率不再受任何步长限制
	var odd := _spec(100.0, [
		_compiled(1, "quick", {"damage": 1.0},
			[_rule(OnSchedule.new(), _cooldown(0.37), [_damage()])]),
	])
	var odd_ctx := _battle(odd, _spec(100.0, []))
	_advance_to(odd_ctx, 0.36)
	t.eq(StatMath.to_int(odd_ctx.sides[1].resources.current(BattleStats.RES_HP)), 100,
		"0.37 秒冷却，0.36 秒时未触发")
	_advance_to(odd_ctx, 1.11)
	t.eq(StatMath.to_int(odd_ctx.sides[1].resources.current(BattleStats.RES_HP)), 97,
		"1.11 秒内恰好触发 3 次（0.37 / 0.74 / 1.11）—— 小数周期精确无误差")

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

	# --- 蓄力：攒够 3 次才放，没放出去的也要计数 ---
	# 它在【消耗层】而不是频率层：挡住时冷却照常推进，
	# 否则调度器会卡在同一时刻反复重试。
	var burst := ChargeCost.new()
	burst.n = 3
	var counter := _spec(100.0, [
		_compiled(1, "tri", {"damage": 5.0},
			[_rule(OnSchedule.new(), _cooldown(0.1), [_damage()], [burst])]),
	])
	var ctx3 := _battle(counter, _spec(100.0, []))
	# 十进制标度下 0.1 是精确的，0.1 × 3 恰好等于 0.3。
	# 换成 2^16 标度这几条会差 1/65536 秒而失败 —— 这正是不用 2 的幂的理由。
	_advance_to(ctx3, 0.2)
	t.eq(StatMath.to_int(ctx3.sides[1].resources.current(BattleStats.RES_HP)), 100,
		"0.1 / 0.2 秒两次只蓄力不执行")
	_advance_to(ctx3, 0.3)
	t.eq(StatMath.to_int(ctx3.sides[1].resources.current(BattleStats.RES_HP)), 95,
		"0.3 秒第 3 次放出 —— 0.1 × 3 精确等于 0.3")
	_advance_to(ctx3, 0.6)
	t.eq(StatMath.to_int(ctx3.sides[1].resources.current(BattleStats.RES_HP)), 90,
		"0.6 秒再放一次 —— 证明被挡住的两次冷却确实照常推进了")


static func run_cost_semantics(t: TestCase) -> void:
	t.begin("消耗语义：付不起则跳过效果，冷却照走")

	var cost := ResourceCost.new()
	cost.resource_key = BattleStats.RES_STAMINA
	cost.amount = 10.0

	var spec := _spec(100.0, [
		_compiled(1, "heavy", {"damage": 20.0, "max_stamina": 15.0},
			[_rule(OnSchedule.new(), _cooldown(1.0), [_damage()], [cost])]),
	])
	var ctx := _battle(spec, _spec(100.0, []))
	var me := ctx.sides[0]
	var foe := ctx.sides[1]

	t.eq(StatMath.to_int(me.resources.current(BattleStats.RES_STAMINA)), 15, "初始耐力 15")

	_advance_to(ctx, StatMath.to_float(ctx.now) + 1.0)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 80, "第一次出手成功")
	t.eq(StatMath.to_int(me.resources.current(BattleStats.RES_STAMINA)), 5, "扣掉 10 点耐力")

	_advance_to(ctx, StatMath.to_float(ctx.now) + 1.0)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 80,
		"耐力只剩 5，付不起，效果被跳过")

	# 关键：冷却确实被消耗了。补满耐力后不应立刻出手 ——
	# 若冷却没走，武器会在耐力回满那一瞬间立刻打出，耐力不足就毫无代价
	me.resources.change(BattleStats.RES_STAMINA, StatMath.from_float(15.0), BattleEvent.REASON_REGEN)
	t.eq(StatMath.to_int(me.resources.current(BattleStats.RES_STAMINA)), 15, "耐力补满")
	_advance_to(ctx, StatMath.to_float(ctx.now) + 0.05)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 80,
		"补满耐力后不会立刻出手 —— 证明失败那次冷却已被消耗")
	_advance_to(ctx, StatMath.to_float(ctx.now) + 0.95)
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
			[_rule(OnSchedule.new(), _cooldown(1.0), [_damage()], [stack_cost, res_cost])]),
	])
	var ctx2 := _battle(combo, _spec(100.0, []))
	var me2 := ctx2.sides[0]
	me2.apply_buff(charge, 1)          # 只有 1 层，不够 2 层
	var stamina_before := me2.resources.current(BattleStats.RES_STAMINA)
	_advance_to(ctx2, 1.0)
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
				[_rule(OnSchedule.new(), _cooldown(0.5), [_damage()])]),
		])

	# --- 掩码只影响派发，不影响日志 ---
	var masked := _battle(make_spec.call(), _spec(100.0, []))
	masked.mask_enabled = true
	_advance_to(masked, 3.0)

	var full := _battle(make_spec.call(), _spec(100.0, []))
	full.mask_enabled = false
	_advance_to(full, 3.0)

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
		_rule(OnSchedule.new(), _cooldown(1.0), [_self_damage(3.0)])
	] as Array[AbilityRule]

	var igniter := ApplyStatus.new()
	igniter.target = ApplyStatus.Target.OPPONENT
	igniter.buff = burn
	igniter.stacks = 1

	var caster := _spec(100.0, [
		_compiled(1, "torch", {},
			[_rule(OnBattleStart.new(), Always.new(), [igniter])]),
	])
	var ctx := _battle(caster, _spec(100.0, []))
	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()
	t.eq(ctx.sides[1].stacks_of(&"burn"), 1, "灼烧已施加")

	# 灼烧是自发型，靠时间轮而非事件 —— BattleSim 里没有为它写任何特例
	_advance_to(ctx, 1.0)
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP)), 97,
		"灼烧每秒掉 3 点")
	_advance_to(ctx, 3.0)
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP)), 91,
		"3 秒共掉 9 点")

	# --- 带【事件型】规则的 buff 才涉及掩码，施加后必须重算 ---
	var thorns_rule := _rule(OnResourceChanged.new(), Always.new(), [_damage(1.0)])
	var thorns := BuffDef.new()
	thorns.id = &"thorns"
	thorns.rules = [thorns_rule] as Array[AbilityRule]

	var spiker := ApplyStatus.new()
	spiker.target = ApplyStatus.Target.SELF
	spiker.buff = thorns

	var quiet2 := _battle(
		_spec(100.0, [_compiled(1, "cloak", {},
			[_rule(OnBattleStart.new(), Always.new(), [spiker])])]),
		_spec(100.0, [])
	)
	t.check(not quiet2.is_listening(BattleEvent.RESOURCE_CHANGED),
		"开战前没有任何规则订阅 resource_changed")
	quiet2.emit(BattleEvent.BATTLE_START, -1, {})
	quiet2.drain()
	t.check(quiet2.is_listening(BattleEvent.RESOURCE_CHANGED),
		"buff 带来了订阅该事件的规则，掩码必须已重算 —— 否则这条规则会静默失效")


static func run_chain_and_guard(t: TestCase) -> void:
	t.begin("连带触发与派发保护")

	# --- 连带触发：不是特例，只是订阅 item_fired ---
	var chained := OnItemFired.new()
	chained.same_side = true
	chained.include_self = false

	var spec := _spec(100.0, [
		_compiled(1, "trigger_src", {"damage": 4.0},
			[_rule(OnSchedule.new(), _cooldown(1.0), [_damage()])]),
		_compiled(2, "follower", {"damage": 6.0},
			[_rule(chained, Always.new(), [_damage()])]),
	])
	var ctx := _battle(spec, _spec(100.0, []))
	_advance_to(ctx, StatMath.to_float(ctx.now) + 1.0)
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


static func run_battle_sim(t: TestCase) -> void:
	t.begin("BattleSim 端到端")

	var make := func(hp: float, dmg: float, cd: float) -> CombatantSpec:
		return _spec(hp, [
			_compiled(1, "w", {"damage": dmg},
				[_rule(OnSchedule.new(), _cooldown(cd), [_damage()])]),
		])

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var r: BattleResult = BattleSim.run(make.call(30.0, 10.0, 1.0), make.call(100.0, 1.0, 1.0), rng)

	t.eq(r.winner, 0, "输出高的一方获胜")
	t.check(not r.is_draw(), "不是平局")
	# A 每秒 10 点，B 100 血 → 第 10 秒击杀；B 每秒 1 点，A 30 血撑得住
	t.eq(r.duration_sec(), 10.0, "恰好第 10 秒结束，时刻是算出来的不是逼近的")
	t.check(r.log.size() > 0, "产出回放日志")

	var names := {}
	for e in r.log:
		names[String(e.name)] = true
	t.check(names.has("battle_start"), "日志含开战事件")
	t.check(names.has("item_fired"), "日志含出手事件")
	t.check(names.has("died"), "日志含阵亡事件")
	t.check(not names.has("tick"), "日志里没有 tick —— 模拟里根本没有帧")

	# --- 同种子同结果 ---
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var r2: BattleResult = BattleSim.run(make.call(30.0, 10.0, 1.0), make.call(100.0, 1.0, 1.0), rng2)
	t.eq(r2.winner, r.winner, "同种子胜负一致")
	t.eq(r2.duration, r.duration, "同种子时长一致")
	t.eq(r2.log.size(), r.log.size(), "同种子日志条数一致")
	var a_lines: Array = []
	var b_lines: Array = []
	for e in r.log:
		a_lines.append(str(e))
	for e in r2.log:
		b_lines.append(str(e))
	t.eq(a_lines, b_lines, "同种子日志逐条一致 —— 一个 seed 即可重现任何 bug")

	# --- 打不死判平局，不会死循环 ---
	var stalemate := BattleSim.run(
		_spec(100.0, []), _spec(100.0, []), RandomNumberGenerator.new(), 5.0
	)
	t.check(stalemate.is_draw(), "双方都没有攻击手段，判平局")
	t.eq(stalemate.log.size() > 0, true, "平局也有日志")

	# --- 批量模拟：整场一次算完，快到可以刷平衡 ---
	var started := Time.get_ticks_msec()
	for i in 200:
		var seeded := RandomNumberGenerator.new()
		seeded.seed = i
		BattleSim.run(make.call(60.0, 7.0, 0.8), make.call(60.0, 5.0, 0.6), seeded)
	var elapsed := Time.get_ticks_msec() - started
	t.check(elapsed < 3000, "200 场模拟应在 3 秒内跑完，实际 %d ms" % elapsed)


static func run_event_index(t: TestCase) -> void:
	t.begin("事件索引")

	# 一条订阅 resource_changed 的 buff 规则
	var thorns_rule := _rule(OnResourceChanged.new(), Always.new(), [_damage(1.0)])
	var thorns := BuffDef.new()
	thorns.id = &"thorns"
	thorns.rules = [thorns_rule] as Array[AbilityRule]

	var ctx := _battle(_spec(100.0, []), _spec(100.0, []))
	var me := ctx.sides[0]

	t.check(not ctx.is_listening(BattleEvent.RESOURCE_CHANGED), "开局无人订阅")
	t.eq(ctx.subscribers_of(BattleEvent.RESOURCE_CHANGED).size(), 0, "索引为空")

	# --- 施加：索引自动重建 ---
	me.apply_buff(thorns, 1, ctx.now)
	t.check(ctx.is_listening(BattleEvent.RESOURCE_CHANGED),
		"施加带规则的 buff 后索引自动重建，无需调用方记得")
	t.eq(ctx.subscribers_of(BattleEvent.RESOURCE_CHANGED).size(), 1, "索引里有 1 条订阅")

	var before := StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP))
	ctx.emit(BattleEvent.RESOURCE_CHANGED, 0, {"key": "hp", "delta": -5, "reason": "damage"})
	ctx.drain()
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP)), before - 1,
		"buff 的规则确实被派发到了")

	# --- 移除：索引必须跟着清掉 ---
	# 这是修复前的真 bug：残留条目会让已删除的规则继续触发，
	# 表现为「某个效果明明没了却还在生效」，极难定位
	me.remove_buff_stacks(&"thorns", 1)
	t.eq(me.stacks_of(&"thorns"), 0, "buff 已移除")
	t.check(not ctx.is_listening(BattleEvent.RESOURCE_CHANGED), "索引已清空")
	t.eq(ctx.subscribers_of(BattleEvent.RESOURCE_CHANGED).size(), 0, "不再有订阅者")

	var after_removal := StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP))
	ctx.emit(BattleEvent.RESOURCE_CHANGED, 0, {"key": "hp", "delta": -5, "reason": "damage"})
	ctx.drain()
	t.eq(StatMath.to_int(ctx.sides[1].resources.current(BattleStats.RES_HP)), after_removal,
		"已移除的规则绝不能再触发")

	# --- 索引只收订阅者，自发型规则不进索引 ---
	var sched_only := _battle(
		_spec(100.0, [_compiled(1, "w", {"damage": 1.0},
			[_rule(OnSchedule.new(), _cooldown(1.0), [_damage()])])]),
		_spec(100.0, [])
	)
	t.eq(sched_only.subscribers_of(BattleEvent.TICK).size(), 0, "自发型不订阅任何事件")
	t.eq(sched_only.subscribers_of(BattleEvent.ITEM_FIRED).size(), 0, "它也不订阅出手事件")
	_advance_to(sched_only, 1.0)
	t.eq(StatMath.to_int(sched_only.sides[1].resources.current(BattleStats.RES_HP)), 99,
		"但它照常按时间轮出手")

	# --- 派发顺序稳定：side 0 在前，各方内部按登记顺序 ---
	var listener := func() -> AbilityRule:
		return _rule(OnItemFired.new(), Always.new(), [_damage(1.0)])
	var order_ctx := _battle(
		_spec(100.0, [_compiled(1, "a", {}, [listener.call()]),
			_compiled(2, "b", {}, [listener.call()])]),
		_spec(100.0, [_compiled(3, "c", {}, [listener.call()])])
	)
	var subs := order_ctx.subscribers_of(BattleEvent.ITEM_FIRED)
	t.eq(subs.size(), 3, "三条订阅")
	t.eq((subs[0] as RuleRuntime).owner_side, 0, "第一条属于 side 0")
	t.eq((subs[1] as RuleRuntime).owner_side, 0, "第二条属于 side 0")
	t.eq((subs[2] as RuleRuntime).owner_side, 1, "第三条属于 side 1")
	t.eq((subs[0] as RuleRuntime).source_uid, 1, "side 0 内部按登记顺序")
	t.eq((subs[1] as RuleRuntime).source_uid, 2, "side 0 内部按登记顺序")


static func run_schedule_heap(t: TestCase) -> void:
	t.begin("时间轮")

	var mk := func(order: int) -> RuleRuntime:
		var rt := RuleRuntime.new()
		rt.order = order
		return rt

	# --- 堆序 ---
	var h := ScheduleHeap.new()
	t.check(h.is_empty(), "初始为空")
	t.eq(h.peek_time(), -1, "空堆 peek 返回 -1")

	h.push(500, mk.call(1))
	h.push(100, mk.call(2))
	h.push(900, mk.call(3))
	h.push(300, mk.call(4))
	t.eq(h.size(), 4, "四个条目")
	t.eq(h.peek_time(), 100, "堆顶是最小时刻")

	var popped: Array = []
	while not h.is_empty():
		popped.append(h.pop()[ScheduleHeap.T])
	t.eq(popped, [100, 300, 500, 900], "弹出顺序按时刻升序")

	# --- 同刻按次序键，这是确定性的唯一保证 ---
	var h2 := ScheduleHeap.new()
	h2.push(200, mk.call(100007))   # side 1
	h2.push(200, mk.call(2))        # side 0 第 3 条
	h2.push(200, mk.call(0))        # side 0 第 1 条
	var orders: Array = []
	while not h2.is_empty():
		orders.append(h2.pop()[ScheduleHeap.ORDER])
	t.eq(orders, [0, 2, 100007],
		"同刻并列按次序键升序 —— side 0 在前，各方内部按登记顺序")

	# --- 次序键由 CombatantRuntime 写入 ---
	var spec := _spec(100.0, [
		_compiled(1, "a", {}, [_rule(OnSchedule.new(), _cooldown(1.0), [_damage(1.0)])]),
		_compiled(2, "b", {}, [_rule(OnSchedule.new(), _cooldown(1.0), [_damage(1.0)])]),
	])
	var side0 := CombatantRuntime.from_spec(spec, 0)
	var side1 := CombatantRuntime.from_spec(spec, 1)
	t.eq(side0.rules[0].order, 0, "side 0 第一条次序键为 0")
	t.eq(side0.rules[1].order, 1, "side 0 第二条为 1")
	t.check(side1.rules[0].order > side0.rules[1].order, "side 1 的次序键整体靠后")


static func run_snapshot_cooldown(t: TestCase) -> void:
	t.begin("冷却快照语义")

	var B := StatMath.Buff
	var quicken := BuffDef.new()
	quicken.id = &"quicken"
	quicken.mods = [_mod(BattleStats.HASTE, B.HASTE, 100)] as Array[StatModifier]

	var spec := _spec(100.0, [
		_compiled(1, "sword", {"damage": 10.0},
			[_rule(OnSchedule.new(), _cooldown(1.0), [_damage()])]),
	])
	var ctx := _battle(spec, _spec(100.0, []))
	var me := ctx.sides[0]
	var foe := ctx.sides[1]

	# 冷却 1 秒，开局已排在 t=1.0
	_advance_to(ctx, 0.5)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 100, "0.5 秒时还没出手")

	# 半途施加 +100% 急速
	me.apply_buff(quicken, 1, ctx.now)
	t.eq(me.item_stat(1, BattleStats.HASTE), StatMath.from_float(2.0), "速度已翻倍")

	_advance_to(ctx, 0.99)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 100,
		"**正在走的这一轮不受影响** —— 急速不会把它提前到 0.75 秒")

	_advance_to(ctx, 1.0)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 90,
		"仍然在原定的 1.0 秒出手")

	# 从这一次起才按新速率
	_advance_to(ctx, 1.49)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 90, "1.49 秒时未到")
	_advance_to(ctx, 1.5)
	t.eq(StatMath.to_int(foe.resources.current(BattleStats.RES_HP)), 80,
		"下一轮冷却减半，1.5 秒即出手")


static func run_lazy_removal(t: TestCase) -> void:
	t.begin("时间轮惰性删除")

	# 自发型规则挂在 buff 上：入堆后若 buff 被移除，堆里的条目必须作废
	var burn := BuffDef.new()
	burn.id = &"burn"
	burn.rules = [
		_rule(OnSchedule.new(), _cooldown(1.0), [_self_damage(5.0)])
	] as Array[AbilityRule]

	var ctx := _battle(_spec(100.0, []), _spec(100.0, []))
	var victim := ctx.sides[1]

	victim.apply_buff(burn, 1, ctx.now)
	t.eq(ctx.schedule.size(), 1, "buff 的自发规则已排进时间轮")

	_advance_to(ctx, 1.0)
	t.eq(StatMath.to_int(victim.resources.current(BattleStats.RES_HP)), 95, "1 秒时灼烧生效")

	# 移除 buff。堆里还留着它下一次的条目，必须被丢弃而不是照常触发
	victim.remove_buff_stacks(&"burn", 1)
	t.eq(victim.stacks_of(&"burn"), 0, "buff 已移除")
	t.check(ctx.schedule.size() > 0, "堆里仍残留着它的条目（惰性删除，不主动摘）")

	_advance_to(ctx, 5.0)
	t.eq(StatMath.to_int(victim.resources.current(BattleStats.RES_HP)), 95,
		"移除后绝不能再触发 —— 弹出时发现规则已不属于该单位，直接丢弃")
	t.eq(ctx.schedule.size(), 0, "残留条目已被清空")


static func run_unit_stat_aggregation(t: TestCase) -> void:
	t.begin("单位级属性聚合")

	# 加法类属性跨物品求和
	var spec := _spec(0.0, [
		_compiled(1, "a", {"max_hp": 30.0, "armor": 2.0}),
		_compiled(2, "b", {"max_hp": 20.0, "armor": 3.0}),
	])
	var rt := CombatantRuntime.from_spec(spec, 0)
	t.eq(rt.stat_int(BattleStats.ARMOR), 5, "护甲这类加法属性跨物品求和")

	# 乘法单位元类属性【不能】跨物品累加
	var many := _spec(100.0, [
		_compiled(1, "a", {"damage": 1.0}),
		_compiled(2, "b", {"damage": 1.0}),
		_compiled(3, "c", {"damage": 1.0}),
	])
	var rt2 := CombatantRuntime.from_spec(many, 0)
	t.eq(rt2.stat(BattleStats.HASTE), StatMath.ONE,
		"三件物品各带 1.0 速度，单位级仍是 1.0 —— 累加会得出「N 件 = N 倍速」")
	t.eq(rt2.item_stat(1, BattleStats.HASTE), StatMath.ONE, "单件仍是 1.0")

	# 空单位读 haste 也是 1.0，不是 0
	var empty := CombatantRuntime.from_spec(_spec(100.0, []), 0)
	t.eq(empty.stat(BattleStats.HASTE, StatMath.ONE), StatMath.ONE, "无物品时 haste 为 1.0")


static func run_regen(t: TestCase) -> void:
	t.begin("资源 · 按时间懒结算的回复")

	# regen_xxx 是一条普通属性，和 max_xxx 对称。没有定时器，也没有每秒事件 ——
	# 推进器每到一个时刻，才按「距上次结算过了多久 × 当刻速率」补上。
	var drain := ResourceCost.new()
	drain.resource_key = BattleStats.RES_STAMINA
	drain.amount = 10.0

	var spec := _spec(100.0, [_compiled(1, "gun", {"max_stamina": 100.0, "regen_stamina": 5.0}, [
		_rule(OnSchedule.new(), _cooldown(2.0), [_damage(5.0)], [drain]),
	])])
	var ctx := _battle(spec, _spec(100.0, []))
	BattleSim.run_context(ctx, 0.0)  # 只跑开场，把回复时钟对齐
	var pool := ctx.sides[0].resources
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 100, "开场满耐力")

	# 先手动扣掉一半，再推进时间看回了多少
	pool.change(BattleStats.RES_STAMINA, StatMath.from_float(-60.0), BattleEvent.REASON_COST)
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 40, "扣到 40")

	ctx.sides[0].settle_regen(_sec(4.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 60, "4 秒 × 5/秒 = 回 20")

	# --- 线性累积：勤结算不会算多 ---
	pool.change(BattleStats.RES_STAMINA, StatMath.from_float(-60.0), BattleEvent.REASON_COST)
	ctx.sides[0].settle_regen(_sec(5.0))
	ctx.sides[0].settle_regen(_sec(6.0))
	ctx.sides[0].settle_regen(_sec(8.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 20,
		"分三次结算到 8 秒，与一次结算到 8 秒等价（0 + 4 秒 × 5）")

	# --- 上限截断，不攒溢出 ---
	ctx.sides[0].settle_regen(_sec(100.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 100, "回到满就停住")
	ctx.sides[0].settle_regen(_sec(200.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 100, "满了之后不再涨")

	# --- 没配回复速率的资源不动 ---
	var still := _spec(100.0, [_compiled(1, "tank", {"max_stamina": 50.0}, [])])
	var ctx2 := _battle(still, _spec(100.0, []))
	BattleSim.run_context(ctx2, 0.0)
	ctx2.sides[0].resources.change(
		BattleStats.RES_STAMINA, StatMath.from_float(-30.0), BattleEvent.REASON_COST
	)
	ctx2.sides[0].settle_regen(_sec(50.0))
	t.eq(StatMath.to_int(ctx2.sides[0].resources.current(BattleStats.RES_STAMINA)), 20,
		"没有 regen_stamina 就完全不回")


static func run_regen_buff(t: TestCase) -> void:
	t.begin("资源 · buff 影响回复速率")

	# 「某某 buff 让耐力回得更快」不需要任何新机制 ——
	# regen_stamina 是普通属性，一条 StatModifier 就够，走的是和增伤同一条公式。
	var vigor := BuffDef.new()
	vigor.id = &"vigor"
	vigor.max_stacks = 5
	vigor.mods = [_mod(BattleStats.REGEN_STAMINA, StatMath.Buff.EMPOWER, 100)] as Array[StatModifier]

	var spec := _spec(100.0, [_compiled(1, "gear", {"max_stamina": 100.0, "regen_stamina": 5.0}, [])])
	var ctx := _battle(spec, _spec(100.0, []))
	BattleSim.run_context(ctx, 0.0)
	var who := ctx.sides[0]
	var pool := who.resources
	pool.change(BattleStats.RES_STAMINA, StatMath.from_float(-80.0), BattleEvent.REASON_COST)

	who.settle_regen(_sec(2.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 30, "基础 5/秒，2 秒回 10")

	# 叠一层 +100%
	who.apply_buff(vigor, 1, _sec(2.0))
	who.settle_regen(_sec(4.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 50,
		"+100% 后 10/秒，再 2 秒回 20")

	# 再叠一层：同乘区相加，5 × (1 + 1.0 + 1.0) = 15/秒
	who.apply_buff(vigor, 1, _sec(4.0))
	who.settle_regen(_sec(6.0))
	t.eq(StatMath.to_int(pool.current(BattleStats.RES_STAMINA)), 80,
		"两层 = 15/秒，再 2 秒回 30（同乘区相加，不是相乘）")


static func run_regen_in_battle(t: TestCase) -> void:
	t.begin("资源 · 回复让武器打得出第二轮")

	# 这一组是回归测试：没有回复时，耐力见底后整场哑火 ——
	# 沙盒里一眼就能看见，但单元测试里只表现为伤害总量偏低。
	var cost := ResourceCost.new()
	cost.resource_key = BattleStats.RES_STAMINA
	cost.amount = 10.0

	var make := func(regen: float) -> CombatantSpec:
		return _spec(100.0, [_compiled(1, "gun",
			{"damage": 5.0, "max_stamina": 20.0, "regen_stamina": regen},
			[_rule(OnSchedule.new(), _cooldown(1.0), [_damage()], [cost])])])

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var dry := BattleSim.run(make.call(0.0), _spec(500.0, []), rng, 10.0)
	var dry_left := int(dry.final["sides"][1]["resources"][&"hp"][0])

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var wet := BattleSim.run(make.call(10.0), _spec(500.0, []), rng2, 10.0)
	var wet_left := int(wet.final["sides"][1]["resources"][&"hp"][0])

	t.eq(500 - dry_left, 10, "不回复：20 点耐力只够打两发，之后整场哑火")
	t.check(500 - wet_left > 40, "回复 10/秒：每秒都打得起，伤害高得多（实际 %d）" % (500 - wet_left))

