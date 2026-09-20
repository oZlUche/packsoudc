## 把正在结算的这一包伤害按比例弹回给施加方。**只在受伤前阶段有效。**
##
## 为什么不用 [DealDamage] 手写：
##
## 1. 反弹量取决于**这一下有多痛**，而 DealDamage 只会读属性或固定值，
##    拿不到伤害包。
## 2. 反伤必须打出 [constant DamageTypes.REFLECT] 类型。那个类型 provokes 为 false，
##    因此不会招致对方的反伤 —— **两件反伤道具不会互相引燃**。
##    用 DealDamage 手写的话作者很容易漏填类型，配出一场对轰。
##
## 类型仍然可以改（[member damage_type]），但默认值是对的那个。
class_name ReflectDamage
extends CombatEffect

## 反弹当前待结算伤害的百分比
@export var percent: int = 30

## 额外的固定反弹值
@export var flat: float = 0.0

## 反弹伤害的类型。默认 reflect —— 改成会招致反应的类型就要自己承担对轰风险
@export var damage_type: StringName = DamageTypes.REFLECT


func apply(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null:
		return  # 不在受伤前阶段，静默跳过
	# 无主伤害（环境）与自伤不反弹：没有可以弹回去的对象
	if p.source_side < 0 or p.source_side == ctx.owner.side:
		return

	var amount := StatMath.from_float(flat)
	if percent != 0:
		amount += StatMath.mul(p.pending(), StatMath.from_percent(percent))
	if amount <= 0:
		return

	var attacker := ctx.battle.sides[p.source_side]
	DamageResolver.resolve(ctx.battle, DamagePacket.create(
		damage_type, amount, attacker, ctx.owner.side, ctx.source_uid()
	))


func describe() -> String:
	if flat != 0.0 and percent != 0:
		return "反弹 %d%% 伤害并附加 %.0f 点" % [percent, flat]
	if flat != 0.0:
		return "反弹 %.0f 点" % flat
	return "反弹 %d%% 伤害" % percent
