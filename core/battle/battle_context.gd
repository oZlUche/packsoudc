## 战场的公共状态与事件总线（架构文档 4.4）。
##
## [b]日志与派发是两件事。[/b] [member log] 只收回放视图需要的事件，与掩码无关；
## 掩码只决定要不要把事件派发给规则。不这样分开的话，
## 「掩码开／关两条路径产出逐条相同」这个不变式根本不可能成立 ——
## 而那条不变式是掩码能长期保持为「纯优化」的唯一保证。
class_name BattleContext
extends RefCounted

## 当前时刻，定点秒。事件驱动模拟，**没有帧**。
var now: int = 0
var rng: RandomNumberGenerator = null
var sides: Array[CombatantRuntime] = []

## 回放日志。内容与掩码无关。
var log: Array[BattleEvent] = []

## 关掉后，未被订阅的事件也照样构造并入队。
## 测试用它比对两条路径 —— 派发本身仍走索引，没有订阅者的事件自然是空操作，
## 所以结果必须完全一致。
var mask_enabled: bool = true

## 事件名 → 订阅它的规则列表。
##
## 既是派发索引，也顺带回答「有没有人听」—— 原先的 `_listened` 掩码是它的退化版本，
## 已合并进来，不再需要两个结构。
var _by_event: Dictionary = {}

## 自发型规则的时间轮。每条规则在堆里至多一个条目，只排下一次。
var schedule: ScheduleHeap = ScheduleHeap.new()

## 单次排空最多派发多少条。防「A 触发 B、B 又触发 A」变成死循环。
## 超限则丢弃剩余队列并记一条 DISPATCH_OVERFLOW，便于内容配错时定位而不是直接崩。
var max_chain: int = 256

var _queue: Array[BattleEvent] = []
var _draining: bool = false

## 正在结算中的伤害包，栈顶是当前这一包。
##
## 是栈而不是单个字段：受伤前效果自己也可能造成伤害（荆棘反弹），
## 那一下会在本次结算内部再开一层。
var _damage_stack: Array[DamagePacket] = []

## 伤害结算的最大嵌套层数。**兜底，不是防线。**
##
## 真正阻止反伤对轰的是伤害类型：反伤打出的是 [constant DamageTypes.REFLECT]，
## 而它 provokes 为 false，因此第一层就终止了。这个上限只在内容把某种
## 会招致反应的类型配进反弹效果时兜住，并记一条 dispatch_overflow 供定位。
const MAX_DAMAGE_DEPTH := 4


static func create(a: CombatantRuntime, b: CombatantRuntime, p_rng: RandomNumberGenerator) -> BattleContext:
	var ctx := BattleContext.new()
	ctx.sides = [a, b]
	ctx.rng = p_rng
	# 资源池自己不认识事件总线，由战斗单位把变动转成 resource_changed。
	# 生命、耐力、法力共用这一条，新增资源不需要接线。
	for rt in ctx.sides:
		(rt as CombatantRuntime).bind_context(ctx)
	ctx.refresh_event_index()
	# 开局把所有自发型规则排进时间轮
	for rt in ctx.sides:
		var owner := rt as CombatantRuntime
		for rule_rt in owner.rules:
			ctx.schedule_rule(owner, rule_rt as RuleRuntime)
	return ctx


func opponent_of(rt: CombatantRuntime) -> CombatantRuntime:
	return sides[1] if rt == sides[0] else sides[0]


#region 事件掩码
## 重建事件索引。
##
## [b]必须取双方并集[/b]：A 方发出的事件可能被 B 方的物品监听
## （「敌人回血时我获得强化」），按单侧算会漏。
##
## [b]规则集变化后必须重建[/b]：施加带 rules 的 buff 会引入新订阅，不重建则那条规则
## 静默失效；移除 buff 后不重建则已删除的规则继续被派发。后者更糟。
## 因此改由 [CombatantRuntime] 在规则集变动时自动调用，不靠各处记得。
##
## 遍历顺序固定为 side 0 → side 1、各方内部按规则登记顺序，派发顺序由此确定。
func refresh_event_index() -> void:
	_by_event.clear()
	for rt in sides:
		for rule_rt in rt.rules:
			var trigger := (rule_rt as RuleRuntime).rule.trigger
			if trigger == null:
				continue
			for n in trigger.subscribed_events():
				if not _by_event.has(n):
					_by_event[n] = [] as Array[RuleRuntime]
				(_by_event[n] as Array[RuleRuntime]).append(rule_rt)


