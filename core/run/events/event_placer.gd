## 生成地图时把事件定进节点（063；作者：生成时定好，但可能被覆盖或替换，不要写死）。
##
## 按节点类型查 [NodeRules.events_by_type] 的权重表，用节点 `content_seed` 派生的随机数抽一个，写进 `node.content["event"]`。
## 已经有的不覆盖（作者数据、预设、别的系统替换过的都算数）。随机点揭开时由 [NodeEvents.reveal] 按揭成的类型再抽。
## 取事件的时候（[NodeEvents]）先看内容里有没有，没有再按表抽 —— 旧存档里没这个键也照样走。
class_name EventPlacer
extends RefCounted


## 全图铺一遍。返回定了事件的节点数。093：成组限量的事件（[NodeRules.event_groups]）先铺 —— 每张图最多几个、偏前期
static func fill(graph: MapGraph, rules: NodeRules) -> int:
	if graph == null or rules == null:
		return 0
	var n := fill_groups(graph, rules)
	var used := used_counts(graph)
	for id in graph.node_ids():
		var node := graph.get_node(id)
		if node.type == &"random" or String(node.content.get("event", "")) != "":
			continue
		var eid := _pick(node, node.type, rules, used)
		if eid != &"":
			node.content["event"] = String(eid)
			used[String(eid)] = int(used.get(String(eid), 0)) + 1
			n += 1
	return n


## 303：图上已经配了的事件 id → 几处（[member NodeRules.event_max_per_map] 对着它数）
static func used_counts(graph: MapGraph) -> Dictionary:
	var out := {}
	if graph == null:
		return out
	for id in graph.node_ids():
		var eid := String(graph.get_node(id).content.get("event", ""))
		if eid != "":
			out[eid] = int(out.get(eid, 0)) + 1
	return out


## 093：成组限量的事件。每组：在还没配事件的**事件点**里挑 max_per_map 个（early = 越浅的点权重越高：(1 − 深度)² + 0.05），
## 各抽一个组内事件写进去。可复现：随机数按「组名 + 图上第一个点的 content_seed」派生。返回放了几个
static func fill_groups(graph: MapGraph, rules: NodeRules) -> int:
	var placed := 0
	if rules.event_groups.is_empty():
		return 0
	var ids := graph.node_ids()
	if ids.is_empty():
		return 0
	var depths := EnemyPlacer.depths_of(graph)
	var groups: Array = rules.event_groups.keys()
	Ids.sort(groups)
	for gname in groups:
		var g = rules.event_groups[gname]
		if not (g is Dictionary):
			continue
		var cfg := g as Dictionary
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("group:%s:%d" % [gname, graph.get_node(ids[0]).content_seed])
		if rng.randf() >= float(cfg.get("chance", 1.0)):
			continue
		var want := int(cfg.get("max_per_map", 1))
		var early := bool(cfg.get("early", false))
		var pool: Array[int] = []
		for id in ids:
			var node := graph.get_node(id)
			if node.type == &"event" and String(node.content.get("event", "")) == "":
				pool.append(id)
		for k in want:
			if pool.is_empty():
				break
			var weights: Array[float] = []
			for id in pool:
				var w := 1.0
				if early:
					var d := float(depths.get(id, 0.5))
					w = (1.0 - d) * (1.0 - d) + 0.05
				weights.append(w)
			var chosen := pool[MapRng.pick_index(weights, rng)]     # 权重都 ≥ 0.05：总有得抽，不会是 -1
			pool.erase(chosen)
			var eid := rules.group_pick(String(gname), rng)
			if eid == &"":
				break
			graph.get_node(chosen).content["event"] = String(eid)
			graph.get_node(chosen).content["event_group"] = String(gname)
			placed += 1
	return placed


## 这个点按 [param type] 该配哪个事件（确定的：同一个点同一种类型永远同一个）
## 303：给了 [param graph] 就按图上已配的数避开到了上限的事件（随机点揭开、踩上去现配时用）
static func pick_for(node: MapNode, type: StringName, rules: NodeRules, graph: MapGraph = null) -> StringName:
	return _pick(node, type, rules, used_counts(graph) if graph != null and not rules.event_max_per_map.is_empty() else {}) if rules != null else &""


static func _pick(node: MapNode, type: StringName, rules: NodeRules, used: Dictionary) -> StringName:
	if node == null or rules == null:
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:event:%s" % [node.content_seed, type])
	return rules.event_pick_for(type, rng, used)


## 资产目录里的全部事件：id → 定义
static func load_all(dir_path: String = ContentPaths.EVENTS) -> Dictionary:
	var out := {}
	for res in ContentPaths.load_resources(dir_path):
		if res is EventDef and (res as EventDef).id != &"":
			out[(res as EventDef).id] = res
	return out
