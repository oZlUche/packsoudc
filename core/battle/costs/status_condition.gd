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


## 142：「若对手有流血」「若你流血至少 3 层」「若对手没有流血」
func describe() -> String:
	var s := Glossary.status_name(buff_id)
	if negate:
		if stacks <= 1:
			return UiText.t("cost.status_self_none" if on_self else "cost.status_opp_none") % s
		return UiText.t("cost.status_self_below" if on_self else "cost.status_opp_below") % [s, stacks]
	if stacks <= 1:
		return UiText.t("cost.status_self_has" if on_self else "cost.status_opp_has") % s
	return UiText.t("cost.status_self_min" if on_self else "cost.status_opp_min") % [s, stacks]


## 151：条件满足的概率（取反 = 一减它）
func estimated_factor(ctx: PowerContext, _rate: float) -> float:
	var p := ctx.weights.condition_factor
	return 1.0 - p if negate else p


func is_condition() -> bool:
	return true
