## 条件（282）：[member ids] 里的独一道具哪儿都没有（仓库、带回的棋盘、集市、这一局各处，[UniqueItems]）
class_name OwnedNowhere
extends EventCondition

@export var ids: Array[StringName] = []


func check(ctx: EventContext) -> bool:
	var owned := UniqueItems.owned_ids(ctx.meta if ctx != null else null, null, ctx.items if ctx != null else null)
	for id in ids:
		if owned.has(id):
			return false
	return true


func describe() -> String:
	return UiText.t("cond.not_met")
