## 标准轴（架构文档 4.3「标准轴」，报告 103 4e，作者定）：单位级的带符号层数。
##
## 每个战斗单位每条轴一个 int 层数，默认 0：增益为正、减益为负、直接相抵（3 层加速 + 1 层减速 = +2）。
## 结算是公式的最后一步、在道具级终值之上：百分比轴 `终值 × (1 + 层数 × 步长)`（因子低于 0 钳到 0），
## 固定值轴 `终值 + 层数 × 步长`。系统层（加时这类系统规则施加的）单独记，净化只动内容层。
##
## **新加一条轴 = 这张表加一行**：结算、面板、词条、导入器校验全部跟着表走，不改公式代码。
## 和乘区枚举一样属于架构而不是内容，步长是推荐起点，可调
class_name StatAxes
extends RefCounted

const ATTACK_SPEED := &"attack_speed"
const DAMAGE_DEALT := &"damage_dealt"
const DAMAGE_TAKEN := &"damage_taken"
const REGEN_HP := &"regen_hp"
const REGEN_HP_PCT := &"regen_hp_pct"
const REGEN_STAMINA := &"regen_stamina"
## 104：暴击的两条固定值轴（暴击只接受加算）。步长是属性本身的单位（0.01 = 1%），显示按百分数
const CRIT_CHANCE := &"crit_chance"
const CRIT_DAMAGE := &"crit_damage"
## 105（作者定）：火焰伤害加成是一条普通增益轴 —— 祈祷攒的层数在这里，伤害管线按攻方读。
## 放大的是**所有**火焰来源（附魔、灼烧、任何火焰伤害），不是只有附魔那一下
const FIRE_DAMAGE := &"fire_damage"
## 106（作者定）：防护、生命上限、法力上限都是角色自己的量 —— 单位级固定值轴，不落到每件道具上。
## 防护为负（破绽）**倒贴**：直接伤害反而变多（[DamageResolver] 第 4 步）；法力上限归零由 `ResourcePool.set_max` 兜底
## 153（作者定）：防护改名格挡。这条轴是**加在生效的那层格挡之上**的修正（盾牌各一层、只取最高，[CombatantRuntime]），
## 正名【加固】（不和属性名「格挡」撞）、负名【破绽】，为负照 106 倒贴
const BLOCK := &"block"
const MAX_HP := &"max_hp"
const MAX_MANA := &"max_mana"
## 105 第十节（作者定）：耐力消耗按层数**连乘** —— 5 层 = ×0.97^5 ≈ 85.9%。
## 只有武器消耗耐力，所以是单位级的一条轴，不按件筛
const STAMINA_COST := &"stamina_cost"

## PERCENT：`终值 × (1 + 层数 × 步长%)`，层数间**加算**（3 层加速 = +9%）。
## FLAT：`终值 + 层数 × 步长`。
## COMPOUND（105 第十节）：`终值 × (步长/100)^层数`，层数间**连乘**（5 层灵巧 = ×0.97^5）——
## 作者给耐力消耗定的就是这条曲线：每层省掉当前的 3%，而不是各层相加。
## 加一种模式只是多一种**因子算法**；道具级的公式（4.3 的乘区与 flat）一个字没动，轴仍是公式之后的最后一步
enum Mode { PERCENT, FLAT, COMPOUND }

