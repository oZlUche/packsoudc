## 全场最多执行一次。
class_name OncePerBattle
extends Cadence

const KEY := &"used"

func can_fire(ctx: RuleContext) -> bool:
	return not bool(ctx.state().get(KEY, false))

func commit(ctx: RuleContext) -> void:
	ctx.state()[KEY] = true
