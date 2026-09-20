## 造成伤害。
class_name DealDamage
extends CombatEffect

@export var target: Target = Target.OPPONENT

## 伤害类型。用于抗性、元素联动、以及「受到火焰伤害时」这类扳机。
##
## [b]刻意不与乘区绑定。[/b] 火焰伤害吃不吃 FIRE 乘区由效果自己声明
## （写在对应物品的属性上），否则伤害类型与乘区被迫一一对应，
## 以后想加「不吃任何元素加成的真实伤害」就没法表达。
@export var damage_type: StringName = &"physical"

## 固定伤害值；damage_stat 非空时改用属性值
@export var amount: float = 0.0
## 从属性表取伤害，通常是 damage
@export var damage_stat: StringName = &"damage"
## 伤害是否乘以来源 buff 的层数。「灼烧每层 2 点」用它
@export var per_stack: bool = false


func apply(ctx: RuleContext) -> void:
	var raw := StatMath.from_float(amount)
	if damage_stat != &"":
		var from_stats := ctx.item_stat(damage_stat, -1)
		if from_stats >= 0:
			raw = from_stats
	if per_stack:
		raw *= ctx.source_stacks()
	if raw <= 0:
		return

	for victim in resolve_targets(ctx, target):
		# 护甲按定点值减伤，下限 0
		var armor := victim.stat(BattleStats.ARMOR, 0)
		var dealt := maxi(0, raw - armor)
		var actual := victim.resources.change(
			BattleStats.RES_HP, -dealt, BattleEvent.REASON_DAMAGE
		)
		# 专门的伤害事件：携带类型与原始／实际两个数值。
		# resource_changed 记的是「实际掉了多少血」，不带类型，
		# 「受到 N 点某类伤害时」这类扳机需要的是这一条。
		ctx.battle.emit(BattleEvent.DAMAGE, victim.side, {
			"type": String(damage_type),
			"raw": raw,
			"amount": -actual,
			"source_side": ctx.owner.side,
			"uid": ctx.source_uid(),
		})
		if not victim.is_alive():
			ctx.battle.emit(BattleEvent.DIED, victim.side, {})


func estimated_damage(stats: StatSet) -> float:
	if target == Target.SELF:
		return 0.0
	var dmg := amount
	if damage_stat != &"":
		var from_stats := stats.total_of(damage_stat, -1)
		if from_stats >= 0:
			dmg = StatMath.to_float(from_stats)
	return dmg


func describe() -> String:
	return "造成 %s 伤害" % damage_type
