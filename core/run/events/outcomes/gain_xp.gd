## 后果（372）：直接给 [member amount] 点经验值（照乘难度系数，记来源 `event`）。事件拿它直接补经验
class_name GainXp
extends EventOutcome

@export var amount: int = 0


func apply(ctx: EventContext) -> void:
	if amount > 0:
		ctx.xp_gained += ctx.hooks.level_gain(amount)


func describe() -> String:
	return UiText.t("event.xp_up") % amount
