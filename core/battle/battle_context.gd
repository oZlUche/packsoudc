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

## 关掉即全量派发。测试用它跑「全开」路径与掩码路径比对。
var mask_enabled: bool = true
var _listened: Dictionary = {}

## 单次排空最多派发多少条。防「A 触发 B、B 又触发 A」变成死循环。
## 超限则丢弃剩余队列并记一条 DISPATCH_OVERFLOW，便于内容配错时定位而不是直接崩。
var max_chain: int = 256

var _queue: Array[BattleEvent] = []
var _draining: bool = false


static func create(a: CombatantRuntime, b: CombatantRuntime, p_rng: RandomNumberGenerator) -> BattleContext:
	var ctx := BattleContext.new()
	ctx.sides = [a, b]
	ctx.rng = p_rng
	# 资源池自己不认识事件总线，由战斗单位把变动转成 resource_changed。
	# 生命、耐力、法力共用这一条，新增资源不需要接线。
	for rt in ctx.sides:
		(rt as CombatantRuntime).bind_context(ctx)
	ctx.refresh_event_mask()
	return ctx


func opponent_of(rt: CombatantRuntime) -> CombatantRuntime:
	return sides[1] if rt == sides[0] else sides[0]


#region 事件掩码
## 重算订阅并集。
##
## [b]必须取双方并集[/b]：A 方发出的事件可能被 B 方的物品监听
## （「敌人回血时我获得强化」），按单侧算会漏。
##
## [b]规则集变化后必须重算[/b]：施加带 rules 的 buff 会引入新订阅，
## 不重算的话那条规则会静默失效 —— 没报错、没崩溃，只是「有时候不生效」，
## 是最难查的一类 bug。重算很便宜，宁可多算。
func refresh_event_mask() -> void:
	_listened.clear()
	for rt in sides:
		for rule_rt in rt.rules:
			var trigger := (rule_rt as RuleRuntime).rule.trigger
			if trigger == null:
				continue
			for n in trigger.subscribed_events():
				_listened[n] = true


func is_listening(n: StringName) -> bool:
	return true if not mask_enabled else _listened.has(n)
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
#endregion


func snapshot() -> Dictionary:
	return {"time": now, "sides": [sides[0].snapshot(), sides[1].snapshot()]}
