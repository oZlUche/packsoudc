## 格阵形态的生成器基类（第 8 阶段 8-2，报告 078）：沙漏、塔这类**分层格阵**共用的铺点、连边、断边、定类型、校验。
##
## 子类只回答「形状长什么样」（[method shape] 给一个 [LatticeShape]）和默认配置；层与层之间怎么连、
## 怎么保证每个点都到得了、类型怎么填，这里只写一遍。和环形生成器一样：造不出来换种子重试，绝不产出坏图。
##
## 铺法：每层在自己的格子里按填充率挑一些放点（第 0 层、最后一层、只许直上的层全填）；
## 层与层之间凡是列差不超过 forward_reach 的都先连上，同层挨着的连横边，然后按概率断 ——
## 断的时候守住「每个点向上至少一条、向下至少一条」，全图连通与「单向也到得了终点」就都成立。
## tier = 层号（越往上越难），侵蚀分档默认也是层号（可反过来：从终点那头侵蚀）。
@abstract
class_name LatticeMapGenerator
extends MapGenerator

var _shape: LatticeShape = null
var _graph: MapGraph = null
var _rng: RandomNumberGenerator = null
## row -> {col: id}
var _cells: Array[Dictionary] = []


## 由配置算出形状。配置不对返回 null 并在 build_note 里说
@abstract func shape(cfg: Resource) -> LatticeShape


func build(cfg: Resource, rng: RandomNumberGenerator) -> MapGraph:
	_shape = shape(cfg)
	if _shape == null:
		return null
	var why := _shape.problem()
	if why != "":
		build_note = why
		return null
	if _shape.rules == null:
		_shape.rules = LatticeTypeRules.new()
	_rng = rng
	_graph = MapGraph.new()
	_graph.layout_kind = _shape.kind
	var cells_meta: Array = []
	var straight: Array = []
	for r in _shape.row_count():
		cells_meta.append((_shape.rows[r]["cols"] as Array).duplicate())
		if _shape.is_straight(r):
			straight.append(r)
	var goals_meta: Array = []
	for c in _shape.goal_cols():
		goals_meta.append([c, String(_shape.goals[c])])
	_graph.layout_meta = {
		"rows": _shape.row_count(), "cols": _shape.cols, "cells": cells_meta, "straight_rows": straight,
		"orientation": String(_shape.orientation), "goals": goals_meta,
		"forward_reach": _shape.forward_reach, "lateral_span": _shape.lateral_span,
		"one_way": _shape.one_way, "one_way_from_row": _shape.one_way_from_row,
		"erosion_reversed": _shape.erosion_reversed,
	}
	if not _place_nodes():
		return null
	_link()
	_thin()
	var typer := LatticeTypeAssigner.new()
	if not typer.assign(_graph, _shape.rules, _rng):
		build_note = "类型分配失败：" + typer.note
		return null
	return _graph


