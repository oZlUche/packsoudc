## 减少增益／减益的层数。
##
## 「净化」「驱散」「削减对手的蓄力」都用它。[member stacks] 为 0 表示**全部移除**。
class_name RemoveStatus
extends CombatEffect

@export var target: Target = Target.SELF
@export var buff_id: StringName = &""
## 移除几层；0 = 全部
@export var stacks: int = 1


func apply(ctx: RuleContext) -> void:
	if buff_id == &"":
		return
	for who in resolve_targets(ctx, target):
		var have := who.stacks_of(buff_id)
		if have <= 0:
			continue
		var n := have if stacks <= 0 else mini(stacks, have)
		var removed := who.remove_buff_stacks(buff_id, n)
		if removed > 0:
			ctx.battle.emit(BattleEvent.STATUS_UNSTACKED, who.side, {
				"buff": String(buff_id), "delta": -removed,
				"stacks": who.stacks_of(buff_id), "reason": "removed",
			})


func describe() -> String:
	return "移除 %s %s 层" % [buff_id, "全部" if stacks <= 0 else str(stacks)]
