## 开局钱 +n（6.6）
class_name StartingFundsBonus
extends RunEffect

@export var amount: int = 10


func modify(ctx: RunContext) -> void:
	ctx.starting_funds_bonus += amount


func describe() -> String:
	return "开局钱 %+d" % amount
