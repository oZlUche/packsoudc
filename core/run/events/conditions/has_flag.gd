## 条件（091）：局外旗标 [member flag] 的数至少 [member min_value]（没立过 = 0）；[member absent] 反过来 —— 要求**没到**这个数。
## 剧情 / 见过谁 / 做过什么都靠它分支：旗标由后果 [SetFlag] 立，跟局外存档。沙盒里没有局外（ctx.meta 为 null）= 当作没立过
class_name HasFlag
extends EventCondition

@export var flag: StringName = &""
@export var min_value: int = 1
## 反过来：旗标没到 min_value 才满足
@export var absent: bool = false


func check(ctx: EventContext) -> bool:
	var v := ctx.meta.flag(flag) if ctx != null and ctx.meta != null else 0
	return v < min_value if absent else v >= min_value


func describe() -> String:
	# 旗标是内部记账，玩家只看一句
	return "条件还没满足"
