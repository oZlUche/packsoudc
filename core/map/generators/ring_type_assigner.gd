## 给一张已有拓扑的同心环图填节点类型（架构文档 5.4 步骤 5，M3-3c）。
##
## 输入是拓扑齐全、类型全是占位 `battle` 的 [MapGraph] 加配置，输出是填好 `type` 的同一张图。
## 单独一个类，因为拓扑与类型各有一套规矩，混在一起出了错分不清是路没铺好还是类型填错了。
##
## 两类规矩，按 035 的教训分开放：
## - **图自身的性质**进校验（[method validate]，规则跟着图走，写进 `layout_meta.type_rules`）：
##   环配额、步数覆盖、高危区里不放休息区与商店、不许相邻的类型对、高危区里的精英与搜索点、
##   中途撤离点只在撤离环间。
## - **路线上的位置**是生成规则：喘气处放在路线的几分之几处、撤离点放在两条路线共用的地方，
##   校验都不查 —— 手绘的图有权不守。
## - **路线相关的**只在生成时尽力（[method _calibrate_routes]）：风格的 `mix`、风险收益档位、
##   性价比相当。校验一条都不查 —— 路线是生成规则，不是合格条件。
class_name RingTypeAssigner
extends RefCounted

## 路线校准最多走几轮。每轮改一个节点的类型
const MAX_CALIBRATION_ROUNDS := 40
## 撤离环间至少几个撤离点：一个付费、一个免费（倒计时过半还要关掉一个免费的）
const MIN_EXTRACTS := 2
## 259：路线外的点往外找最近路线的步数上限
const NEAR_STEPS := 4

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
	# 出生点是一种节点，不只是一个标记：固定为 spawn，不参与 mix、配额与校准
	for id in g.entry_ids:
		_put_type(id, &"spawn", true)

	_assign_zone_content()
	_fix_route_ends()
	_place_exit_shops()
	_place_route_havens()
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
		search_pool.assign(MapRng.shuffled(search_pool, _rng))
		for k in mini(spec.min_search, search_pool.size()):
			_put_type(search_pool[k], &"search", true)


## 去撤离点的路线，末端定为撤离点。
func _fix_route_ends() -> void:
	for route in _g.routes:
		if String(route.get("ends_at", "core")) != "extract":
			continue
		var ids: Array = route["node_ids"]
		# 一环的图上路线的末端就是出生点自己，那就不改 —— 出生点是出生点
		if not ids.is_empty() and not _fixed.has(int(ids[-1])):
			_put_type(int(ids[-1]), &"extract", true)


## 去撤离点的路线：撤离点之后的换乘区第一个点放商店（报告 053）—— 出口之后有东西可买，成了继续走的诱因。
## 放下了，这条路线上就不再按步数放商店；放不下（没有换乘区、或这一环的商店配额满了）就照旧放在路线上
func _place_exit_shops() -> void:
	if not _haven.has("shop"):
		return
	for route in _g.routes:
		var tail: Array = route.get("exit_ids", [])
		if tail.is_empty():
			continue
		var id := int(tail[0])
		if _g.get_node(id).type == &"shop" or _can_become(id, &"shop"):
			_put_type(id, &"shop", true)


func _has_exit_shop(route: Dictionary) -> bool:
	var tail: Array = route.get("exit_ids", [])
	return not tail.is_empty() and _g.get_node(int(tail[0])).type == &"shop"


