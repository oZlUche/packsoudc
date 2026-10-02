## 开战时带几层某条标准轴（105 第十节）：`axis_boost{axis, stacks}`。
##
## 通用构件，不属于哪位神 ——「开战带 n 层 X」这类效果任何神都能用（日神 3 级的 5 层「灵巧」是第一个用例）。
## 层数填进 [member CompileInput.axes]，编译器写进 [member CombatantSpec.axes]，运行时种进**系统层**：
## 这一场的常驻加成，对手的净化洗不掉（105 作者定）。
##
## buff 栏不另画一格：层数本来就按 103 的规矩画成轴格（「灵巧 ×5」），所以 [method battle_note] 返回空
class_name AxisBoostPerk
extends FaithPerk

## 哪条轴（[StatAxes.TABLE] 里的 id；导入器按表校验）
@export var axis: StringName = &""
## 开战带几层（带符号：负层是减益）
@export var stacks: int = 0


func compile_into(input: CompileInput, _board: GridInventory, _run: RunState) -> void:
	if axis == &"" or stacks == 0:
		return
	input.shift_axis(axis, stacks)


func _summary() -> String:
	if axis == &"" or stacks == 0:
		return ""
	return "开战时获得 %d 层「%s」（%s）" % [absi(stacks), StatAxes.name_of(axis, stacks), StatAxes.describe(axis, stacks).get_slice("\n", 0)]
