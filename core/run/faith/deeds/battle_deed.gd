## 进行战斗：每打一场给 amount 点；[member won_only] = 只算打赢的
class_name BattleDeed
extends FaithDeed

@export var won_only: bool = false


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle":
		return 0
	return amount if bool(payload.get("won", false)) or not won_only else 0


func describe() -> String:
	return ("打赢一场 +%d" if won_only else "打一场 +%d") % amount
