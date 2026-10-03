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


func describe(_ctx: RuleContext) -> String:
	return "%s %.0f" % [resource_key, amount]
