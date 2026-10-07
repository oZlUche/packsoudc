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


## 第 r 环的槽位数，从图上读（`layout_meta.ring_slots`）。键两种都认：生成期是整数，
## 过一遍 JSON 之后字典键会变成字符串（[method MapGraph.normalize] 的约定）。没记就是 [param default]
static func slots_of(graph: MapGraph, r: int, default: int) -> int:
	var table: Dictionary = graph.layout_meta.get("ring_slots", {})
	return int(table.get(r, table.get(str(r), default)))


## 相邻的路线对：[[i, j], ...]。两条路线只有一对，三条以上首尾也相邻
static func route_pairs(route_count: int) -> Array:
	var out: Array = []
	if route_count == 2:
		out.append([0, 1])
	elif route_count > 2:
		for i in route_count:
			out.append([i, (i + 1) % route_count])
	return out
