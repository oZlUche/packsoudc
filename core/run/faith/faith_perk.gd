## 信仰级的效果（093，作者表的「1～5 级效果」）：写在信仰上、过了第 [member tier] 阶就生效，不属于某件道具（道具上的按阶功能仍是 [FaithBonus]）。
##
## 构件：每一条效果一个子类、注册表（RunRegistry.FAITH_PERKS）一行；信仰文件里 `perks: [{"tier": 1, "type": "..."}]`。
## 基类给出几个**落点**的钩子，子类只重写自己用得到的那个；各系统在自己的点上问 [method RunState.faith_perks]：
## - 编译期 [method compile_into]：往编译器的入参 [CompileInput] 里放东西（加规则、改属性、加轴层数）
## - 神坛 [method altar_label] / [method altar_apply]：休息处神坛上的特殊操作（和献祭二选一，共用这一次机会；不占休息）
## - 献祭之后 [method on_offered]
## - 踩上一个点 [method on_node_entered]
## - 掉落 [method modify_loot]
## - 战前准备屏 [method prebattle_label] / [method prebattle_apply]
class_name FaithPerk
extends Resource

## 第几阶起生效（1 = 过了第一道阈值）
@export var tier: int = 1
## 给界面的补充一句，接在字段生成的主句后面（104 第十节：不再覆盖主句）。
## 是 [TextTemplate] 模板：数要写成 `{字段名}`（[method params]），不写死
@export var note: String = ""


## 给界面的一句：字段生成的主句（[method _summary]）+ 作者的补充（[member note]）
func describe() -> String:
	var main := _summary()
	var extra := TextTemplate.render(note, params()) if note != "" else ""
	if main == "" or extra == "":
		return main + extra
	return "%s　%s" % [main, extra]


## 子类重写：按字段拼的主句
func _summary() -> String:
	return ""


## [member note] 的占位符：自己的数值字段（[TextParams]）
func params() -> Dictionary:
	return TextParams.of(self)


## 103：这条效果在战斗里是不是「通用 buff」—— 作用对象是角色本身（所有道具、基线、角色受到 / 造成的伤害）。
## 是的话返回给 buff 栏常驻格的一句（空串 = 不进栏：只作用于某件 / 某类道具的、不影响战斗的都返回空）。默认不进
func battle_note(_run: RunState) -> String:
	return ""


## 编译期（105）：往编译器的入参里放东西。
##
## [b]不再见到 [CombatantSpec][/b] —— 以前是编译完再改一遍编译结果，战斗单位于是有两个来源，
## 预估和真打也就有了两套路径。现在 perk 只会往 [CompileInput] 放：整单位的修饰 / 规则、
## 基线修饰、按件的 [ScopedMod]、轴的开战层数、结算旗子。
## [param board] 可以读（perk 在 `core/run`，数棋盘上的食物没问题），[param run] 给局内的账
func compile_into(_input: CompileInput, _board: GridInventory, _run: RunState) -> void:
	pass


## 神坛上的按钮文字；空 = 这条效果不是神坛操作
func altar_label() -> String:
	return ""


## 神坛操作现在能不能做：空串 = 能，否则是原因
func altar_available(_run: RunState, _node: MapNode) -> String:
	return ""


## 神坛操作要先挑一项（大地之神改造此点：挑类型）；空 = 不用挑
func altar_options() -> Array[StringName]:
	return [] as Array[StringName]


## 做神坛操作（[param option] 是挑的那一项，不用挑就空）。返回给日志的一句（空 = 没做）
func altar_apply(_run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	return ""


## 献祭了这些道具之后（自然之神：献祭食物回体力）。返回给日志的一句
func on_offered(_run: RunState, _defs: Array, _node: MapNode) -> String:
	return ""


## 踩上一个点之后（大地之神：给对应类型的道具）。返回给日志的一句
func on_node_entered(_run: RunState, _node: MapNode, _first_visit: bool) -> String:
	return ""


## 掉落计算时改上下文（日神：必掉额外一件）
func modify_loot(_ctx: LootContext, _node_type: StringName) -> void:
	pass


## 战前准备屏的额外按钮；空 = 没有
func prebattle_label(_run: RunState, _type: StringName) -> String:
	return ""


## 战前准备屏按了那个按钮。返回 true = 这一场按它处理了
func prebattle_apply(_run: RunState) -> bool:
	return false
