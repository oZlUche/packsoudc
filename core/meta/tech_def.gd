## 局外科技（110）：一张定义 + [MetaState] 里通用的等级 / 上交记录。仓库扩建是第一条内容。
## 走内容管线：`data/authoring/techs/*.json` → `data/techs/*.tres`；逻辑见 [TechService]
##
## 118（作者定）：科技排成一棵树 —— [member requires] 是前置（每一项至少 1 级才能点本节点），[member column] 是第几列；
## 深度不写，按前置算（根 0，其余 = 前置里最深的 + 1，[method TechService.depth_of]），界面里深度 0 在最下面、往上长
class_name TechDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的名字，`{"en": "..."}`
@export var display_names: Dictionary = {}
## 科技页的先后（小的在前）；118：同列同深度撞位时按它左右排
@export var order: int = 0
## 118：前置科技 id —— 每一项都至少 1 级才能点本节点。空 = 根节点
@export var requires: Array[StringName] = []
## 118：树上的列（0 起，从左往右）
@export var column: int = 0
## 118：说明面板「效果」区的一句总述（占位符照 112，不写数字 —— 数字由各级的 [method TechEffect.describe_level] 生成）
@export_multiline var description: String = ""
## 221 F5: description in other languages, {"en": ...}; read with [method Names.description_of]
@export var descriptions: Dictionary = {}
## 每升一级做什么
@export var effect: TechEffect = null
## 各级要什么：下标 0 = 升到第 1 级；有几项就有几级
@export var tiers: Array[TechTier] = []


## 一共几级
func max_level() -> int:
	return tiers.size()
