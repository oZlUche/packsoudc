## 侵蚀掉钱：在侵蚀区每走一步丢钱，越深丢越多
class_name ErodeDrainMoney
extends ErosionEffect

@export var amount: int = 5
@export var per_depth: int = 0


func apply(ctx: ErosionContext) -> void:
	var n := amount + per_depth * ctx.depth
	if n <= 0 or ctx.run.wallet == null:
		return
	var lost := mini(n, ctx.run.wallet.balance)
	if lost > 0 and ctx.run.wallet.spend(lost, &"erosion"):
		ctx.money_lost += lost


func describe() -> String:
	return "丢钱 %d%s%s" % [amount, ("（每深一层 +%d）" % per_depth) if per_depth > 0 else "", gate_text()]
