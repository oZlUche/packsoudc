## 388 第 2 批：日神的节拍 —— 事件来了总放行；自发的那一下排在日夜时间轴的下一个结算点（阶段起止、残阳 / 斜月的尾巴、下一整秒，[method SunCycle.next_boundary]）。
## 时间轴只看时刻，所以排好的时刻不会失效
class_name SunCadence
extends Cadence

var effect: SunCycle = null


func next_time(_ctx: RuleContext, now: int) -> int:
	return effect.next_boundary(now) if effect != null else NEVER


func can_fire(_ctx: RuleContext, _now: int) -> bool:
	return true


func commit(_ctx: RuleContext, _now: int) -> void:
	pass
