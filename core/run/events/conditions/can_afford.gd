## 条件：钱够不够。事件方案 2026-11-11：给了 [member reward_key] 就按那份冻结奖励的定价 × [member reward_price_mult] 算（和 [ChangeMoney] 同一笔）
class_name CanAfford
extends EventCondition

@export var amount: int = 10
@export var reward_key: StringName = &""
@export var reward_price_mult: float = 1.0


func price(ctx: EventContext) -> int:
	if reward_key == &"":
		return amount
	var o := ChangeMoney.new()
	o.reward_key = reward_key
	o.reward_price_mult = reward_price_mult
	return EventRewards.price_of(ctx.node, o, ctx.items)


func check(ctx: EventContext) -> bool:
	return ctx.wallet != null and ctx.wallet.can_afford(price(ctx))


func describe() -> String:
	return UiText.t("cond.coins") % amount


func describe_in(ctx: EventContext) -> String:
	return UiText.t("cond.coins") % price(ctx)
