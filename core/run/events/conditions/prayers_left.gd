## 条件（372）：这座神坛还能祷告（每座有次数，[LevelModule.prayers_left]）。没装局内成长 = 不满足
class_name PrayersLeft
extends EventCondition


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.node != null and ctx.hooks.level_prayers_left(ctx.node) > 0


func describe() -> String:
	return UiText.t("cond.prayers_used")
