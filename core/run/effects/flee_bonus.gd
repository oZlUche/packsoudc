## 逃跑：从猎手面前逃跑的成功率加这么多（猎手系统读 RunContext.flee_bonus）
class_name FleeBonus
extends RunEffect

@export var amount: float = 0.2


func modify(ctx: RunContext) -> void:
	ctx.flee_bonus += amount


func describe() -> String:
	return "逃跑 %+.0f%%" % (amount * 100.0)
