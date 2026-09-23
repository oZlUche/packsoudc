## 后果：开商店（给将来「商店点也先过事件」用）
class_name OpenShop
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.open_shop = true


func describe() -> String:
	return "开店"
