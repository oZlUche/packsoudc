## 一次移动的意图（架构文档 5.6「为未来的移动机制预留接口」）。
##
## [b]一切移动都经过它[/b]，哪怕现在只有 `step` 一种。行动计数、侵蚀结算、存档与 HUD
## 挂在**意图的结算结果**上，而不是挂在「走过一条边」这个动作上 ——
## 将来加传送、定点移动，只是多一种意图的解析方式（第 14 节）。
##
## 它是纯数据，不会自己去改任何东西。合法性由 [MapNavigator] 判、结算由 [MapTravel] 做。
class_name MoveIntent
extends RefCounted

## 走一条边到相邻的点
const STEP := &"step"
## 传送（8-1，报告 076）：走一条 kind 为 portal 的边，两端可以隔很远；花的行动点是那条边说的，不经过途中任何点
const TELEPORT := &"teleport"

## "step"；未来 "teleport" / "waypoint" / …
var kind: StringName = STEP

var from_id: int = -1
var to_id: int = -1

## 花几个行动点。由解析器给出，[b]不假定等于 1[/b]，也不假定等于某条边的 action_cost —
## 那只是 step 这一种的算法
var action_cost: int = 1

## 途经的节点（不含两端），供沿途惩罚结算。step 为空
var passes_through: Array[int] = []


static func step(p_from: int, p_to: int, p_cost: int) -> MoveIntent:
	return _make(STEP, p_from, p_to, p_cost)


static func teleport(p_from: int, p_to: int, p_cost: int) -> MoveIntent:
	return _make(TELEPORT, p_from, p_to, p_cost)


static func _make(p_kind: StringName, p_from: int, p_to: int, p_cost: int) -> MoveIntent:
	var m := MoveIntent.new()
	m.kind = p_kind
	m.from_id = p_from
	m.to_id = p_to
	m.action_cost = p_cost
	return m


func to_dict() -> Dictionary:
	return {
		"kind": String(kind), "from": from_id, "to": to_id,
		"action_cost": action_cost, "passes_through": passes_through.duplicate(),
	}


static func from_dict(d: Dictionary) -> MoveIntent:
	var m := MoveIntent.new()
	m.kind = StringName(d.get("kind", "step"))
	m.from_id = int(d.get("from", -1))
	m.to_id = int(d.get("to", -1))
	m.action_cost = int(d.get("action_cost", 1))
	for v in d.get("passes_through", []):
		m.passes_through.append(int(v))
	return m
