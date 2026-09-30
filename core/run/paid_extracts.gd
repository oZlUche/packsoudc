## 把几个中途撤离点标成付费的（架构文档 6.6，M4-5）。和 [EnemyPlacer] 一样是生成之后的一遍：
## 生成器不认识钱。挑**最深**的那几个（tier 高的先；同深按 id）—— 离核心最近的出口最值钱。
## 费用记进 `node.content["fee"]`，跟着图存；核心不是中途撤离点，不收。
class_name PaidExtracts
extends RefCounted


## 标好，返回标了的节点 id（按挑选顺序）
static func mark(graph: MapGraph, rules: EconomyRules) -> Array[int]:
	var out: Array[int] = []
	if graph == null or rules == null or rules.paid_extracts <= 0:
		return out
	var extracts: Array[int] = []
	for id in graph.node_ids():
		if graph.get_node(id).type == &"extract":
			extracts.append(id)
	extracts.sort_custom(func(a: int, b: int) -> bool:
		var ta := graph.get_node(a).tier
		var tb := graph.get_node(b).tier
		return ta > tb if ta != tb else a < b)
	for i in mini(rules.paid_extracts, extracts.size()):
		graph.get_node(extracts[i]).content["fee"] = rules.extract_fee
		out.append(extracts[i])
	return out


## 这个点收多少。0 = 免费
static func fee_of(node: MapNode) -> int:
	return int(node.content.get("fee", 0)) if node != null else 0


## 092（作者定）：全局倒计时过半时关掉一个撤离点 —— 挑**离出生点最近的免费**撤离点（最容易到的那个先没了，逼人往里走或早撤）。
## `closes_at` 记进节点内容（倒计时剩这么多时关，跟着图存）。返回标了哪个点，没有可标的 -1
static func mark_closing(graph: MapGraph, step_limit: int) -> int:
	if graph == null or step_limit <= 0:
		return -1
	var best := -1
	var best_d := 1 << 30
	for entry in graph.entry_ids:
		var dist := MapNavigator.distance_map(graph, entry)
		for id in graph.node_ids():
			var n := graph.get_node(id)
			if n.type != &"extract" or fee_of(n) > 0 or not dist.has(id):
				continue
			var d := int(dist[id])
			if d < best_d or (d == best_d and id < best):
				best_d = d
				best = id
	if best < 0:
		return -1
	graph.get_node(best).content["closes_at"] = step_limit / 2
	return best


## 这个撤离点在倒计时剩多少时关闭；-1 = 不关
static func closes_at(node: MapNode) -> int:
	return int(node.content.get("closes_at", -1)) if node != null and node.content.has("closes_at") else -1
