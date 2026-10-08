## 某状态掉光时（132）：最后一层被移除（净化、消耗、转化）或到期的那一次。和 [OnStatusApplied] 成对。
##
## 听 [constant BattleEvent.STATUS_UNSTACKED] 里剩余层数为 0 的那一条；只掉了几层、还剩的不算。
## 掉光时又施加同一个状态不算自环（它要再掉光一次才会再触发），导入器不拦
class_name OnStatusRemoved
extends Trigger

@export var buff_id: StringName = &""
## 自己身上（true）还是对手身上（false）
@export var on_self: bool = true


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.STATUS_UNSTACKED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if buff_id == &"" or event.get_name(&"buff") != buff_id:
		return false
	if not ctx.event_on(event, on_self):
		return false
	return event.get_int(&"stacks", 1) <= 0


func describe() -> String:
	return "%s的%s掉光时" % ["你" if on_self else "对手", Glossary.status_name(buff_id)]
