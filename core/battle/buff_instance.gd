## 战场上一个 buff 的实际存在：层数与剩余时长。
class_name BuffInstance
extends RefCounted

var def: BuffDef
var stacks: int = 1
## 剩余帧数；def.duration_ticks 为 0 时恒为 -1，表示持续到战斗结束
var remaining: int = -1


static func create(p_def: BuffDef, p_stacks: int = 1) -> BuffInstance:
	var b := BuffInstance.new()
	b.def = p_def
	b.stacks = maxi(1, p_stacks)
	b.remaining = p_def.duration_ticks if p_def.duration_ticks > 0 else -1
	return b


func is_permanent() -> bool:
	return remaining < 0


func is_expired() -> bool:
	return remaining == 0


func refresh() -> void:
	if def.duration_ticks > 0:
		remaining = def.duration_ticks


## 返回实际增加的层数（受 max_stacks 限制）
func add_stacks(n: int) -> int:
	if n <= 0:
		return 0
	var before := stacks
	stacks += n
	if def.max_stacks > 0:
		stacks = mini(stacks, def.max_stacks)
	if def.refresh_on_restack:
		refresh()
	return stacks - before
