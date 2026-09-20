## 时机：这条规则关心什么事件、什么条件下算命中（架构文档 4.4）。
##
## 连带触发不是特殊机制 —— 它就是一个订阅 [constant BattleEvent.ITEM_FIRED] 的普通子类。
## 把「连带触发」单列成字段，等于又写死了一种时机。
@abstract
class_name Trigger
extends Resource

## 关心哪些事件。开战前会把所有规则的订阅求并集，只广播有人听的事件，
## 因此**漏报一个事件名会让整条规则静默失效**，这里必须报全。
@abstract func subscribed_events() -> Array[StringName]

## 事件到来时是否算命中。只读，不得改任何状态。
@abstract func matches(ctx: RuleContext, event: BattleEvent) -> bool


## 是否为自发型：不等事件，由频率层排出执行时刻，由 [BattleSim] 放进时间轮。
## 只有 [OnSchedule] 返回 true。
func is_self_driven() -> bool:
	return false
