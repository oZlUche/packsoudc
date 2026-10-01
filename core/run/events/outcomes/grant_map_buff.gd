## 后果：给一个地图 buff（强化、弱化，或者只是一个标记，062）
class_name GrantMapBuff
extends EventOutcome

@export var buff: StringName = &""


func apply(ctx: EventContext) -> void:
	if buff != &"" and ctx.hooks.grant_map_buff(buff):
		ctx.buffs_granted.append(String(buff))


func describe() -> String:
	return "获得「%s」" % buff
