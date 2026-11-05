## 后果（281 寂灭的路（三））：全黑法杖与四颗元素之核从背包里消失，寂灭落在法杖空出来的格子上（[method JimiePath.sacrifice]）
class_name JimieSacrifice
extends EventOutcome


func apply(ctx: EventContext) -> void:
	if ctx != null and JimiePath.sacrifice(ctx.board, ctx.storage, ctx.items):
		ctx.items_given.append(JimiePath.RED)


func describe() -> String:
	return "献上全黑法杖与四颗元素之核，换来寂灭"
