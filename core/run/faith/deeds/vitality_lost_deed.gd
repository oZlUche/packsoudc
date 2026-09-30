## 失去体力（093 表：蛮神「失去量 × 50」）：地图上每掉一点体力给 multiplier 点
class_name VitalityLostDeed
extends FaithDeed

@export var multiplier: float = 50.0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"vitality_change":
		return 0
	var delta := int(payload.get("delta", 0))
	return roundi(float(-delta) * multiplier) if delta < 0 else 0


func describe() -> String:
	return "每失去 1 点体力 +%.2g" % multiplier
