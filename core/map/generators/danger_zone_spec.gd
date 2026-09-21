## 一片高危区（架构文档 5.4）。
##
## 高危区把「诱惑」做成**拓扑**：一片与外界只有一条边相连的区域，里面有精英守着、
## 有好几个搜索点。进去就得从同一条路出来，行动点花两遍。
## 玩家看得见入口、看得见里面有什么，然后自己决定值不值。
class_name DangerZoneSpec
extends Resource

## 落在哪几环之间（含）。环号自内向外：1 是最内环，环数是最外环。
@export var ring_range: Vector2i = Vector2i(1, 3)

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
