## 条件：这个点现在算哪种类型（随机点按揭开的算）在名单里（8-3）。一个事件挂在几种点上时，按点分支
class_name NodeTypeIs
extends EventCondition

@export var types: Array[StringName] = []


func check(ctx: EventContext) -> bool:
	return ctx.node != null and types.has(NodeEvents.effective_type(ctx.node))


func describe() -> String:
	var names: Array[String] = []
	for t in types:
		names.append(UiText.pick(UiText.TEXT.get("node.short.%s" % t), String(t)))     # short names, as on the map legend
	return UiText.t("cond.node_type") % " / ".join(names)
