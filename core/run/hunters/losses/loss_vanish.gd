## 输了猎手消失
class_name LossVanish
extends HunterLossOutcome


func apply(h: Hunter, sys: HunterSystem) -> void:
	sys.remove(h)


func describe() -> String:
	return "输了它消失"
