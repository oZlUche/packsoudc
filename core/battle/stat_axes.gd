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

enum Mode { PERCENT, FLAT }

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
}

## 显示顺序（面板）
const ORDER: Array[StringName] = [ATTACK_SPEED, DAMAGE_DEALT, DAMAGE_TAKEN, REGEN_HP, REGEN_HP_PCT, REGEN_STAMINA, CRIT_CHANCE, CRIT_DAMAGE, FIRE_DAMAGE]


static func has(axis: StringName) -> bool:
	return TABLE.has(axis)


static func info(axis: StringName) -> Dictionary:
	return TABLE.get(axis, {})


static func stat_of(axis: StringName) -> StringName:
	return info(axis).get("stat", &"")


static func is_percent(axis: StringName) -> bool:
	return int(info(axis).get("mode", Mode.PERCENT)) == Mode.PERCENT


## 每层步长：百分比轴是百分数（3.0 = 3%），固定值轴是每层的量
static func step_of(axis: StringName) -> float:
	return float(info(axis).get("step", 0.0))


## 百分比轴的因子（定点）：1 + 层数 × 步长，低于 0 钳到 0
static func factor(axis: StringName, stacks: int) -> int:
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
	var step := step_of(axis)
	var unit := "%" if is_percent(axis) else ""
	if bool(info(axis).get("pct", false)):
		step *= 100.0
		unit = "%"
	var what: String = {
		ATTACK_SPEED: "攻速", DAMAGE_DEALT: "造成的伤害", DAMAGE_TAKEN: "受到的最终伤害",
		REGEN_HP: "每秒回血", REGEN_HP_PCT: "每秒按生命上限回血", REGEN_STAMINA: "每秒回耐力",
		CRIT_CHANCE: "暴击率", CRIT_DAMAGE: "暴击伤害", FIRE_DAMAGE: "造成的火焰伤害",
	}.get(axis, String(axis))
	var lines: Array[String] = ["%s：每层 %s%s%s（正为%s、负为%s，相抵）" % [
		what, "±", _num(step), unit, String(info(axis).get("pos", "")), String(info(axis).get("neg", ""))]]
	var total := stacks + system_stacks
	lines.append("现在 %+d 层 → %s%s%s" % [total, "+" if total >= 0 else "−", _num(absf(total * step)), unit])
	if system_stacks != 0:
		lines.append("其中 %+d 层来自系统规则，不可解除" % system_stacks)
	return "\n".join(lines)


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## 一条 mod 是不是落在某条轴的属性上（导入器：只有这一条 mod 的简单 buff 提示改用轴）
static func axis_for_stat(stat: StringName) -> StringName:
	for a in ORDER:
		if stat_of(a) == stat and stat != &"":
			return a
	return &""
