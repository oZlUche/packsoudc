## 信仰级的效果（093，作者表的「1～5 级效果」）：写在信仰上、过了第 [member tier] 阶就生效，不属于某件道具（道具上的按阶功能仍是 [FaithBonus]）。
##
## 构件：每一条效果一个子类、注册表（EffectRegistry.FAITH_PERKS）一行；信仰文件里 `perks: [{"tier": 1, "type": "..."}]`。
## 基类给出几个**落点**的钩子，子类只重写自己用得到的那个；各系统在自己的点上问 [method RunState.faith_perks]：
## - 编译期 [method modify_spec]：开战时在编译好的玩家战斗单位上做手脚（加规则、改属性）
## - 神坛 [method altar_label] / [method altar_apply]：休息处神坛上的特殊操作（和献祭二选一，共用这一次机会；不占休息）
## - 献祭之后 [method on_offered]
## - 踩上一个点 [method on_node_entered]
## - 掉落 [method modify_loot]
## - 战前准备屏 [method prebattle_label] / [method prebattle_apply]
## - 战斗收尾 [method draw_is_win]
class_name FaithPerk
extends Resource

## 第几阶起生效（1 = 过了第一道阈值）
@export var tier: int = 1
## 给界面的一句（空就用 describe）
@export var note: String = ""


func describe() -> String:
	return note


## 编译期：开战那一瞬在玩家的战斗单位上做手脚。[param run] 给随机数（可复现：按节点与用途取）与局内账
func modify_spec(_spec: CombatantSpec, _board: GridInventory, _run: RunState) -> void:
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


## 平局算赢（自然之神 5 级）
func draw_is_win() -> bool:
	return false
