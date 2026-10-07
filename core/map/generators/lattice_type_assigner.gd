## 给一张拓扑齐全的格阵图填类型（8-2，报告 078）。输入类型全是占位 `battle`，输出填好的同一张图。
##
## 顺序：出生点 / 终点固定 → 中途撤离点落在允许的层、两两够远 → 其余按权重抽 → 每层配额 → 步数覆盖 → 不许相邻。
## 校验在 [LatticeTypeRules.validate]（规则写进图）。这里只管尽力凑，凑不出来返回 false 让生成器换种子。
class_name LatticeTypeAssigner
extends RefCounted

var note: String = ""

var _g: MapGraph
var _rules: LatticeTypeRules
var _rng: RandomNumberGenerator
var _fixed: Dictionary = {}
var _by_row: Dictionary = {}


func assign(g: MapGraph, rules: LatticeTypeRules, rng: RandomNumberGenerator) -> bool:
	_g = g
	_rules = rules
	_rng = rng
	_fixed = {}
	_by_row = {}
	note = ""
	for id in g.node_ids():
		var r := int(g.get_node(id).layout.get("row", -1))
		if not _by_row.has(r):
			_by_row[r] = [] as Array[int]
		(_by_row[r] as Array[int]).append(id)
	for id in g.entry_ids:
		g.get_node(id).type = &"spawn"
		_fixed[id] = true
	# 终点那一层放什么由形状说（layout_meta.goals：[列, 类型]），核心不是必须的
	var goal_types := {}
	for pair in g.layout_meta.get("goals", []):
		goal_types[int(pair[0])] = StringName(String(pair[1]))
	for id in g.goal_ids:
		var n := g.get_node(id)
		n.type = goal_types.get(int(n.layout.get("col", -1)), &"core")
		_fixed[id] = true
	if not _place_extracts():
		return false
	_assign_by_weights()
	_enforce_quota()
	_enforce_coverage()
	_enforce_adjacency()
	g.layout_meta["type_rules"] = rules.to_meta()
	return true


## 中途撤离点：允许的层里、离已有撤离点够远的候选，每次挑最远的那几个里随机一个
func _place_extracts() -> bool:
	if _rules.extract_rows.is_empty() or _rules.extract_count.y <= 0:
		return true
	var want := _rng.randi_range(maxi(0, _rules.extract_count.x), maxi(_rules.extract_count.x, _rules.extract_count.y))
	var placed: Array[int] = []
	for _k in want:
		var pool: Array[int] = []
		var best := -1
		for r in _rules.extract_rows:
			for id in _by_row.get(int(r), []):
				if _fixed.has(id):
					continue
				var d := _distance_to(id, placed)
				if d < _rules.extract_min_distance:
					continue
				if d > best:
					best = d
					pool = [id]
				elif d == best:
					pool.append(id)
		if pool.is_empty():
			break
		var pick: int = pool[_rng.randi_range(0, pool.size() - 1)]
		_g.get_node(pick).type = &"extract"
		_fixed[pick] = true
		placed.append(pick)
	if placed.size() < _rules.extract_count.x:
		note = "撤离点只放下 %d 个，至少要 %d（允许的层 %s、间距 %d）" % [placed.size(), _rules.extract_count.x, str(_rules.extract_rows), _rules.extract_min_distance]
		return false
	return true


func _distance_to(id: int, others: Array[int]) -> int:
	if others.is_empty():
		return 1 << 20
	var dist := MapNavigator.distance_map(_g, id)
	var best := 1 << 20
	for o in others:
		best = mini(best, int(dist.get(o, 1 << 20)))
	return best


func _assign_by_weights() -> void:
	for id in _g.node_ids():
		if not _fixed.has(id):
			_g.get_node(id).type = _weighted(_rules.type_weights, [])


