## 战场上一个 buff 的实际存在：层数与剩余时长。
class_name BuffInstance
extends RefCounted

var def: BuffDef
var stacks: int = 1
## 到期时刻（定点秒）。-1 表示持续到战斗结束。
## 记绝对时刻而不是倒计时 —— 事件驱动的模拟直接把它排进时间轮，
## 不需要每帧去减。
var expires_at: int = -1


static func create(p_def: BuffDef, p_stacks: int = 1, now: int = 0) -> BuffInstance:
	var b := BuffInstance.new()
	b.def = p_def
	b.stacks = maxi(1, p_stacks)
	b.refresh(now)
	return b


func is_permanent() -> bool:
	return expires_at < 0


func is_expired_at(t: int) -> bool:
	return not is_permanent() and t >= expires_at


func refresh(now: int) -> void:
	if def.duration_sec > 0.0:
		expires_at = now + StatMath.from_float(def.duration_sec)
	else:
		expires_at = -1


## 返回实际增加的层数（受 max_stacks 限制）
func add_stacks(n: int, now: int = 0) -> int:
	if n <= 0:
		return 0
	var before := stacks
	stacks += n
	if def.max_stacks > 0:
		stacks = mini(stacks, def.max_stacks)
	if def.refresh_on_restack:
		refresh(now)
	return stacks - before