## 喘气处按**路线上的步数**放，不看环：每条路线走到几分之几处放休息区、几分之几处放商店
## （MapScaleProfile.haven_at：中型 1/3 与 2/3，小型两个都在一半，撞上就挨着放）。
## 分母是路线上出生点与尽头之间的那些点。落点放不了（高危区里、配额满了、和邻居凑成禁止的一对）
## 就往两边挪一格再试。放下的固定住，后面的 mix 与配额不再动它
func _place_route_havens() -> void:
	var at := _cfg.haven_at()
	if at.is_empty():
		return
	for route in _g.routes:
		var ids: Array = route["node_ids"]
		var inner: Array[int] = []
		for k in range(1, ids.size() - 1):
			inner.append(int(ids[k]))
		if inner.is_empty():
			continue
		var used := {}
		for t in _sorted_keys(at):
			if not _haven.has(t) or (t == "shop" and _has_exit_shop(route)):
				continue
			var k := clampi(roundi(float(at[t]) * float(inner.size() - 1)), 0, inner.size() - 1)
			# 位置撞上了（小型图两个都在一半）：紧挨着放，先往尽头那边挪
			while used.has(k) and k < inner.size() - 1:
				k += 1
			for step in inner.size():
				var placed := false
				for j in ([k + step, k - step] if step > 0 else [k]):
					if j < 0 or j >= inner.size() or used.has(j):
						continue
					var id: int = inner[j]
					if _g.get_node(id).type == StringName(t):
						used[j] = true
						placed = true
						break
					if _can_become(id, StringName(t)):
						_put_type(id, StringName(t), true)
						used[j] = true
						placed = true
						break
				if placed:
					break


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
		# 先把 min_share 保底的份额留出来，剩下的按比例配额（最大余数法），再打乱
		var keys := _sorted_keys(mix)
		var total := 0.0
		for k in keys:
			total += float(mix[k])
		var counts := {}
		var given := 0
		for k in _sorted_keys(style.min_share):
			counts[k] = ceili(float(style.min_share[k]) * float(exclusive.size()))
			given += int(counts[k])
			if not keys.has(k):
				keys.append(k)
		var remaining := maxi(0, exclusive.size() - given)
		var remainders := []
		for k in keys:
			var exact := float(mix.get(k, 0.0)) / maxf(total, 0.001) * float(remaining)
			counts[k] = int(counts.get(k, 0)) + floori(exact)
			given += floori(exact)
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
		bag.assign(MapRng.shuffled(bag, _rng))
		var order: Array = MapRng.shuffled(exclusive, _rng)
		for j in order.size():
			_put_type(int(order[j]), StringName(bag[j]), false)


## 其余节点按所在环的权重抽。
func _assign_by_weights() -> void:
	for id in _g.node_ids():
		if _fixed.has(id) or _assigned.has(id):
			continue
		if not _routes_of.has(id) and _g.get_node(id).zone == 0:
			var style := _nearest_style(id)
			if style != null:
				_g.get_node(id).layout["near_style"] = String(style.id)
		var t := _pick_weighted(_weights_for(id))
		if t != &"":
			_put_type(id, t, false)


## 环配额：超了改成权重次高的可替换类型，缺了从本环的非固定节点里改。
func _enforce_quota() -> void:
	for r in range(_cfg.ring_count(), 0, -1):
		var spec := _cfg.spec_for_ring(r)
		if spec == null or spec.quota.is_empty():
			continue
		var ring_ids := _ring_ids(r)
		for t in _sorted_keys(spec.quota):
			var lim := _quota(r, t)
			while _count_in_ring(r, t) > lim.y:
				var victim := _pick_of_type(ring_ids, t)
				if victim < 0:
					break
				var alt := _replacement_type(victim, [t])
				if alt == &"":
					break
				_put_type(victim, alt, false)
		for t in _sorted_keys(spec.quota):
			var lim := _quota(r, t)
			while _count_in_ring(r, t) < lim.x:
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
			var dist := MapNavigator.distances_to_type(_g, StringName(t))
			var uncovered: Array[int] = []
			for id in _g.node_ids():
				if int(dist.get(id, 1 << 20)) > k and _needs_haven(_g.get_node(id)):
					uncovered.append(id)
			if uncovered.is_empty():
				break
			# 从每个超标点出发走 K 步，沿途的候选各记一分 —— 超标点少、候选多，反过来算贵得多
			var gain := {}
			for u in uncovered:
				for id in MapNavigator.within_steps(_g, u, k):
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
		if not MapNodeTypes.pair_forbidden(_cfg.no_adjacent, _g.get_node(e.from_id).type, _g.get_node(e.to_id).type):
			continue
		for id in [e.to_id, e.from_id]:
			if _fixed.has(id):
				continue
			var alt := _replacement_type(id, [String(_g.get_node(id).type)])
			if alt != &"":
				_put_type(id, alt, false)
				break


