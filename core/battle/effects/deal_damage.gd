## 造成伤害。
class_name DealDamage
extends Effect

enum Target { OPPONENT, SELF }

@export var target: Target = Target.OPPONENT
## 固定伤害值；damage_stat 非空时改用属性值
@export var amount: float = 0.0
## 从属性表取伤害，通常是 damage
@export var damage_stat: StringName = &"damage"
## 伤害是否乘以来源 buff 的层数。「灼烧每层 2 点」用它
@export var per_stack: bool = false


func apply(ctx: RuleContext) -> void:
	var dmg := StatMath.from_float(amount)
	if damage_stat != &"":
		var from_stats := ctx.item_stat(damage_stat, -1)
		if from_stats >= 0:
			dmg = from_stats
	if per_stack:
		dmg *= ctx.source_stacks()
	if dmg <= 0:
		return

	var victim := ctx.opponent() if target == Target.OPPONENT else ctx.owner
	# 护甲按定点比例减伤，下限 0
	var armor := victim.stat(BattleStats.ARMOR, 0)
	if armor > 0:
		dmg = maxi(0, dmg - armor)

	var actual := victim.resources.change(BattleStats.RES_HP, -dmg, BattleEvent.REASON_DAMAGE)
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {
		"effect": "deal_damage", "uid": ctx.source_uid(),
		"target_side": victim.side, "amount": -actual,
	})
	if not victim.is_alive():
		ctx.battle.emit(BattleEvent.DIED, victim.side, {})


func describe() -> String:
	return "造成伤害"


func estimated_damage(stats: StatSet) -> float:
	if target == Target.SELF:
		return 0.0
	var dmg := StatMath.to_float(StatMath.from_float(amount))
	if damage_stat != &"":
		var from_stats := stats.total_of(damage_stat, -1)
		if from_stats >= 0:
			dmg = StatMath.to_float(from_stats)
	return dmg
