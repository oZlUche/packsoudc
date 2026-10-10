## 改一条标准轴的层数（4.3「标准轴」，103 4e）：`delta` 带符号 —— 「加速 2 层」是 +2，「减速 1 层」是 −1，二者直接相抵。
##
## 能用轴表达的单位级增减（攻速、造成伤害、受到伤害、回血、耐力回复）一律走它，不再为「加速」「减速」各开一个 buff。
## 层数永续、战斗结束清空。和 [ApplyStatus] 并列
class_name ShiftAxis
extends CombatEffect

@export var target: Target = Target.SELF
## 哪条轴，见 [StatAxes]
@export var axis: StringName = &""
## 带符号的层数
@export var delta: int = 1
## 层数是否乘以来源 buff 的层数
@export var per_stack: bool = false


func apply(ctx: RuleContext) -> void:
	if delta == 0 or not StatAxes.has(axis):
		return
	var n := delta * (ctx.source_stacks() if per_stack else 1)
	for who in resolve_targets(ctx, target):
		shift(ctx.battle, who, axis, n, false)


## 改轴并记一条 axis_shifted。系统规则（加时）也走这里，`system = true` 记在系统层
static func shift(battle: BattleContext, who: CombatantRuntime, p_axis: StringName, n: int, system: bool) -> void:
	if who == null or who.dead or who.shift_axis(p_axis, n, system) == 0:
		return
	battle.emit(BattleEvent.AXIS_SHIFTED, who.side, {
		"axis": String(p_axis), "delta": n, "stacks": who.axis_stacks(p_axis),
		"system_stacks": who.axis_system(p_axis), "system": system,
	})


func describe() -> String:
	if not StatAxes.has(axis):
		return "改 %s ?" % axis
	return "%s%s %d 层" % ["使对手" if target == Target.OPPONENT else ("双方" if target == Target.BOTH else ""),
		StatAxes.name_of(axis, delta), absi(delta)]


## 151：估值 —— 层数 × 一层轴在那一边身上每秒值多少（[method PowerContext.axis_value]）× 平均待多久；给对手取反
func estimated_value(ctx: PowerContext) -> float:
	if axis == &"" or not StatAxes.has(axis):
		return NAN
	var n := delta * (ctx.stacks_or_assumed() if per_stack else 1.0)
	var stay := ctx.weights.expected_duration(0.0, true)
	var v := 0.0
	if target != Target.OPPONENT:
		v += n * ctx.for_carrier(true).axis_value(axis) * stay
	if target != Target.SELF:
		v -= n * ctx.for_carrier(false).axis_value(axis) * stay
	return v
