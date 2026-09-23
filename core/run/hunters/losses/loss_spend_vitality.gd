## 输了扣体力
class_name LossSpendVitality
extends HunterLossOutcome

@export var amount: int = 1


func apply(_h: Hunter, sys: HunterSystem) -> void:
	sys.spend_vitality(amount)


func describe() -> String:
	return "输了体力 -%d" % amount
