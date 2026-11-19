## 后果（287）：打开托付屏（就是 092 的保险箱屏）—— 撤离点上的「托付」。这个点不算用过，关了回来再弹
class_name OpenSafe
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.open_safe = true


func describe() -> String:
	return "打开托付"
