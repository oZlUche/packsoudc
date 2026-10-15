## 一种元素反应（175）：目标身上带着甲元素的印、又挨上乙元素 → 结算这里的效果。
##
## 数据在 `data/authoring/reactions/<甲>_<乙>.json`（两种元素按 [constant ReactionResolver.ELEMENTS] 的顺序拼 id）。
## 效果就是普通的规则内容（[CombatEffect]），以**攻击方**为主人跑：「对手」= 挨打的那一方，「自己」= 引发反应的那一方。
## 结算见 [ReactionResolver]（175 补充一，作者伪代码）：量 N = max(已有印的层数, 新来的层数)，已有印扣光、新来的不叠，再跑效果
class_name ReactionDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var display_names: Dictionary = {}
## 一句说明（百科的反应页、悬浮窗的词条）
@export_multiline var description: String = ""
@export var descriptions: Dictionary = {}
## 两种元素（`fire` / `ice` / `lightning` / `poison` / `bleed`），不分先后
@export var elements: Array[StringName] = []
## 效果。层数类（`per_stack`：「每层 3 点」、施加几层）读的是反应的量 N（[member RuleContext.reaction_stacks]，见 [ReactionResolver]）
@export var effects: Array[CombatEffect] = []


func has_element(element: StringName) -> bool:
	return elements.has(element)