## 按权重抽一个，跳过 [param exclude] 里的。表空了退回 battle（按字典插入序扣减，140 M-25 合进 [method MapRng.pick_weighted]）
func _weighted(weights: Dictionary, exclude: Array) -> StringName:
	return MapRng.pick_weighted(weights, _rng, [], exclude, &"battle")


## 每层配额：超了把多的改成自由类型；缺了从本层的自由类型点里改
func _enforce_quota() -> void:
	var free := _rules.free_types()
	for r in _by_row:
		for t in _rules.quota:
			var lim: Array = _rules.quota[t]
			var have: Array[int] = []
			var spare: Array[int] = []
			for id in _by_row[r]:
				if _fixed.has(id):
					continue
				var n := _g.get_node(id)
				if n.type == StringName(String(t)):
					have.append(id)
				elif free.has(String(n.type)):
					spare.append(id)
			have.assign(MapRng.shuffled(have, _rng))
			spare.assign(MapRng.shuffled(spare, _rng))
			while have.size() > int(lim[1]) and not have.is_empty():
				var id: int = have.pop_back()
				_g.get_node(id).type = _weighted(_rules.type_weights, _non_free())
			while have.size() < int(lim[0]) and not spare.is_empty():
				var id2: int = spare.pop_back()
				_g.get_node(id2).type = StringName(String(t))
				have.append(id2)


func _non_free() -> Array:
	var out: Array = []
	for t in _rules.type_weights:
		if not _rules.free_types().has(String(t)):
			out.append(String(t))
	return out


## 步数覆盖：每个（不在高危层的）点距最近的 T 不超过 K。贪心：每次把能新覆盖最多点的自由点改成 T，
## 只在配额还允许的层里改
func _enforce_coverage() -> void:
	var free := _rules.free_types()
	for t in _rules.coverage:
		var type := StringName(String(t))
		var k := int(_rules.coverage[t])
		for _round in 64:
			var dist := MapNavigator.distances_to_type(_g, type)
			var uncovered: Array[int] = []
			for id in _g.node_ids():
				if int(dist.get(id, 1 << 20)) > k and _g.get_node(id).danger <= _rules.no_haven_in_danger_above:
					uncovered.append(id)
			if uncovered.is_empty():
				break
			var best := -1
			var best_gain := 0
			for id in _g.node_ids():
				var n := _g.get_node(id)
				if _fixed.has(id) or not free.has(String(n.type)) or n.danger > _rules.no_haven_in_danger_above:
					continue
				if not _quota_allows(int(n.layout.get("row", -1)), type):
					continue
				var reach := MapNavigator.distance_map(_g, id)
				var gain := 0
				for u in uncovered:
					if int(reach.get(u, 1 << 20)) <= k:
						gain += 1
				if gain > best_gain:
					best_gain = gain
					best = id
			if best < 0:
				break
			_g.get_node(best).type = type


func _quota_allows(r: int, type: StringName) -> bool:
	if not _rules.quota.has(String(type)):
		return true
	var lim: Array = _rules.quota[String(type)]
	var n := 0
	for id in _by_row.get(r, []):
		if _g.get_node(id).type == type:
			n += 1
	return n < int(lim[1])


## 不许相邻：违反的那一对里挑一个非固定的改成不和邻居冲突的自由类型
func _enforce_adjacency() -> void:
	var free := _rules.free_types()
	for _round in 3:
		var changed := false
		for e in _g.edges:
			if not _violates(e.from_id, e.to_id):
				continue
			var pick := e.to_id if not _fixed.has(e.to_id) else e.from_id
			if _fixed.has(pick):
				continue
			for t in MapRng.shuffled(free, _rng):
				_g.get_node(pick).type = StringName(t)
				var ok := true
				for n in _g.neighbors(pick):
					if _violates(pick, n):
						ok = false
				if ok:
					changed = true
					break
		if not changed:
			return


func _violates(a: int, b: int) -> bool:
	return MapNodeTypes.pair_forbidden(_rules.no_adjacent, _g.get_node(a).type, _g.get_node(b).type)
