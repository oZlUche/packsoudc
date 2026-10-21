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

## 171（作者定）：是否有专属解说 —— 悬浮窗的增益 / 受益句提到这个 buff 时，有解说写解说、没有只写名字（基础轴的 buff 直接用名字）
@export var has_blurb: bool = false
## 171：解说文本（`has_blurb` 真才显示、才写进 JSON）；`blurbs` 是别的语言，`{"en": "…"}`（和 display_names 同款）
@export_multiline var blurb: String = ""
@export var blurbs: Dictionary = {}

## 111：解说两栏只在勾了「有专属解说」时显示；175 补充四：按层计时与减半只给可叠层的
const FIELD_WHEN := {"blurb": {"has_blurb": [true]}, "blurbs": {"has_blurb": [true]},
	"seconds_per_stack": {"stackable": [true]}, "decay_halve_on": {"stackable": [true]}}

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
## 175 补充四：**按层计时**（0 = 不计时，永续）—— 每叠上一层，剩余时间加这么多秒；每秒倒数一次（和 on_schedule 同一个时间轮，
## 排在自己的规则后面：到点的那一跳照样跳），倒数到 0 整个移除。燃血 / 菌血：N 层 = 每秒 N 点 / 持续 N 秒，再反应加层也加时间。
## 是 085「可叠层永续」的例外（作者 175 补充四原话：持续 N 秒、重新反应会延长时间）
@export var seconds_per_stack: int = 0
## 175 补充四：在这个时机把层数减半（向下取整，1 → 0 移除）：空 = 不减半；`tick` = 自己的周期规则每结算一次之后（流血）；
## `weapon_fired` = 挂着它的单位的武器每出手一次（寒冷）；`stamina_paid` = 挂着它的单位每付一次耐力（麻痹）。
## 两种衰减都不低于实例的保底层数（[member BuffInstance.guard]）
@export var decay_halve_on: StringName = &""

const HALVE_TICK := &"tick"
const HALVE_WEAPON_FIRED := &"weapon_fired"
const HALVE_STAMINA_PAID := &"stamina_paid"
const HALVE_ON: Array[StringName] = [&"", HALVE_TICK, HALVE_WEAPON_FIRED, HALVE_STAMINA_PAID]


## 可叠层（137：可叠就是不限层）
func is_stackable() -> bool:
	return stackable


## 叠到 [param n] 层之后实际是几层（不可叠固定 1 层；175 补充四：可叠层的不封顶）
func capped(n: int) -> int:
	return n if is_stackable() else 1


## 175 补充四：[member seconds_per_stack] 的那条规则（自发、每秒一次、倒数剩余时间），[method CombatantRuntime.apply_buff] 和 [member rules] 一起登记，
## 排在 rules 后面（同一刻先跳伤再倒数：燃血 3 层在第 1、2、3 秒各打 3 点，第 3 秒那一跳之后消失）。不写进内容
func decay_rule() -> AbilityRule:
	if seconds_per_stack <= 0 or not is_stackable():
		return null
	if _decay_rule == null:
		var cd := CooldownCadence.new()
		cd.seconds = 1.0
		cd.use_haste = false
		var e := StatusDecay.new()
		_decay_rule = AbilityRule.new()
		_decay_rule.trigger = OnSchedule.new()
		_decay_rule.cadence = cd
		_decay_rule.effects = [e] as Array[CombatEffect]
	return _decay_rule

var _decay_rule: AbilityRule = null


## 永续：不过期，到战斗结束 —— 可叠层的一律永续；不可叠层的没填时长也永续
func is_permanent() -> bool:
	return is_stackable() or duration_sec <= 0.0


## 171：句子里怎么称呼它 —— 有专属解说写解说（当前语言没有用中文），否则名字
func sentence_text(lang: String = "") -> String:
	if has_blurb and blurb.strip_edges() != "":
		return Names.pick(blurbs, blurb, lang)
	return Names.of(self, lang)


## 给界面看的时长一句：「永续」/「持续 N 秒」
func duration_text() -> String:
	if seconds_per_stack > 0 and is_stackable():
		return UiText.t("battle.dur_per_stack")     # 175 补充四：燃血 / 菌血（具体那句在词条正文里）
	return UiText.t("battle.dur_permanent") if is_permanent() else UiText.t("battle.dur_seconds") % duration_sec

