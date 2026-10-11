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
## 否则减伤、护甲、免疫、反转就得在每个来源上各实现一遍，
## 而「以血为代价」的道具正好是玩家最想用减伤去抵消的那类。
##
## 默认 [constant DamageTypes.DRAIN]（流失）：走完整管线，但不点亮反伤与吸血，
## 否则割自己一刀会变成正收益。想让它算作真正的伤害就改成别的类型。
@export var loss_type: StringName = DamageTypes.DRAIN

## 132：这一包伤害**实际扣除量**的百分之几（0..100），和 [member amount] 相加；符号跟 amount（amount 为负就是扣）。
## 只在 [OnDamage] 触发时有包（吸血）；别的时机这部分是 0，导入器给警告
@export var percent_of_damage: int = 0


func apply(ctx: RuleContext) -> void:
	var value := StatMath.from_float(amount)
	if amount_stat != &"":
		var from_stats := ctx.item_stat(amount_stat, -1)
		if from_stats >= 0:
			value = from_stats if amount >= 0.0 else -from_stats
	if per_stack:
		value *= ctx.source_stacks()
	if percent_of_damage > 0 and ctx.event != null and ctx.event.name == BattleEvent.DAMAGE:
		var hit := maxi(0, ctx.event.get_int(&"amount"))
		var part := StatMath.mul(hit, StatMath.from_percent(clampi(percent_of_damage, 0, 100)))
		value += -part if amount < 0.0 else part
	if value == 0:
		return

	for who in resolve_targets(ctx, target):
		if who.dead:
			continue     # 087：倒下的不吃治疗、不扣资源（倒下是终局）
		if value < 0 and resource_key == BattleStats.RES_HP:
			# 106 第八节：以血为代价（超频、献祭）不是武器打出来的，所以**不是直接伤害** ——
			# 格挡不该把自己割的那一刀挡掉。这正是作者说的「另行说明」那一类
			DamageResolver.deal(ctx.battle, who, -value, loss_type, ctx.owner.side, ctx.source_uid(), false)
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
		who.settle_death(ctx.battle)


func describe() -> String:
	return "%s %s %.0f" % ["获得" if amount >= 0.0 else "失去", resource_key, absf(amount)]


## 151：估值 —— 生命 / 护甲：得到的乘治疗权重、失去的按伤害算；耐力 / 法力乘耐力权重；
## 吸血那部分按这一下的大小（受击扳机是对面那一下，出手扳机是自己那一下）。给自己为正，给对手取反
func estimated_value(ctx: PowerContext) -> float:
	var amt := amount
	if amount_stat != &"" and ctx.stats != null and ctx.stats.total_of(amount_stat, -1) >= 0:
		amt = StatMath.to_float(ctx.stats.total_of(amount_stat)) * (1.0 if amount >= 0.0 else -1.0)
	if per_stack:
		amt *= ctx.stacks_or_assumed()
	if percent_of_damage > 0:
		var hit := ctx.incoming_hit() if ctx.incoming else ctx.hit_size()
		amt += hit * clampi(percent_of_damage, 0, 100) / 100.0 * (-1.0 if amount < 0.0 else 1.0)
	var w := ctx.weights
	var per := w.stamina_weight
	if resource_key == BattleStats.RES_HP or resource_key == BattleStats.RES_ARMOR:
		per = w.heal_weight if amt > 0.0 else 1.0
	return amt * per * -side_sign(target)
