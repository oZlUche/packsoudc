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
## 175 补充四（激荡）：这条轴「满」了之后，多出来的层数改加到这条轴上（`crit_chance` → `crit_damage`）；空 = 不溢出。
## 「满」= 这个单位所有武器里最终暴击率最高的那把到 100%（待定 补 4.3 A；没有武器看单位自己的）
@export var overflow_to: StringName = &""


func apply(ctx: RuleContext) -> void:
	if delta == 0 or not StatAxes.has(axis):
		return
	var n := delta * (ctx.source_stacks() if per_stack else 1)
	for who in resolve_targets(ctx, target):
		var spill := 0
		if overflow_to != &"" and StatAxes.has(overflow_to) and n > 0:
			spill = maxi(0, n - room(who, axis))
		if n - spill != 0:
			shift(ctx.battle, who, axis, n - spill, false)
		if spill > 0:
			shift(ctx.battle, who, overflow_to, spill, false)


## 175 补充四：[param who] 的 [param p_axis] 还能加几层才满（属性到 100%）—— 按道具的轴看武器里最高的那把，否则看单位自己的
static func room(who: CombatantRuntime, p_axis: StringName) -> int:
	var stat := StatAxes.stat_of(p_axis)
	var step := StatMath.from_float(StatAxes.step_of(p_axis))
	if stat == &"" or step <= 0:
		return 1 << 30
	var fallback := BattleStats.default_base(stat)
	var best := -1
	if StatAxes.on_items(p_axis):
		for uid in who.item_base:
			if who.tags_of(uid).has(&"weapon"):
				best = maxi(best, who.item_stat(uid, stat, fallback))
	if best < 0:
		best = who.stat(stat, fallback)
	var left := StatMath.ONE - best
	return 0 if left <= 0 else ceili(float(left) / float(step))


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
		return UiText.t("fx.axis_unknown") % axis
	var key := "fx.axis_opp" if target == Target.OPPONENT else ("fx.axis_both" if target == Target.BOTH else "fx.axis_self")
	var head := UiText.t(key) % [StatAxes.name_of(axis, delta), absi(delta)]
	if overflow_to != &"" and StatAxes.has(overflow_to):
		head += UiText.t("fx.axis_overflow") % [StatAxes.what_of(axis), StatAxes.name_of(overflow_to, 1)]
	return head


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
