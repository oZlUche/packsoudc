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
	var who := "你" if on_self else "对手"
	var n := absi(stacks) if stacks != 0 else 1
	return "若%s的%s%s %d 层" % [who, StatAxes.name_of(axis, stacks), "不到" if negate else "至少", n]
