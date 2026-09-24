## 后果：这个点照它的类型照常发生（8-3）—— 休息点回体力、商店开店、搜索点开搜、战斗点开打、撤离点报到。
## 给「休息 / 商店点也先过事件」用：事件只管前面那一屏，发生的事还是老路那一套（数值都在 NodeRules）
class_name Proceed
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.proceed = true


func describe() -> String:
	return "照这个点的类型发生"
