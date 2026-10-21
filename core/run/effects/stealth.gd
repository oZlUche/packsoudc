## 潜行：猎手感知你的距离乘这个倍数（< 1 更难被发现；猎手系统读 RunContext.sense_mult）
class_name Stealth
extends RunEffect

@export var mult: float = 0.75


func modify(ctx: RunContext) -> void:
	ctx.sense_mult *= maxf(0.0, mult)


func describe() -> String:
	return UiText.t("bonus.stealth") % mult
