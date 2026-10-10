## 一种增益／减益的定义（架构文档 4.5）。
##
## 战斗中一切属性变化都由 buff 承载，**包括资源上限** ——
## 「强壮」提供额外生命上限就是一条作用于 max_hp 的 mod，不为上限另开机制。
##
## buff 仅在本场战斗内存在，结束全部清空。
class_name BuffDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}
## 仅影响 UI 配色与「净化」类效果的筛选，不影响结算
@export var is_debuff: bool = false
## 103：系统效果（加时的鏖战、衰竭）—— 不可解除：移除效果与消耗层数对它一律无效；面板单独一种配色。
## 由 [OvertimeRules] 在代码里造，不是内容
@export var system: bool = false

@export_group("叠层与时长")
## 137（作者定）：可叠层 = 层数不限；不可叠层 = 固定一层（将来的「无敌」）。没有「至多 N 层」
## （老字段 `max_stacks` 由导入器迁移：1 → 不可叠，其余 → 可叠）
@export var stackable: bool = true
## 时长，秒。作者定的规矩（085）：**可叠层的 buff 永续**（中毒、流血、结界……叠上就一直在，直到被清除或战斗结束），
## 这个字段对它们不生效、导入器也不许填；**不可叠层的**（往往是「满足 X 条件时获得 ABC」那种复杂的）才可以过期，
## 0 = 也永续。可以是任意小数（模拟按时刻跳跃，不受「帧」粒度限制）
@export var duration_sec: float = 0.0
## 叠层时是否把时长刷新回满（只对会过期的有意义）
@export var refresh_on_restack: bool = true


## 可叠层（137：可叠就是不限层）
func is_stackable() -> bool:
	return stackable


## 永续：不过期，到战斗结束 —— 可叠层的一律永续；不可叠层的没填时长也永续
func is_permanent() -> bool:
	return is_stackable() or duration_sec <= 0.0


## 给界面看的时长一句：「永续」/「持续 N 秒」
func duration_text() -> String:
	return "永续" if is_permanent() else "持续 %.1f 秒" % duration_sec

@export_group("效果")
## **每层一份**，走 4.3 公式
@export var mods: Array[StatModifier] = []
## buff 自己也能带触发规则 —— 这是「复合效果」成立的关键。
## 「灼烧：每层每秒掉 2 点血」= 挂在这里的一条 OnTick + Cooldown(1s) + DealDamage，
## BattleSim 里不需要为灼烧写任何特例。
@export var rules: Array[AbilityRule] = []
@export var on_apply: Array[CombatEffect] = []
@export var on_expire: Array[CombatEffect] = []


#region 151 战斗力估算
## 一层挂在某一边身上，每秒对那一边值多少（[param ctx] 是那一边的角度，[method PowerContext.for_carrier]）：
## 属性修饰 + 自己的规则（流血：每层每秒伤自己一点 = −1）
func value_per_sec(ctx: PowerContext) -> float:
	if ctx.depth > 3:
		return 0.0
	var v := 0.0
	for m in mods:
		v += ctx.stat_value((m as StatModifier).stat, (m as StatModifier).mode, (m as StatModifier).amount)
	for r in rules:
		v += (r as AbilityRule).estimated_value_per_sec(ctx)
	return v


## 一层总共值多少 = 每秒 × 平均待多久（[method PowerWeights.expected_duration]）+ 上身 / 到期那一下
func stack_value(ctx: PowerContext) -> float:
	if ctx.depth > 3:
		return 0.0
	var v := value_per_sec(ctx) * ctx.weights.expected_duration(duration_sec, is_permanent())
	for e in on_apply + on_expire:
		var x := (e as CombatEffect).estimated_value(ctx)
		if not is_nan(x):
			v += x
	return v
#endregion
