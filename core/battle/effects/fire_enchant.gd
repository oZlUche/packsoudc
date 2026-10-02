## 火焰附魔（093，日神 1 / 3 级）：这件武器每出手一次，另造一次火焰伤害 = max([member fixed]，武器伤害 × [member percent]%)。
## 配 on_item_fired（只听自己）用。
##
## 105：祈祷攒的加成不再塞进这里（原来的 `bonus_percent`）—— 它是标准轴 `fire_damage`，
## 由 [DamageResolver] 按攻方读，所以灼烧之类别的火焰来源也一起吃到。
class_name FireEnchant
extends CombatEffect

@export var fixed: float = 3.0
@export var percent: int = 30
@export var target: Target = Target.OPPONENT


func apply(ctx: RuleContext) -> void:
	var from_stat := ctx.item_stat(BattleStats.DAMAGE, 0)
	var by_percent := StatMath.mul(from_stat, StatMath.from_percent(percent)) if from_stat > 0 else 0
	var raw := maxi(StatMath.from_float(fixed), by_percent)
	if raw <= 0:
		return
	for victim in resolve_targets(ctx, target):
		DamageResolver.resolve(ctx.battle, DamagePacket.create(DamageTypes.FIRE, raw, victim, ctx.owner.side, ctx.source_uid()))


func estimated_damage(_stats: StatSet) -> float:
	return fixed


func describe() -> String:
	return "出手时附带火焰伤害 max(%.0f, %d%% 武器伤害)" % [fixed, percent]
