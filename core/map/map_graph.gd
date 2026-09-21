## 一张地图：点、路，以及几份标注（架构文档 5.2）。**拓扑无关。**
##
## 地图形态会随章节变化，所以这里不允许出现任何形状相关的字段 —— 那些只能存在于
## 节点与边的 `layout` 字典里，由生成器写、布局策略读。[code]tests/test_map_graph.gd[/code]
## 里有一条会红的检查守着这件事：靠人记住的约束，到第二章开工时必然已经没人记得。
##
## 序列化是确定的：同一张图永远导出同样的字节（节点按 id 升序、边按加入顺序），
## 存档、回放与「同种子同一张图」的测试都靠它。
class_name MapGraph
extends RefCounted

## 用哪个布局策略画。数据层只原样保存，不解读。
var layout_kind: StringName = &""

## 全局布局参数，数据层不解读
var layout_meta: Dictionary = {}

## id -> MapNode
var nodes: Dictionary = {}

var edges: Array[MapEdge] = []

## 出生点。每个出生点对应一条路线，开局由玩家挑（5.4.2）
var entry_ids: Array[int] = []

## 终点（章节核心）
var goal_ids: Array[int] = []

## 危险区域：zone_id -> {"node_ids": Array[int], "gate_ids": Array[int]}。
## gate_ids = 出入口在区内的那一头；一片区可以有好几个口（5.5）
var zones: Dictionary = {}

## 每个出生点一条路线：{entry_id, style, node_ids, ends_at, risk, reward}。
## 路线只是一串节点 id 加几个标签；开局给玩家看的就是这一份。
var routes: Array[Dictionary] = []

## id -> Array[MapEdge]，懒建的邻接索引。加点加边后作废。
var _incident: Dictionary = {}
var _index_valid: bool = false


#region 构建
## 加一个点。id 重复则拒绝。
func add_node(node: MapNode) -> bool:
	if node == null or nodes.has(node.id):
		return false
	nodes[node.id] = node
	_index_valid = false
	return true


## 加一条路。两端必须都是已有的点，且不能自己连自己。
func add_edge(edge: MapEdge) -> bool:
	if edge == null or edge.from_id == edge.to_id:
		return false
	if not nodes.has(edge.from_id) or not nodes.has(edge.to_id):
		return false
	edges.append(edge)
	_index_valid = false
	return true


## 便捷写法：连两个点，返回那条路（失败返回 null）。
func connect_nodes(a: int, b: int, kind: StringName = &"", action_cost: int = 1) -> MapEdge:
	var e := MapEdge.new()
	e.from_id = a
	e.to_id = b
	e.kind = kind
	e.action_cost = action_cost
	return e if add_edge(e) else null


func remove_edge(edge: MapEdge) -> void:
	edges.erase(edge)
	_index_valid = false


## 删一个点，连同挨着它的全部路；出生点、终点、危险区域里的登记一并清掉。
##
## [b]路线不动。[/b] 路线是一串有意义的节点，删掉中间一个之后该怎么接是作者的决定，
## 这里替他接上或整条删掉都是越权 —— 留着，让校验去说「路线断了」。
func remove_node(id: int) -> bool:
	if not nodes.has(id):
		return false
	for e in edges_of(id):
		edges.erase(e)
	nodes.erase(id)
	entry_ids.erase(id)
	goal_ids.erase(id)
	for zid in zones.keys():
		var info: Dictionary = zones[zid]
		var members: Array = info.get("node_ids", [])
		members.erase(id)
		(info.get("gate_ids", []) as Array).erase(id)
		if members.is_empty():
			zones.erase(zid)
	_index_valid = false
	return true


## 还没被用过的最小正整数 id。编辑器加点时用。
func next_free_id() -> int:
	var id := 1
	while nodes.has(id):
		id += 1
	return id
#endregion


#region 查询
func get_node(id: int) -> MapNode:
	return nodes.get(id, null)


func has_node(id: int) -> bool:
	return nodes.has(id)


func node_count() -> int:
	return nodes.size()


## 全部节点 id，升序。遍历节点请用它 —— 字典的迭代顺序取决于插入顺序，
## 而「同种子同一张图」要求一切遍历都与插入顺序无关。
func node_ids() -> Array[int]:
	var out: Array[int] = []
	for id in nodes:
		out.append(int(id))
	out.sort()
	return out


