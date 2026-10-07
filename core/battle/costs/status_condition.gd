## 状态条件（130）：目标身上至少有这么多层才放行，**不扣层**。
##
## 和 [ChanceCondition] 一样是「条件型消耗」：失败行为和消耗一致（跳过效果、冷却照走），所以同层。
## 「对流血目标普攻 +20%」用它；要扣层用 [StatusStackCost]
class_name StatusCondition
extends Cost

@export var buff_id: StringName = &""
## 看自己身上（true）还是对手身上（false）
@export var on_self: bool = false
@export var stacks: int = 1
## 132：取反 —— 「对手**没有**流血时」
@export var negate: bool = false


func can_pay(ctx: RuleContext) -> bool:
	if buff_id == &"":
		return false
	var who := ctx.side_of(on_self)
	var ok := who != null and who.stacks_of(buff_id) >= maxi(1, stacks)
	return ok != negate


func pay(_ctx: RuleContext) -> void:
	pass


func describe(_ctx: RuleContext) -> String:
	return "%s%s %s %d" % ["自己" if on_self else "对手", DamageTypes.name_of(buff_id), "<" if negate else "≥", maxi(1, stacks)]
