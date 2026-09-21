## 一片高危区（架构文档 5.4）。
##
## 高危区把「诱惑」做成**拓扑**：一片与外界只有一条边相连的区域，里面有精英守着、
## 有好几个搜索点。进去就得从同一条路出来，行动点花两遍。
## 玩家看得见入口、看得见里面有什么，然后自己决定值不值。
class_name DangerZoneSpec
extends Resource

## 落在哪几环之间（含）。环号自内向外：1 是最内环，环数是最外环。
@export var ring_range: Vector2i = Vector2i(1, 3)

## 环数少于这个值的地图上，这一片**根本不去长**，也不算缺。
##
## 高危区要避开骨架与换乘弧，而换乘弧会占满它所在的那一环；环太少时能落脚的地方
## 只剩一环，生成器就得靠反复重试去碰运气（四环时平均要试五次）。
## 与其让重试替配置擦屁股，不如直接说清楚：小地图没有高危区。
@export var min_rings: int = 5

## false = 可选：长不起来就跳过，这一次尝试照样算数（跳过了几片记在
## `layout_meta.zones_skipped`，不是不声不响）。
## true = 必须有：长不起来这一次尝试作废，换种子重来。
@export var required: bool = true

## 节点数范围 [min, max]
@export var size: Vector2i = Vector2i(4, 6)

## 区内至少几个精英。[b]M3-3c 才用到。[/b]
@export var min_elites: int = 1

## 区内至少几个搜索点 —— **没有收益的高危区只是惩罚，不是诱惑**。
## [b]M3-3c 才用到。[/b]
@export var min_search: int = 2

## 唯一入口优先落在精英所在的点。不强制：有时让精英守在区内更深处更有意思。
## [b]M3-3c 才用到[/b]（M3-3 阶段还没有精英，任挑一个有对外边的点）。
@export var gate_prefers_elite: bool = true


## 这张 [param ring_count] 环的图上要不要长这一片。
func applies_to(ring_count: int) -> bool:
	return ring_count >= min_rings
