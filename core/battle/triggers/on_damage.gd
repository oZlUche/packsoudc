## 受到／造成某类伤害之后。
##
## 订阅专门的伤害事件而非 resource_changed —— 后者不带伤害类型，
## 也分不清「我打了人」与「我挨了打」。
##
## 结算已经完成，此时改不了这一下的伤害；要减伤请用 [OnBeforeDamage]。
class_name OnDamage
extends DamageTrigger


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.DAMAGE] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	return matches_damage(ctx, event)