## id → {stat: 作用的属性（空 = 不直接落在属性上：受到伤害与火焰伤害由伤害管线读，按上限回血折进 regen_hp）, mode, step: 百分比轴是百分数、固定值轴是每层的量, pos, neg,
## items: 固定值轴也落到每件道具上（暴击按道具读，104）, pct: 固定值按百分数显示}
const TABLE := {
	ATTACK_SPEED: {"stat": &"haste", "mode": Mode.PERCENT, "step": 3.0, "pos": "加速", "neg": "减速"},
	DAMAGE_DEALT: {"stat": &"damage", "mode": Mode.PERCENT, "step": 3.0, "pos": "强攻", "neg": "虚弱"},
	DAMAGE_TAKEN: {"stat": &"", "mode": Mode.PERCENT, "step": 5.0, "pos": "易伤", "neg": "坚韧"},
	REGEN_HP: {"stat": &"regen_hp", "mode": Mode.FLAT, "step": 1.0, "pos": "回春", "neg": "失血"},
	REGEN_HP_PCT: {"stat": &"", "mode": Mode.PERCENT, "step": 1.0, "pos": "再生", "neg": "腐蚀"},
	REGEN_STAMINA: {"stat": &"regen_stamina", "mode": Mode.FLAT, "step": 1.0, "pos": "回气", "neg": "疲乏"},
	CRIT_CHANCE: {"stat": &"crit_chance", "mode": Mode.FLAT, "step": 0.01, "pos": "锐目", "neg": "失准", "items": true, "pct": true},
	CRIT_DAMAGE: {"stat": &"crit_damage", "mode": Mode.FLAT, "step": 0.05, "pos": "致命", "neg": "钝击", "items": true, "pct": true},
	FIRE_DAMAGE: {"stat": &"", "mode": Mode.PERCENT, "step": 3.0, "pos": "炽烈", "neg": "熄火"},
	STAMINA_COST: {"stat": &"stamina_cost", "mode": Mode.COMPOUND, "step": 97.0, "pos": "灵巧", "neg": "笨拙"},
	BLOCK: {"stat": &"block", "mode": Mode.FLAT, "step": 1.0, "pos": "加固", "neg": "破绽"},
	MAX_HP: {"stat": &"max_hp", "mode": Mode.FLAT, "step": 1.0, "pos": "生长", "neg": "衰颓"},
	MAX_MANA: {"stat": &"max_mana", "mode": Mode.FLAT, "step": 1.0, "pos": "充盈", "neg": "枯竭"},
}

## 显示顺序（面板）
const ORDER: Array[StringName] = [ATTACK_SPEED, DAMAGE_DEALT, DAMAGE_TAKEN, REGEN_HP, REGEN_HP_PCT, REGEN_STAMINA, CRIT_CHANCE, CRIT_DAMAGE, FIRE_DAMAGE, STAMINA_COST, BLOCK, MAX_HP, MAX_MANA]


static func has(axis: StringName) -> bool:
	return TABLE.has(axis)


static func info(axis: StringName) -> Dictionary:
	return TABLE.get(axis, {})


static func stat_of(axis: StringName) -> StringName:
	return info(axis).get("stat", &"")


static func mode_of(axis: StringName) -> int:
	return int(info(axis).get("mode", Mode.PERCENT))


static func is_percent(axis: StringName) -> bool:
	return mode_of(axis) == Mode.PERCENT


static func is_compound(axis: StringName) -> bool:
	return mode_of(axis) == Mode.COMPOUND


## 这条轴是不是「乘一个因子」型（PERCENT 与 COMPOUND 都是）—— 结算走同一条路，只是因子算法不同
static func is_factor(axis: StringName) -> bool:
	return mode_of(axis) != Mode.FLAT


## 每层步长：百分比轴是百分数（3.0 = 3%），固定值轴是每层的量
static func step_of(axis: StringName) -> float:
	return float(info(axis).get("step", 0.0))


## 因子型轴的因子（定点）。
##
## PERCENT：`1 + 层数 × 步长`，低于 0 钳到 0。
## COMPOUND：`(步长/100)^层数` —— **不用 `pow`**：层数是小整数，逐次 [method StatMath.mul] 循环几下就完，
## 跨平台逐位一致（4.3「全程定点」）。负层是反过来除，所以「+5 层灵巧 −2 层笨拙」= ×0.97³，和相抵一致
static func factor(axis: StringName, stacks: int) -> int:
	if is_compound(axis):
		var per := StatMath.from_float(step_of(axis) / 100.0)
		var f := StatMath.ONE
		for _i in absi(stacks):
			f = StatMath.mul(f, per)
		return f if stacks >= 0 else StatMath.div(StatMath.ONE, maxi(1, f))
	return maxi(0, StatMath.ONE + StatMath.from_float(stacks * step_of(axis) / 100.0))


