## 两个点之间的一条路（架构文档 5.2）。拓扑无关。
##
## 数据层只关心「这两个点相连」。一条路画成弧还是直线、画多长，由 [member kind]
## 交给布局策略决定；配置表里两个点隔着几格，同样不代表画出来隔多远（5.4.1）。
class_name MapEdge
extends RefCounted

## 传送点这一种边（8-1）：两端可以隔很远，走它是一次传送
const PORTAL := &"portal"

var from_id: int = 0
var to_id: int = 0

## 单向路。第一章全部为 false；字段留给未来的单向形态。
var directed: bool = false

## 画法提示，数据层不解读
var kind: StringName = &""

## 通过这条路消耗的行动点。
##
## [b]不要在别处直接读它往 ActionClock 里加[/b] —— 一切移动经过 MoveIntent（5.6），
## 否则传送、定点移动这类「不是走一条边」的移动就没地方接。
var action_cost: int = 1

## 布局载荷，例如一条跨过中间几层的路记下它跨了几层。数据层不解读。
var layout: Dictionary = {}


## 从 [param id] 这一头看过去，对面是谁。不挨着这条路则返回 -1。
func is_portal() -> bool:
	return kind == PORTAL


func other(id: int) -> int:
	if id == from_id:
		return to_id
	if id == to_id:
		return from_id
	return -1


## 能不能从 [param id] 出发走这条路。
func passable_from(id: int) -> bool:
	if id == from_id:
		return true
	return id == to_id and not directed


func to_dict() -> Dictionary:
	return {
		"from": from_id,
		"to": to_id,
		"directed": directed,
		"kind": String(kind),
		"action_cost": action_cost,
		"layout": layout.duplicate(true),
	}


static func from_dict(d: Dictionary) -> MapEdge:
	var e := MapEdge.new()
	e.from_id = int(d.get("from", 0))
	e.to_id = int(d.get("to", 0))
	e.directed = bool(d.get("directed", false))
	e.kind = StringName(d.get("kind", ""))
	e.action_cost = int(d.get("action_cost", 1))
	e.layout = MapGraph.normalize(d.get("layout", {}))
	return e
