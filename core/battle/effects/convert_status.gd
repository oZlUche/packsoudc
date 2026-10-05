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
			var removed := who.remove_buff_stacks(from, have)
			if removed > 0:
				ctx.battle.emit(BattleEvent.STATUS_UNSTACKED, who.side, {
					"buff": String(from), "delta": -removed, "stacks": who.stacks_of(from), "reason": "converted",
				})
		ApplyStatus.give(ctx, who, to, n)


func describe() -> String:
	if to == null:
		return "转化 ?"
	return "%s转为%s" % [DamageTypes.name_of(from), Names.of(to)]
