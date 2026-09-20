## 造成伤害。
##
## 本效果只负责**算出原始值并交给管线**，减免与结算全在 [DamageResolver] 里 ——
## 护盾、护甲、受伤前减伤、反转对所有伤害来源一视同仁，不该由每个效果各实现一遍。
class_name DealDamage
extends CombatEffect

@export var target: Target = Target.OPPONENT

## 伤害类型。决定能否被护盾吸收、吃不吃护甲、是否通知受伤效果，
## 具体性质见 [DamageTypeDef]，不写死在结算里。
##
## [b]刻意不与乘区绑定。[/b] 火焰伤害吃不吃 FIRE 乘区由内容自己在属性上声明，
## 否则伤害类型与乘区被迫一一对应，以后想加「不吃任何元素加成的真实伤害」就没法表达。
@export var damage_type: StringName = DamageTypes.PHYSICAL

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
		DamageResolver.resolve(ctx.battle, DamagePacket.create(
			damage_type, raw, victim, ctx.owner.side, ctx.source_uid()
		))


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
