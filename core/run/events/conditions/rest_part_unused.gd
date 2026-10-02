## 条件（反馈）：休息点上的 [member part] 这一份还没用。休息点有两份独立的机会 —— 休息（rest）与神坛（altar），
## 各用各的；选「继续赶路」两份都不动，回头还能来。用过的选项靠它（配 hide_when_locked）藏起来
class_name RestPartUnused
extends EventCondition

## rest = 休息（歇一会儿 / 扎营）；altar = 神坛（献祭或特殊操作，二选一）
@export var part: StringName = &"rest"


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.node != null and not NodeEvents.rest_part_used(ctx.node, part)


func describe() -> String:
	return "这里的神坛已经用过了" if part == &"altar" else "这里已经休息过了"
