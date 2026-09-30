## 道具成功循环（093 表：日神「每次道具成功循环结算 +2」）：一场里每一次**真的出手**（没因为耐力 / 资源不足跳过）给 amount 点；[member cap] 一场上限
class_name ItemCycleDeed
extends FaithDeed

## 一场战斗最多给几点；0 = 不限
@export var cap: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle":
		return 0
	var got := amount * int(payload.get("fired_total", 0))
	return mini(got, cap) if cap > 0 else got


func describe() -> String:
	return "道具每成功出手一次 +%d%s" % [amount, ("（每场最多 %d）" % cap) if cap > 0 else ""]
