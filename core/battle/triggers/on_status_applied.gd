## 某个状态被施加时（130）：目标身上这个 buff 的层数**增加**的那一瞬。
##
## 只听 [constant BattleEvent.STATUS_APPLIED]：层数真的加上去了才发，叠满之后只刷新时长的那一下不发。
## 施加了几层进 [method RuleContext.source_stacks]，`apply_status(per_stack)` 读得到。
##
## [member by_self] 默认只认本方施加的 —— 对手自己身上的中毒（反噬件、它自己的规则）不算到你头上。
## 导入器拦自环：同一条规则听 X 又施加 X，会一直自己点燃自己
class_name OnStatusApplied
extends Trigger

@export var buff_id: StringName = &""
## 自己身上被施加（true）还是对手身上（false）
@export var on_self: bool = false
## 只认本方施加的
@export var by_self: bool = true


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.STATUS_APPLIED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if buff_id == &"" or event.get_name(&"buff") != buff_id:
		return false
	if not ctx.event_on(event, on_self):
		return false
	if by_self and event.get_int(&"source_side", -1) != ctx.owner.side:
		return false
	return event.get_int(&"delta") > 0


## 142：「你给对手施加流血时」「你被施加中毒时」「对手被施加流血时」（不认施加者）
func describe() -> String:
	var s := Glossary.status_name(buff_id)
	if by_self:
		return "你给%s施加%s时" % ["自己" if on_self else "对手", s]
	return "%s被施加%s时" % ["你" if on_self else "对手", s]


## 151：本件自己施加的那个 buff 按它施加的频率；别的按假定频率
func estimated_rate(ctx: PowerContext, _cadence_hz: float) -> float:
	if by_self:
		var key := ("self:" if on_self else "opp:") + String(buff_id)
		if ctx.applied_rate.has(key):
			return float(ctx.applied_rate[key])
	return ctx.weights.status_applied_rate
