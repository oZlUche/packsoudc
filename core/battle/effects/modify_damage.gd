## 改写正在结算的那一包伤害。**只在受伤前阶段有效。**
##
## 配 [OnBeforeDamage] 使用。减伤、免疫、反转全是它的不同参数：
##
## [codeblock]
## 消耗 2 层格挡减免 10 点
##   on_before_damage(受到) · always · status_stack(格挡,2) · modify_damage(flat=-10)
## 解毒剂：中毒伤害反转成治疗
##   on_before_damage(受到, poison) · always · uses(1) · modify_damage(invert)
## 一次完全免疫
##   on_before_damage(受到) · always · uses(1) · modify_damage(cancel)
## [endcodeblock]
##
## 「有条件的减伤不能写成固定属性」正是它存在的理由 ——
## 前置条件由消耗层表达，这里只管改数。
class_name ModifyDamage
extends CombatEffect

## 固定增减，负为减伤。在百分比之后结算。
@export var flat: float = 0.0
## 百分比增减，-50 即减半。同一包伤害上多条效果的百分比【相加】。
@export var percent: int = 0
## 反转：伤害变治疗
@export var invert: bool = false
## 完全取消这一次
@export var cancel: bool = false


func apply(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null:
		# 不在受伤前阶段。静默跳过而不是报错 —— 同一条规则可能被别的扳机复用
		return
	if flat != 0.0:
		p.add_flat(StatMath.from_float(flat))
	if percent != 0:
		p.add_percent(StatMath.from_percent(percent))
	if invert:
		p.invert()
	if cancel:
		p.cancel()


func describe() -> String:
	if cancel:
		return "免疫这一次伤害"
	if invert:
		return "反转这一次伤害"
	var parts: Array[String] = []
	if percent != 0:
		parts.append("%+d%%" % percent)
	if flat != 0.0:
		parts.append("%+.0f" % flat)
	return "伤害 " + "、".join(parts) if not parts.is_empty() else "不改动伤害"
