## 输了什么都不发生（猎手留在原地，下一步可能再打）
class_name LossNothing
extends HunterLossOutcome


func apply(_h: Hunter, _sys: HunterSystem) -> void:
	pass


func describe() -> String:
	return "输了没事"
