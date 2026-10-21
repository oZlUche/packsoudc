## 标准轴条件（132）：某条轴（4.3）至少几层才放行，**不扣**。
##
## [member stacks] 可以为负：按绝对值比、同号 —— 3 = 「至少 3 层加速」，−2 = 「至少 2 层减速」。看的是合计层数（内容层 + 系统层）
class_name AxisCondition
extends Cost

@export var axis: StringName = &""
## 看自己（true）还是对手（false）
@export var on_self: bool = true
@export var stacks: int = 1
## 取反
@export var negate: bool = false


func can_pay(ctx: RuleContext) -> bool:
	var who := ctx.side_of(on_self)
	if who == null or axis == &"" or stacks == 0:
		return negate
	var have := who.axis_total(axis)
	var ok := have >= stacks if stacks > 0 else have <= stacks
	return ok != negate


func pay(_ctx: RuleContext) -> void:
	pass


func describe() -> String:
	var n := absi(stacks) if stacks != 0 else 1
	var key := ("cost.axis_self_below" if negate else "cost.axis_self_min") if on_self else ("cost.axis_opp_below" if negate else "cost.axis_opp_min")
	return UiText.t(key) % [StatAxes.name_of(axis, stacks), n]


## 151：条件满足的概率（取反 = 一减它）
func estimated_factor(ctx: PowerContext, _rate: float) -> float:
	var p := ctx.weights.condition_factor
	return 1.0 - p if negate else p


func is_condition() -> bool:
	return true
