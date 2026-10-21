## 受到／造成某类伤害之后。
##
## 订阅专门的伤害事件而非 resource_changed —— 后者不带伤害类型，
## 也分不清「我打了人」与「我挨了打」。
##
## 结算已经完成，此时改不了这一下的伤害；要减伤请用 [OnBeforeDamage]。
class_name OnDamage
extends DamageTrigger

## 132：只在这一包是暴击时（104 的 `crit` 旗）。只对「造成」有意义 —— 配「受到」导入器给警告
@export var crit_only: bool = false


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.DAMAGE] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	return (not crit_only or event.get_bool(&"crit")) and super.matches(ctx, event)


func _phase() -> int:
	return PHASE_CRIT if crit_only else PHASE_ON


## 151：只认暴击的再乘假定暴击率
func estimated_rate(ctx: PowerContext, cadence_hz: float) -> float:
	var rate := super.estimated_rate(ctx, cadence_hz)
	return rate * ctx.weights.crit_rate if crit_only else rate
