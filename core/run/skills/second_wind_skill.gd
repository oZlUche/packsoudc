## 咬牙（136，布鲁图斯）：地图上用，恢复 [member amount] 点体力。体力是满的不能用（不扣次数）
class_name SecondWindSkill
extends RunSkill

@export var amount: int = 1


func is_active() -> bool:
	return true


func activate(run: RunState) -> String:
	if run == null or run.vitality == null:
		return "没有体力"
	if run.vitality.current >= run.vitality.maximum:
		return "体力是满的"
	run.vitality.restore(amount, &"skill")
	return ""


func describe() -> String:
	return "恢复 %d 点体力" % amount
