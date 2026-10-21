## 175 补充四：按层计时的倒数（[member BuffDef.seconds_per_stack] 的那条规则，[method BuffDef.decay_rule] 在代码里造，不是内容）。
## 每秒一次：来源 buff 的剩余秒数减一，到 0 整个移除（status_unstacked，reason `expired`）
class_name StatusDecay
extends CombatEffect


func apply(ctx: RuleContext) -> void:
	var inst := ctx.source_buff()
	if inst == null:
		return
	inst.seconds_left -= 1
	if inst.seconds_left <= 0:
		ctx.owner.decay_buff(ctx.battle, inst, 0, "expired")


func describe() -> String:
	return UiText.t("fx.decay")