## 挨着这个点的全部路，不论方向。要不要走得通另问 [method MapEdge.passable_from]。
func edges_of(id: int) -> Array[MapEdge]:
	_ensure_index()
	var out: Array[MapEdge] = []
	out.assign(_incident.get(id, []))
	return out


## 从这个点一步能到的点，升序去重。单向路只算顺着走的那一头。
func neighbors(id: int) -> Array[int]:
	var out: Array[int] = []
	for e in edges_of(id):
		if not e.passable_from(id):
			continue
		var o := e.other(id)
		if not out.has(o):
			out.append(o)
	out.sort()
	return out


## 两点之间的路；没有则返回 null。有多条时返回先加入的那条。
func edge_between(a: int, b: int) -> MapEdge:
	for e in edges_of(a):
		if e.other(a) == b:
			return e
	return null


func _ensure_index() -> void:
	if _index_valid:
		return
	_incident = {}
	for e in edges:
		for end in [e.from_id, e.to_id]:
			if not _incident.has(end):
				_incident[end] = []
			(_incident[end] as Array).append(e)
	_index_valid = true
#endregion


#region 存档
func to_dict() -> Dictionary:
	var node_dicts: Array = []
	for id in node_ids():
		node_dicts.append((nodes[id] as MapNode).to_dict())
	var edge_dicts: Array = []
	for e in edges:
		edge_dicts.append(e.to_dict())
	# zones 以 id 为键；JSON 的键只能是字符串，所以存成按 id 升序的数组
	var zone_ids: Array = zones.keys()
	zone_ids.sort()
	var zone_dicts: Array = []
	for zid in zone_ids:
		var z: Dictionary = (zones[zid] as Dictionary).duplicate(true)
		z["id"] = int(zid)
		zone_dicts.append(z)
	return {
		"version": 1,
		"layout_kind": String(layout_kind),
		"layout_meta": layout_meta.duplicate(true),
		"nodes": node_dicts,
		"edges": edge_dicts,
		"entry_ids": entry_ids.duplicate(),
		"goal_ids": goal_ids.duplicate(),
		"zones": zone_dicts,
		"routes": routes.duplicate(true),
	}


static func from_dict(d: Dictionary) -> MapGraph:
	var g := MapGraph.new()
	g.layout_kind = StringName(d.get("layout_kind", ""))
	g.layout_meta = normalize(d.get("layout_meta", {}))
	for raw in d.get("nodes", []):
		g.add_node(MapNode.from_dict(raw))
	for raw in d.get("edges", []):
		if not g.add_edge(MapEdge.from_dict(raw)):
			push_warning("MapGraph.from_dict: 丢弃一条两端对不上的路 %s" % str(raw))
	g.entry_ids = _int_array(d.get("entry_ids", []))
	g.goal_ids = _int_array(d.get("goal_ids", []))
	for raw in d.get("zones", []):
		var z: Dictionary = normalize(raw)
		var zid := int(z.get("id", 0))
		z.erase("id")
		g.zones[zid] = z
	for raw in d.get("routes", []):
		g.routes.append(normalize(raw))
	return g


static func _int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	for v in (raw as Array):
		out.append(int(v))
	return out


## 把从 JSON 读回来的自由字典里「其实是整数」的浮点数还原成整数。
##
## JSON 没有整数类型，`{"order": 3}` 读回来是 3.0；不还原的话，存一次读一次
## `to_dict()` 的结果就变了，「同一张图永远导出同样的字节」不再成立。
## 代价是真正的 2.0 也会变成 2 —— 自由字典里因此约定：要小数就别写成整数值。
static func normalize(value: Variant) -> Variant:
	if value is float:
		var f: float = value
		return int(f) if absf(f) < 9.0e15 and float(int(f)) == f else f
	if value is Dictionary:
		var out := {}
		for k in (value as Dictionary):
			out[k] = normalize(value[k])
		return out
	if value is Array:
		var arr: Array = []
		for v in (value as Array):
			arr.append(normalize(v))
		return arr
	return value
#endregion
