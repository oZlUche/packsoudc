## 开战瞬间命中一次。
class_name OnBattleStart
extends Trigger

func subscribed_events() -> Array[StringName]:
	return [BattleEvent.BATTLE_START] as Array[StringName]

func matches(_ctx: RuleContext, _event: BattleEvent) -> bool:
	return true


func describe() -> String:
	return "开战时"
