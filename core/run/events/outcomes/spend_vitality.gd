## 后果：扣体力（7.1）。扣到 0 由 NodeEvents 判战败
class_name SpendVitality
extends EventOutcome

@export var amount: int = 1


func apply(ctx: EventContext) -> void:
	if ctx.vitality != null:
		ctx.spent += ctx.vitality.spend(amount, &"event")


func describe() -> String:
	return "体力 -%d" % amount
