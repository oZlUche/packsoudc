## 体力上限 +n（7.1 的体力）
## 149：[member percent] 按角色的基数放大（Σ百分数相加后乘一次），[member amount] 在乘完之后加；两样可以并存
class_name VitalityMaxBonus
extends RunEffect

@export var amount: int = 1
## 百分数（20 = +20%）
@export var percent: int = 0


func modify(ctx: RunContext) -> void:
	ctx.vitality_max_bonus += amount
	ctx.vitality_max_mult += percent


func describe() -> String:
	var parts: Array[String] = []
	if percent != 0:
		parts.append("%+d%%" % percent)
	if amount != 0 or percent == 0:
		parts.append("%+d" % amount)
	return UiText.t("bonus.vitality_max") % UiText.t("tip.list_sep").join(parts)
