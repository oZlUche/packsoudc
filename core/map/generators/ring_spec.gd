## 一个环的配置（架构文档 5.4）。
class_name RingSpec
extends Resource

## 环的类型，内容层用它选敌人池、掉落表与美术："outskirts" / "ruins" / "depths" …
## 拓扑层不解读它，只原样写进节点的 layout。
@export var kind: StringName = &""

## 这一环有多少个角度槽位（均匀分布）。
## **0 = 按半径算**：越靠里周长越短，槽位数随之减少（见 [RingMapConfig.arc_per_slot]）。
@export var slots: int = 0

## 其中多少个槽位真的有节点。少于 slots 时，空槽连成 1～2 段**空白区** ——
## 不是撒胡椒面式的随机缺口，而是一整段没有东西的弧。**0 = 全部**。
@export var node_count: int = 0

## 类型 → [min, max]：这一环每种类型至少几个、至多几个。没列的类型不限。
## 权重只负责填配额之外的空位 —— 「这一环至少一个休息区」说不出口的话，只靠权重是碰运气。
## [b]M3-3c 才用到。[/b]
@export var quota: Dictionary = {}

## 类型 → 权重。[b]M3-3c 才用到。[/b]
@export var type_weights: Dictionary = {}
