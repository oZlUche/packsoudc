## 造成伤害。
##
## 本效果只负责**算出原始值并交给管线**，减免与结算全在 [DamageResolver] 里 ——
## 护甲、格挡、受伤前减伤、反转对所有伤害来源一视同仁，不该由每个效果各实现一遍。
class_name DealDamage
extends CombatEffect

@export var target: Target = Target.OPPONENT

## 伤害类型。决定能否被护甲吸收、是否通知受伤效果，
## 具体性质见 [DamageTypeDef]，不写死在结算里。
##
## [b]刻意不与乘区绑定。[/b] 火焰伤害吃不吃 ELEMENT（元素增伤）乘区由内容自己在属性上声明，
## 否则伤害类型与乘区被迫一一对应，以后想加「不吃任何元素加成的真实伤害」就没法表达。
@export var damage_type: StringName = DamageTypes.PHYSICAL

## 固定伤害值 —— **备用**：只在 damage_stat 留空、或属性表里没有那条属性时才用。
## 和 base_stats 里的 damage **不相加**，属性有值就以属性为准（这样 buff / 套装 / 邻接的伤害加成才有落点）。
## 武器一般不填它，只写 base_stats.damage；「灼烧每层 2 点」这类不吃加成的固定伤才填
@export var amount: float = 0.0
## 从属性表取伤害的键，通常是 damage；留空 = 只用上面的固定值
@export var damage_stat: StringName = &"damage"
## 伤害是否乘以来源 buff 的层数。「灼烧每层 2 点」用它
@export var per_stack: bool = false
## 106 第八节（作者定）：这一下算不算**直接伤害**（吃格挡）。−1 = 按来源定（道具的规则 = 直接、buff 的规则 = 非直接），
## 0 / 1 = 强制非直接 / 直接 —— 作者说的「除非另行说明」就是这个口子，现有内容都不填
@export var direct_override: int = -1

## 132：按生命比例的那部分 —— `max_hp` / `current_hp` / `missing_hp`，空 = 不用。**和上面的固定值 / 属性相加**（处决 = 固定 + 比例）
@export var percent_of: StringName = &""
## 132：比例（0..100）
@export var percent: int = 0
## 132：比例按谁的生命算（默认对手；BOTH = 按挨打的那一方自己的）
@export var percent_of_target: Target = Target.OPPONENT
## 132：伤害乘以**目标身上**这个状态的层数（0 层 = 不打）；和 [member per_stack]（来源层数）可同时写
@export var per_target_stack: StringName = &""

const PERCENT_OF := [&"max_hp", &"current_hp", &"missing_hp"]


func apply(ctx: RuleContext) -> void:
	deal(ctx, damage_type, 0)


## 175：真正打出去的那一下 —— [param type] 是这一包的类型，[param extra_raw] 并进从属性取的原值（法杖轮到的那颗晶石的伤害，[FireLoaded]）
func deal(ctx: RuleContext, type: StringName, extra_raw: int) -> void:
	var raw := StatMath.from_float(amount)
	var from_stat := false
	if damage_stat != &"":
		var from_stats := ctx.item_stat(damage_stat, -1)
		if from_stats >= 0:
			raw = from_stats + extra_raw
			from_stat = true
	if per_stack:
		raw *= ctx.source_stacks()
	var by_hp := percent_of != &"" and percent > 0
	if raw <= 0 and not by_hp:
		return

	# 104（作者定）：暴击 —— 只有从属性取伤害的那一包掷（固定值伤害不暴击），造包时掷、在管线之前，
	# 所以护甲 / 减伤 / 格挡 / 加时看到的都是暴击后的原始值。双方对称。一次出手掷一次，打到几个目标都一样
	var crit := from_stat and roll_crit(ctx)
	if crit:
		raw = StatMath.mul(raw, maxi(0, ctx.item_stat(BattleStats.CRIT_DAMAGE, BattleStats.default_base(BattleStats.CRIT_DAMAGE))))

	for victim in resolve_targets(ctx, target):
		var dmg := raw
		if by_hp:
			dmg += hp_part(ctx, victim)
		if per_target_stack != &"":
			dmg *= victim.stacks_of(per_target_stack)
		if dmg <= 0:
			continue
		var packet := DamagePacket.create(type, dmg, victim, ctx.owner.side, ctx.source_uid(), direct_of(ctx, direct_override))
		packet.crit = crit
		DamageResolver.resolve(ctx.battle, packet)


