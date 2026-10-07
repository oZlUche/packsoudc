## 休息多回（136，布鲁图斯）：休息区回体力时多回 [member amount] 点。[NodeEvents] 的休息读 RunContext.rest_bonus
class_name RestBonus
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.rest_bonus += maxi(0, amount)


func describe() -> String:
	return "休息多回 %d 点体力" % amount
