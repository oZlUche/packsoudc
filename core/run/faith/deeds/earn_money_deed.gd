## 获得金币：每进账 [member per_amount] 币给 amount 点（一笔进账按整除算）
class_name EarnMoneyDeed
extends FaithDeed

@export var per_amount: int = 10


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"earn_money":
		return 0
	@warning_ignore("integer_division")
	return amount * (int(payload.get("amount", 0)) / maxi(1, per_amount))


func describe() -> String:
	return "每进账 %d 币 +%d" % [maxi(1, per_amount), amount]
