## 后果：这个点从此算另一种类型（8-3）。写进内容的 `resolved_type`（和随机点揭开是同一个记号），
## 同一个选项里后面的「照常发生」「开战」按新类型走；地图重画
class_name ChangeNodeType
extends EventOutcome

@export var node_type: StringName = &"battle"


func apply(ctx: EventContext) -> void:
	if node_type != &"" and MapNodeTypes.has(node_type):
		ctx.new_type = node_type


func describe() -> String:
	return "这个点变成%s点" % node_type
