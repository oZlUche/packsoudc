## 条件：有没有某个地图 buff
class_name HasMapBuff
extends EventCondition

@export var buff: StringName = &""


func check(ctx: EventContext) -> bool:
	return ctx.buff_present(buff)


func describe() -> String:
	return UiText.t("cond.needs_named") % content_name("run_buffs", buff)
