## 后果：回体力（7.1）
class_name RestoreVitality
extends EventOutcome

@export var amount: int = 1


func apply(ctx: EventContext) -> void:
	if ctx.vitality != null:
		ctx.restored += ctx.vitality.restore(amount, &"event")


func describe() -> String:
	return "体力 +%d" % amount
