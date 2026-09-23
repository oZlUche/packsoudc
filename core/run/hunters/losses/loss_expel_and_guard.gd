## 输了玩家被赶回上一个点，猎手驻守原地（此后不动）
class_name LossExpelAndGuard
extends HunterLossOutcome


func apply(h: Hunter, sys: HunterSystem) -> void:
	sys.expel_player()
	h.guarding = true


func describe() -> String:
	return "输了被赶回上一个点，它驻守"
