## 条件（194 §1）：这座休息点的铸炉还没用过（一座只能铸一次）。配 hide_when_locked，铸过了「铸炉」选项就藏起来
class_name ForgeUnused
extends EventCondition


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.node != null and not NodeEvents.forge_used(ctx.node)


func describe() -> String:
	return "这座铸炉已经用过了"
