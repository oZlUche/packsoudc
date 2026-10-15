## 一种元素反应（175）：目标身上带着甲元素的印、又挨上乙元素 → 结算这里的效果。
##
## 数据在 `data/authoring/reactions/<甲>_<乙>.json`（两种元素按 [constant ReactionResolver.ELEMENTS] 的顺序拼 id）。
## 效果就是普通的规则内容（[CombatEffect]），以**攻击方**为主人跑：「对手」= 挨打的那一方，「自己」= 引发反应的那一方。
## 结算顺序见 [ReactionResolver]：先记下两边印的层数，再按 [member consume] 吃掉印，最后跑效果
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
## 吃掉哪边的印：`both`（默认）/ `none` / 某一种元素（只吃那一边的）。凝毒要留着中毒和寒印，电解要留着中毒去升阶
@export var consume: StringName = &"both"
## 效果。层数类（「每层 3 点」的 per_stack）读的是**被吃掉的印的层数**（爆燃吃掉几层中毒就打几层）
@export var effects: Array[CombatEffect] = []

const CONSUME_BOTH := &"both"
const CONSUME_NONE := &"none"


## 这一边（元素）的印要不要吃掉
func consumes(element: StringName) -> bool:
	if consume == CONSUME_NONE:
		return false
	return consume == CONSUME_BOTH or consume == element


func has_element(element: StringName) -> bool:
	return elements.has(element)
