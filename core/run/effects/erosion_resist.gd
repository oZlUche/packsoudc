## 耐侵蚀（136，布鲁图斯）：侵蚀扣体力时少扣 [member amount] 点（最少扣零）。[ErodeSpendVitality] 读 RunContext.erosion_resist
class_name ErosionResist
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.erosion_resist += maxi(0, amount)


func describe() -> String:
	return "侵蚀扣体力少扣 %d 点" % amount
