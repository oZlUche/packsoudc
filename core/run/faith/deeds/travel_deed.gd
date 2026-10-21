## 移动一定距离：每走满 [member every_steps] 步给 amount 点（看总步数）
class_name TravelDeed
extends FaithDeed

@export var every_steps: int = 1


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"travel":
		return 0
	var every := maxi(1, every_steps)
	return amount if int(payload.get("steps", 0)) % every == 0 else 0


func describe() -> String:
	return UiText.t("deed.travel") % [maxi(1, every_steps), amount]
