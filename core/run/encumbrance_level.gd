## 129：负重的一级（[EncumbranceRules.levels] 的一行）
class_name EncumbranceLevel
extends Resource

## 负重超过上限的这么多倍（严格大于）才到这一级
@export var over: float = 1.0
@export var display_name: String = ""
@export var display_names: Dictionary = {}
## 战斗减益。`regen_*` / `max_*` 的 `flat` 写的是**基线的比例**（−0.1 = 一成），由 [method EncumbranceRules.combat_mods] 乘基线折成真值；
## 别的属性（急速走乘区）照原样用
@export var mods: Array[StatModifier] = []
## 走一步（含传送）花的行动点乘几；原地等待不乘
@export var travel_mult: int = 1
