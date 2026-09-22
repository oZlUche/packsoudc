## 给一张已有拓扑的同心环图填节点类型（架构文档 5.4 步骤 5，M3-3c）。
##
## 输入是拓扑齐全、类型全是占位 `battle` 的 [MapGraph] 加配置，输出是填好 `type` 的同一张图。
## 单独一个类，因为拓扑与类型各有一套规矩，混在一起出了错分不清是路没铺好还是类型填错了。
##
## 两类规矩，按 035 的教训分开放：
## - **图自身的性质**进校验（[method validate]，规则跟着图走，写进 `layout_meta.type_rules`）：
##   环配额、步数覆盖、高危区里不放休息区与商店、不许相邻的类型对、高危区里的精英与搜索点、
##   每 N 环一个撤离点。
## - **路线相关的**只在生成时尽力（[method _calibrate_routes]）：风格的 `mix`、风险收益档位、
##   性价比相当。校验一条都不查 —— 路线是生成规则，不是合格条件。
class_name RingTypeAssigner
extends RefCounted

## 路线校准最多走几轮。每轮改一个节点的类型
const MAX_CALIBRATION_ROUNDS := 40

var note: String = ""

var _g: MapGraph
var _cfg: RingMapConfig
var _rng: RandomNumberGenerator
## 不许再改类型的节点：核心、撤离点、高危区里为凑数改出来的精英与搜索点
var _fixed: Dictionary = {}
## id -> 经过它的路线下标
var _routes_of: Dictionary = {}
## 已经按规则定过类型的节点（还可以被后面的修正改）
var _assigned: Dictionary = {}
var _haven: Array[String] = []
var _mandatory: Array[String] = []
## ring -> Array[int]；ring -> {type -> 个数}。类型分配时节点集不变，算一次就够，
## 否则 _can_become 每问一次都要扫全图，覆盖那一步是 O(n²) 次问
var _by_ring: Dictionary = {}
var _counts: Dictionary = {}


func assign(g: MapGraph, cfg: RingMapConfig, rng: RandomNumberGenerator) -> bool:
	_g = g
	_cfg = cfg
	_rng = rng
	_fixed = {}
	_assigned = {}
	_haven = _sorted_keys(cfg.coverage)
	_mandatory = []
	for t in cfg.mandatory_types:
		_mandatory.append(String(t))
	_index_routes()
	_by_ring = {}
	_counts = {}
	for id in g.node_ids():
		var r := _ring(id)
		if not _by_ring.has(r):
			_by_ring[r] = [] as Array[int]
			_counts[r] = {}
		(_by_ring[r] as Array[int]).append(id)
		_bump(r, String(g.get_node(id).type), 1)
	for id in g.goal_ids:
		_fixed[id] = true

	_assign_zone_content()
	_fix_route_ends()
	_assign_route_mix()
	_assign_by_weights()
	_enforce_quota()
	_enforce_coverage()
	_enforce_adjacency()
	_place_extracts()
	_calibrate_routes()
	_write_route_scores()
	g.layout_meta["type_rules"] = rules_from_config(cfg)
	return true


#region 步骤
func _index_routes() -> void:
	_routes_of = {}
	for i in _g.routes.size():
		for id in (_g.routes[i]["node_ids"] as Array):
			if not _routes_of.has(int(id)):
				_routes_of[int(id)] = [] as Array[int]
			(_routes_of[int(id)] as Array[int]).append(i)


