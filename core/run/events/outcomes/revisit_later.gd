## 后果：先回地图（作者 2026-10-12）—— 关掉这个事件、这个点不算用过；人走开再回来，同一个事件再弹一次。
## 给门禁事件当退路：条件没满足时玩家得能离开去准备（回上一个点拿东西），回来还得面对这一关，不能借此跳过
class_name RevisitLater
extends EventOutcome


func apply(ctx: EventContext) -> void:
	ctx.revisit = true


func describe() -> String:
	return "先回地图，回来再弹"
