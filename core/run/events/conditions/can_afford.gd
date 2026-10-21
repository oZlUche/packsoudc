## 条件：钱够不够
class_name CanAfford
extends EventCondition

@export var amount: int = 10


func check(ctx: EventContext) -> bool:
	return ctx.wallet != null and ctx.wallet.can_afford(amount)


func describe() -> String:
	return UiText.t("cond.coins") % amount
