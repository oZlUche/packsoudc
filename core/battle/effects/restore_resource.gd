## 恢复资源：治疗、回耐力、回法力共用它。
class_name RestoreResource
extends Effect

enum Target { SELF, OPPONENT }

@export var target: Target = Target.SELF
@export var resource_key: StringName = &"hp"
@export var amount: float = 5.0
@export var amount_stat: StringName = &""
@export var per_stack: bool = false


func apply(ctx: RuleContext) -> void:
	var value := StatMath.from_float(amount)
	if amount_stat != &"":
		var from_stats := ctx.item_stat(amount_stat, -1)
		if from_stats >= 0:
			value = from_stats
	if per_stack:
		value *= ctx.source_stacks()
	if value <= 0:
		return

	var who := ctx.owner if target == Target.SELF else ctx.opponent()
	var actual := who.resources.change(resource_key, value, BattleEvent.REASON_HEAL)
	if actual != 0:
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {
			"effect": "restore_resource", "uid": ctx.source_uid(),
			"target_side": who.side, "key": String(resource_key), "amount": actual,
		})


func describe() -> String:
	return "恢复资源"
