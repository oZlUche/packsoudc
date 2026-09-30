## 确定性战斗模拟（架构文档 4.7）。
##
## [b]事件驱动，没有帧。[/b] 帧是渲染概念；模拟直接算出每次出手与每个 buff 到期的
## 精确时刻，在时刻之间跳跃。好处：
##
## - **零累积误差**。固定步长要把 dt 反复相加，除不尽的步长会稳定跑偏；
##   这里只在离散时刻改写状态，冷却 0.37 秒就是精确的 0.37 秒
## - **快**。下一个事件由最小堆 O(log n) 给出，不必每跳一步就把全部规则问一遍
## - 分辨率不再受步长限制，出手间隔可以是任意小数
##
## 整场战斗在开战瞬间一次算完（4.1：战斗中没有任何玩家操作），
## [BattleView] 只是个播放器，「跳过」就是把播放游标推到日志末尾。
class_name BattleSim
extends RefCounted

## 超时上限：打不死就判平局，防止互相无法击破时死循环
const DEFAULT_TIME_LIMIT := 60.0
## 同一时刻最多结算多少次，防止零冷却规则卡死
const MAX_STEPS_PER_INSTANT := 64


static func run(
	a: CombatantSpec, b: CombatantSpec, rng: RandomNumberGenerator,
	time_limit_sec: float = DEFAULT_TIME_LIMIT
) -> BattleResult:
	var ctx := BattleContext.create(
		CombatantRuntime.from_spec(a, 0), CombatantRuntime.from_spec(b, 1), rng
	)
	var result := run_context(ctx, time_limit_sec)
	if result.winner == -1 and bool(a.flags.get("draw_is_win", false)):
		result.winner = 0     # 093（自然之神 5 级）：平局也视为胜利
	return result


## 用现成的上下文跑。测试与批量模拟用它注入特定初始状态。
static func run_context(ctx: BattleContext, time_limit_sec: float = DEFAULT_TIME_LIMIT) -> BattleResult:
	var limit := StatMath.from_float(time_limit_sec)

	for rt in ctx.sides:
		(rt as CombatantRuntime).resources.reset_regen_clock(ctx.now)

	var result := BattleResult.new()
	result.initial = ctx.snapshot()

	ctx.emit(BattleEvent.BATTLE_START, -1, {})
	ctx.drain()

	while _both_alive(ctx) and ctx.now < limit:
		var next := _next_instant(ctx)
		if next < 0 or next > limit:
			break  # 再没有任何事会发生，或已越过时限
		ctx.now = maxi(ctx.now, next)
		_resolve_instant(ctx)

	if ctx.now > limit:
		ctx.now = limit
	# 把回复补到收尾时刻，否则最终快照停在最后一个事件那一刻
	for rt in ctx.sides:
		(rt as CombatantRuntime).settle_regen(ctx.now)
	result.winner = _winner(ctx)
	result.duration = ctx.now
	result.log = ctx.log
	result.final = ctx.snapshot()
	ctx.emit(BattleEvent.BATTLE_END, -1, {"winner": result.winner})
	ctx.drain()
	return result


## 下一个会发生点事的时刻：时间轮堆顶，或最近的 buff 到期。
static func _next_instant(ctx: BattleContext) -> int:
	var best := ctx.schedule.peek_time()
	for rt in ctx.sides:
		var expiry := (rt as CombatantRuntime).next_expiry()
		if expiry >= 0 and (best < 0 or expiry < best):
			best = expiry
	return best


## 结算 ctx.now 这一刻发生的所有事。
##
## 顺序固定：**先处理到期，再处理出手**。
## 一个正好在此刻到期的增益不应该再为这一刻的出手加成 —— 否则「buff 还剩 0 秒」
## 这种边界会变成玩家无法预期的运气。
static func _resolve_instant(ctx: BattleContext) -> void:
	# 回复先补：这一段时间里 buff 还在，速率就该按它算。
	# 放到到期之后补，等于让最后这一段用上了 buff 消失后的速率。
	for rt in ctx.sides:
		(rt as CombatantRuntime).settle_regen(ctx.now)

	for rt in ctx.sides:
		if (rt as CombatantRuntime).settle_undying(ctx.now):
			ctx.emit(BattleEvent.DIED, (rt as CombatantRuntime).side, {})     # 093：坚持期到了、血还是 0：真倒下
	for rt in ctx.sides:
		var owner := rt as CombatantRuntime
		for buff in owner.expire_buffs(ctx.now):
			ctx.emit(BattleEvent.STATUS_UNSTACKED, owner.side, {
				"buff": String(buff.def.id), "delta": -buff.stacks, "stacks": 0,
				"reason": "expired",
			})
			for e in buff.def.on_expire:
				(e as Effect).apply(RuleContext.create(
					ctx, owner, RuleRuntime.create(null, 0, buff, owner.side)
				))
	ctx.drain()

	# 弹出所有已到时刻的自发型规则。
	#
	# 每次出手后规则会以新时刻重新入堆（严格大于当前时刻），所以这个循环必然收敛 ——
	# 不需要「同一时刻每条只试一次」那种额外记账。
	var steps := 0
	while steps < MAX_STEPS_PER_INSTANT:
		var t := ctx.schedule.peek_time()
		if t < 0 or t > ctx.now:
			break
		var entry := ctx.schedule.pop()
		var rt2 := entry[ScheduleHeap.RULE] as RuleRuntime
		var owner2 := ctx.sides[rt2.owner_side] as CombatantRuntime
		# 惰性删除：buff 掉了之后它的规则还留在堆里，这里丢弃
		if not owner2.owns_rule(rt2):
			continue
		RuleEngine.fire_scheduled(ctx, owner2, rt2)
		ctx.drain()
		steps += 1
		if not _both_alive(ctx):
			break
	if steps >= MAX_STEPS_PER_INSTANT:
		push_warning("BattleSim: 同一时刻结算超过 %d 次，疑似零冷却规则" % MAX_STEPS_PER_INSTANT)


static func _both_alive(ctx: BattleContext) -> bool:
	return ctx.sides[0].is_alive() and ctx.sides[1].is_alive()


## 0 / 1 为获胜方，-1 为平局
static func _winner(ctx: BattleContext) -> int:
	var a_alive := ctx.sides[0].is_alive()
	var b_alive := ctx.sides[1].is_alive()
	if a_alive == b_alive:
		return -1
	return 0 if a_alive else 1
