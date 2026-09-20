## 受到／造成某类伤害时，且伤害不低于 N 点。
##
## 订阅专门的伤害事件而非 resource_changed —— 后者不带伤害类型，
## 也分不清「造成」与「受到」。
class_name OnDamage
extends Trigger

enum Direction {
	TAKEN,  ## 本方受到伤害
	DEALT,  ## 本方造成伤害
}

@export var direction: Direction = Direction.TAKEN
## 伤害类型；为空表示不限
@export var damage_type: StringName = &""
## 至少这么多点才算数（按实际扣除量，不是原始值）
@export var min_amount: float = 0.0


func subscribed_events() -> Array[StringName]:
	return [BattleEvent.DAMAGE] as Array[StringName]


func matches(ctx: RuleContext, event: BattleEvent) -> bool:
	# 伤害事件的 side 是【承受方】，source_side 是【施加方】
	var hit := event.side == ctx.owner.side
	var dealt := event.get_int(&"source_side") == ctx.owner.side
	match direction:
		Direction.TAKEN:
			if not hit:
				return false
		_:
			if not dealt or hit:
				return false  # 打到自己不算「造成伤害」
	if damage_type != &"" and event.get_name(&"type") != damage_type:
		return false
	return event.get_int(&"amount") >= StatMath.from_float(min_amount)
