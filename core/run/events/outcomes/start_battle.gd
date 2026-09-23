## 后果：开一场战斗。这个点自己有敌人就打它，没有就由敌人池现造一个
class_name StartBattle
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.start_battle = true


func describe() -> String:
	return "开战"
