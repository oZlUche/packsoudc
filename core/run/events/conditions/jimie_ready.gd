## 条件（281 寂灭的路（三））：没有激活信仰、背包里有全黑法杖与四颗元素之核、寂灭哪儿都没有 —— 休息点神坛的「献祭」靠它（配 hide_when_locked）
class_name JimieReady
extends EventCondition


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.faith_tier_now() < 0 and JimiePath.sacrifice_ready(ctx.board, ctx.meta)


func describe() -> String:
	return "寂灭的献祭备齐了"
