## 后果：进容器屏搜（搜索点的「要不要搜」是事件，搜本身是会话，6.2）
class_name OpenSearch
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.open_search = true


func describe() -> String:
	return "搜索"
