## 149：败仗少扣几点体力（科技「不屈」）—— 最少还是扣一点；必死的、写了无代价的不管。[NodeEvents] 读 RunContext.loss_discount
class_name LossDiscount
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.loss_discount += maxi(0, amount)


func describe() -> String:
	return UiText.t("bonus.loss_discount") % amount