func is_listening(n: StringName) -> bool:
	return true if not mask_enabled else _by_event.has(n)


## 订阅该事件的规则。返回内部数组，**调用方遍历前须自行复制** ——
## 效果可能施加 buff 从而触发索引重建。
func subscribers_of(n: StringName) -> Array[RuleRuntime]:
	return _by_event.get(n, [] as Array[RuleRuntime])


## 把一条自发型规则排进时间轮。非自发型直接忽略。
func schedule_rule(owner: CombatantRuntime, rt: RuleRuntime) -> void:
	var rule := rt.rule
	if rule == null or not rule.is_valid() or not rule.trigger.is_self_driven():
		return
	var t := rule.cadence.next_time(RuleContext.create(self, owner, rt), now)
	if t == Cadence.NEVER:
		return
	schedule.push(maxi(t, now), rt)
#endregion


#region 事件
## 广播一条事件。没人听且回放也用不上时，连对象都不构造。
func emit(name: StringName, side: int, payload: Dictionary = {}) -> void:
	var for_view := BattleEvent.is_view_event(name)
	var for_rules := is_listening(name)
	if not for_view and not for_rules:
		return
	var e := BattleEvent.make(name, now, side, payload)
	if for_view:
		log.append(e)
	if for_rules:
		_queue.append(e)


## 逐条派发队列。**不递归立即派发** —— 否则连锁触发会变成栈溢出而不是可控的链。
func drain() -> void:
	if _draining:
		return  # 已在排空中，新事件排到队尾由外层循环处理
	_draining = true
	var processed := 0
	while not _queue.is_empty():
		if processed >= max_chain:
			_queue.clear()
			log.append(BattleEvent.make(
				BattleEvent.DISPATCH_OVERFLOW, now, -1, {"limit": max_chain}
			))
			push_warning("BattleContext: 单帧连锁派发超过 %d 条，已截断" % max_chain)
			break
		var e: BattleEvent = _queue.pop_front()
		RuleEngine.dispatch(self, e)
		processed += 1
	_draining = false


func pending() -> int:
	return _queue.size()


## 正在结算的伤害包，不在结算中时为 null
func current_damage() -> DamagePacket:
	return _damage_stack.back() if not _damage_stack.is_empty() else null


## 同步派发「受伤前」。**只有伤害管线该调它。**
##
## 普通事件一律入队，靠 [method drain] 逐条处理，连锁才不会变成栈溢出。
## 这一条是例外：受伤前效果必须在伤害算出来之前改到包，排队就晚了。
## 代价是允许有限重入，因此有 [constant MAX_DAMAGE_DEPTH] 兜底。
func dispatch_before_damage(packet: DamagePacket) -> void:
	if packet == null or not is_listening(BattleEvent.BEFORE_DAMAGE):
		return
	if _damage_stack.size() >= MAX_DAMAGE_DEPTH:
		log.append(BattleEvent.make(
			BattleEvent.DISPATCH_OVERFLOW, now, -1,
			{"limit": MAX_DAMAGE_DEPTH, "where": "before_damage"}
		))
		push_warning("BattleContext: 伤害结算嵌套超过 %d 层，本层不再派发受伤前效果"
			% MAX_DAMAGE_DEPTH)
		return
	_damage_stack.append(packet)
	RuleEngine.dispatch(self, BattleEvent.make(
		BattleEvent.BEFORE_DAMAGE, now, packet.victim_side(), {
			"type": String(packet.type),
			"amount": packet.pending(),
			"provokes": packet.def().provokes,
			"source_side": packet.source_side,
			"uid": packet.source_uid,
		}
	))
	_damage_stack.pop_back()
#endregion


func snapshot() -> Dictionary:
	return {"time": now, "sides": [sides[0].snapshot(), sides[1].snapshot()]}