@export_group("效果")
## 152（作者定）：**每层**带几层标准轴 ——「每层血怒 = 一层【强攻】+ 一层【加速】」。层数跟着 buff 走（[BuffAxis]）。
## 能用轴表达的增减（伤害、攻速、回血、暴击……）写这里，不写 [member mods]；导入器对 mods 里落在轴上的那几条给提醒
@export var axes: Array[BuffAxis] = []
## **每层一份**，走 4.3 公式。轴表达不了的属性（护甲上限这类）写这里
@export var mods: Array[StatModifier] = []
## buff 自己也能带触发规则 —— 这是「复合效果」成立的关键。
## 「灼烧：每层每秒掉 2 点血」= 挂在这里的一条 OnTick + Cooldown(1s) + DealDamage，
## BattleSim 里不需要为灼烧写任何特例。
@export var rules: Array[AbilityRule] = []
@export var on_apply: Array[CombatEffect] = []
@export var on_expire: Array[CombatEffect] = []

@export_group("元素与治疗")
## 175：这个状态是哪种元素的【印】（`fire` / `ice` / `lightning` / `poison` / `bleed`，和伤害类型同名）；空 = 不是印。
## 补充四：五种基础状态灼伤 / 寒冷 / 麻痹 / 中毒 / 流血各是一种元素的印。目标身上带着一种印、又挨上另一种 → 反应（[ReactionResolver]）
@export var element: StringName = &""
## 175：挂着它时，目标**每次恢复生命**先被截走这么多（百分比，0..100）。燃血 100 = 治疗无效
@export var heal_cut: int = 0
## 175 补充一：挂着它时，目标**每次恢复生命**后按实际恢复量叠这个状态（菌血 = `poison`：回了 7 点就加 7 层中毒，恢复照常）；空 = 不叠
@export var heal_echo: StringName = &""
## 175 补充一：恢复一点叠几层 [member heal_echo]
@export var heal_echo_per_point: float = 1.0
## 175 补充四：每层的百分比（寒冷：武器这一次的冷却每层 +X%；麻痹：这一次的耐力消耗每层 +X%）。作者会调，写在 json 里
@export var per_stack_percent: float = 0.0
## 175 补充四：挂着它时，**受到**这些类型的伤害每层 +X%（`{"poison": 25}`，剧毒）。伤害管线第 4 步、「受到伤害」轴之后乘一次，不加轴
@export var damage_taken_by_type: Dictionary = {}


## 152：每层带几层 [param axis]（同一条轴写了几行就相加）
func axis_stacks_per(axis: StringName) -> int:
	var n := 0
	for a in axes:
		if a != null and (a as BuffAxis).axis == axis:
			n += (a as BuffAxis).stacks
	return n


#region 151 战斗力估算
## 一层挂在某一边身上，每秒对那一边值多少（[param ctx] 是那一边的角度，[method PowerContext.for_carrier]）：
## 带的轴层 + 属性修饰 + 自己的规则（流血：每层每秒伤自己一点 = −1）
func value_per_sec(ctx: PowerContext) -> float:
	if ctx.depth > 3:
		return 0.0
	var v := 0.0
	for a in axes:
		if a != null and StatAxes.has((a as BuffAxis).axis):
			v += (a as BuffAxis).stacks * ctx.axis_value((a as BuffAxis).axis)
	for m in mods:
		v += ctx.stat_value((m as StatModifier).stat, (m as StatModifier).mode, (m as StatModifier).amount)
	for r in rules:
		v += (r as AbilityRule).estimated_value_per_sec(ctx)
	return v


## 一层总共值多少 = 每秒 × 平均待多久（[method PowerWeights.expected_duration]；155：可叠层的按一场的一半）+ 上身 / 到期那一下
func stack_value(ctx: PowerContext) -> float:
	if ctx.depth > 3:
		return 0.0
	var v := value_per_sec(ctx) * ctx.weights.expected_duration(duration_sec, is_permanent(), is_stackable())
	for e in on_apply + on_expire:
		var x := (e as CombatEffect).estimated_value(ctx)
		if not is_nan(x):
			v += x
	return v
#endregion
