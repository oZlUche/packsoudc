## 后果：钱加减。减的付不起就一分不动（条件层该先用 CanAfford 挡住）
class_name ChangeMoney
extends EventOutcome

@export var amount: int = 10


func apply(ctx: EventContext) -> void:
	if ctx.wallet == null or amount == 0:
		return
	if amount > 0:
		ctx.money += ctx.wallet.earn(amount, &"event")
	elif ctx.wallet.spend(-amount, &"event"):
		ctx.money += amount


func describe() -> String:
	return "钱 %+d" % amount