#region 铺点
func _place_nodes() -> bool:
	_cells = []
	var last := _shape.row_count() - 1
	var next_id := 1
	var chosen: Array = []
	for r in _shape.row_count():
		var allowed: Array[int] = []
		allowed.assign(_shape.rows[r]["cols"])
		allowed.sort()
		var forced := {}
		# 只许直上的层两头的层得有对着的格子，不然线段接不上
		for rr in [r - 1, r + 1]:
			if _shape.is_straight(rr):
				for c in _shape.rows[rr]["cols"]:
					forced[int(c)] = true
		if r == last:
			for c in _shape.goal_cols():
				forced[c] = true
		var picked: Array[int] = []
		# 全填的层：第 0 层、最后一层、直上层，以及直上层两头的层 —— 那两层里不对着线段的点靠横边走到线段口，
		# 所以它们得连成一片（横边也不断，见 _thin）
		if r == 0 or r == last or _shape.is_straight(r) or _shape.is_straight(r - 1) or _shape.is_straight(r + 1):
			picked = allowed.duplicate()
		else:
			var want := clampi(roundi(float(allowed.size()) * float(_shape.rows[r]["fill"])), 1, allowed.size())
			var pool := _shuffled(allowed)
			for c in pool:
				if forced.has(c) and not picked.has(c):
					picked.append(c)
			for c in pool:
				if picked.size() >= want:
					break
				if not picked.has(c) and _has_backing(c, chosen[r - 1] if r > 0 else [], r):
					picked.append(c)
			# 下面那层每个点都得有向上的去处：没有的，在够得着的格子里补一个
			if r > 0:
				for c_below in chosen[r - 1]:
					if _reachable_col(int(c_below), picked, r):
						continue
					var fix := _nearest_allowed(int(c_below), allowed, picked, r)
					if fix < 0:
						build_note = "第 %d 层的 %d 列向上没路可连" % [r - 1, c_below]
						return false
					picked.append(fix)
			picked.sort()
		chosen.append(picked)
	# 终点那一层与直上层也得给下面留路。直上层：线段口在下面那层得有点（其余的点横着走到线段口）
	for r in range(1, _shape.row_count()):
		if _shape.is_straight(r):
			for c in _shape.rows[r]["cols"]:
				if not (chosen[r - 1] as Array).has(int(c)):
					build_note = "第 %d 层的 %d 列是线段口，下面那层却没点" % [r, c]
					return false
			continue
		for c_below in chosen[r - 1]:
			if not _reachable_col(int(c_below), chosen[r], r):
				build_note = "第 %d 层的 %d 列向上没路可连" % [r - 1, c_below]
				return false
	# 建点
	for r in _shape.row_count():
		var table := {}
		for c in chosen[r]:
			var n := MapNode.new()
			n.id = next_id
			next_id += 1
			n.type = &"battle"
			n.tier = r
			n.erosion_band = (last - r) if _shape.erosion_reversed else r
			n.danger = _shape.danger_of(r)
			n.content_seed = _rng.randi()
			n.layout = {"row": r, "col": int(c)}
			_graph.add_node(n)
			table[int(c)] = n.id
		_cells.append(table)
	# 出生点匀着放在第 0 层；终点是最后一层里形状说的那几格
	var row0: Array = _cells[0].keys()
	row0.sort()
	var k := _shape.entry_count
	for i in k:
		var idx := roundi(float(i) * float(row0.size() - 1) / float(maxi(1, k - 1))) if k > 1 else (row0.size() - 1) / 2
		var id: int = _cells[0][row0[idx]]
		if not _graph.entry_ids.has(id):
			_graph.entry_ids.append(id)
	_graph.goal_ids = [] as Array[int]
	for c in _shape.goal_cols():
		_graph.goal_ids.append(int(_cells[last][c]))
	return true


## 这一列在下面那层有没有够得着的点
func _has_backing(c: int, below: Array, r: int) -> bool:
	if r == 0:
		return true
	var reach := 0 if _shape.is_straight(r) or _shape.is_straight(r - 1) else _shape.forward_reach
	for cb in below:
		if absi(int(cb) - c) <= reach:
			return true
	return false


func _reachable_col(c_below: int, above: Array, r: int) -> bool:
	var reach := 0 if _shape.is_straight(r) or _shape.is_straight(r - 1) else _shape.forward_reach
	for ca in above:
		if absi(int(ca) - c_below) <= reach:
			return true
	return false


func _nearest_allowed(c_below: int, allowed: Array[int], picked: Array[int], r: int) -> int:
	var reach := 0 if _shape.is_straight(r) or _shape.is_straight(r - 1) else _shape.forward_reach
	var best := -1
	for c in allowed:
		if picked.has(c) or absi(c - c_below) > reach:
			continue
		if best < 0 or absi(c - c_below) < absi(best - c_below):
			best = c
	return best
#endregion