## 132：按生命比例的那部分（定点）
func hp_part(ctx: RuleContext, victim: CombatantRuntime) -> int:
	var who: CombatantRuntime = victim
	match percent_of_target:
		Target.SELF:
			who = ctx.owner
		Target.OPPONENT:
			who = ctx.opponent()
	if who == null:
		return 0
	var mx := who.resources.maximum(BattleStats.RES_HP)
	var cur := who.resources.current(BattleStats.RES_HP)
	var base := 0
	match percent_of:
		&"max_hp":
			base = mx
		&"current_hp":
			base = cur
		&"missing_hp":
			base = maxi(0, mx - cur)
	return maxi(0, StatMath.mul(base, StatMath.from_percent(clampi(percent, 0, 100))))


## 掷一次暴击：暴击率按定点万分比（0.10 = 1000），≤ 0 永不、≥ 1 必中 —— 两头都不消耗随机数
static func roll_crit(ctx: RuleContext) -> bool:
	var chance := ctx.item_stat(BattleStats.CRIT_CHANCE, BattleStats.default_base(BattleStats.CRIT_CHANCE))
	if chance <= 0:
		return false
	if chance >= StatMath.ONE:
		return true
	return ctx.roll("crit", 1, StatMath.ONE, chance) <= chance


func estimated_damage(stats: StatSet) -> float:
	if target == Target.SELF:
		return 0.0
	var dmg := amount
	if damage_stat != &"":
		var from_stats := stats.total_of(damage_stat, -1)
		if from_stats >= 0:
			# 104：从属性取的那一包会暴击，预估乘期望值 1 + 暴击率 × (暴击伤害 − 1)（默认 1.05）
			var chance := clampf(StatMath.to_float(stats.total_of(BattleStats.CRIT_CHANCE)), 0.0, 1.0)
			var mult := maxf(0.0, StatMath.to_float(stats.total_of(BattleStats.CRIT_DAMAGE)))
			dmg = StatMath.to_float(from_stats) * (1.0 + chance * (mult - 1.0))
	return dmg

## 151：估值 —— 一下打多少（属性取的含暴击期望；按生命比例的按假定生命：最大生命算满，当前 / 已损失算一半；
## 按层数的按估算上下文假定的层数），打对手为正、打自己为负、两边都打抵掉
func estimated_value(ctx: PowerContext) -> float:
	var dmg := amount
	if damage_stat != &"" and ctx.stats != null and ctx.stats.total_of(damage_stat, -1) >= 0:
		dmg = estimated_damage(ctx.stats) if target != Target.SELF else StatMath.to_float(ctx.stats.total_of(damage_stat))
	if percent_of != &"" and percent > 0:
		dmg += ctx.weights.assumed_hp * (1.0 if percent_of == &"max_hp" else 0.5) * percent / 100.0
	if per_stack or per_target_stack != &"":
		dmg *= ctx.stacks_or_assumed()
	return dmg * side_sign(target)


## 142：固定值、按层数、按比例都写出来（「对手每层流血造成 3 点物理伤害」「造成 4 点 + 对手 10% 最大生命的物理伤害」）；
## 只读属性表的（武器的普通攻击）照旧只写「造成物理伤害」—— 数值随加成变，看 DPS 那行
func describe() -> String:
	var parts: Array[String] = []
	var fixed := damage_stat == &"" and amount > 0.0
	if fixed:
		parts.append("%s 点" % TextTemplate.num(amount))
	if percent_of != &"" and percent > 0:
		var whose := {Target.OPPONENT: "对手", Target.SELF: "自己", Target.BOTH: "目标"}[percent_of_target] as String
		parts.append("%s %d%% %s" % [whose, percent, PERCENT_OF_NAMES.get(String(percent_of), String(percent_of))])
	var head := ""
	if per_target_stack != &"":
		head = "对手每层%s" % Glossary.status_name(per_target_stack)
	elif per_stack:
		head = "每层"
	var what := " + ".join(parts)
	if what == "":
		return "%s造成%s伤害" % [head, Glossary.damage_type_name(damage_type)]
	var joiner := "的" if percent_of != &"" and percent > 0 else ""
	return "%s造成 %s%s%s伤害" % [head, what, joiner, Glossary.damage_type_name(damage_type)]


const PERCENT_OF_NAMES := {"max_hp": "最大生命", "current_hp": "当前生命", "missing_hp": "已损失生命"}
