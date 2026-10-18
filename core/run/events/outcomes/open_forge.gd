## 后果（194 §1）：打开铸炉（休息点的「铸炉」选项，和神坛并列）—— 三件道具熔成一枚铸牌。不算用掉休息那一份
class_name OpenForge
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.open_forge = true


func describe() -> String:
	return "打开铸炉"
