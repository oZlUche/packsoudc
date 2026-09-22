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
