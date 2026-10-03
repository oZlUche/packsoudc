## 条件（093）：激活了一个信仰，且它现在至少第 [member min_tier] 阶（0 = 激活了就行）。休息点的「神坛」选项靠它：没信仰不显示。
## 113：[member faith] 给了就只认这一位神（信仰 id，如 `brute`）；空 = 哪位都行
class_name FaithActive
extends EventCondition

@export var min_tier: int = 0
## 113：只认这一位神（信仰 id）；空 = 任一
@export var faith: StringName = &""


func check(ctx: EventContext) -> bool:
	if ctx == null:
		return false
	if faith != &"" and ctx.active_faith_id() != faith:
		return false
	var tier := ctx.faith_tier_now()
	return tier >= 0 and tier >= min_tier


func describe() -> String:
	var who := "信仰" if faith == &"" else "「%s」" % faith
	return "需要激活%s" % who if min_tier <= 0 else "需要%s至少 %d 级" % [who, min_tier]
