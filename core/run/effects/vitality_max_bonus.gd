## 体力上限 +n（7.1 的体力）
class_name VitalityMaxBonus
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.vitality_max_bonus += amount


func describe() -> String:
	return "体力上限 %+d" % amount
