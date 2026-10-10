## 一次伤害结算的可变账本（架构文档 4.6）。
##
## 从产生到落到血量为止，这一包伤害在管线里被逐步改写。受伤前效果拿到的就是它。
##
## [b]为什么要有这个对象[/b]：减伤不能写成「护甲」一个数。
## 「消耗 2 层格挡减免 10 点」「喝了解毒剂时中毒伤害反转成治疗」这类效果有前置条件，
## 塞不进任何一个固定字段；它们需要的是一个能在结算中途被改的账本。
##
## 全部数值都是定点。
class_name DamagePacket
extends RefCounted

#region 输入，创建后不再改
var type: StringName = DamageTypes.PHYSICAL
## 原始值，尚未经过任何削减
var raw: int = 0
var victim: CombatantRuntime = null
## 施加方阵营；-1 表示无主（环境伤害）
var source_side: int = -1
## 来源物品 uid；0 表示来自 buff 或套装
var source_uid: int = 0
## 104：这一包是暴击（[DealDamage] 造包时掷的，raw 已经乘过暴击伤害）
var crit: bool = false
## 106 第八节（作者定）：这一包是不是**直接伤害** —— 看来源，武器（道具的规则）造成的是直接，
## buff 造成的（灼烧、中毒、到期爆发）是非直接，套装 / 单位级规则也算非直接。
## **格挡（加固 / 破绽）只对直接伤害生效**；造包的效果用 [method CombatEffect.direct_of] 填它
var direct: bool = false
#endregion

#region 管线中途写入
## 被护盾吸收掉的量
var absorbed: int = 0
## 受伤前效果的固定增减，负为减伤
var flat: int = 0
## 受伤前效果的百分比增减（定点），-ONE/2 即减半
var percent: int = 0
## 反转：最终结果取反，伤害变治疗
var inverted: bool = false
## 完全取消这一次
var cancelled: bool = false
## 实际被格挡挡掉的量（153：原名 armor；破绽为负）
var block: int = 0
## 最终结算量。正为扣血，负为回血
var final: int = 0
## 落到资源上的实际变化量（可能被上限或归零截断）
var applied: int = 0
#endregion


static func create(
	p_type: StringName, p_raw: int, p_victim: CombatantRuntime,
	p_source_side: int = -1, p_source_uid: int = 0, p_direct: bool = false
) -> DamagePacket:
	var p := DamagePacket.new()
	p.type = p_type
	p.raw = p_raw
	p.victim = p_victim
	p.source_side = p_source_side
	p.source_uid = p_source_uid
	p.direct = p_direct
	return p


func victim_side() -> int:
	return victim.side if victim != null else -1


## 护盾吸收之后、受伤前效果之前的待结算量。受伤前效果据此判断「这一下够不够狠」。
func pending() -> int:
	return maxi(0, raw - absorbed)


func def() -> DamageTypeDef:
	return DamageTypes.get_def(type)


#region 供受伤前效果调用
func add_flat(v: int) -> void:
	flat += v


func add_percent(p: int) -> void:
	percent += p


func invert() -> void:
	inverted = not inverted


func cancel() -> void:
	cancelled = true
#endregion


func _to_string() -> String:
	return "DamagePacket(%s 原始 %.1f → 护盾 -%.1f → 格挡 -%.1f → 最终 %.1f)" % [
		type, StatMath.to_float(raw), StatMath.to_float(absorbed),
		StatMath.to_float(block), StatMath.to_float(final),
	]
