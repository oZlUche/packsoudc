## 加时开始时（132）：加时叠第一层的那一瞬（103 的 [OvertimeRules]），整场只一次。
##
## 听的就是加时叠层事件 [constant BattleEvent.OVERTIME_STACKED]（全局，side −1），只认第一次
class_name OnOvertime
extends Trigger


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.OVERTIME_STACKED] as Array[StringName]


func matches(_ctx: RuleContext, event: BattleEvent) -> bool:
	return event.get_int(&"count") == 1


func describe() -> String:
	return UiText.t("trig.overtime")
