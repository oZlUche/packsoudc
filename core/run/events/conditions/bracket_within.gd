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
		return UiText.t("cond.bracket_min") % min_bracket
	if min_bracket <= 0:
		return UiText.t("cond.bracket_max") % max_bracket
	return UiText.t("cond.bracket_range") % [min_bracket, max_bracket]