## 高危区里先凑够精英与搜索点。**被吸收进来的路线节点不许当必须型**（036）——
## 精英只放在非路线的成员上，优先放在出入口。
func _assign_zone_content() -> void:
	var spec := _cfg.zone_spec
	if spec == null:
		return
	var zone_ids: Array = _g.zones.keys()
	zone_ids.sort()
	for zone_id in zone_ids:
		var members: Array = _g.zones[zone_id]["node_ids"]
		if members.is_empty() or _g.get_node(int(members[0])).danger < 2:
			continue
		var gates: Array = _g.zones[zone_id].get("gate_ids", [])
		var elite_pool: Array[int] = []
		for id in gates:
			if not _absorbed(int(id)) and not _fixed.has(int(id)):
				elite_pool.append(int(id))
		for id in members:
			if not _absorbed(int(id)) and not _fixed.has(int(id)) and not elite_pool.has(int(id)):
				elite_pool.append(int(id))
		for k in mini(spec.min_elites, elite_pool.size()):
			_put_type(elite_pool[k], &"elite", true)
		var search_pool: Array[int] = []
		for id in members:
			if not _fixed.has(int(id)):
				search_pool.append(int(id))
		search_pool = _shuffled(search_pool)
		for k in mini(spec.min_search, search_pool.size()):
			_put_type(search_pool[k], &"search", true)


## 去撤离点的路线，末端定为撤离点。
func _fix_route_ends() -> void:
	for route in _g.routes:
		if String(route.get("ends_at", "core")) != "extract":
			continue
		var ids: Array = route["node_ids"]
		if not ids.is_empty():
			_put_type(int(ids[-1]), &"extract", true)


## 路线独占的节点按风格的 mix 比例分配；几条路线共用的算混合，走所在环的权重。
func _assign_route_mix() -> void:
	for i in _g.routes.size():
		var style := _cfg.style_by_id(StringName(_g.routes[i].get("style", "")))
		var exclusive: Array[int] = []
		for id in (_g.routes[i]["node_ids"] as Array):
			var n := _g.get_node(int(id))
			if (_routes_of[int(id)] as Array).size() == 1 and not _fixed.has(int(id)) and n.zone == 0:
				exclusive.append(int(id))
		if exclusive.is_empty():
			continue
		var mix: Dictionary = style.mix if style != null else {}
		if mix.is_empty():
			continue
		# 按比例配额：最大余数法，再打乱
		var keys := _sorted_keys(mix)
		var total := 0.0
		for k in keys:
			total += float(mix[k])
		var counts := {}
		var given := 0
		var remainders := []
		for k in keys:
			var exact := float(mix[k]) / maxf(total, 0.001) * float(exclusive.size())
			counts[k] = floori(exact)
			given += int(counts[k])
			remainders.append([exact - floorf(exact), k])
		remainders.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		for r in remainders:
			if given >= exclusive.size():
				break
			counts[r[1]] = int(counts[r[1]]) + 1
			given += 1
		var bag: Array[String] = []
		for k in keys:
			for _c in int(counts[k]):
				bag.append(k)
		bag = _shuffled_strings(bag)
		var order := _shuffled(exclusive)
		for j in order.size():
			_put_type(order[j], StringName(bag[j]), false)


## 其余节点按所在环的权重抽。
func _assign_by_weights() -> void:
	for id in _g.node_ids():
		if _fixed.has(id) or _assigned.has(id):
			continue
		var t := _pick_weighted(_weights_for(id))
		if t != &"":
			_put_type(id, t, false)


## 环配额：超了改成权重次高的可替换类型，缺了从本环的非固定节点里改。
func _enforce_quota() -> void:
	for r in range(_ring_count(), 0, -1):
		var spec := _cfg.spec_for_ring(r)
		if spec == null or spec.quota.is_empty():
			continue
		var ring_ids := _ring_ids(r)
		for t in _sorted_keys(spec.quota):
			var lim := _quota(r, t)
			while _count(ring_ids, t) > lim.y:
				var victim := _pick_of_type(ring_ids, t)
				if victim < 0:
					break
				var alt := _replacement_type(victim, [t])
				if alt == &"":
					break
				_put_type(victim, alt, false)
		for t in _sorted_keys(spec.quota):
			var lim := _quota(r, t)
			while _count(ring_ids, t) < lim.x:
				var pool: Array[int] = []
				for id in ring_ids:
					if _can_become(id, StringName(t)):
						pool.append(id)
				if pool.is_empty():
					break
				_put_type(pool[_rng.randi_range(0, pool.size() - 1)], StringName(t), false)


