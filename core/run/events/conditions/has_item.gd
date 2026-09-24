## 条件：身上有某道具（8-3）。item 为空 = 任何道具都算；看棋盘、暂存区或两处
class_name HasItem
extends EventCondition

enum Where { BOARD, STORAGE, BOTH }

@export var item: StringName = &""
@export var count: int = 1
@export var where: Where = Where.BOTH


func check(ctx: EventContext) -> bool:
	return ctx.count_item(item, where) >= maxi(1, count)


func describe() -> String:
	var what := "任何道具" if item == &"" else String(item)
	return "需要%s ×%d%s" % [what, maxi(1, count), ["（棋盘上）", "（暂存区里）", ""][where]]
