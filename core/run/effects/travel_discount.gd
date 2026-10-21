## 熟门熟路（136，安德烈乌斯）：地图上每走 [member every] 步，下一步不花行动点。[MapTravel] 读 RunContext.free_step_every 记步
class_name TravelDiscount
extends RunEffect

@export var every: int = 4


func modify(ctx: RunContext) -> void:
	if every <= 0:
		return
	ctx.free_step_every = every if ctx.free_step_every <= 0 else mini(ctx.free_step_every, every)


func describe() -> String:
	return UiText.t("bonus.travel_discount") % every
