## 消耗 N 层某个增益。
##
## 「消耗 3 层蓄力，打出一次重击」用它表达。非武器道具通常没有消耗，
## 但检查环节一律保留，正是为了这类效果。
class_name StatusStackCost
extends Cost

@export var buff_id: StringName = &""
@export var stacks: int = 1
## 130：扣自己身上的（默认）还是对手身上的（「对手攒够六层流血就放血一刀」）
@export var on_self: bool = true


func can_pay(ctx: RuleContext) -> bool:
	var who := ctx.side_of(on_self)
	if who == null:
		return false
	var inst := who.find_buff(buff_id)
	if inst != null and inst.def.system:
		return false     # 103：系统效果不可解除，也就不能拿来当消耗
	return who.stacks_of(buff_id) >= maxi(1, stacks)


func pay(ctx: RuleContext) -> void:
	RemoveStatus.take(ctx, ctx.side_of(on_self), buff_id, maxi(1, stacks))


func describe() -> String:
	return "消耗%s %d 层%s" % ["你" if on_self else "对手", maxi(1, stacks), Glossary.status_name(buff_id)]


## 151：吃层打折（吃掉的层本身有价值）
func estimated_factor(ctx: PowerContext, _rate: float) -> float:
	return ctx.weights.stack_cost_factor
