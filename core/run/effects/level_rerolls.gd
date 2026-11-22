## 372（作者 18:15）：局内升级选牌时「刷新」（三张一起换一批）的次数 —— 局外机制树的科技给，一局用完为止（[LevelModule]）
class_name LevelRerolls
extends RunEffect

@export var times: int = 1


func modify(ctx: RunContext) -> void:
	ctx.level_rerolls += maxi(0, times)


func describe() -> String:
	return UiText.t("bonus.level_rerolls") % times
