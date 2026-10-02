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

## 固定伤害值 —— **备用**：只在 damage_stat 留空、或属性表里没有那条属性时才用。
## 和 base_stats 里的 damage **不相加**，属性有值就以属性为准（这样 buff / 套装 / 邻接的伤害加成才有落点）。
## 武器一般不填它，只写 base_stats.damage；「灼烧每层 2 点」这类不吃加成的固定伤才填
@export var amount: float = 0.0
## 从属性表取伤害的键，通常是 damage；留空 = 只用上面的固定值
@export var damage_stat: StringName = &"damage"
## 伤害是否乘以来源 buff 的层数。「灼烧每层 2 点」用它
@export var per_stack: bool = false
## 106 第八节（作者定）：这一下算不算**直接伤害**（吃防护）。−1 = 按来源定（道具的规则 = 直接、buff 的规则 = 非直接），
## 0 / 1 = 强制非直接 / 直接 —— 作者说的「除非另行说明」就是这个口子，现有内容都不填
@export var direct_override: int = -1


func apply(ctx: RuleContext) -> void:
	var raw := StatMath.from_float(amount)
	var from_stat := false
	if damage_stat != &"":
		var from_stats := ctx.item_stat(damage_stat, -1)
		if from_stats >= 0:
			raw = from_stats
			from_stat = true
	if per_stack:
		raw *= ctx.source_stacks()
	if raw <= 0:
		return

	# 104（作者定）：暴击 —— 只有从属性取伤害的那一包掷（固定值伤害不暴击），造包时掷、在管线之前，
	# 所以护盾 / 减伤 / 护甲 / 加时看到的都是暴击后的原始值。双方对称。一次出手掷一次，打到几个目标都一样
	var crit := from_stat and roll_crit(ctx)
	if crit:
		raw = StatMath.mul(raw, maxi(0, ctx.item_stat(BattleStats.CRIT_DAMAGE, BattleStats.default_base(BattleStats.CRIT_DAMAGE))))

	for victim in resolve_targets(ctx, target):
		var packet := DamagePacket.create(damage_type, raw, victim, ctx.owner.side, ctx.source_uid(), direct_of(ctx, direct_override))
		packet.crit = crit
		DamageResolver.resolve(ctx.battle, packet)


## 掷一次暴击：暴击率按定点万分比（0.10 = 1000），≤ 0 永不、≥ 1 必中 —— 两头都不消耗随机数
static func roll_crit(ctx: RuleContext) -> bool:
	var chance := ctx.item_stat(BattleStats.CRIT_CHANCE, BattleStats.default_base(BattleStats.CRIT_CHANCE))
	if chance <= 0:
		return false
	if chance >= StatMath.ONE:
		return true
	return ctx.rng().randi_range(1, StatMath.ONE) <= chance


func estimated_damage(stats: StatSet) -> float:
	if target == Target.SELF:
		return 0.0
	var dmg := amount
	if damage_stat != &"":
		var from_stats := stats.total_of(damage_stat, -1)
		if from_stats >= 0:
			# 104：从属性取的那一包会暴击，预估乘期望值 1 + 暴击率 × (暴击伤害 − 1)（默认 1.05）
			var chance := clampf(StatMath.to_float(stats.total_of(BattleStats.CRIT_CHANCE)), 0.0, 1.0)
			var mult := maxf(0.0, StatMath.to_float(stats.total_of(BattleStats.CRIT_DAMAGE)))
			dmg = StatMath.to_float(from_stats) * (1.0 + chance * (mult - 1.0))
	return dmg


func describe() -> String:
	return "造成 %s 伤害" % Glossary.damage_type_name(damage_type)
