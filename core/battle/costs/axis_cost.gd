## 扣自己的轴层数（132）：[ShiftAxis] 的消耗面 —— 「消耗 2 层加速，打出一击」。
##
## **不检查够不够**：扣到负也允许（「透支」）。要「有才扣」就在它前面放一条 [AxisCondition]。
## 只动内容层（系统层是加时这类系统规则的，不拿来付账）
class_name AxisCost
extends Cost

@export var axis: StringName = &""
@export var stacks: int = 1


func can_pay(_ctx: RuleContext) -> bool:
	return axis != &""


func pay(ctx: RuleContext) -> void:
	if stacks != 0:
		ShiftAxis.shift(ctx.battle, ctx.owner, axis, -stacks, false)


func describe() -> String:
	return "消耗你 %d 层%s" % [absi(stacks), StatAxes.name_of(axis, stacks)]
