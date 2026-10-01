## 加时与衰竭（103 第 4 条，作者定）：打到第 [member starts_at_sec] 秒起双方受到的最终伤害 +[member damage_taken_percent]%，
## 之后每 [member stack_every_sec] 秒再叠一层；第 [member decay_starts_at_sec] 秒起双方每 [member decay_every_sec] 秒掉
## [member decay_amount] 点生命上限，直到一方倒下 —— 从此没有平局。
##
## [b]不在 BattleSim 里写特例[/b]：两种效果都是「系统 buff」（不限层、永续、不可解除），走 4.3 公式、4.5 叠层、面板与词条；
## 模拟循环只多一种「系统时刻」（[method next_at]）。数值在这里，每章的 [NodeRules] 可以各给一份。
class_name OvertimeRules
extends Resource

const OVERTIME_ID := &"overtime"
const DECAY_ID := &"decay"

## 加时从第几秒开始
@export var starts_at_sec: float = 30.0
## 之后每隔几秒再叠一层
@export var stack_every_sec: float = 5.0
## 每层：受到的最终伤害 +N%
@export var damage_taken_percent: int = 20
## 衰竭从第几秒开始
@export var decay_starts_at_sec: float = 60.0
## 每隔几秒掉一次
@export var decay_every_sec: float = 1.0
## 每次掉多少生命上限（固定值）
@export var decay_amount: float = 5.0

var _overtime: BuffDef = null
var _decay: BuffDef = null

static var _default: OvertimeRules = null


## 没给就用默认那份（加时必须一直在：沙盒、猎手校准和真打对得上）
static func or_default(rules: OvertimeRules) -> OvertimeRules:
	if rules != null:
		return rules
	if _default == null:
		_default = OvertimeRules.new()
	return _default


## 鏖战：每层受到的最终伤害 +N%（[constant BattleStats.DAMAGE_TAKEN] 的乘区）
func overtime_buff() -> BuffDef:
	if _overtime == null:
		_overtime = _system_buff(OVERTIME_ID, "鏖战", "Overtime")
		var m := StatModifier.new()
		m.stat = BattleStats.DAMAGE_TAKEN
		m.mult_category = StatMath.Buff.EMPOWER
		m.mult_percent = damage_taken_percent
		_overtime.mods.append(m)
	return _overtime


## 衰竭：每层生命上限 −N（固定值）
func decay_buff() -> BuffDef:
	if _decay == null:
		_decay = _system_buff(DECAY_ID, "衰竭", "Decay")
		var m := StatModifier.new()
		m.stat = BattleStats.MAX_HP
		m.flat = -decay_amount
		_decay.mods.append(m)
	return _decay


static func _system_buff(id: StringName, zh: String, en: String) -> BuffDef:
	var d := BuffDef.new()
	d.id = id
	d.display_name = zh
	d.display_names = {"en": en}
	d.is_debuff = true
	d.system = true
	return d


## 第 [param index] 次（从 0 数）加时 / 衰竭的时刻，定点
func overtime_at(index: int) -> int:
	return StatMath.from_float(starts_at_sec) + index * StatMath.from_float(maxf(0.001, stack_every_sec))


func decay_at(index: int) -> int:
	return StatMath.from_float(decay_starts_at_sec) + index * StatMath.from_float(maxf(0.001, decay_every_sec))


## 导入器用：数值合不合理。返回错误列表（[路径, 说明]）
func problems() -> Array:
	var out: Array = []
	if starts_at_sec <= 0.0:
		out.append(["starts_at_sec", "加时开始时刻应为正"])
	if stack_every_sec <= 0.0:
		out.append(["stack_every_sec", "叠层间隔应为正"])
	if decay_every_sec <= 0.0:
		out.append(["decay_every_sec", "衰竭间隔应为正"])
	if decay_amount <= 0.0:
		out.append(["decay_amount", "衰竭每次掉的生命上限应为正 —— 否则可能永远分不出胜负"])
	if decay_starts_at_sec < starts_at_sec:
		out.append(["decay_starts_at_sec", "衰竭不应早于加时"])
	return out
