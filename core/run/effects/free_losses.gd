## 免罚的败仗：和节点敌人打输前 n 次不扣体力（安德烈乌斯；猎手与核心不算）。[NodeEvents] 读 RunContext.free_losses，已免几次它自己记
class_name FreeLosses
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.free_losses += maxi(0, amount)


func describe() -> String:
	return UiText.t("bonus.free_losses") % amount
