## 输了猎手离开：往离玩家远的方向走几步，并歇几步不再追
class_name LossRetreat
extends HunterLossOutcome

@export var steps: int = 2
@export var cooldown: int = 2


func apply(h: Hunter, sys: HunterSystem) -> void:
	sys.retreat(h, steps, cooldown)


func describe() -> String:
	return "输了它退 %d 步、歇 %d 步" % [steps, cooldown]
