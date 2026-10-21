## 条件：到现在为止花的行动点在某个区间里（8-3）。max 为 -1 = 不封顶
class_name StepsWithin
extends EventCondition

@export var min_steps: int = 0
@export var max_steps: int = -1


func check(ctx: EventContext) -> bool:
	return ctx.steps >= min_steps and (max_steps < 0 or ctx.steps <= max_steps)


func describe() -> String:
	if max_steps < 0:
		return UiText.t("cond.steps_min") % min_steps
	if min_steps <= 0:
		return UiText.t("cond.steps_max") % max_steps
	return UiText.t("cond.steps_range") % [min_steps, max_steps]
