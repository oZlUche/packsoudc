## 敌人池里的一行：谁、多重、在哪儿出现（架构文档 6.0）。
##
## 「根据地图类型配置不同敌人」落在 [member kinds]：环的种类（`RingSpec.kind`，生成器写进
## 节点 layout 的 `kind`）就是地图类型 —— 废墟里出拾荒者，深处出守卫。空 = 哪儿都出。
class_name EnemyPoolEntry
extends Resource

@export var enemy: StringName = &""
@export var weight: float = 1.0

## 只在这些环种类里出现（对应节点 `layout.kind`）。空 = 不限
@export var kinds: Array[StringName] = []

## 只在这些节点类型里出现（battle / elite / core）。空 = 池的 combat_types 全部
@export var node_types: Array[StringName] = []

## 危险等级至少多少才出现
@export var min_danger: int = 0


func fits(node: MapNode) -> bool:
	if node.danger < min_danger:
		return false
	if not node_types.is_empty() and not node_types.has(node.type):
		return false
	if not kinds.is_empty():
		var kind := StringName(String(node.layout.get("kind", "")))
		if not kinds.has(kind):
			return false
	return true