## 步数覆盖：每个节点距最近的 T 不超过 K。贪心集合覆盖 —— 挑能覆盖最多超标节点的候选改成 T。
## 高危区里的点不算：那里本来就不放喘气的地方，进去就是知道没得歇。
func _enforce_coverage() -> void:
	for t in _haven:
		var k := int(_cfg.coverage[t])
		for _guard in _g.node_count():
			var dist := distances_to_type(_g, StringName(t))
			var uncovered: Array[int] = []
			for id in _g.node_ids():
				if int(dist.get(id, 1 << 20)) > k and _needs_haven(_g.get_node(id)):
					uncovered.append(id)
			if uncovered.is_empty():
				break
			# 从每个超标点出发走 K 步，沿途的候选各记一分 —— 超标点少、候选多，反过来算贵得多
			var gain := {}
			for u in uncovered:
				for id in _within_steps(u, k):
					gain[id] = int(gain.get(id, 0)) + 1
			var best := -1
			var best_gain := 0
			for id in _g.node_ids():
				var g_: int = gain.get(id, 0)
				if g_ <= best_gain or _g.get_node(id).type == StringName(t) or not _can_become(id, StringName(t)):
					continue
				best = id
				best_gain = g_
			if best < 0:
				break       # 没有候选能改善。校验会说覆盖不达标，这一次就换种子
			_put_type(best, StringName(t), false)


## 不许相邻的类型对：违反的换成权重次高的。
func _enforce_adjacency() -> void:
	for e in _g.edges:
		if not _pair_forbidden(_g.get_node(e.from_id).type, _g.get_node(e.to_id).type):
			continue
		for id in [e.to_id, e.from_id]:
			if _fixed.has(id):
				continue
			var alt := _replacement_type(id, [String(_g.get_node(id).type)])
			if alt != &"":
				_put_type(id, alt, false)
				break


## 撤离点：先按各路线的 bailout_every_rings 在路线上放，再按全图的 extract_every_rings 补。
## 撤离点**覆盖**非必须型节点 —— 出口吃掉休息区，玩家就没地方喘气了。
func _place_extracts() -> void:
	for route in _g.routes:
		var style := _cfg.style_by_id(StringName(route.get("style", "")))
		if style == null or style.bailout_every_rings <= 0:
			continue
		var ids: Array = route["node_ids"]
		var outer := _ring_count()
		var next_at := outer - style.bailout_every_rings
		for id in ids:
			var r := _ring(int(id))
			if r > next_at or r <= 0:
				continue
			if _can_become(int(id), &"extract"):
				_put_type(int(id), &"extract", true)
				next_at = r - style.bailout_every_rings
			# 这个点动不了（必须型 / 固定）就顺着路线看下一个，别硬改
	var step := _cfg.extract_every_rings
	if step <= 0:
		return
	var r_hi := _ring_count()
	while r_hi >= 1:
		var r_lo := maxi(1, r_hi - step + 1)
		var window: Array[int] = []
		var has := false
		for id in _g.node_ids():
			var r := _ring(id)
			if r >= r_lo and r <= r_hi:
				if _g.get_node(id).type == &"extract":
					has = true
				elif _can_become(id, &"extract"):
					window.append(id)
		if not has and not window.is_empty():
			_put_type(window[_rng.randi_range(0, window.size() - 1)], &"extract", true)
		r_hi = r_lo - 1


