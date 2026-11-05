## 后果（281 寂灭的路（三））：魔法之神的残余意识说完了 —— 这一局当场结算、回基地（[method RunState.extract_by_jimie]）
class_name JimieAscend
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.jimie_ascend = true


func describe() -> String:
	return "结算回基地"
