## 279（阔剑线）：给这件攒「下一下 +[member amount]」—— 配 on_item_fired（你的其他道具出手时）用；
## 这件下一次从属性取伤害的那一下加上它、用掉（[method DealDamage.primed]）。不叠：攒着的还没用就不再加
class_name PrimeNextHit
extends CombatEffect

@export var amount: float = 2.0


func apply(ctx: RuleContext) -> void:
	if ctx.owner != null and amount > 0.0:
		ctx.owner.prime(ctx.source_uid(), StatMath.from_float(amount))


func describe() -> String:
	return UiText.t("fx.prime_next") % TextTemplate.num(amount)


## 151：估值 —— 一次出手最多多 [member amount]（不叠），按每下都吃到算
func estimated_value(_ctx: PowerContext) -> float:
	return 0.0
