## 152（作者定）：buff **每层**带几层标准轴（[StatAxes]）——「每层血怒 = 一层【强攻】+ 一层【加速】」。
##
## 这些层数是**被包含**的：跟着 buff 的层数走（叠一层多一份、掉一层少一份），buff 没了它们也没了，
## 净化、到期、吃层都不用另管。结算时并进那条轴的合计（[method CombatantRuntime.axis_total]），
## 所以和道具直接 shift_axis 给的层、别的 buff 带的层直接相抵。
##
## 要「直接加 3% 伤害」这种量，写这里而不是 buff 的 mods：轴的步长是全局统一的（4.3），
## 数值平衡只调轴表一处
class_name BuffAxis
extends Resource

## 哪条轴，见 [StatAxes]
@export var axis: StringName = &""
## buff 每一层带几层（带符号：正 = 轴的正名，如【加速】；负 = 反名，如【减速】）
@export_range(-99, 99) var stacks: int = 1


static func make(p_axis: StringName, p_stacks: int = 1) -> BuffAxis:
	var a := BuffAxis.new()
	a.axis = p_axis
	a.stacks = p_stacks
	return a


## 「强攻 1 层」
func text() -> String:
	return "%s %d 层" % [StatAxes.name_of(axis, stacks), absi(stacks)]


## 编辑器在字段下画的灰字（[PropertyForm] 的 `editor_hint()` 约定）：这几层折成多少
func editor_hint() -> String:
	if axis == &"":
		return "先选一条标准轴"
	if not StatAxes.has(axis):
		return "没有这条标准轴 '%s' —— 导入会报错" % axis
	if stacks == 0:
		return "层数是 0，这条不起作用"
	return "每层 buff 带 %s。%s" % [text(), StatAxes.describe(axis, stacks).split("\n")[0]]