## 名字：正层用正名、负层用负名
static func name_of(axis: StringName, stacks: int) -> String:
	var i := info(axis)
	if i.is_empty():
		return String(axis)
	return String(i["neg"]) if stacks < 0 else String(i["pos"])


## 固定值轴是不是也落到每件道具上（104：暴击按道具读）
static func on_items(axis: StringName) -> bool:
	return bool(info(axis).get("items", false))


## 给 buff 栏悬浮窗的一句
static func describe(axis: StringName, stacks: int, system_stacks: int = 0) -> String:
	if is_compound(axis):
		return _describe_compound(axis, stacks, system_stacks)
	var step := step_of(axis)
	var unit := "%" if is_percent(axis) else ""
	if bool(info(axis).get("pct", false)):
		step *= 100.0
		unit = "%"
	var what := what_of(axis)
	var lines: Array[String] = ["%s：每层 %s%s%s" % [what, "±", _num(step), unit]]
	var total := stacks + system_stacks
	lines.append("现在 %+d 层 → %s%s%s" % [total, "+" if total >= 0 else "−", _num(absf(total * step)), unit])
	if system_stacks != 0:
		lines.append("其中 %+d 层无法清除" % system_stacks)
	return "\n".join(lines)


## 这条轴作用在什么上（悬浮窗用的全称）
static func what_of(axis: StringName) -> String:
	return String({
		ATTACK_SPEED: "攻速", DAMAGE_DEALT: "造成的伤害", DAMAGE_TAKEN: "受到的最终伤害",
		REGEN_HP: "每秒回血", REGEN_HP_PCT: "每秒按生命上限回血", REGEN_STAMINA: "每秒回耐力",
		CRIT_CHANCE: "暴击率", CRIT_DAMAGE: "暴击伤害", FIRE_DAMAGE: "造成的火焰伤害",
		BLOCK: "格挡", MAX_HP: "生命上限", MAX_MANA: "法力上限",
		STAMINA_COST: "耐力消耗",
	}.get(axis, String(axis)))


## 152：[param stacks] 层折成多少，短的一句（「造成的伤害 +3%」「格挡 −3」「耐力消耗 ×97%」）
static func effect_text(axis: StringName, stacks: int) -> String:
	var what := what_of(axis).split("（")[0]
	if is_compound(axis):
		return "%s ×%.1f%%" % [what, StatMath.to_float(factor(axis, stacks)) * 100.0]
	var step := step_of(axis)
	var unit := "%" if is_percent(axis) else ""
	if bool(info(axis).get("pct", false)):
		step *= 100.0
		unit = "%"
	return "%s %s%s%s" % [what, "+" if stacks >= 0 else "−", _num(absf(stacks * step)), unit]


## 连乘轴的一句：每层乘一个因子，现在共乘了多少
static func _describe_compound(axis: StringName, stacks: int, system_stacks: int) -> String:
	var i := info(axis)
	var per := step_of(axis)
	var what := what_of(axis)
	var lines: Array[String] = ["%s：每层 ×%s%%" % [what, _num(per)]]
	var total := stacks + system_stacks
	lines.append("现在 %+d 层 → ×%.1f%%" % [total, StatMath.to_float(factor(axis, total)) * 100.0])
	if system_stacks != 0:
		lines.append("其中 %+d 层无法清除" % system_stacks)
	return "\n".join(lines)


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## 一条 mod 是不是落在某条轴的属性上（导入器：只有这一条 mod 的简单 buff 提示改用轴）
static func axis_for_stat(stat: StringName) -> StringName:
	for a in ORDER:
		if stat_of(a) == stat and stat != &"":
			return a
	return &""
