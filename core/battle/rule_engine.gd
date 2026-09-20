## 四层规则的求值（架构文档 4.4）。[BattleSim] 只负责推进时间，求值全在这里。
class_name RuleEngine
extends RefCounted


## 把一条事件派发给双方的所有规则。
##
## 遍历顺序固定：先 side 0 后 side 1，各方内部按规则登记顺序 ——
## 登记顺序来自编译期按 uid 升序的物品遍历，因此整体是确定性的。
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
	if not rule.cadence.can_fire(rc):
		return false
	rule.cadence.commit(rc)

	# 3. 消耗。本层内部原子：全过才逐个扣，不允许半付款
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


## 推进一帧：先让冷却类累积进度，再广播 tick。
static func advance(ctx: BattleContext, delta_fp: int) -> void:
	for rt in ctx.sides:
		for rule_rt in (rt as CombatantRuntime).rules:
			var cadence := (rule_rt as RuleRuntime).rule.cadence
			if cadence != null:
				cadence.advance(RuleContext.create(ctx, rt, rule_rt), delta_fp)
