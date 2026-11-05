## 条件（282）：基地铺子 [member facility]（`smithy` 铁匠铺 / `market` 集市）到 [member level] 级。没有局外（沙盒）= 不满足
class_name FacilityAtLeast
extends EventCondition

@export var facility: StringName = &""
@export var level: int = 1


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.meta != null and ctx.meta.facility_level(facility) >= level


func describe() -> String:
	return UiText.t("cond.not_met")
