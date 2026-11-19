## 信仰重构 C / D：信仰机制的扳机 —— 订阅几条事件、全都放行，由配套的效果（[SkillMomentum] 这类）按事件名自己分流。
## 一条规则 = 一份状态（[method RuleContext.state]），一位神的整套战斗机制住在一条规则里，就不用跨规则传数。
## [member pulse]：另外按节拍自发（频率层用 [FaithPulseCadence]），日神的窗口、自然的周期治疗靠它
class_name FaithMechanicTrigger
extends Trigger

@export var events: Array[StringName] = []
@export var pulse: bool = false


func subscribed_events() -> Array[StringName]:
	return events


func matches(_ctx: RuleContext, _event: BattleEvent) -> bool:
	return true


func is_self_driven() -> bool:
	return pulse


func describe() -> String:
	return ""
