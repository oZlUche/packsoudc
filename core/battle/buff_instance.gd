## 战场上一个 buff 的实际存在：层数与剩余时长。
class_name BuffInstance
extends RefCounted

var def: BuffDef
var stacks: int = 1
## 到期时刻（定点秒）。-1 表示持续到战斗结束。
## 记绝对时刻而不是倒计时 —— 事件驱动的模拟直接把它排进时间轮，
## 不需要每帧去减。
var expires_at: int = -1
## 175 补充四：保底层数（凝毒 / 冻疮，[GuardStatus]）—— 移除、反应消耗、两种衰减都不会把层数压到它以下；
## 反应选印、算 N 时照常数全部层数（「纳入计算但不真正减少」）。0 = 没有保底
var guard: int = 0
## 175 补充四：按层计时的剩余秒数（[member BuffDef.seconds_per_stack]；每叠一层加那么多秒，[StatusDecay] 每秒减一）
var seconds_left: int = 0


static func create(p_def: BuffDef, p_stacks: int = 1, now: int = 0) -> BuffInstance:
	var b := BuffInstance.new()
	b.def = p_def
	b.stacks = p_def.capped(maxi(1, p_stacks))
	b.seconds_left = b.stacks * maxi(0, p_def.seconds_per_stack)
	b.refresh(now)
	return b


func is_permanent() -> bool:
	return expires_at < 0


func is_expired_at(t: int) -> bool:
	return not is_permanent() and t >= expires_at


func refresh(now: int) -> void:
	if not def.is_permanent():
		expires_at = now + StatMath.from_float(def.duration_sec)
	else:
		expires_at = -1


## 返回实际增加的层数。137：可叠层不封顶（175 补充四：五种印也不封顶）；不可叠层固定一层
func add_stacks(n: int, now: int = 0) -> int:
	if n <= 0:
		return 0
	var before := stacks
	stacks = def.capped(stacks + n)
	seconds_left += (stacks - before) * maxi(0, def.seconds_per_stack)     # 175 补充四：再叠就延长
	if def.refresh_on_restack:
		refresh(now)
	return stacks - before


## 175 补充四：最多能拿掉几层（保底以上的部分）
func removable() -> int:
	return maxi(0, stacks - guard)
