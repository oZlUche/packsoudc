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
## [b]留空时只认「会招致反应」的类型[/b]（[member DamageTypeDef.provokes]）——
## 也就是直接攻击。中毒、流血、反伤、流失都不在其列：
## 持续伤害每秒跳一次，若能招致反伤，一个中毒 buff 就把反伤刷成了主要输出；
## 反伤若能招致反伤，两件反伤道具会互相引燃。
##
## 想专门监听其中某一种，把本字段**显式**填成那个类型名即可 ——
## 写下类型名就表示作者知道自己在监听什么。这是留给联动效果的口子。
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
	elif not event.get_bool(&"provokes", true):
		return false
	return event.get_int(&"amount") >= StatMath.from_float(min_amount)
