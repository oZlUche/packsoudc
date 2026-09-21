## 找出图上该画成「岔路口」的地方（架构文档 5.9）。
##
## 四个点两两相连 → 一个**四岔路口**；三个点两两相连 → 一个**三岔路口**。
## 数据层照旧只记「谁和谁相连」—— 六条边画成六条线会在中间打叉，玩家分不清那是一个路口
## 还是两条互不相干的路叠在一起；画成一个路口伸出四条腿，意思才是对的。
##
## 先找四岔、再找三岔：一条边只归一个路口，四岔占过的边三岔不再用。
## 同一档里**由内向外**（tier 高的先）—— 内圈的点挤，先把那里定下来。
##
## 纯拓扑，不认识任何地图形态。
class_name MapJunctions
extends RefCounted


## 返回 `{quads: Array[Array[int]], tris: Array[Array[int]], edge_keys: Dictionary}`。
## edge_keys 是被路口占用的边（"小id:大id"），画图时这些边不再单独画线。
static func find(graph: MapGraph) -> Dictionary:
	var out := {"quads": [], "tris": [], "edge_keys": {}}
	if graph == null:
		return out
	var ids := graph.node_ids()
	var nbrs := {}
	for id in ids:
		var set := {}
		for e in graph.edges_of(id):
			set[e.other(id)] = true     # 画图不分方向：单向路也是一条线
		nbrs[id] = set

	var quads: Array = []
	var tris: Array = []
	for a in ids:
		for b in ids:
			if b <= a or not nbrs[a].has(b):
				continue
			for c in ids:
				if c <= b or not nbrs[a].has(c) or not nbrs[b].has(c):
					continue
				tris.append([a, b, c])
				for d in ids:
					if d > c and nbrs[a].has(d) and nbrs[b].has(d) and nbrs[c].has(d):
						quads.append([a, b, c, d])

	var used: Dictionary = out["edge_keys"]
	for group in [[quads, "quads"], [tris, "tris"]]:
		var cliques: Array = group[0]
		cliques.sort_custom(func(x: Array, y: Array) -> bool:
			var tx := _tier_sum(graph, x)
			var ty := _tier_sum(graph, y)
			return tx > ty or (tx == ty and x < y))
		for clique in cliques:
			var keys := _edge_keys(clique)
			var free := true
			for k in keys:
				if used.has(k):
					free = false
			if not free:
				continue
			for k in keys:
				used[k] = true
			(out[group[1]] as Array).append(clique)
	return out


static func edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func _edge_keys(clique: Array) -> Array[String]:
	var keys: Array[String] = []
	for i in clique.size():
		for j in range(i + 1, clique.size()):
			keys.append(edge_key(int(clique[i]), int(clique[j])))
	return keys


static func _tier_sum(graph: MapGraph, clique: Array) -> int:
	var total := 0
	for id in clique:
		total += graph.get_node(int(id)).tier
	return total
