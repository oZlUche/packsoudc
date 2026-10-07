## 单步合法性判定与只读图查询（架构文档 5.6）。**拓扑无关。**
##
## [b]不做自动寻路。[/b] 玩家只能一步一步走到相邻的点 —— 每一步都得是一次独立决策，
## 那正是侵蚀施压的着力点。所以这里[b]没有任何多步移动的入口[/b]：
## [method distance_map] 与下面几个 BFS 都是只读查询（HUD 的「距最近撤离点 N 步」、生成期的覆盖与校验），
## 任何情况下都不得用它驱动移动。测试里有一条守着这件事：公开方法就这几个，多一个都红。
##
## 全部是静态方法：它没有状态，状态在 [MapTravel]。
class_name MapNavigator
extends RefCounted


## 从 [param current_id] 一步能走到的点，升序。单向路只算顺着走的那一头。
static func available_moves(graph: MapGraph, current_id: int) -> Array[int]:
	if graph == null or not graph.has_node(current_id):
		return [] as Array[int]
	return graph.neighbors(current_id)


## 从 [param from_id] 走到 [param to_id] 要走的那条路；不相邻、或者那条路不能从这头走，返回 null。
## 有多条路时取先加入的那条 —— 和 [method MapGraph.edge_between] 一致。
static func edge_for_step(graph: MapGraph, from_id: int, to_id: int) -> MapEdge:
	if graph == null or from_id == to_id:
		return null
	for e in graph.edges_of(from_id):
		if e.other(from_id) == to_id and e.passable_from(from_id):
			return e
	return null


## 把「想走到 to_id」解析成一个 step 意图。走不了返回 null。
##
## [b]这是唯一一处把 edge.action_cost 变成行动点的地方。[/b] 别处直接读 action_cost 加进
## [ActionClock]，就是在给传送挖坑（第 14 节）。
static func resolve_step(graph: MapGraph, from_id: int, to_id: int) -> MoveIntent:
	var e := edge_for_step(graph, from_id, to_id)
	if e == null:
		return null
	if e.is_portal():
		return MoveIntent.teleport(from_id, to_id, e.action_cost)     # 传送点（8-1）：同一条路，另一种意图
	return MoveIntent.step(from_id, to_id, e.action_cost)


## 只读：从 [param from_id] 出发到每个点的最少步数（id → 步数）。到不了的不在结果里。
## 数的是**边数**，不是行动点 —— HUD 说的「还有几步」是这个。
static func distance_map(graph: MapGraph, from_id: int) -> Dictionary:
	var dist := {}
	if graph == null or not graph.has_node(from_id):
		return dist
	dist[from_id] = 0
	var queue: Array[int] = [from_id]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for n in graph.neighbors(id):
			if not dist.has(n):
				dist[n] = int(dist[id]) + 1
				queue.append(n)
	return dist


## 只读：离 [param from_id] 最近的某类型节点。返回 `{"id": int, "steps": int}`；没有则 id = -1。
## 同样近的取 id 小的，好让 HUD 稳定。
static func nearest_of_type(graph: MapGraph, from_id: int, type: StringName) -> Dictionary:
	var best := {"id": -1, "steps": -1}
	var dist := distance_map(graph, from_id)
	for id in graph.node_ids() if graph != null else []:
		if graph.get_node(id).type != type or not dist.has(id):
			continue
		var steps := int(dist[id])
		if best["id"] < 0 or steps < int(best["steps"]):
			best = {"id": id, "steps": steps}
	return best


## 只读：每个节点到最近的某类型节点的步数（多源 BFS，id → 步数）。到不了的不在结果里。
## 生成期的步数覆盖、校验与统计工具都问它 —— 格阵与环形共用，不各抄一份
static func distances_to_type(graph: MapGraph, type: StringName) -> Dictionary:
	var dist := {}
	var queue: Array[int] = []
	for id in graph.node_ids():
		if graph.get_node(id).type == type:
			dist[id] = 0
			queue.append(id)
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for n in graph.neighbors(id):
			if not dist.has(n):
				dist[n] = int(dist[id]) + 1
				queue.append(n)
	return dist


## 只读：从 [param from_id] 走 [param limit] 步之内到得了的点（id → 步数，含出发点自己）。
static func within_steps(graph: MapGraph, from_id: int, limit: int) -> Dictionary:
	var dist := {from_id: 0}
	var queue: Array[int] = [from_id]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		if int(dist[id]) >= limit:
			continue
		for n in graph.neighbors(id):
			if not dist.has(n):
				dist[n] = int(dist[id]) + 1
				queue.append(n)
	return dist


## 只读：这几个点只沿着彼此之间的路走，是不是连成一片（高危区内部不许断成几片）。
static func connected_within(graph: MapGraph, ids: Array) -> bool:
	if ids.size() <= 1:
		return true
	var inside := {}
	for id in ids:
		inside[int(id)] = true
	var seen := {int(ids[0]): true}
	var queue: Array[int] = [int(ids[0])]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for n in graph.neighbors(id):
			if inside.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == ids.size()
