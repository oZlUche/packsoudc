## 后果（372）：直接给 [member amount] 点经验值（照乘难度系数，记来源 `event`）。序章三用它把阶补到教学要的那一档
class_name GainXp
extends EventOutcome

@export var amount: int = 0


func apply(ctx: EventContext) -> void:
	if amount > 0:
		ctx.xp_gained += ctx.hooks.level_gain(amount)


func describe() -> String:
	return UiText.t("event.xp_up") % amount
