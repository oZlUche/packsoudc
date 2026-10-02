## 条件（093）：激活了一个信仰，且它现在至少第 [member min_tier] 阶（0 = 激活了就行）。休息点的「神坛」选项靠它：没信仰不显示
class_name FaithActive
extends EventCondition

@export var min_tier: int = 0


func check(ctx: EventContext) -> bool:
	if ctx == null:
		return false
	var tier := ctx.faith_tier_now()
	return tier >= 0 and tier >= min_tier


func describe() -> String:
	return "需要激活一个信仰" if min_tier <= 0 else "需要信仰至少 %d 级" % min_tier
