## 局外科技（110）：一张定义 + [MetaState] 里通用的等级 / 上交记录。仓库扩建是第一条内容。
## 走内容管线：`data/authoring/techs/*.json` → `data/techs/*.tres`；逻辑见 [TechService]
class_name TechDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的名字，`{"en": "..."}`
@export var display_names: Dictionary = {}
## 科技页的先后（小的在前）
@export var order: int = 0
## 每升一级做什么
@export var effect: TechEffect = null
## 各级要什么：下标 0 = 升到第 1 级；有几项就有几级
@export var tiers: Array[TechTier] = []


## 一共几级
func max_level() -> int:
	return tiers.size()
