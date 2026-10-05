## 129：负重上限 +n（科技「扛重」）
class_name CarryCapacityBonus
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.carry_capacity_bonus += amount


func describe() -> String:
	return "负重上限 %+d" % amount