## 中途撤离点只落在**撤离环间**（正中间的那一两环，RingMapConfig.extract_band）。
##
## 先让相邻的两条路线共用一个：每对路线挑一个两条路都够得着的点 —— 合流后共用的点、
## 相邻直连的换乘点、换乘弧上的点 —— 放一个撤离点，三条路线两两共享；
## 一对都放不下时，撤离环间至少还得有一个（随便哪条路线够得着的都行）。
## 撤离点**覆盖**非必须型节点（出口吃掉休息区，玩家就没地方喘气了），不进高危区；
## 两个撤离点之间的最短路至少 extract_gap 步 —— 挨得太近的两个出口等于一个。
func _place_extracts() -> void:
	var band := _cfg.extract_band()
	if band.is_empty():
		return
	var gap := _cfg.effective_extract_gap()
	# 每对相邻路线：两条路都够得着的撤离环间候选
	var pairs := RingSpec.route_pairs(_g.routes.size())
	for pi in MapRng.shuffled_range(pairs.size(), _rng):
		var pair: Array = pairs[pi]
		# 搜索路线的尽头已经是这一对共用的撤离点了
		if _pair_has_extract(int(pair[0]), int(pair[1]), band):
			continue
		var shared := _shared_band_candidates(int(pair[0]), int(pair[1]), band, gap)
		if shared.is_empty():
			continue
		_put_type(_farthest_from_extracts(shared), &"extract", true)
	# 兜底：撤离环间至少 MIN_EXTRACTS 个（随便哪条路线够得着的都行），间距照守 —— 校验查它。
	# 搜索路线的尽头现在就是环间里共用的那一个（报告 053），以前它在核心前一环另算一个；
	# 不补的话多数图只剩一个出口，付费标掉一个就没有免费的了
	while _count_extracts_in(band) < MIN_EXTRACTS:
		var any: Array[int] = []
		for id in _g.node_ids():
			if band.has(_ring(id)) and _can_become(id, &"extract") and _far_from_extracts(id, gap):
				any.append(id)
		if any.is_empty():
			return
		_put_type(_farthest_from_extracts(any), &"extract", true)


func _count_extracts_in(band: Array[int]) -> int:
	var n := 0
	for id in _g.node_ids():
		if _g.get_node(id).type == &"extract" and band.has(_ring(id)):
			n += 1
	return n


func _pair_has_extract(i: int, j: int, band: Array[int]) -> bool:
	for id in _shared_pool(i, j):
		if band.has(_ring(id)) and _g.get_node(id).type == &"extract":
			return true
	return false


## 路线 i 与 j 在撤离环间上共用的地方：两条路都经过的点、它们之间相邻直连的换乘点、
## 换乘弧上的点。只要还能改成撤离点、且离已有的撤离点够远的
func _shared_band_candidates(i: int, j: int, band: Array[int], gap: int) -> Array[int]:
	var out: Array[int] = []
	for id in _shared_pool(i, j):
		if band.has(_ring(id)) and _can_become(id, &"extract") and _far_from_extracts(id, gap):
			out.append(id)
	return out


## 路线 i 与 j 共用的地方（不限环）：两条路都经过的点、相邻直连的换乘点、换乘弧上的点
func _shared_pool(i: int, j: int) -> Array[int]:
	var pool := {}
	for id in _routes_of:
		var on: Array = _routes_of[id]
		if on.has(i) and on.has(j):
			pool[id] = true
	for link in (_g.layout_meta.get("pivot_links", []) as Array):
		if link.size() >= 4 and ((int(link[2]) == i and int(link[3]) == j) or (int(link[2]) == j and int(link[3]) == i)):
			pool[int(link[0])] = true
			pool[int(link[1])] = true
	for arc in (_g.layout_meta.get("pivot_arcs", []) as Array):
		var rs: Array = arc.get("routes", [])
		if rs.size() >= 2 and ((int(rs[0]) == i and int(rs[1]) == j) or (int(rs[0]) == j and int(rs[1]) == i)):
			for id in (arc.get("node_ids", []) as Array):
				pool[int(id)] = true
	var out: Array[int] = []
	out.assign(pool.keys())
	out.sort()
	return out


## 候选里离已有撤离点最远的那几个再随机挑一个 —— 随手挑一个，下一个就可能没地方放了
func _farthest_from_extracts(pool: Array[int]) -> int:
	var best := -1
	var picks: Array[int] = []
	for id in pool:
		var d := _distance_to_extracts(id)
		if d > best:
			best = d
			picks = [id]
		elif d == best:
			picks.append(id)
	return picks[_rng.randi_range(0, picks.size() - 1)]


## 到最近的已有撤离点几步；一个都没有就是很大的数。
func _distance_to_extracts(id: int) -> int:
	var dist := MapNavigator.distances_to_type(_g, &"extract")
	return int(dist.get(id, 1 << 20))


