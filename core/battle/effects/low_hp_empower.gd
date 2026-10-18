## 低血增伤（093，蛮神 1 级；188 补充一作者改成门槛式）：改写本方正在造成的这一包伤害 —— 生命低于 [member hp_percent]% 时 +[member percent]%。
## 配 on_before_damage（本方施加）用；不在受伤前阶段静默跳过
class_name LowHpEmpower
extends CombatEffect

@export var hp_percent: int = 30
@export var percent: int = 10


func apply(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or ctx.owner == null or percent == 0:
		return
	var cur := ctx.owner.resources.current(BattleStats.RES_HP)
	var mx := maxi(1, ctx.owner.resources.maximum(BattleStats.RES_HP))
	if cur * 100 < mx * hp_percent:
		p.add_percent(StatMath.from_percent(percent))


func describe() -> String:
	return "生命值低于 %d%% 时，造成伤害提高 %d%%" % [hp_percent, percent]


## 151：估值 —— 自己出手那一下 × 加成 × 低血时间占比
func estimated_value(ctx: PowerContext) -> float:
	return ctx.hit_size() * float(percent) / 100.0 * ctx.weights.low_hp_share
