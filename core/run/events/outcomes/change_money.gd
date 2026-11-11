## 后果：钱加减。减的付不起就一分不动（条件层该先用 CanAfford 挡住）
##
## 事件方案 2026-11-11：给了 [member reward_key] 就不看 [member amount]，改成**付**那份冻结奖励的定价 × [member reward_price_mult]
## （[method EventRewards.price_of]）—— 药摊按实际抽中的药报价，点之前就定了
class_name ChangeMoney
extends EventOutcome

@export var amount: int = 10
@export var reward_key: StringName = &""
@export var reward_price_mult: float = 1.0


func delta(ctx: EventContext) -> int:
	if reward_key != &"":
		return -EventRewards.price_of(ctx.node, self, ctx.items)
	return amount


func apply(ctx: EventContext) -> void:
	var d := delta(ctx)
	if ctx.wallet == null or d == 0:
		return
	if d > 0:
		ctx.money += ctx.wallet.earn(d, &"event")
	elif ctx.wallet.spend(-d, &"event"):
		ctx.money += d


func describe() -> String:
	return "付奖励定价 ×%s" % reward_price_mult if reward_key != &"" else "钱 %+d" % amount
