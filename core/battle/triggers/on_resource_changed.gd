## 资源变动时命中。生命、耐力、法力共用一条事件，靠这里的条件筛选。
##
## 「受到伤害时反击」= resource_key = hp、direction = DECREASE、same_side = true。
class_name OnResourceChanged
extends Trigger

enum Direction { ANY, INCREASE, DECREASE }

@export var resource_key: StringName = &"hp"
@export var direction: Direction = Direction.DECREASE
@export var same_side: bool = true
## 只在指定原因时命中；为空表示不限。
## 例如只想听真实伤害而不想听「上限变动连带的当前值变化」，就填 damage。
@export var reasons: Array[StringName] = []


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.RESOURCE_CHANGED] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	if not ctx.event_on(event, same_side):
		return false
	if resource_key != &"" and event.get_name(&"key") != resource_key:
		return false
	var delta := event.get_int(&"delta")
	match direction:
		Direction.INCREASE:
			if delta <= 0:
				return false
		Direction.DECREASE:
			if delta >= 0:
				return false
		_:
			pass
	if not reasons.is_empty() and not reasons.has(event.get_name(&"reason")):
		return false
	return true