## 路线风险 / 收益校准（5.4.2）。**尽力而为，不进校验。**
##
## 每轮在各路线的独占节点里挑「改一个类型能把总违规量降得最多」的那一处改掉，
## 直到没有违规、没有改善、或轮数用尽。
## 换【出去】的只能是非必须型、非喘气型（换掉休息区会牵动覆盖，换掉精英会牵动配额）；
## 换【进来】的可以是精英这类必须型，但只限于风格 mix 里列了它的路线 —— 配额与禁止相邻照样守着，
## 偏战斗的路线要靠它抬风险；不然战斗路线抬不上去，校准只能把别的路线往下压，压出一堆事件点。
## 偏搜索的路线 mix 里没有精英，就不会为了拉平性价比往它身上塞精英。
func _calibrate_routes() -> void:
	if _g.routes.size() < 2:
		return
	var swappable: Array[String] = []      # 能换出去的
	var targets: Array[String] = []        # 能换进来的
	for t in _sorted_keys(_cfg.type_risk):
		if _haven.has(t) or t == "extract" or t == "core":
			continue
		targets.append(t)
		if not _mandatory.has(t):
			swappable.append(t)
	var candidates: Array[int] = []
	for id in _g.node_ids():
		if _fixed.has(id) or not _routes_of.has(id) or (_routes_of[id] as Array).size() != 1:
			continue
		var t := String(_g.get_node(id).type)
		if _g.get_node(id).zone == 0 and swappable.has(t):
			candidates.append(id)

	# 增量算：每个候选改动只影响一条路线的分数和构成，不必每次把全图重算一遍
	var sums := route_scores(_g, _cfg)
	var comps: Array[Dictionary] = []
	for i in _g.routes.size():
		comps.append(_exclusive_composition(i))
	for _round in MAX_CALIBRATION_ROUNDS:
		var base := _violation_of(sums, comps)
		if base <= 1e-6:
			return
		var best_id := -1
		var best_type := &""
		var best_score := base
		for id in candidates:
			var n := _g.get_node(id)
			var old := n.type
			if not swappable.has(String(old)):
				continue        # 上一轮换成了必须型，就不再动它
			var ri: int = (_routes_of[id] as Array)[0]
			var style := _cfg.style_by_id(StringName(_g.routes[ri].get("style", "")))
			var old_score := node_score(_cfg, n)
			for t in targets:
				if StringName(t) == old or not _can_become(id, StringName(t)):
					continue
				if _mandatory.has(t) and (style == null or not style.mix.has(t)):
					continue
				n.type = StringName(t)
				var new_score := node_score(_cfg, n)
				n.type = old
				var saved_sum: Dictionary = sums[ri]
				var saved_comp: Dictionary = comps[ri]
				sums[ri] = {"risk": saved_sum["risk"] - old_score["risk"] + new_score["risk"],
					"reward": saved_sum["reward"] - old_score["reward"] + new_score["reward"]}
				var comp := saved_comp.duplicate()
				comp[String(old)] = int(comp.get(String(old), 0)) - 1
				comp[t] = int(comp.get(t, 0)) + 1
				comps[ri] = comp
				var score := _violation_of(sums, comps)
				sums[ri] = saved_sum
				comps[ri] = saved_comp
				if score < best_score - 1e-6:
					best_score = score
					best_id = id
					best_type = StringName(t)
		if best_id < 0:
			return
		var ri: int = (_routes_of[best_id] as Array)[0]
		var before := node_score(_cfg, _g.get_node(best_id))
		var old_t := String(_g.get_node(best_id).type)
		_put_type(best_id, best_type, false)
		var after := node_score(_cfg, _g.get_node(best_id))
		sums[ri] = {"risk": sums[ri]["risk"] - before["risk"] + after["risk"],
			"reward": sums[ri]["reward"] - before["reward"] + after["reward"]}
		comps[ri][old_t] = int(comps[ri].get(old_t, 0)) - 1
		comps[ri][String(best_type)] = int(comps[ri].get(String(best_type), 0)) + 1


func _exclusive_composition(route_index: int) -> Dictionary:
	var comp := {}
	for id in (_g.routes[route_index]["node_ids"] as Array):
		if (_routes_of[int(id)] as Array).size() == 1 and _g.get_node(int(id)).zone == 0 				and not _fixed.has(int(id)):
			var t := String(_g.get_node(int(id)).type)
			comp[t] = int(comp.get(t, 0)) + 1
	return comp


