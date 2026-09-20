## 消耗 N 层某个增益。
##
## 「消耗 3 层蓄力，打出一次重击」用它表达。非武器道具通常没有消耗，
## 但检查环节一律保留，正是为了这类效果。
class_name StatusStackCost
extends Cost

@export var buff_id: StringName = &""
@export var stacks: int = 1


func can_pay(ctx: RuleContext) -> bool:
	return ctx.owner.stacks_of(buff_id) >= maxi(1, stacks)


func pay(ctx: RuleContext) -> void:
	var removed := ctx.owner.remove_buff_stacks(buff_id, maxi(1, stacks))
	if removed > 0:
		ctx.emit(BattleEvent.STATUS_UNSTACKED, {
			"buff": String(buff_id), "delta": -removed,
			"stacks": ctx.owner.stacks_of(buff_id),
		})


func describe(_ctx: RuleContext) -> String:
	return "%s ×%d" % [buff_id, stacks]
