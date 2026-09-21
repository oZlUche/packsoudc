## 一片高危区怎么**长出来**（架构文档 5.4 / 5.5）。长成什么样才算数见 [ZoneRules]。
##
## 高危区把「诱惑」做成**拓扑**：一片相连的节点，里面有精英守着、有好几个搜索点，
## 与外界只靠少数几个出入口相连。玩家看得见入口、看得见里面有什么，然后自己决定值不值。
##
## [b]它和路线一样是「长」出来的[/b]：某条路线走过半程、旁边还有空地时，从路线上岔出一个新起点，
## 跟着各条路线一环一环同步生长，直到软上限或周围没地方 —— 所以它占多大是和路线实时抢出来的，
## 不是事后在图上圈一块。
class_name DangerZoneSpec
extends Resource

## 环数少于这个值的地图上，这一片**根本不去长**，也不算缺。
@export var min_rings: int = 4

## false = 可选：没岔出来就跳过，这一次尝试照样算数（跳过了几片记在
## `layout_meta.zones_skipped`，不是不声不响）。
## true = 必须有：没岔出来这一次尝试作废，换种子重来。
@export var required: bool = true

## 路线走过几成之后才可能岔出高危区。0.5 = 半程。
## 太早岔出来，高危区会堵在出生点门口。
@export var start_after_progress: float = 0.5

## 过了半程之后，每走一环有多大概率岔出来。
## 到了最后一个能岔的环还没岔，就不再掷骰直接岔。
@export var spawn_chance: float = 0.5

## 软上限：长到这么多个点就停。**由地图规模决定** ——「环数 ≤ 键」用对应的值，
## 键从小到大找第一个够的；都不够就用最大的那个。硬上限是 [member ZoneRules.max_size]。
## 键写成字符串：JSON 的键本来就只能是字符串，表单里的字典编辑器也按字符串处理
@export var soft_cap_by_rings: Dictionary = {"5": 4, "7": 6, "99": 9}

## 区内至少几个精英。[b]M3-3c 才用到。[/b]
@export var min_elites: int = 1

## 区内至少几个搜索点 —— **没有收益的高危区只是惩罚，不是诱惑**。
## [b]M3-3c 才用到。[/b]
@export var min_search: int = 2


## 这张 [param ring_count] 环的图上要不要长这一片。
func applies_to(ring_count: int) -> bool:
	return ring_count >= min_rings


func soft_cap_for(ring_count: int) -> int:
	var keys: Array = soft_cap_by_rings.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	if keys.is_empty():
		return ZoneRules.DEFAULT_MAX_SIZE
	for k in keys:
		if ring_count <= int(k):
			return int(soft_cap_by_rings[k])
	return int(soft_cap_by_rings[keys[-1]])
