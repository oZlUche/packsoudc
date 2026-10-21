## 置入一定价值的道具：从别的容器置入棋盘、价值（[ItemValue.of]）不低于 [member min_value] 的每件给 amount 点
class_name PlaceItemDeed
extends FaithDeed

@export var min_value: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	return amount if event == &"place_item" and int(payload.get("value", 0)) >= min_value else 0


func describe() -> String:
	return UiText.t("deed.place_item") % [min_value, amount]
