## 条件：身上有某道具（8-3）。item 为空 = 任何道具都算；tag 给了就只算带这个标签的（083 教程：棋盘上得有武器）；看棋盘、地上或两处
class_name HasItem
extends EventCondition

enum Where { BOARD, STORAGE, BOTH }

@export var item: StringName = &""
@export var tag: StringName = &""
@export var count: int = 1
@export var where: Where = Where.BOTH
## 114：反过来 —— 身上**没有**（不到 count 件）才过。序章一的退路：没拿到匕首就别卡在合成的门上
@export var missing: bool = false


func check(ctx: EventContext) -> bool:
	return (ctx.count_item(item, where, tag) >= maxi(1, count)) != missing


func describe() -> String:
	var what := String(item) if item != &"" else ("带「%s」的道具" % tag if tag != &"" else "任何道具")
	if missing:
		return "身上没有%s%s" % [what, ["（棋盘上）", "（地上）", ""][where]]
	return "需要%s ×%d%s" % [what, maxi(1, count), ["（棋盘上）", "（地上）", ""][where]]
