## 后果（093）：打开神坛（休息处的「神坛」选项）——献祭、看信力、信仰的特殊操作
class_name OpenAltar
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.open_altar = true


func describe() -> String:
	return "打开神坛"
