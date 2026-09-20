## 增加或减少某种资源。**正负都走这一条** —— 治疗、回耐力、抽血、耗蓝共用。
##
## 原先叫 RestoreResource 且只有正向语义，减少要靠传负数，命名撒谎。
class_name ChangeResource
extends CombatEffect

@export var target: Target = Target.SELF
@export var resource_key: StringName = &"hp"
## 正数为获得，负数为失去
@export var amount: float = 5.0
@export var amount_stat: StringName = &""
@export var per_stack: bool = false


func apply(ctx: RuleContext) -> void:
	var value := StatMath.from_float(amount)
	if amount_stat != &"":
		var from_stats := ctx.item_stat(amount_stat, -1)
		if from_stats >= 0:
			value = from_stats if amount >= 0.0 else -from_stats
	if per_stack:
		value *= ctx.source_stacks()
	if value == 0:
		return

	var reason := BattleEvent.REASON_HEAL if value > 0 else BattleEvent.REASON_COST
	for who in resolve_targets(ctx, target):
		var actual := who.resources.change(resource_key, value, reason)
		if actual != 0:
			ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {
				"effect": "change_resource", "uid": ctx.source_uid(),
				"target_side": who.side, "key": String(resource_key), "amount": actual,
			})
		if not who.is_alive():
			ctx.battle.emit(BattleEvent.DIED, who.side, {})


func describe() -> String:
	return "%s %s %.0f" % ["获得" if amount >= 0.0 else "失去", resource_key, absf(amount)]
