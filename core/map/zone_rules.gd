## 一片高危区得长成什么样才算数（架构文档 5.5）。
##
## 这是**图自身的性质**，所以进校验；而「高危区从哪条路线上岔出来、长多快」是生成规则，
## 在 [DangerZoneSpec] 里。两者分开放：手绘的图没有生成规则，但一样要守这里的几条。
##
## 规则跟着图走（写进 `layout_meta.zone_rules`）—— 校验与编辑器从图上读，不必手上有配置。
class_name ZoneRules
extends Resource

const DEFAULT_MIN_SIZE := 3
const DEFAULT_MAX_SIZE := 9

## 至少几个相连的点。可以跨环
@export var min_size: int = DEFAULT_MIN_SIZE
## 至多几个点
@export var max_size: int = DEFAULT_MAX_SIZE
## 出入口的上限，随规模放宽：「点数 ≤ 键」用对应的值。3~4 个点至多 2 个，5~6 至多 3 个，7~9 至多 4 个。
## **出入口是区内连着区外的那个【点】，不是边**：一个点身上通向区外的路再多也只算一个口 ——
## 玩家站在那个点上，出去就是出去了，从哪条路出去没差别。至少 1 个（吸收了路线节点的小区可能 2 个）
## （键写成字符串，理由同 DangerZoneSpec.soft_cap_by_rings）
@export var max_gates_by_size: Dictionary = {"4": 2, "6": 3, "9": 4}


func max_gates_for(size: int) -> int:
	var keys: Array = max_gates_by_size.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		if size <= int(k):
			return int(max_gates_by_size[k])
	return int(max_gates_by_size[keys[-1]]) if not keys.is_empty() else 1


func to_dict() -> Dictionary:
	var gates := {}
	for k in max_gates_by_size:
		gates[str(k)] = int(max_gates_by_size[k])
	return {"min_size": min_size, "max_size": max_size, "max_gates_by_size": gates}


## 从图上读。图上没写（老存档、别的形态）就用默认值。
static func from_graph(graph: MapGraph) -> ZoneRules:
	var rules := ZoneRules.new()
	var d: Dictionary = graph.layout_meta.get("zone_rules", {}) if graph != null else {}
	rules.min_size = int(d.get("min_size", DEFAULT_MIN_SIZE))
	rules.max_size = int(d.get("max_size", DEFAULT_MAX_SIZE))
	if d.has("max_gates_by_size"):
		rules.max_gates_by_size = {}
		for k in (d["max_gates_by_size"] as Dictionary):
			rules.max_gates_by_size[str(k)] = int(d["max_gates_by_size"][k])
	return rules


## 高危区（danger ≥ 2 的区域）长得对不对：规模、区内相连、出入口（点）数目。
## 中危区不归这里管 —— 它只是一片难一点的地方，没有「只靠几个口进出」的要求。
static func validate(graph: MapGraph, v: MapValidation) -> void:
	var rules := from_graph(graph)
	for zone_id in graph.zones:
		var ids: Array = graph.zones[zone_id]["node_ids"]
		if ids.is_empty() or graph.get_node(int(ids[0])) == null 				or graph.get_node(int(ids[0])).danger < 2:
			continue
		if ids.size() < rules.min_size or ids.size() > rules.max_size:
			v.fail(&"zone_size", "高危区 %s 有 %d 个点，该在 %d～%d 之间"
				% [zone_id, ids.size(), rules.min_size, rules.max_size])
		var gates := gate_ids(graph, ids).size()
		var cap := rules.max_gates_for(ids.size())
		if gates < 1 or gates > cap:
			v.fail(&"zone_gate", "高危区 %s（%d 个点）有 %d 个出入口节点，该在 1～%d 之间"
				% [zone_id, ids.size(), gates, cap])
		if not MapNavigator.connected_within(graph, ids):
			v.fail(&"zone_connected", "高危区 %s 内部断成了几片" % zone_id)


## 这片区与区外之间的全部路。
static func crossing_edges(graph: MapGraph, member_ids: Array) -> Array[MapEdge]:
	var inside := {}
	for id in member_ids:
		inside[int(id)] = true
	var out: Array[MapEdge] = []
	for e in graph.edges:
		if inside.has(e.from_id) != inside.has(e.to_id):
			out.append(e)
	return out


## 出入口在区内的那一头，升序去重。
static func gate_ids(graph: MapGraph, member_ids: Array) -> Array[int]:
	var inside := {}
	for id in member_ids:
		inside[int(id)] = true
	var out: Array[int] = []
	for e in crossing_edges(graph, member_ids):
		var g := e.from_id if inside.has(e.from_id) else e.to_id
		if not out.has(g):
			out.append(g)
	out.sort()
	return out
