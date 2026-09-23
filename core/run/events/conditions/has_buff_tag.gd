## 条件：激活的 buff 里有没有带这个标记的（地图 buff 当标记用，导向分支）
class_name HasBuffTag
extends EventCondition

@export var tag: StringName = &""


func check(ctx: EventContext) -> bool:
	return ctx.tag_present(tag)


func describe() -> String:
	return "需要标记「%s」" % tag
