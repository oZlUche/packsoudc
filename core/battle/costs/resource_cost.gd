## 消耗资源：耐力、法力等。
##
## 面板消耗可写死在本条上，也可取自属性键（[member amount_stat]）——
## 取自属性时会走 4.3 公式结算，「减少耐力消耗 20%」就是一条普通 StatModifier。
class_name ResourceCost
extends Cost

@export var resource_key: StringName = &"stamina"
## 面板消耗；amount_stat 非空时以属性值为准
@export var amount: float = 10.0
## 从属性表取消耗值，例如 stamina_cost
@export var amount_stat: StringName = &""


func _amount_fp(ctx: RuleContext) -> int:
	if amount_stat != &"":
		var from_stats := ctx.item_stat(amount_stat, -1)
		if from_stats >= 0:
			return from_stats
	return StatMath.from_float(amount)


func can_pay(ctx: RuleContext) -> bool:
	return ctx.owner.resources.can_afford(resource_key, _amount_fp(ctx))


func pay(ctx: RuleContext) -> void:
	ctx.owner.resources.change(resource_key, -_amount_fp(ctx), BattleEvent.REASON_COST)


func trace_info(ctx: RuleContext) -> Dictionary:
	return {"cost": "ResourceCost", "resource": String(resource_key), "need": _amount_fp(ctx),
		"have": ctx.owner.resources.current(resource_key) if ctx.owner.resources.has(resource_key) else 0}


## 142：「消耗 5 耐力」；按属性取的写属性名（数值随加成变，写死反而错）
func describe() -> String:
	var res := Glossary.resource_name(resource_key)
	if amount_stat != &"":
		return "消耗%s（%s）" % [res, Glossary.stat_name(amount_stat)]
	return "消耗 %s %s" % [TextTemplate.num(amount), res]


## 151：耐力能持续几成 = min(1, 回复 ÷ (每次 × 一秒几次))；别的资源不打折
func estimated_factor(ctx: PowerContext, rate: float) -> float:
	if resource_key != BattleStats.RES_STAMINA:
		return 1.0
	var amt := amount
	if amount_stat != &"" and ctx.stats != null and ctx.stats.total_of(amount_stat, -1) >= 0:
		amt = StatMath.to_float(ctx.stats.total_of(amount_stat))
	var need := amt * rate
	return minf(1.0, ctx.weights.stamina_regen / need) if need > 0.0 else 1.0
