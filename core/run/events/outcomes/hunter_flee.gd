## 后果：从猎手面前逃跑（071）。只立旗，[NodeEvents] 让猎手系统掷成功率；没逃掉接着打
class_name HunterFlee
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.hunter_flee = true


func describe() -> String:
	return "逃跑"
