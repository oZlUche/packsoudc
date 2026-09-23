## 幸运 +n（6.1：每点加 DropRule.luck_bonus 的掉落率，可正可负）
class_name LuckBonus
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.luck_bonus += amount


func describe() -> String:
	return "幸运 %+d" % amount
