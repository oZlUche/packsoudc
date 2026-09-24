## 格阵形态（沙漏、塔）的类型规则（8-2，报告 078）：权重、每层配额、步数覆盖、不许相邻、撤离点落在哪几层。
##
## 和环形图的分法一样（035 的教训）：**图自身的性质**进校验（写进 `layout_meta.type_rules`，规则跟着图走）；
## 怎么挑是生成规则，校验不查。没有路线的概念 —— 格阵的路线是玩家自己走出来的。
class_name LatticeTypeRules
extends Resource

## 类型 → 权重，非固定的点按它抽
@export var type_weights: Dictionary = {"battle": 3, "search": 3, "event": 3, "random": 2, "elite": 1}
## 每一层的配额：类型 → [至少, 至多]
@export var quota: Dictionary = {"shop": [0, 1], "rest": [0, 2], "elite": [0, 2]}
## 类型 → 每个点到最近该类型点的步数上限（喘气处的覆盖）
@export var coverage: Dictionary = {"rest": 4, "shop": 6}
## danger 高于此值的层里不放喘气的地方（coverage 里列的那几种）
@export var no_haven_in_danger_above: int = 1
## 不许相邻的类型对
@export var no_adjacent: Array = [["elite", "elite"], ["shop", "shop"]]
## 中途撤离点只落在这几层（0 = 出生那层）。空 = 这张图没有中途撤离点
@export var extract_rows: Array[int] = []
## 放几个中途撤离点 [至少, 至多]
@export var extract_count: Vector2i = Vector2i(1, 2)
## 撤离点两两之间的最短路至少几步
@export var extract_min_distance: int = 4
## 抽到了就不许被撤离点、覆盖修正覆盖掉的类型
@export var mandatory_types: Array[StringName] = [&"elite", &"shop", &"rest"]


## 写进图的那一份（校验从图上读，手上不必有配置）
func to_meta() -> Dictionary:
	var rows: Array = []
	for r in extract_rows:
		rows.append(int(r))
	return {
		"quota": quota.duplicate(true),
		"coverage": coverage.duplicate(true),
		"no_haven_in_danger_above": no_haven_in_danger_above,
		"no_adjacent": no_adjacent.duplicate(true),
		"extract_rows": rows,
		"extract_min_distance": extract_min_distance,
		"spawn_typed_entries": true,
	}


## 类型 → 权重里「可以随便换」的那几种（不在配额里、不是喘气处）
func free_types() -> Array[String]:
	var out: Array[String] = []
	for t in type_weights:
		if not quota.has(t) and not coverage.has(t) and not mandatory_types.has(StringName(String(t))):
			out.append(String(t))
	return out


## 图自身的类型性质（规则从图上读；和生成器无关，手改的图也能问）
static func validate(graph: MapGraph, v: MapValidation) -> void:
	var rules: Dictionary = graph.layout_meta.get("type_rules", {})
	if rules.is_empty():
		return
	var by_row := {}
	for id in graph.node_ids():
		var r := int(graph.get_node(id).layout.get("row", -1))
		if not by_row.has(r):
			by_row[r] = [] as Array[int]
		(by_row[r] as Array[int]).append(id)

	# --- 每层配额 ---
	var quota_rules: Dictionary = rules.get("quota", {})
	for r in by_row:
		for t in quota_rules:
			var lim: Array = quota_rules[t]
			var n := 0
			for id in by_row[r]:
				if graph.get_node(id).type == StringName(String(t)):
					n += 1
			if n < int(lim[0]) or n > int(lim[1]):
				v.fail(&"quota", "第 %d 层有 %d 个 %s，配额是 %d～%d" % [r, n, t, lim[0], lim[1]])

	# --- 步数覆盖与高危层里不放喘气处 ---
	var threshold := int(rules.get("no_haven_in_danger_above", 1))
	var coverage_rules: Dictionary = rules.get("coverage", {})
	for t in coverage_rules:
		var k := int(coverage_rules[t])
		var dist := RingTypeAssigner.distances_to_type(graph, StringName(String(t)))
		var over := 0
		for id in graph.node_ids():
			if int(dist.get(id, 1 << 20)) > k and graph.get_node(id).danger <= threshold:
				over += 1
		if over > 0:
			v.fail(&"coverage", "%d 个节点距最近的 %s 超过 %d 步" % [over, t, k])
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.danger > threshold and coverage_rules.has(String(n.type)):
			v.fail(&"haven", "节点 %d 在 danger %d 的层里，却是 %s" % [id, n.danger, n.type])

	# --- 出生点是 spawn、spawn 都是出生点；终点是 core ---
	if bool(rules.get("spawn_typed_entries", false)):
		for id in graph.entry_ids:
			if graph.has_node(id) and graph.get_node(id).type != &"spawn":
				v.fail(&"spawn", "出生点 %d 的类型是 %s，不是 spawn" % [id, graph.get_node(id).type])
		for id in graph.node_ids():
			if graph.get_node(id).type == &"spawn" and not graph.entry_ids.has(id):
				v.fail(&"spawn", "节点 %d 是 spawn，却不是出生点" % id)
		for id in graph.goal_ids:
			if graph.has_node(id) and graph.get_node(id).type != &"core":
				v.fail(&"core", "终点 %d 的类型是 %s，不是 core" % [id, graph.get_node(id).type])

	# --- 不许相邻 ---
	var pairs: Array = rules.get("no_adjacent", [])
	for e in graph.edges:
		var ta := String(graph.get_node(e.from_id).type)
		var tb := String(graph.get_node(e.to_id).type)
		for pair in pairs:
			if (pair[0] == ta and pair[1] == tb) or (pair[0] == tb and pair[1] == ta):
				v.fail(&"adjacent", "%d（%s）与 %d（%s）挨着" % [e.from_id, ta, e.to_id, tb])

	# --- 中途撤离点只在允许的层、两两够远 ---
	var allowed: Array = rules.get("extract_rows", [])
	var gap := int(rules.get("extract_min_distance", 0))
	var extracts: Array[int] = []
	for id in graph.node_ids():
		if graph.get_node(id).type == &"extract":
			extracts.append(id)
			var r := int(graph.get_node(id).layout.get("row", -1))
			if not allowed.has(r):
				v.fail(&"extract_row", "撤离点 %d 在第 %d 层，允许的是 %s" % [id, r, str(allowed)])
	if gap > 1:
		for i in extracts.size():
			var dist := MapNavigator.distance_map(graph, extracts[i])
			for j in range(i + 1, extracts.size()):
				if dist.has(extracts[j]) and int(dist[extracts[j]]) < gap:
					v.fail(&"extract_gap", "撤离点 %d 与 %d 只隔 %d 步，至少 %d" % [extracts[i], extracts[j], dist[extracts[j]], gap])
