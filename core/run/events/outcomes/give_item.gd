## 后果：给一件指定的道具（到地上，和以前的事件一样由 RunState 收）
class_name GiveItem
extends EventOutcome

@export var item: StringName = &""
@export var count: int = 1


func apply(ctx: EventContext) -> void:
	if item == &"" or (ctx.items != null and ctx.items.get_def(item) == null):
		return
	for i in maxi(0, count):
		ctx.items_given.append(item)


func describe() -> String:
	return "给 %s ×%d" % [item, count]