## 分数记成【百分之一为单位的整数】：自由字典过 JSON 时整数值的浮点会被还原成整数，
## 11.0 存一次读一次就变了 11，「同一张图永远导出同样的字节」就不成立了（MapGraph.normalize）
func _write_route_scores() -> void:
	var scores := route_scores(_g, _cfg)
	for i in _g.routes.size():
		_g.routes[i]["risk_x100"] = roundi(scores[i]["risk"] * 100.0)
		_g.routes[i]["reward_x100"] = roundi(scores[i]["reward"] * 100.0)
#endregion


#region 打分
## 一个节点的风险分与收益分：type_risk / type_reward × danger 倍率。
## 搜索点按基准搜索次数计 —— 搜几次是玩家的旋钮，生成器只按基准定档。
static func node_score(cfg: RingMapConfig, n: MapNode) -> Dictionary:
	var t := String(n.type)
	var risk := float(cfg.type_risk.get(t, 0.0))
	var reward := float(cfg.type_reward.get(t, 0.0))
	if n.type == &"search":
		risk *= float(cfg.reference_searches)
		reward *= float(cfg.reference_searches)
	var d := clampi(n.danger, 0, 99)
	var rm := cfg.danger_risk_multiplier
	var wm := cfg.danger_reward_multiplier
	risk *= rm[mini(d, rm.size() - 1)] if not rm.is_empty() else 1.0
	reward *= wm[mini(d, wm.size() - 1)] if not wm.is_empty() else 1.0
	return {"risk": risk, "reward": reward}