## 这个点到已有的每个撤离点是不是都至少 gap 步。
func _far_from_extracts(id: int, gap: int) -> bool:
	if gap <= 1:
		return true
	for other in MapNavigator.within_steps(_g, id, gap - 1):
		if other != id and _g.get_node(other).type == &"extract":
			return false
	return true


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
		# 只在「事件点」之间换：出生点、核心、撤离点、喘气处、岔路口各有各的来处
		if _haven.has(t) or MapNodeTypes.STRUCTURAL.has(StringName(t)):
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
const MIX_WEIGHT := 0.08

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
	var band: Array = []
	for r in cfg.extract_band():
		band.append(r)
	var rules := {
		"quota": quota,
		"coverage": cfg.coverage.duplicate(),
		"no_haven_in_danger_above": cfg.no_haven_in_danger_above,
		"no_adjacent": cfg.no_adjacent.duplicate(true),
		"mandatory_types": mandatory,
		# 撤离点只在这几环上；空 = 不查（大型的两道撤离环间还没定）。
		# 去撤离点的路线也在这里收尾（报告 053），没有例外
		"extract_band": band,
		# 环间里至少几个：一个付费、一个免费。以前搜索路线在核心前一环另有一个出口，挪进环间之后得补
		"extract_min_count": MIN_EXTRACTS,
		"extract_min_distance": cfg.effective_extract_gap(),
		"spawn_typed_entries": true,
	}
	var lim := cfg.node_range()
	if lim.y > 0:
		rules["node_range"] = [lim.x, lim.y]
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
		var dist := MapNavigator.distances_to_type(graph, StringName(t))
		var over := 0
		var worst := 0
		for id in graph.node_ids():
			var d := int(dist.get(id, 1 << 20))
			var n := graph.get_node(id)
			if d > k and n.danger <= threshold:
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

	# --- 出生点是 spawn，spawn 都是出生点 ---
	if bool(rules.get("spawn_typed_entries", false)):
		for id in graph.entry_ids:
			if graph.get_node(id) != null and graph.get_node(id).type != &"spawn":
				v.fail(&"spawn", "出生点 %d 的类型是 %s，不是 spawn" % [id, graph.get_node(id).type])
		for id in graph.node_ids():
			if graph.get_node(id).type == &"spawn" and not graph.entry_ids.has(id):
				v.fail(&"spawn", "节点 %d 是 spawn，却不是出生点" % id)

	# --- 不许相邻 ---
	var pairs: Array = rules.get("no_adjacent", [])
	for e in graph.edges:
		var ta := graph.get_node(e.from_id).type
		var tb := graph.get_node(e.to_id).type
		if MapNodeTypes.pair_forbidden(pairs, ta, tb):
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

	# --- 撤离点两两之间至少几步 ---
	var gap := int(rules.get("extract_min_distance", 0))
	if gap > 1:
		var extracts: Array[int] = []
		for id in graph.node_ids():
			if graph.get_node(id).type == &"extract":
				extracts.append(id)
		for i in extracts.size():
			var dist := MapNavigator.within_steps(graph, extracts[i], gap - 1)
			for j in range(i + 1, extracts.size()):
				if dist.has(extracts[j]):
					v.fail(&"extract_spacing", "撤离点 %d 与 %d 只隔 %d 步，至少要 %d"
						% [extracts[i], extracts[j], dist[extracts[j]], gap])

	# --- 节点总数落在规模模板的范围里 ---
	if rules.has("node_range"):
		var lim: Array = rules["node_range"]
		if graph.node_count() < int(lim[0]) or graph.node_count() > int(lim[1]):
			v.fail(&"node_count", "%d 个点，这个规模该是 %d～%d" % [graph.node_count(), lim[0], lim[1]])

	# --- 撤离点只在撤离环间，且那里至少有一个。去撤离点的路线也在环间收尾（报告 053），没有例外 ---
	var band: Array = rules.get("extract_band", [])
	if not band.is_empty():
		var in_band := 0
		for id in graph.node_ids():
			var n := graph.get_node(id)
			if n.type != &"extract":
				continue
			var r := int(n.layout.get("ring", 0))
			if band.has(r):
				in_band += 1
			else:
				v.fail(&"extract_band", "撤离点 %d 在第 %d 环，中途撤离点只能在撤离环间（第 %s 环）"
					% [id, r, "～".join(PackedStringArray([str(band[0]), str(band[-1])]))])
		if in_band < maxi(1, int(rules.get("extract_min_count", 1))):
			v.fail(&"extract_band", "撤离环间（第 %s 环）里只有 %d 个撤离点，至少要 %d 个"
				% ["～".join(PackedStringArray([str(band[0]), str(band[-1])])), in_band,
					maxi(1, int(rules.get("extract_min_count", 1)))])


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


## 这个点要不要算进覆盖：高危区里的不算（那里不放喘气处）
func _needs_haven(n: MapNode) -> bool:
	return n.danger <= _cfg.no_haven_in_danger_above


func _absorbed(id: int) -> bool:
	return _routes_of.has(id) and _g.get_node(id).zone != 0


