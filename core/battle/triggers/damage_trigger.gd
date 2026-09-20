## 伤害相关扳机的共同部分：方向、类型、点数门槛。
##
## [OnDamage]（受伤后）与 [OnBeforeDamage]（受伤前）只差订阅哪条事件，
## 筛选逻辑完全相同，因此提到这里。
@abstract
class_name DamageTrigger
extends Trigger

enum Direction {
	TAKEN,  ## 本方承受
	DEALT,  ## 本方施加
}

@export var direction: Direction = Direction.TAKEN

## 伤害类型；留空表示不限。
##
## [b]留空时只认「会通知」的类型[/b] —— 流失（自伤、以血为代价）不会点亮
## 反伤与吸血，否则割自己一刀就成了正收益。
## 想专门监听流失，把本字段显式填成 [constant DamageTypes.DRAIN] 即可，
## 这是留给未来联动效果的口子。
@export var damage_type: StringName = &""

## 至少这么多点才算数。按**实际扣除量**判定，不是原始值 ——
## 被护盾全吸收掉的一下不该点亮反伤。
@export var min_amount: float = 0.0


## 伤害事件的 side 是【承受方】，source_side 是【施加方】
func matches_damage(ctx: RuleContext, event: BattleEvent) -> bool:
	var hit := event.side == ctx.owner.side
	var dealt := event.get_int(&"source_side") == ctx.owner.side
	match direction:
		Direction.TAKEN:
			if not hit:
				return false
		_:
			if not dealt or hit:
				return false  # 打到自己不算「造成伤害」
	if damage_type != &"":
		if event.get_name(&"type") != damage_type:
			return false
	elif not event.get_bool(&"notifies", true):
		return false
	return event.get_int(&"amount") >= StatMath.from_float(min_amount)