#region 连边与断边
func _link() -> void:
	for r in range(1, _shape.row_count()):
		var reach := 0 if _shape.is_straight(r) or _shape.is_straight(r - 1) else _shape.forward_reach
		var directed := _shape.one_way and (r - 1) >= _shape.one_way_from_row
		for cb in _cells[r - 1]:
			for ca in _cells[r]:
				if absi(int(ca) - int(cb)) <= reach:
					var e := _graph.connect_nodes(int(_cells[r - 1][cb]), int(_cells[r][ca]), &"forward")
					if e != null:
						e.directed = directed
	for r in _shape.row_count():
		if not _shape.allows_lateral(r):
			continue
		var cols: Array = _cells[r].keys()
		cols.sort()
		for i in range(1, cols.size()):
			if int(cols[i]) - int(cols[i - 1]) - 1 <= _shape.lateral_span:
				_graph.connect_nodes(int(_cells[r][cols[i - 1]]), int(_cells[r][cols[i]]), &"lateral")


## 按概率断边，守住：每个点向上至少一条（最后一层除外）、向下至少一条（第 0 层除外）；
## 第 0 层与最后一层的横边不断（出生点之间、终点那层得连成一片）
func _thin() -> void:
	var last := _shape.row_count() - 1
	for raw in _shuffled_edges():
		var e := raw as MapEdge
		var ra := int(_graph.get_node(e.from_id).layout["row"])
		var rb := int(_graph.get_node(e.to_id).layout["row"])
		if ra == rb:
			var keep := ra == 0 or ra == last or _shape.is_straight(ra - 1) or _shape.is_straight(ra + 1)
			if keep or _rng.randf() >= _shape.lateral_break_chance:
				continue
			_graph.remove_edge(e)
			continue
		if _rng.randf() >= _shape.forward_break_chance:
			continue
		var lower := e.from_id if ra < rb else e.to_id
		var upper := e.to_id if ra < rb else e.from_id
		if _count_dir(lower, 1) > 1 and _count_dir(upper, -1) > 1:
			_graph.remove_edge(e)


## 这个点有几条边通向上（dir = 1）/ 下（dir = -1）一层
func _count_dir(id: int, dir: int) -> int:
	var r := int(_graph.get_node(id).layout["row"])
	var n := 0
	for e in _graph.edges_of(id):
		if int(_graph.get_node(e.other(id)).layout["row"]) == r + dir:
			n += 1
	return n


func _shuffled_edges() -> Array:
	var out: Array = _graph.edges.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: MapEdge = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _shuffled(ids: Array[int]) -> Array[int]:
	var out: Array[int] = ids.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out
#endregion


#region 校验
## 格阵自己的规矩（规则从图上读，手改的图也能问）：边只连相邻层或同层邻格、直上层不横连、tier = 层号、
## 单向的图每个点都到得了终点；类型规则见 [LatticeTypeRules.validate]。传送点先摘下来，它不是路
func validate(graph: MapGraph, v: MapValidation) -> void:
	var portals: Array = []
	if graph != null:
		for e in graph.edges.duplicate():
			if (e as MapEdge).is_portal():
				graph.remove_edge(e)
				portals.append(e)
	_validate_lattice(graph, v)
	for e in portals:
		graph.add_edge(e)


