## 条件：段位（074，只看步数）在某个区间里（8-3）。这一局没有猎手机制 = 没有段位，永远不满足
class_name BracketWithin
extends EventCondition

@export var min_bracket: int = 0
@export var max_bracket: int = -1


func check(ctx: EventContext) -> bool:
	var b := ctx.bracket_now()
	return b >= 0 and b >= min_bracket and (max_bracket < 0 or b <= max_bracket)


func describe() -> String:
	if max_bracket < 0:
		return "需要段位 ≥ %d" % min_bracket
	if min_bracket <= 0:
		return "需要段位 ≤ %d" % max_bracket
	return "需要段位 %d～%d" % [min_bracket, max_bracket]
