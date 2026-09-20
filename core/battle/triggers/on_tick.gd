## 每逻辑帧都命中。配合 [CooldownCadence] 即为「按冷却自动出手」。
class_name OnTick
extends Trigger

func subscribed_events() -> Array[StringName]:
	return [BattleEvent.TICK] as Array[StringName]

func matches(_ctx: RuleContext, _event: BattleEvent) -> bool:
	return true
