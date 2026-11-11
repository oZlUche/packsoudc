## 后果（281 寂灭的路（三））：全黑法杖与四颗元素之核从背包里消失，寂灭落在法杖空出来的格子上（[method JimiePath.sacrifice]）
class_name JimieSacrifice
extends EventOutcome


func apply(ctx: EventContext) -> void:
	if ctx != null and not ctx.hooks.unique_owned(JimiePath.RED):     # 305：执行时再查一遍
		JimiePath.sacrifice(ctx.board, ctx.storage, ctx.items)     # 自己摆好了：不进 items_given（那是「持有方发到地上」的单子，进了会多发一把）


func describe() -> String:
	return "献上全黑法杖与四颗元素之核，换来寂灭"
