## 生成地图时把事件定进节点（063；作者：生成时定好，但可能被覆盖或替换，不要写死）。
##
## 按节点类型查 [NodeRules.events_by_type] 的权重表，用节点 `content_seed` 派生的随机数抽一个，写进 `node.content["event"]`。
## 已经有的不覆盖（作者数据、预设、别的系统替换过的都算数）。随机点揭开时由 [NodeEvents.reveal] 按揭成的类型再抽。
## 取事件的时候（[NodeEvents]）先看内容里有没有，没有再按表抽 —— 旧存档里没这个键也照样走。
class_name EventPlacer
extends RefCounted


## 全图铺一遍。返回定了事件的节点数
static func fill(graph: MapGraph, rules: NodeRules) -> int:
	if graph == null or rules == null:
		return 0
	var n := 0
	for id in graph.node_ids():
		var node := graph.get_node(id)
		if node.type == &"random" or String(node.content.get("event", "")) != "":
			continue
		var eid := pick_for(node, node.type, rules)
		if eid != &"":
			node.content["event"] = String(eid)
			n += 1
	return n


## 这个点按 [param type] 该配哪个事件（确定的：同一个点同一种类型永远同一个）
static func pick_for(node: MapNode, type: StringName, rules: NodeRules) -> StringName:
	if node == null or rules == null:
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:event:%s" % [node.content_seed, type])
	return rules.event_pick_for(type, rng)


## 资产目录里的全部事件：id → 定义
static func load_all(dir_path: String = ContentPaths.EVENTS) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name in dir.get_files():
		var name := file_name.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var res := ResourceLoader.load(dir_path.path_join(name))
		if res is EventDef and (res as EventDef).id != &"":
			out[(res as EventDef).id] = res
	return out
