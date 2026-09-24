## 浅层侵蚀：在侵蚀区每走一步扣体力，越深扣越多（5.7 的「惩罚随停留深度递增」）
class_name ErodeSpendVitality
extends ErosionEffect

@export var amount: int = 1
## 每深一层多扣多少
@export var per_depth: int = 0


func apply(ctx: ErosionContext) -> void:
	var n := amount + per_depth * ctx.depth
	if n <= 0 or ctx.run.vitality == null:
		return
	ctx.vitality_spent += ctx.run.vitality.spend(n, &"erosion")


func describe() -> String:
	return "扣体力 %d%s%s" % [amount, ("（每深一层 +%d）" % per_depth) if per_depth > 0 else "", gate_text()]
