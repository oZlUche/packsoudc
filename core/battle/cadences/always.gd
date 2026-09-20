## 每次命中都执行。
class_name Always
extends Cadence

func can_fire(_ctx: RuleContext) -> bool:
	return true

func commit(_ctx: RuleContext) -> void:
	pass
