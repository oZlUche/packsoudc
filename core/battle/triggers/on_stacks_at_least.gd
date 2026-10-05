## 拥有 N 层某增益／减益时。
##
## **状态条件型扳机**：条件在层数变化的那一刻被求值。
##
## [b]消耗型 vs 激活型[/b]由 [member consume] 区分：
## 勾上即为消耗型，本扳机会向规则**隐式追加**一条 [StatusStackCost]。
##
## 为什么不在扳机里直接扣层数：`matches()` 必须只读，而消耗必须发生在
## 频率与其他条件都通过之后 —— 否则「攒够 3 层但耐力不够」会把 3 层白吃掉。
## 作者只填一个勾选框，四层结构不破。
class_name OnStacksAtLeast
extends Trigger

@export var buff_id: StringName = &""
@export var stacks: int = 3
## 自己身上的层数还是对手身上的
@export var on_self: bool = true
## 消耗型：触发后扣掉这些层数
@export var consume: bool = false


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.STATUS_STACKED, BattleEvent.STATUS_UNSTACKED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if event.get_name(&"buff") != buff_id:
		return false
	var who := ctx.owner if on_self else ctx.opponent()
	if (event.side == ctx.owner.side) != on_self:
		return false
	return who.stacks_of(buff_id) >= maxi(1, stacks)


func implied_costs() -> Array[Cost]:
	if not consume:
		return [] as Array[Cost]
	var c := StatusStackCost.new()
	c.buff_id = buff_id
	c.stacks = maxi(1, stacks)
	c.on_self = on_self     # 130：对手身上的也能吃（放血刀）
	return [c] as Array[Cost]
