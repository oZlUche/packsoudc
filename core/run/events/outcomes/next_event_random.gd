## 后果（093）：从几个事件里按权重随机接一个（「触发信仰」：靠近祭坛之后随机撞上一位神）。随机数是这个点的，同一局同一点永远同一个
class_name NextEventRandom
extends EventOutcome

## 事件 id → 权重
@export var events: Dictionary = {}


func apply(ctx: EventContext) -> void:
	if events.is_empty():
		return
	var keys: Array = events.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += maxf(0.0, float(events[k]))
	if total <= 0.0:
		return
	var roll := (ctx.rng.randf() if ctx != null and ctx.rng != null else 0.0) * total
	var pick: String = String(keys[-1])
	for k in keys:
		roll -= maxf(0.0, float(events[k]))
		if roll <= 0.0:
			pick = String(k)
			break
	ctx.next_event = StringName(pick)


func describe() -> String:
	return "随机接一个事件（%s）" % "、".join(PackedStringArray(events.keys()))
