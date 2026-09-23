## 后果：迎战猎手（开打前事件屏的选项，071）。只立旗，[NodeEvents] 按旗子调猎手系统
class_name HunterFight
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.hunter_fight = true


func describe() -> String:
	return "迎战猎手"
