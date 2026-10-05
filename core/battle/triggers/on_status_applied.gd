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
	if (event.side == ctx.owner.side) != on_self:
		return false
	if by_self and event.get_int(&"source_side", -1) != ctx.owner.side:
		return false
	return event.get_int(&"delta") > 0
