## 条件：体力至少几点（7.1）
class_name VitalityAtLeast
extends EventCondition

@export var amount: int = 2


func check(ctx: EventContext) -> bool:
	return ctx.vitality != null and ctx.vitality.current >= amount


func describe() -> String:
	return UiText.t("cond.vitality") % amount
