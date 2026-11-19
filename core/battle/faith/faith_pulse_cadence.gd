## 信仰重构 D：信仰机制的节拍 —— 事件来了总放行（同 always），另外从 [member first_sec] 起每 [member every_sec] 秒自发一次
## （自发那一下 [member RuleContext.event] 是空的）。节拍按战斗时间轴的整格排，不随出手漂移；配 [member FaithMechanicTrigger.pulse]
class_name FaithPulseCadence
extends Cadence

@export var every_sec: float = 6.0
@export var first_sec: float = 6.0


func next_time(_ctx: RuleContext, now: int) -> int:
	var every := StatMath.from_float(every_sec)
	var first := StatMath.from_float(first_sec)
	if every <= 0:
		return NEVER
	if now < first:
		return first
	@warning_ignore("integer_division")
	return first + ((now - first) / every + 1) * every


func can_fire(_ctx: RuleContext, _now: int) -> bool:
	return true


func commit(_ctx: RuleContext, _now: int) -> void:
	pass
