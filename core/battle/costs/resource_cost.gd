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
	var v := StatMath.from_float(amount)
	if amount_stat != &"":
		var from_stats := ctx.item_stat(amount_stat, -1)
		if from_stats >= 0:
			v = from_stats
	return _numbed(ctx, v)


## 175 补充四：麻痹 —— 付耐力时 × (1 + 层数 × 每层%)（[member BuffDef.decay_halve_on] = `stamina_paid` 的状态）；
## 和 105 的灵巧 / 笨拙轴并列连乘（轴已经乘在属性里），不混进轴
func _numbed(ctx: RuleContext, v: int) -> int:
	if resource_key != BattleStats.RES_STAMINA or v <= 0:
		return v
	var pct := ctx.owner.percent_on(BuffDef.HALVE_STAMINA_PAID)
	return StatMath.mul(v, StatMath.ONE + StatMath.from_float(pct / 100.0)) if pct > 0.0 else v


func can_pay(ctx: RuleContext) -> bool:
	return ctx.owner.resources.can_afford(resource_key, _amount_fp(ctx))


func pay(ctx: RuleContext) -> void:
	ctx.owner.resources.change(resource_key, -_amount_fp(ctx), BattleEvent.REASON_COST)
	if resource_key == BattleStats.RES_STAMINA:
		ctx.owner.halve_on(ctx.battle, BuffDef.HALVE_STAMINA_PAID)     # 用完减半


func trace_info(ctx: RuleContext) -> Dictionary:
	return {"cost": "ResourceCost", "resource": String(resource_key), "need": _amount_fp(ctx),
		"have": ctx.owner.resources.current(resource_key) if ctx.owner.resources.has(resource_key) else 0}


## 142：「消耗 5 耐力」；按属性取的写属性名（数值随加成变，写死反而错）
func describe() -> String:
	var res := Glossary.resource_name(resource_key)
	if amount_stat != &"":
		return "消耗%s（%s）" % [res, Glossary.stat_name(amount_stat)]
	return "消耗 %s %s" % [TextTemplate.num(amount), res]


## 151：耐力能持续几成（155 补：耐力上限 + 一场的回复，[method PowerWeights.stamina_sustain]）；别的资源不打折
func estimated_factor(ctx: PowerContext, rate: float) -> float:
	return ctx.weights.stamina_sustain(stamina_per_use(ctx.stats) * rate)


## 151 / 155：每次出手耗多少耐力（不是耐力的为 0）。按属性取的看 [param stats]
func stamina_per_use(stats: StatSet) -> float:
	if resource_key != BattleStats.RES_STAMINA:
		return 0.0
	if amount_stat != &"" and stats != null and stats.total_of(amount_stat, -1) >= 0:
		return StatMath.to_float(stats.total_of(amount_stat))
	return amount
