## 恢复生命（093 表：自然之神「恢复量 × 1」）：只算**战斗内**的回血（作者定），量 × multiplier；[member cap] 一场上限
class_name HealDeed
extends FaithDeed

@export var multiplier: float = 1.0
@export var cap: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle":
		return 0
	var got := roundi(float(payload.get("healed", 0.0)) * multiplier)
	return mini(got, cap) if cap > 0 else got


func describe() -> String:
	return UiText.t("deed.heal") % [TextTemplate.num(multiplier), (UiText.t("deed.cap") % cap) if cap > 0 else ""]
