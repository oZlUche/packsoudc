## 转化状态（130）：把目标身上 [member from] 的全部层数换成 [member to] × [member ratio]。
##
## `remove_status` + `apply_status(per_stack)` 拼不出来：per_stack 读的是**来源 buff** 的层数，不是目标身上另一个 buff 的。
## 换算层数四舍五入、至少 1；[member keep_from] 勾上就只加不减（「复制」）。系统 buff（103）不可转。
## 加上去的那部分照常发 status_stacked / status_applied（施加方 = 本规则的主人），扣掉的发 status_unstacked
class_name ConvertStatus
extends CombatEffect

@export var target: Target = Target.OPPONENT
@export var from: StringName = &""
@export var to: BuffDef
@export var ratio: float = 1.0
@export var keep_from: bool = false


func apply(ctx: RuleContext) -> void:
	if from == &"" or to == null or to.id == from:
		return
	for who in resolve_targets(ctx, target):
		var inst := who.find_buff(from)
		if inst == null or inst.def.system or inst.stacks <= 0:
			continue
		var have := inst.stacks
		var n := maxi(1, roundi(float(have) * ratio))
		if not keep_from:
			RemoveStatus.take(ctx, who, from, have, "converted")
		ApplyStatus.give(ctx, who, to, n)


func describe() -> String:
	if to == null:
		return "转化 ?"
	return "%s转为%s" % [DamageTypes.name_of(from), Names.of(to)]


## 151：估值 —— 拿掉 [member from] 的那几层（勾了「复制」就不拿）+ 换上 [member to] × 比例；层数按估算上下文假定
func estimated_value(ctx: PowerContext) -> float:
	if to == null:
		return NAN
	var n := ctx.stacks_or_assumed()
	var from_def := ctx.buff(from)
	if from_def == null and not keep_from:
		return NAN
	var v := 0.0
	for on_owner in [true, false]:
		if (on_owner and target == Target.OPPONENT) or (not on_owner and target == Target.SELF):
			continue
		var carrier := ctx.for_carrier(on_owner)
		var change := n * ratio * to.stack_value(carrier)
		if not keep_from:
			change -= n * from_def.stack_value(carrier)
		v += change if on_owner else -change
	return v
