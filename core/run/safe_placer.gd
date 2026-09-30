## 保险箱点（092，作者定）：生成之后的一遍，把几个中层的普通点换成 `safe` —— 和 [PaidExtracts] 一样，生成器不认识它。
##
## 放进保险箱的道具视为已带出（战败也带得出，结算屏单独一格看得见）。作者定的挑法（和高危区一样，生成完毕之后再挑）：
## 只覆盖**战斗或事件**点、不挨着出生点、不是终点；按「深度最接近 [constant CENTER_DEPTH]（比较靠近中央）」排，同深按 id ——
## 同一张图永远换同几个点，可复现。
## 换成保险箱的点把内容清空（敌人在这之后才由 [EnemyPlacer] 放，所以调用顺序是先这里）。
## **别把 `safe` 写进环形配置的 type_risk / type_reward**：校准会把它当成可分配的类型往图里换。
class_name SafePlacer
extends RefCounted

const CONVERTIBLE: Array[StringName] = [&"battle", &"event"]
## 想要的深度：0 是出生点那一环、1 是核心；「比较靠近中央」取 0.7
const CENTER_DEPTH := 0.7


## 标好，返回换成保险箱的节点 id（按挑选顺序）
static func mark(graph: MapGraph, count: int) -> Array[int]:
	var out: Array[int] = []
	if graph == null or count <= 0:
		return out
	var near_entry := {}
	for entry in graph.entry_ids:
		for n in graph.neighbors(entry):
			near_entry[n] = true
	var depths := EnemyPlacer.depths_of(graph)
	var candidates: Array[int] = []
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.type == &"safe":
			out.append(id)     # 预设图里画好的（K）也算数
			continue
		if not CONVERTIBLE.has(n.type) or near_entry.has(id) or graph.entry_ids.has(id) or graph.goal_ids.has(id):
			continue
		candidates.append(id)
	if out.size() >= count:
		return out
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var da: float = absf(float(depths.get(a, 0.0)) - CENTER_DEPTH)
		var db: float = absf(float(depths.get(b, 0.0)) - CENTER_DEPTH)
		return da < db if not is_equal_approx(da, db) else a < b)
	var picked: Array[int] = []
	for id in candidates:
		if out.size() >= count:
			break
		# 两个保险箱不挨着
		var adjacent := false
		for p in picked:
			if graph.neighbors(p).has(id):
				adjacent = true
				break
		if adjacent:
			continue
		var n := graph.get_node(id)
		n.type = &"safe"
		n.content = {}
		out.append(id)
		picked.append(id)
	return out
