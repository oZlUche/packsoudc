## 四层规则的求值（架构文档 4.4）。[BattleSim] 只负责推进时间，求值全在这里。
class_name RuleEngine
extends RefCounted


## 把一条事件派发给双方的所有规则。
##
## 遍历顺序固定：先 side 0 后 side 1，各方内部按规则登记顺序 ——
## 登记顺序来自编译期按 uid 升序的物品遍历，因此整体是确定性的。
## 自发型规则：不经由事件，直接求值（跳过时机层）。由 [BattleSim] 在排定时刻调用。
static func fire_scheduled(ctx: BattleContext, owner: CombatantRuntime, rt: RuleRuntime) -> bool:
	var rule := rt.rule
	if rule == null or not rule.is_valid():
		return false
	var rc := RuleContext.create(ctx, owner, rt)

	rule.cadence.on_match(rc)
	if not rule.cadence.can_fire(rc, ctx.now):
		return false
	rule.cadence.commit(rc, ctx.now)

	for cost in rule.costs:
		(cost as Cost).on_attempt(rc)
	for cost in rule.costs:
		if not (cost as Cost).can_pay(rc):
			return false
	for cost in rule.costs:
		(cost as Cost).pay(rc)

	if rt.source_uid != 0:
		ctx.emit(BattleEvent.ITEM_FIRED, owner.side, {"uid": rt.source_uid})
	for effect in rule.effects:
		(effect as Effect).apply(rc)
	return true


static func dispatch(ctx: BattleContext, event: BattleEvent) -> void:
	for rt in ctx.sides:
		var owner := rt as CombatantRuntime
		# 复制一份再遍历：效果可能施加 buff 从而往 rules 里追加条目，
		# 边遍历边改会漏掉或重复。新规则从下一条事件开始生效。
		var snapshot := owner.rules.duplicate()
		for rule_rt in snapshot:
			evaluate(ctx, owner, rule_rt as RuleRuntime, event)


## 四层求值。返回是否真的执行了效果。
##
## [b]顺序不可调换，且消耗与频率刻意不原子：[/b]
## 冷却先提交（清零），再检查消耗；付不起则跳过效果，冷却已经走了。
## 否则武器会在耐力回满的那一瞬间立刻打出，耐力不足毫无代价。
## 这不是疏忽，见架构文档 4.4。
static func evaluate(
	ctx: BattleContext, owner: CombatantRuntime, rt: RuleRuntime, event: BattleEvent
) -> bool:
	var rule := rt.rule
	if rule == null or not rule.is_valid():
		return false

	var rc := RuleContext.create(ctx, owner, rt)

	# 1. 时机
	if not rule.trigger.matches(rc, event):
		return false

	# 2. 频率。on_match 先记账（计数类要把没执行的那几次也数上），再判是否放行
	rule.cadence.on_match(rc)
	if not rule.cadence.can_fire(rc, ctx.now):
		return false
	rule.cadence.commit(rc, ctx.now)

	# 3. 消耗。本层内部原子：全过才逐个扣，不允许半付款
	for cost in rule.costs:
		(cost as Cost).on_attempt(rc)
	for cost in rule.costs:
		if not (cost as Cost).can_pay(rc):
			return false
	for cost in rule.costs:
		(cost as Cost).pay(rc)

	# 物品出手。连带触发靠监听这条事件，不需要任何特例
	if rt.source_uid != 0:
		ctx.emit(BattleEvent.ITEM_FIRED, owner.side, {"uid": rt.source_uid})

	# 4. 内容。同一条规则的多个效果共用上面那一次消耗
	for effect in rule.effects:
		(effect as Effect).apply(rc)
	return true


## 把所有冷却进度结算到 now。**速率变化前必须调用** ——
## 否则新速率会被错误地套用到变化之前那段时间上。
static func flush_all(ctx: BattleContext, now: int) -> void:
	for rt in ctx.sides:
		for rule_rt in (rt as CombatantRuntime).rules:
			var cadence := (rule_rt as RuleRuntime).rule.cadence
			if cadence != null:
				cadence.flush(RuleContext.create(ctx, rt, rule_rt), now)


## 自发型规则中最早的下一次执行时刻，以及它属于谁。
## 返回 {"time": int, "owner": CombatantRuntime, "rule": RuleRuntime}，
## 没有自发规则时 time 为 [constant Cadence.NEVER]。
##
## 同刻并列时按 (side, source_uid, 规则序号) 取最小，保证确定性。
## [param skip] 里的 RuleRuntime 会被跳过 —— 同一时刻每条规则只尝试一次，
## 否则「就绪但拒绝执行」的规则（次数没攒够、耐力不够）会让调用方原地空转。
static func earliest_scheduled(ctx: BattleContext, now: int, skip: Dictionary = {}) -> Dictionary:
	var best := {"time": Cadence.NEVER, "owner": null, "rule": null}
	for rt in ctx.sides:
		var owner := rt as CombatantRuntime
		for i in owner.rules.size():
			var rule_rt := owner.rules[i] as RuleRuntime
			var rule := rule_rt.rule
			if rule == null or not rule.is_valid() or not rule.trigger.is_self_driven():
				continue
			if skip.has(rule_rt.get_instance_id()):
				continue
			var t := rule.cadence.next_time(RuleContext.create(ctx, owner, rule_rt), now)
			if t == Cadence.NEVER:
				continue
			if best["time"] == Cadence.NEVER or t < best["time"]:
				best = {"time": t, "owner": owner, "rule": rule_rt}
	return best