func _validate_lattice(graph: MapGraph, v: MapValidation) -> void:
	super.validate(graph, v)
	if graph == null or graph.node_count() == 0:
		return
	var rows := int(graph.layout_meta.get("rows", 0))
	var reach := int(graph.layout_meta.get("forward_reach", 1))
	var span := int(graph.layout_meta.get("lateral_span", 1))
	var straight: Array = graph.layout_meta.get("straight_rows", [])
	var cells: Array = graph.layout_meta.get("cells", [])
	var reversed := bool(graph.layout_meta.get("erosion_reversed", false))
	var one_way := bool(graph.layout_meta.get("one_way", false))
	var from_row := int(graph.layout_meta.get("one_way_from_row", 0))
	var taken := {}
	for id in graph.node_ids():
		var n := graph.get_node(id)
		var r := int(n.layout.get("row", -1))
		var c := int(n.layout.get("col", -1))
		if r < 0 or r >= rows:
			v.fail(&"row", "节点 %d 的层号 %d 不在 0～%d" % [id, r, rows - 1])
			continue
		if r < cells.size() and not (cells[r] as Array).has(c):
			v.fail(&"cell", "节点 %d 在第 %d 层的 %d 列，那里不是格子" % [id, r, c])
		var key := "%d:%d" % [r, c]
		if taken.has(key):
			v.fail(&"cell", "第 %d 层 %d 列上有两个点" % [r, c])
		taken[key] = true
		if n.tier != r:
			v.fail(&"bands", "节点 %d 的 tier %d 不等于层号 %d" % [id, n.tier, r])
		if n.erosion_band != ((rows - 1 - r) if reversed else r):
			v.fail(&"bands", "节点 %d 的侵蚀分档对不上层号" % id)
	for e in graph.edges:
		var a := graph.get_node(e.from_id)
		var b := graph.get_node(e.to_id)
		var ra := int(a.layout.get("row", -1))
		var rb := int(b.layout.get("row", -1))
		var dc := absi(int(a.layout.get("col", 0)) - int(b.layout.get("col", 0)))
		if ra == rb:
			if straight.has(ra):
				v.fail(&"straight", "第 %d 层只许直上直下，%d ↔ %d 却横着连了" % [ra, e.from_id, e.to_id])
			elif dc - 1 > span:
				v.fail(&"edge_length", "%d ↔ %d 同层隔了 %d 列，最多隔 %d 个空格" % [e.from_id, e.to_id, dc, span])
			if one_way and e.directed:
				v.fail(&"one_way", "同层的路 %d ↔ %d 不该是单向的" % [e.from_id, e.to_id])
		elif absi(ra - rb) != 1:
			v.fail(&"edge_length", "%d ↔ %d 跨了 %d 层，只能连相邻层" % [e.from_id, e.to_id, absi(ra - rb)])
		else:
			var lim := 0 if straight.has(ra) or straight.has(rb) else reach
			if dc > lim:
				v.fail(&"edge_length", "%d ↔ %d 斜了 %d 列，最多 %d" % [e.from_id, e.to_id, dc, lim])
			var lower_row := mini(ra, rb)
			var should := one_way and lower_row >= from_row
			if e.directed != should:
				v.fail(&"one_way", "%d ↔ %d 的方向和「不回头」设置对不上" % [e.from_id, e.to_id])
			elif e.directed and int(graph.get_node(e.from_id).layout["row"]) > int(graph.get_node(e.to_id).layout["row"]):
				v.fail(&"one_way", "%d → %d 是向下的单向路，不回头只许向上" % [e.from_id, e.to_id])
	# 单向的图：每个点都得走得到终点（回不了头的死胡同就是困死）
	if one_way and not graph.goal_ids.is_empty():
		var can := _reaches_goal(graph)
		var stuck: Array[int] = []
		for id in graph.node_ids():
			if not can.has(id):
				stuck.append(id)
		if not stuck.is_empty():
			v.fail(&"goal_from_all", "%d 个点顺着单向路走不到终点，例如 %s" % [stuck.size(), str(stuck.slice(0, mini(5, stuck.size())))])
	LatticeTypeRules.validate(graph, v)


## 顺着方向能走到终点的点（从终点倒着找）
static func _reaches_goal(graph: MapGraph) -> Dictionary:
	var seen := {}
	var queue: Array[int] = []
	for id in graph.goal_ids:
		if graph.has_node(id):
			seen[id] = true
			queue.append(id)
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for e in graph.edges_of(id):
			var o := e.other(id)
			if e.passable_from(o) and not seen.has(o):
				seen[o] = true
				queue.append(o)
	return seen
#endregion
