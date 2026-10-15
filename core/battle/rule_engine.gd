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

	if not rule.cadence.can_fire(rc, ctx.now):
		# 理论上不该发生（是按就绪时刻弹出的）。保险起见也要重新入堆，
		# 否则这条规则会永远消失
		_reschedule(ctx, owner, rt, rc)
		if ctx.trace != null:
			_trace(ctx, rt, rc, BattleTrace.RULE_SKIP, {"reason": "cadence"})
		return false
	rule.cadence.commit(rc, ctx.now)
	_reschedule(ctx, owner, rt, rc)
	return _settle(ctx, owner, rt, rc, null)


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
		if rt.born > event.seq:
			continue     # 175：这条规则是在这条事件发出之后才出生的（被这一下施加的 buff），不听它
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
	rc.event = event

	# 1. 时机
	if not rule.trigger.matches(rc, event):
		return false

	# 2. 频率（计数类的「攒够 N 次」在消耗层，见 [Cost.on_attempt]）
	if not rule.cadence.can_fire(rc, ctx.now):
		if ctx.trace != null:
			_trace(ctx, rt, rc, BattleTrace.RULE_SKIP, {"reason": "cadence", "event": String(event.name)})
		return false
	rule.cadence.commit(rc, ctx.now)

	# 3、4. 消耗与内容
	return _settle(ctx, owner, rt, rc, event)


## 频率放行之后的后半段，自发型与事件型共用：消耗 → 出手事件 → 效果。返回是否真的执行了效果。
## 消耗这一层内部原子：全过才逐个扣，不允许半付款；但与上面的频率刻意不原子（冷却已经清零），见 [method evaluate]
static func _settle(ctx: BattleContext, owner: CombatantRuntime, rt: RuleRuntime, rc: RuleContext, event: BattleEvent) -> bool:
	var rule := rt.rule
	var all_costs := rule.effective_costs()
	for cost in all_costs:
		(cost as Cost).on_attempt(rc)
	for cost in all_costs:
		if not (cost as Cost).can_pay(rc):
			if ctx.trace != null:
				_trace(ctx, rt, rc, BattleTrace.RULE_SKIP, {"reason": "cost", "cost": (cost as Cost).trace_info(rc)})
			_emit_skipped(ctx, owner, rt, rc)
			return false
	for cost in all_costs:
		(cost as Cost).pay(rc)
	if ctx.trace != null:
		_trace(ctx, rt, rc, BattleTrace.RULE_FIRE, {"costs": all_costs.map(func(c): return (c as Cost).trace_info(rc))})

	# 物品出手。连带触发靠监听这条事件，不需要任何特例。
	# 108：**听自己出手的规则不算再出手一次** —— 附加规则（毒箭挂给弓的、日神附魔）以宿主身份跑、听的就是宿主的出手；
	# 它要是再发一条宿主的 ITEM_FIRED，就会再触发自己，一直连锁到 max_chain 被截断（一击挂几十层毒 / 几十次附火）。
	# 自发型（event 为 null）天然不是
	var self_fired := event != null and event.name == BattleEvent.ITEM_FIRED and event.get_int(&"uid") == rt.source_uid
	if rt.source_uid != 0 and not self_fired:
		ctx.emit(BattleEvent.ITEM_FIRED, owner.side, _fired_payload(rt, rc))

	# 内容。同一条规则的多个效果共用上面那一次消耗
	for effect in rule.effects:
		(effect as Effect).apply(rc)
	return true


## 103 第 7 条：出手事件带上这条规则下一次就绪的时刻（定点），回放层据此画冷却遮罩；没有冷却的规则不带
static func _fired_payload(rt: RuleRuntime, rc: RuleContext) -> Dictionary:
	var out := {"uid": rt.source_uid}
	var ready := ready_at_of(rt, rc)
	if ready >= 0:
		out["ready_at"] = ready
	_cycle_payload(rt, rc, out)
	return out


## 175：轮读的法杖再带上这一下读的第几颗（`step`，0 起）、一轮几颗（`steps`）、下一下读第几颗（`next`）—— 回放在法杖上标罗马数字
static func _cycle_payload(rt: RuleRuntime, rc: RuleContext, out: Dictionary) -> void:
	if not (rt.rule.cadence is CycleCadence) or rt.source_uid == 0:
		return
	var steps := rc.owner.loaded_of(rt.source_uid).size()
	if steps <= 0:
		return
	out["step"] = int(rc.state().get(CycleCadence.FIRED, 0))
	out["steps"] = steps
	out["next"] = int(rc.state().get(CycleCadence.INDEX, 0))


## 冷却已经走了、耐力不够没出手：也告诉回放「新一轮开始了」，否则遮罩会在这一刻断掉
static func _emit_skipped(ctx: BattleContext, owner: CombatantRuntime, rt: RuleRuntime, rc: RuleContext) -> void:
	if rt.source_uid == 0:
		return
	var ready := ready_at_of(rt, rc)
	if ready >= 0:
		var d := {"uid": rt.source_uid, "ready_at": ready}
		_cycle_payload(rt, rc, d)
		ctx.emit(BattleEvent.ITEM_SKIPPED, owner.side, d)


## 117：内部日志的一条出手 / 跳过：哪件道具（或哪个 buff）的哪条规则、什么时机、下一次就绪
static func _trace(ctx: BattleContext, rt: RuleRuntime, rc: RuleContext, kind: String, extra: Dictionary) -> void:
	var d := {"uid": rt.source_uid, "order": rt.order, "trigger": RegistryLookup.class_of(rt.rule.trigger),
		"cadence": RegistryLookup.class_of(rt.rule.cadence)}
	if rt.buff != null and rt.buff.def != null:
		d["buff"] = String(rt.buff.def.id)
	var ready := ready_at_of(rt, rc)
	if ready >= 0:
		d["ready_at"] = ready
	d.merge(extra, true)
	ctx.trace.record(ctx.now, rt.owner_side, kind, d)


## 冷却型频率的下一次就绪时刻；不是冷却型 -1
static func ready_at_of(rt: RuleRuntime, rc: RuleContext) -> int:
	if rt.rule == null or not (rt.rule.cadence is CooldownCadence):
		return -1
	return int(rc.state().get(CooldownCadence.READY_AT, -1))


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