func _ring(id: int) -> int:
	return int(_g.get_node(id).layout.get("ring", 0))


func _ring_ids(r: int) -> Array[int]:
	return _by_ring.get(r, [] as Array[int])


func _bump(r: int, type: String, delta: int) -> void:
	var per: Dictionary = _counts[r]
	per[type] = int(per.get(type, 0)) + delta


func _count_in_ring(r: int, type: String) -> int:
	return int((_counts.get(r, {}) as Dictionary).get(type, 0))


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
	if type == &"extract" and n.zone != 0:
		return false     # 出口不开在高危区里
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
	if not _share_allows_leaving(id, old):
		return false
	for other in _g.neighbors(id):
		if MapNodeTypes.pair_forbidden(_cfg.no_adjacent, type, _g.get_node(other).type):
			return false
	return true


## 把这个点从 old 类型换走之后，它所在路线的 min_share 还守得住吗。
## 分母 = 这条路线独占的、可换的节点（不算出生点、撤离点、休息区、商店这些固定点）。
func _share_allows_leaving(id: int, old: String) -> bool:
	if not _routes_of.has(id) or (_routes_of[id] as Array).size() != 1:
		return true
	var style := _cfg.style_by_id(StringName(_g.routes[(_routes_of[id] as Array)[0]].get("style", "")))
	if style == null or not style.min_share.has(old):
		return true
	var have := 0
	var pool := 0
	for other in (_g.routes[(_routes_of[id] as Array)[0]]["node_ids"] as Array):
		if (_routes_of[int(other)] as Array).size() != 1 or _fixed.has(int(other)):
			continue
		var ty := String(_g.get_node(int(other)).type)
		if _haven.has(ty) or ty == "extract":
			continue
		pool += 1
		if ty == old:
			have += 1
	return float(have - 1) >= float(style.min_share[old]) * float(pool) - 1e-6


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
	var raw: Dictionary = {"battle": 1.0}
	if spec != null and not spec.type_weights.is_empty():
		raw = spec.type_weights
	elif _cfg.ring_template != null and not _cfg.ring_template.type_weights.is_empty():
		raw = _cfg.ring_template.type_weights
	var n := _g.get_node(id)
	# 259（作者 13:11 选 A）：不在路线上、也不在高危区里的点，环权重和最近那条路线的 mix 各占一半
	# （mix 按环权重的总量归一）—— 战斗路线旁多战斗、搜索路线旁多搜索；夹在两种路线之间或 4 步内没路线就照旧
	if not _routes_of.has(id) and n.zone == 0:
		var style := _nearest_style(id)
		if style != null and not style.mix.is_empty():
			raw = _blend_mix(raw, style.mix)
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


## 259：[param ring] 与 [param mix] 对半 —— mix 先按环权重的总量归一，两边各乘 0.5
static func _blend_mix(ring: Dictionary, mix: Dictionary) -> Dictionary:
	var ring_total := 0.0
	for k in ring:
		ring_total += float(ring[k])
	var mix_total := 0.0
	for k in mix:
		mix_total += float(mix[k])
	var out := {}
	for k in ring:
		out[String(k)] = 0.5 * float(ring[k])
	if mix_total <= 0.0:
		return out
	for k in mix:
		out[String(k)] = float(out.get(String(k), 0.0)) + 0.5 * float(mix[k]) / mix_total * ring_total
	return out


## 259：离 [param id] 最近的路线（沿边走，最多 [constant NEAR_STEPS] 步，第一次碰到路线点为止）；
## 那一圈碰到的路线风格不止一种就返回 null
func _nearest_style(id: int) -> RouteStyle:
	var frontier: Array[int] = [id]
	var seen := {id: true}
	for _d in NEAR_STEPS:
		var next: Array[int] = []
		var found := {}
		for cur in frontier:
			for nb in _g.neighbors(cur):
				if seen.has(nb):
					continue
				seen[nb] = true
				if _routes_of.has(nb):
					for ri in (_routes_of[nb] as Array):
						found[String(_g.routes[int(ri)].get("style", ""))] = true
				else:
					next.append(nb)
		if not found.is_empty():
			if found.size() != 1:
				return null
			return _cfg.style_by_id(StringName(found.keys()[0]))
		frontier = next
	return null


## 按排好序的键扣减（140 M-25：抽法在 [method MapRng.pick_weighted]）
func _pick_weighted(weights: Dictionary) -> StringName:
	return MapRng.pick_weighted(weights, _rng, _sorted_keys(weights))


static func _sorted_keys(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in d:
		out.append(String(k))
	out.sort()
	return out
#endregion
