## 增加或减少某种资源。**正负都走这一条** —— 治疗、回耐力、抽血、耗蓝共用。
##
## 原先叫 RestoreResource 且只有正向语义，减少要靠传负数，命名撒谎。
class_name ChangeResource
extends CombatEffect

@export var target: Target = Target.SELF
@export var resource_key: StringName = BattleStats.RES_HP
## 正数为获得，负数为失去
@export var amount: float = 5.0
@export var amount_stat: StringName = &""
@export var per_stack: bool = false

## 扣**血量**时按哪种伤害类型走管线。
##
## [b]减血一律走伤害管线[/b]（[DamageResolver]），哪怕来源是超频自伤这类机制 ——
## 否则减伤、护盾、免疫、反转就得在每个来源上各实现一遍，
## 而「以血为代价」的道具正好是玩家最想用减伤去抵消的那类。
##
## 默认 [constant DamageTypes.DRAIN]（流失）：走完整管线，但不点亮反伤与吸血，
## 否则割自己一刀会变成正收益。想让它算作真正的伤害就改成别的类型。
@export var loss_type: StringName = DamageTypes.DRAIN


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

	for who in resolve_targets(ctx, target):
		if value < 0 and resource_key == BattleStats.RES_HP:
			DamageResolver.resolve(ctx.battle, DamagePacket.create(
				loss_type, -value, who, ctx.owner.side, ctx.source_uid()
			))
			continue
		var actual := who.resources.change(
			resource_key, value,
			BattleEvent.REASON_HEAL if value > 0 else BattleEvent.REASON_COST
		)
		if actual != 0:
			ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {
				"effect": "change_resource", "uid": ctx.source_uid(),
				"target_side": who.side, "key": String(resource_key), "amount": actual,
			})
		if not who.is_alive():
			ctx.battle.emit(BattleEvent.DIED, who.side, {})


func describe() -> String:
	return "%s %s %.0f" % ["获得" if amount >= 0.0 else "失去", resource_key, absf(amount)]
