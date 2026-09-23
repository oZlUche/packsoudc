## 后果：接着放另一个事件（分支剧情）
class_name NextEvent
extends EventOutcome

@export var event: StringName = &""


func apply(ctx: EventContext) -> void:
	ctx.next_event = event


func describe() -> String:
	return "接「%s」" % event
