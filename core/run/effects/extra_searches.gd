## 每个搜索点多搜 n 次（6.2）
class_name ExtraSearches
extends RunEffect

@export var amount: int = 1


func modify(ctx: RunContext) -> void:
	ctx.extra_searches += amount


func describe() -> String:
	return UiText.t("bonus.extra_searches") % amount
