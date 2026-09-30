## 低血增伤（093，蛮神 1 级）：改写本方正在造成的这一包伤害 —— 当前生命百分比越低加得越多，[member min_percent]（满血）到 [member max_percent]（空血）线性。
## 配 on_before_damage（本方施加）用；不在受伤前阶段静默跳过
class_name LowHpEmpower
extends CombatEffect

@export var min_percent: int = 10
@export var max_percent: int = 50


func apply(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or ctx.owner == null:
		return
	var cur := ctx.owner.resources.current(BattleStats.RES_HP)
	var mx := maxi(1, ctx.owner.resources.maximum(BattleStats.RES_HP))
	var ratio := clampf(float(cur) / float(mx), 0.0, 1.0)
	var percent := roundi(float(min_percent) + float(max_percent - min_percent) * (1.0 - ratio))
	if percent != 0:
		p.add_percent(StatMath.from_percent(percent))


func describe() -> String:
	return "所有伤害 +%d%%～+%d%%（血越少越高）" % [min_percent, max_percent]
