## 后果：给一个地图 buff（强化、弱化，或者只是一个标记，062）
class_name GrantMapBuff
extends EventOutcome

@export var buff: StringName = &""


func apply(ctx: EventContext) -> void:
	if buff != &"" and ctx.grant_map_buff.is_valid() and bool(ctx.grant_map_buff.call(buff)):
		ctx.buffs_granted.append(String(buff))


func describe() -> String:
	return "获得「%s」" % buff
