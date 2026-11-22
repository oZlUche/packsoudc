## 372（作者 18:15）：局内升级选牌时「删除」（这一局不再出这张，空位补一张）的次数 —— 局外机制树的科技给，一局用完为止（[LevelModule]）
class_name LevelRemovals
extends RunEffect

@export var times: int = 1


func modify(ctx: RunContext) -> void:
	ctx.level_removals += maxi(0, times)


func describe() -> String:
	return UiText.t("bonus.level_removals") % times
