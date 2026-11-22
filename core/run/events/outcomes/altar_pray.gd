## 后果（372，作者 18:30）：在神坛前祷告 —— 给一点经验值，不耗道具，奉不奉神都能做；每座神坛有次数（[LevelModule.pray]）。
## 行动点另配一条 `pass_time` 扣（作者：占一次行动计时）
class_name AltarPray
extends EventOutcome


func apply(ctx: EventContext) -> void:
	if ctx.node != null:
		ctx.xp_gained += ctx.hooks.level_pray(ctx.node)


func describe() -> String:
	return UiText.t("event.pray")
