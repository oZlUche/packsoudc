## 条件：激活的 buff 里有没有带这个标记的（地图 buff 当标记用，导向分支）
class_name HasBuffTag
extends EventCondition

@export var tag: StringName = &""


func check(ctx: EventContext) -> bool:
	return ctx.tag_present(tag)


func describe() -> String:
	# 标记多半和同名的地图 buff 一起发（marked）：有就写那个 buff 的名字
	var path := ContentPaths.asset_file("run_buffs", String(tag))
	if path != "" and ResourceLoader.exists(path):
		return "需要「%s」" % content_name("run_buffs", tag)
	var name := TagRegistry.name_of(tag)
	return "需要「%s」" % name if name != "" and name != String(tag) else "需要特定的状态"