## 每条路线的风险分与收益分（沿路线求和）。
static func route_scores(g: MapGraph, cfg: RingMapConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for route in g.routes:
		var risk := 0.0
		var reward := 0.0
		for id in (route["node_ids"] as Array):
			var n := g.get_node(int(id))
			if n == null:
				continue
			var s := node_score(cfg, n)
			risk += s["risk"]
			reward += s["reward"]
		out.append({"risk": risk, "reward": reward})
	return out


## 各路线相对全图平均的档位，以及性价比的离散度。给校准、统计与编辑器看。
static func route_bands(g: MapGraph, cfg: RingMapConfig) -> Dictionary:
	return bands_of(route_scores(g, cfg))


static func bands_of(scores: Array) -> Dictionary:
	var mean_risk := 0.0
	var mean_reward := 0.0
	for s in scores:
		mean_risk += s["risk"]
		mean_reward += s["reward"]
	mean_risk = maxf(mean_risk / maxi(1, scores.size()), 1e-6)
	mean_reward = maxf(mean_reward / maxi(1, scores.size()), 1e-6)
	var rel: Array[Dictionary] = []
	var ratios: Array[float] = []
	for s in scores:
		var ratio: float = s["reward"] / maxf(s["risk"], 1e-6)
		ratios.append(ratio)
		rel.append({"risk": s["risk"] / mean_risk, "reward": s["reward"] / mean_reward, "ratio": ratio})
	var lo: float = ratios.min() if not ratios.is_empty() else 0.0
	var hi: float = ratios.max() if not ratios.is_empty() else 0.0
	var mean_ratio := 0.0
	for r in ratios:
		mean_ratio += r
	mean_ratio = maxf(mean_ratio / maxi(1, ratios.size()), 1e-6)
	return {"rel": rel, "ev_spread": (hi - lo) / mean_ratio}


## 总违规量：各路线偏出自己档位多少 + 性价比离散超出容差多少 + 偏离 mix 多少（轻一点）。
## 0 = 全达标。mix 那一项只是让校准少动几个不必动的点，不是硬指标。
const MIX_WEIGHT := 0.04

func _violation_of(sums: Array, comps: Array) -> float:
	var bands := bands_of(sums)
	var total := 0.0
	var rel: Array = bands["rel"]
	for i in rel.size():
		var style := _cfg.style_by_id(StringName(_g.routes[i].get("style", "")))
		if style == null:
			continue
		total += _outside(rel[i]["risk"], style.risk_band) + _outside(rel[i]["reward"], style.reward_band)
		total += MIX_WEIGHT * _mix_deviation(comps[i], style)
	total += maxf(0.0, float(bands["ev_spread"]) - _cfg.ev_tolerance)
	return total


## 这条路线独占节点的类型构成与风格 mix 差多少（各类型份额之差的绝对值之和，0～2）。
static func _mix_deviation(comp: Dictionary, style: RouteStyle) -> float:
	if style.mix.is_empty():
		return 0.0
	var n := 0
	for k in comp:
		n += int(comp[k])
	if n <= 0:
		return 0.0
	var total := 0.0
	for k in style.mix:
		total += float(style.mix[k])
	var dev := 0.0
	var seen := {}
	for k in style.mix:
		dev += absf(float(style.mix[k]) / total - float(comp.get(String(k), 0)) / float(n))
		seen[String(k)] = true
	for k in comp:
		if not seen.has(k):
			dev += float(comp[k]) / float(n)
	return dev


static func _outside(value: float, band: Vector2) -> float:
	return maxf(0.0, band.x - value) + maxf(0.0, value - band.y)
#endregion


#region 校验（规则从图上读）
static func rules_from_config(cfg: RingMapConfig) -> Dictionary:
	var quota := {}
	for i in cfg.rings.size():
		var spec := cfg.rings[i]
		if spec != null and not spec.quota.is_empty():
			var per := {}
			for t in spec.quota:
				var lim = spec.quota[t]
				per[String(t)] = [int(lim[0]), int(lim[1])]
			quota[str(cfg.ring_count() - i)] = per
	var mandatory: Array = []
	for t in cfg.mandatory_types:
		mandatory.append(String(t))
	var rules := {
		"quota": quota,
		"coverage": cfg.coverage.duplicate(),
		"no_haven_in_danger_above": cfg.no_haven_in_danger_above,
		"no_adjacent": cfg.no_adjacent.duplicate(true),
		"mandatory_types": mandatory,
		"extract_every_rings": cfg.extract_every_rings,
	}
	if cfg.zone_spec != null:
		rules["zone_min"] = {"elite": cfg.zone_spec.min_elites, "search": cfg.zone_spec.min_search}
	return rules


## 类型相关的、**图自身的**规矩。图上没有 type_rules（老存档、手绘图）就什么都不查。
static func validate(graph: MapGraph, v: MapValidation) -> void:
	var rules: Dictionary = graph.layout_meta.get("type_rules", {})
	if rules.is_empty():
		return
	var ring_count := int(graph.layout_meta.get("ring_count", 0))
	var by_ring := {}
	for id in graph.node_ids():
		var r := int(graph.get_node(id).layout.get("ring", -1))
		if not by_ring.has(r):
			by_ring[r] = [] as Array[int]
		(by_ring[r] as Array[int]).append(id)

	# --- 环配额 ---
	var quota: Dictionary = rules.get("quota", {})
	for r_key in quota:
		var r := int(r_key)
		var per: Dictionary = quota[r_key]
		for t in per:
			var lim: Array = per[t]
			var n := 0
			for id in by_ring.get(r, []):
				if graph.get_node(id).type == StringName(t):
					n += 1
			if n < int(lim[0]) or n > int(lim[1]):
				v.fail(&"quota", "第 %d 环有 %d 个 %s，配额是 %d～%d" % [r, n, t, lim[0], lim[1]])

	# --- 步数覆盖（高危区里的点不算：那里本来就没得歇）---
	var threshold := int(rules.get("no_haven_in_danger_above", 1))
	var coverage: Dictionary = rules.get("coverage", {})
	for t in coverage:
		var k := int(coverage[t])
		var dist := distances_to_type(graph, StringName(t))
		var over := 0
		var worst := 0
		for id in graph.node_ids():
			var d := int(dist.get(id, 1 << 20))
			if d > k and graph.get_node(id).danger <= threshold:
				over += 1
				worst = maxi(worst, d)
		if over > 0:
			v.fail(&"coverage", "%d 个节点距最近的 %s 超过 %d 步（最远 %s）"
				% [over, t, k, "到不了" if worst >= (1 << 20) else str(worst)])

	# --- 高危区里不放喘气的地方 ---
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.danger > threshold and coverage.has(String(n.type)):
			v.fail(&"haven", "节点 %d 在 danger %d 的区域里，却是 %s" % [id, n.danger, n.type])

	# --- 不许相邻 ---
	var pairs: Array = rules.get("no_adjacent", [])
	for e in graph.edges:
		var ta := String(graph.get_node(e.from_id).type)
		var tb := String(graph.get_node(e.to_id).type)
		for pair in pairs:
			if (pair[0] == ta and pair[1] == tb) or (pair[0] == tb and pair[1] == ta):
				v.fail(&"adjacent", "%d（%s）与 %d（%s）挨着" % [e.from_id, ta, e.to_id, tb])

	# --- 高危区里的精英与搜索点 ---
	var zone_min: Dictionary = rules.get("zone_min", {})
	if not zone_min.is_empty():
		for zone_id in graph.zones:
			var ids: Array = graph.zones[zone_id]["node_ids"]
			if ids.is_empty() or graph.get_node(int(ids[0])).danger < 2:
				continue
			for t in zone_min:
				var n := 0
				for id in ids:
					if graph.get_node(int(id)).type == StringName(t):
						n += 1
				if n < int(zone_min[t]):
					v.fail(&"zone_content", "高危区 %s 只有 %d 个 %s，至少要 %d" % [zone_id, n, t, zone_min[t]])

	# --- 每 N 环至少一个撤离点 ---
	var step := int(rules.get("extract_every_rings", 0))
	if step > 0 and ring_count > 0:
		var r_hi := ring_count
		while r_hi >= 1:
			var r_lo := maxi(1, r_hi - step + 1)
			var has := false
			for r in range(r_lo, r_hi + 1):
				for id in by_ring.get(r, []):
					if graph.get_node(id).type == &"extract":
						has = true
			if not has:
				v.fail(&"extract", "第 %d～%d 环之间没有撤离点" % [r_lo, r_hi])
			r_hi = r_lo - 1


## 每个节点到最近的某类型节点的步数（多源 BFS）。到不了的不在结果里。
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
#endregion


#region 小工具
func _put_type(id: int, type: StringName, fix: bool) -> void:
	var n := _g.get_node(id)
	var r := _ring(id)
	_bump(r, String(n.type), -1)
	_bump(r, String(type), 1)
	n.type = type
	_assigned[id] = true
	if fix:
		_fixed[id] = true


func _needs_haven(n: MapNode) -> bool:
	return n.danger <= _cfg.no_haven_in_danger_above


func _absorbed(id: int) -> bool:
	return _routes_of.has(id) and _g.get_node(id).zone != 0


func _ring(id: int) -> int:
	return int(_g.get_node(id).layout.get("ring", 0))


func _ring_count() -> int:
	return _cfg.ring_count()


func _ring_ids(r: int) -> Array[int]:
	return _by_ring.get(r, [] as Array[int])


func _bump(r: int, type: String, delta: int) -> void:
	var per: Dictionary = _counts[r]
	per[type] = int(per.get(type, 0)) + delta


func _count_in_ring(r: int, type: String) -> int:
	return int((_counts.get(r, {}) as Dictionary).get(type, 0))


func _count(ids: Array[int], type: String) -> int:
	var n := 0
	for id in ids:
		if _g.get_node(id).type == StringName(type):
			n += 1
	return n


## 第 r 环某类型的配额 [min, max]；没配就是 [0, 很大]。
func _quota(r: int, type: String) -> Vector2i:
	var spec := _cfg.spec_for_ring(r)
	if spec == null or not spec.quota.has(type):
		return Vector2i(0, 1 << 20)
	var lim = spec.quota[type]
	return Vector2i(int(lim[0]), int(lim[1]))


func _pick_of_type(ids: Array[int], type: String) -> int:
	var pool: Array[int] = []
	for id in ids:
		if not _fixed.has(id) and _g.get_node(id).type == StringName(type):
			pool.append(id)
	return pool[_rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else -1


## 这个节点能不能改成 type：不是固定的；不撞配额（新类型没到上限、旧类型没到下限）；
## 高危里不放喘气的；被吸收的路线节点不当必须型；不和邻居凑成禁止的一对。
## 默认**不动已经是必须型的节点** —— 放商店时把休息区盖掉，覆盖就白做了；
## 只有配额超了、或撞上禁止相邻时才允许（from_mandatory）。
func _can_become(id: int, type: StringName, from_mandatory: bool = false) -> bool:
	if _fixed.has(id):
		return false
	var n := _g.get_node(id)
	if n.type == type:
		return true
	if not from_mandatory and _mandatory.has(String(n.type)):
		return false
	var t := String(type)
	if type == &"extract" and (_mandatory.has(String(n.type)) or _haven.has(String(n.type))):
		return false     # 撤离点只覆盖非必须型 —— 出口吃掉休息区，玩家就没地方喘气了
	var r := _ring(id)
	if _count_in_ring(r, t) >= _quota(r, t).y:
		return false
	var old := String(n.type)
	if _count_in_ring(r, old) <= _quota(r, old).x:
		return false
	if n.danger > _cfg.no_haven_in_danger_above and _haven.has(t):
		return false
	if _absorbed(id) and _mandatory.has(t):
		return false
	for other in _g.neighbors(id):
		if _pair_forbidden(type, _g.get_node(other).type):
			return false
	return true


func _pair_forbidden(a: StringName, b: StringName) -> bool:
	for pair in _cfg.no_adjacent:
		if (String(pair[0]) == String(a) and String(pair[1]) == String(b)) \
				or (String(pair[0]) == String(b) and String(pair[1]) == String(a)):
			return true
	return false


## 权重次高的、能改成的类型；没有就空。
func _replacement_type(id: int, exclude: Array) -> StringName:
	# 只有这里会把必须型改成别的：配额超了、或者撞上禁止相邻的一对
	var weights := _weights_for(id)
	var keys := _sorted_keys(weights)
	keys.sort_custom(func(a, b):
		var wa := float(weights[a])
		var wb := float(weights[b])
		return wa > wb or (wa == wb and a < b))
	for t in keys:
		if exclude.has(t) or _mandatory.has(t):
			continue
		if _can_become(id, StringName(t), true):
			return StringName(t)
	return &""


## 这个节点抽类型用的权重：所在环的 type_weights，去掉这里不许放的。
func _weights_for(id: int) -> Dictionary:
	var spec := _cfg.spec_for_ring(_ring(id))
	var raw: Dictionary = spec.type_weights if spec != null and not spec.type_weights.is_empty() \
		else {"battle": 1.0}
	var n := _g.get_node(id)
	var out := {}
	for t in _sorted_keys(raw):
		if n.danger > _cfg.no_haven_in_danger_above and _haven.has(t):
			continue
		if _absorbed(id) and _mandatory.has(t):
			continue
		if _g.zones.has(n.zone) and n.zone != 0 and t == "extract":
			continue
		out[t] = float(raw[t])
	return out


func _pick_weighted(weights: Dictionary) -> StringName:
	var total := 0.0
	for t in weights:
		total += float(weights[t])
	if total <= 0.0:
		return &""
	var roll := _rng.randf() * total
	for t in _sorted_keys(weights):
		roll -= float(weights[t])
		if roll <= 0.0:
			return StringName(t)
	return StringName(_sorted_keys(weights)[-1])


func _within_steps(from_id: int, k: int) -> Dictionary:
	var dist := {from_id: 0}
	var queue: Array[int] = [from_id]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		if int(dist[id]) >= k:
			continue
		for n in _g.neighbors(id):
			if not dist.has(n):
				dist[n] = int(dist[id]) + 1
				queue.append(n)
	return dist


func _shuffled(ids: Array[int]) -> Array[int]:
	var out: Array[int] = ids.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _shuffled_strings(items: Array[String]) -> Array[String]:
	var out: Array[String] = items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


static func _sorted_keys(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in d:
		out.append(String(k))
	out.sort()
	return out
#endregion
