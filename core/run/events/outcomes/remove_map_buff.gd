## 后果：去掉一个地图 buff（用掉一个标记）
class_name RemoveMapBuff
extends EventOutcome

@export var buff: StringName = &""


func apply(ctx: EventContext) -> void:
	if buff != &"" and ctx.remove_map_buff.is_valid() and bool(ctx.remove_map_buff.call(buff)):
		ctx.buffs_removed.append(String(buff))


func describe() -> String:
	return "失去「%s」" % buff
