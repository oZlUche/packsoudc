## 每命中 N 次执行一次。
##
## 「每 3 次攻击附带一次爆发」= [OnItemFired] + EveryNth(3)，不需要新写触发器。
class_name EveryNth
extends Cadence

const KEY := &"hit_count"

@export var n: int = 3


## 命中即计数，无论本次是否执行 —— 否则计数永远停在 0
func on_match(ctx: RuleContext) -> void:
	ctx.state()[KEY] = int(ctx.state().get(KEY, 0)) + 1


func can_fire(ctx: RuleContext) -> bool:
	return int(ctx.state().get(KEY, 0)) >= maxi(1, n)


func commit(ctx: RuleContext) -> void:
	ctx.state()[KEY] = 0
