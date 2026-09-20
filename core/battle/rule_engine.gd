## 四层规则的求值（架构文档 4.4）。[BattleSim] 只负责推进时间，求值全在这里。
class_name RuleEngine
extends RefCounted


## 把一条事件派发给双方的所有规则。
##
## 遍历顺序固定：先 side 0 后 side 1，各方内部按规则登记顺序 ——
## 登记顺序来自编译期按 uid 升序的物品遍历，因此整体是确定性的。
## 自发型规则：不经由事件，直接求值（跳过时机层）。由 [BattleSim] 在排定时刻调用。
##
## [b]无论最终是否真的放出效果，都会重新排进时间轮。[/b]
## 这正是「每次尝试使用后都重算冷却」—— 消耗付不起也照样走冷却。
static func fire_scheduled(ctx: BattleContext, owner: CombatantRuntime, rt: RuleRuntime) -> bool:
	var rule := rt.rule
	if rule == null or not rule.is_valid():
		return false
	var rc := RuleContext.create(ctx, owner, rt)

	rule.cadence.on_match(rc)
	if not rule.cadence.can_fire(rc, ctx.now):
		# 理论上不该发生（是按就绪时刻弹出的）。保险起见也要重新入堆，
		# 否则这条规则会永远消失
		_reschedule(ctx, owner, rt, rc)
		return false
	rule.cadence.commit(rc, ctx.now)
	_reschedule(ctx, owner, rt, rc)

	var all_costs := rule.effective_costs()
	for cost in all_costs:
		(cost as Cost).on_attempt(rc)
	for cost in all_costs:
		if not (cost as Cost).can_pay(rc):
			return false
	for cost in all_costs:
		(cost as Cost).pay(rc)

	if rt.source_uid != 0:
		ctx.emit(BattleEvent.ITEM_FIRED, owner.side, {"uid": rt.source_uid})
	for effect in rule.effects:
		(effect as Effect).apply(rc)
	return true


## 只遍历**订阅了该事件**的规则，而不是全部规则。
##
## 朴素做法是扫全部规则再让每条自己判断，那样每个事件都要给每条规则分配一个
## RuleContext，绝大多数当场丢弃。索引把它降到 O(订阅者)。
static func dispatch(ctx: BattleContext, event: BattleEvent) -> void:
	var subs := ctx.subscribers_of(event.name)
	if subs.is_empty():
		return
	# 复制一份再遍历：效果可能施加或移除 buff 从而重建索引，
	# 边遍历边改会漏掉或重复。规则集的变化从下一条事件开始生效。
	for rule_rt in subs.duplicate():
		var rt := rule_rt as RuleRuntime
		evaluate(ctx, ctx.sides[rt.owner_side], rt, event)


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
	var all_costs := rule.effective_costs()
	for cost in all_costs:
		(cost as Cost).on_attempt(rc)
	for cost in all_costs:
		if not (cost as Cost).can_pay(rc):
			return false
	for cost in all_costs:
		(cost as Cost).pay(rc)

	# 物品出手。连带触发靠监听这条事件，不需要任何特例
	if rt.source_uid != 0:
		ctx.emit(BattleEvent.ITEM_FIRED, owner.side, {"uid": rt.source_uid})

	# 4. 内容。同一条规则的多个效果共用上面那一次消耗
	for effect in rule.effects:
		(effect as Effect).apply(rc)
	return true


## 出手（或尝试出手）之后重新排队。
##
## 时刻必须严格大于当前时刻，否则同刻会被反复弹出，推进器再也走不动。
static func _reschedule(
	ctx: BattleContext, owner: CombatantRuntime, rt: RuleRuntime, rc: RuleContext
) -> void:
	var t: int = rt.rule.cadence.next_time(rc, ctx.now)
	if t == Cadence.NEVER:
		return
	ctx.schedule.push(maxi(t, ctx.now + 1), rt)
