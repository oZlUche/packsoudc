## 第一章的同心环地图 —— **拓扑与骨架**（架构文档 5.4，M3-3）。
##
## [b]骨架先行[/b]：不是生成一张图再从里面找路线，而是先从每个出生点逐环向内铺一条路线，
## 再往路线周围长出地图。否则「偏战斗的路线」只能靠事后给一条碰巧存在的路径贴标签，
## 贴不贴得上看运气。
##
## 本类只做拓扑：槽位、骨架、换乘、高危区、候选边、隔离、断边、不交叉。
## 节点类型由 [RingTypeAssigner] 在拓扑齐了之后填 ——
## 拓扑与类型各有一套不变式，混在一起出了错分不清是路没铺好还是类型填错了。
class_name RingMapGenerator
extends MapGenerator

## 核心的节点 id 固定为 0，别处一眼认得出来
const CORE_ID := 0

# --- 一次 build 的中间状态。build 开头清空，不跨次残留 ---
var _cfg: RingMapConfig = null
var _graph: MapGraph = null
var _rng: RandomNumberGenerator = null
## r -> {slot: node_id}
var _ring_slots: Array = []
## 受保护的节点：骨架与换乘弧经过的点。高危区不许碰它们
var _protected_nodes: Dictionary = {}
## 受保护的边："小id:大id"。断边跳过它们
var _protected_edges: Dictionary = {}
var _next_id: int = 1
## 这一次 build 里有几片【必须有】的高危区没长起来。校验据此判这次尝试作废
var _zones_missing: int = 0
## 高危区的生长树：[[from, to], ...]。区是沿着「空间相邻」长出来的，
## 但候选边按另一套规则建（次序最近的若干个）—— 两者对不上时区内根本没边相连。
## 所以生长时走过的每一步都记下来，建边之后补齐并保护
var _zone_links: Array = []
## 正在生长的高危区：{id, spec, cap, anchor, first, members}。anchor 是它岔出来的那个路线节点
var _zone_heads: Array[Dictionary] = []
## 还没岔出来的高危区配置
var _zones_pending: int = 0
## 换乘安排在哪几环（由规模模板给的次数均分出来）
var _pivot_rings: Array[int] = []
## "路线i:路线j:第k次" -> true，已经换乘过的
var _pivot_done: Dictionary = {}
## 这一次 build 打算要几片
var _zone_target: int = 0
## 这张图必须有几片、至多几片（来自规模模板）
var _zone_range: Vector2i = Vector2i.ZERO
## 路线下标 -> 它身上岔出的高危区 id
var _zones_on_route: Dictionary = {}
## 高危区岔出来的那条边 [anchor, first]：它是天然的第一个出入口，受保护
var _zone_gate_links: Array = []
var _zones_skipped: int = 0
## 路线下标 -> 环 -> 这一环上要多横着走几步（route_length_factor 多出来的步数撒在各环上）
var _extra_steps: Array[Dictionary] = []
## 路线的尽头（去撤离点的路线在撤离环间那段弧的最后一个点）：不许当高危区的岔出点、不许被吸收
var _route_ends: Dictionary = {}
## 骨架铺完之后高危区还要用：每条路线的点、每条路线的风格
var _paths: Array = []
var _styles: Array[RouteStyle] = []
## 路线下标 -> 撤离点之后、相邻路线之前的那几个点（换乘区，商店放第一个）。只有去撤离点的路线有
var _exit_tails: Dictionary = {}


func default_config() -> Resource:
	return RingMapConfig.sample(5)


func build(cfg: Resource, rng: RandomNumberGenerator) -> MapGraph:
	_cfg = cfg as RingMapConfig
	if _cfg == null or _cfg.ring_count() <= 0 or _cfg.routes.is_empty():
		return null
	_rng = rng
	_graph = MapGraph.new()
	_graph.layout_kind = &"ring"
	_graph.layout_meta = {
		"ring_count": _cfg.ring_count(), "ring_slots": {},
		# 这张图自己带着边长上限：校验、编辑器都从图上读，不必手上有配置
		"edge_max_ring_offset": _cfg.edge_max_ring_offset,
		"edge_max_slot_offset": _cfg.edge_max_slot_offset,
		"edge_max_arc_span": _cfg.tangential_span_max,
		"fill_cap": _cfg.fill_cap,
		"zone_rules": _rules().to_dict(),
	}
	_ring_slots = []
	_protected_nodes = {}
	_protected_edges = {}
	_next_id = 1
	_zones_missing = 0
	_zone_links = []
	_zone_heads = []
	_zone_gate_links = []
	_zones_skipped = 0
	_zones_on_route = {}
	_extra_steps = []
	_route_ends = {}
	_paths = []
	_styles = []
	_exit_tails = {}
	# 几片高危区由规模模板说了算：min 必须有，多出来的在 [min, max] 里随机
	_zone_range = _cfg.zone_count_range()
	# 指定了片数就要那么多（已经被夹进规模的范围了）；没指定就在范围里随机
	if _zone_range.y <= 0:
		_zones_pending = 0
	elif _cfg.zone_count >= 0:
		_zones_pending = _zone_range.y
	else:
		_zones_pending = _rng.randi_range(_zone_range.x, _zone_range.y)
	_zone_target = _zones_pending
	_pivot_done = {}
	_pivot_rings = _schedule_pivots()
	_graph.layout_meta["pivot_links"] = []
	_graph.layout_meta["pivot_arcs"] = []

	_make_core()
	if not _make_ring_nodes():
		return null
	if not _lay_skeleton():
		return null
	_lay_pivots()
	# 路线与换乘都铺完了，高危区才从非搜索路线的后半段岔出来、长进剩下的空位（报告 053 第三条）——
	# 和路线同步长的时候，它一半的失败是占走了路线自己的下一步
	_lay_zones()
	# 受保护的结构先建（骨架已经在了，接着是高危区的生长树），候选边后建 ——
	# 候选边碰上会交叉的情况自己让路，不能反过来让骨架去迁就它
	_link_zone_trees()
	_link_candidates()
	_isolate_zones()
	_repair_inward()
	_rescue_stranded()
	_reconnect_islands()
	_break_tangentials()
	_fix_crossings()
	# 拓扑齐了，再填类型。分开两步：出了错分得清是路没铺好还是类型填错了
	var typer := RingTypeAssigner.new()
	if not typer.assign(_graph, _cfg, _rng):
		build_note = "类型分配失败：" + typer.note
		return null
	_add_portals()
	return _graph


## 传送点（8-1，报告 076）：类型填完之后连几条 portal 边 —— 两个隔得够远的普通点之间，走一次花 portal_cost 行动点。
## 它不是「路」：校验、角度求解、路口识别都把它剔掉（[method without_portals]），只有移动与距离认它
func _add_portals() -> void:
	if _cfg.portal_count <= 0:
		return
	var ids: Array[int] = []
	for id in _graph.node_ids():
		if not MapNodeTypes.STRUCTURAL.has(_graph.get_node(id).type):
			ids.append(id)
	var used := {}
	var made := 0
	var tries := 0
	while made < _cfg.portal_count and tries < 400 and ids.size() >= 2:
		tries += 1
		var a: int = ids[_rng.randi_range(0, ids.size() - 1)]
		var b: int = ids[_rng.randi_range(0, ids.size() - 1)]
		if a == b or used.has(a) or used.has(b):
			continue
		var dist := MapNavigator.distance_map(_graph, a)
		if not dist.has(b) or int(dist[b]) < _cfg.portal_min_steps:
			continue
		if _graph.connect_nodes(a, b, MapEdge.PORTAL, maxi(0, _cfg.portal_cost)) != null:
			used[a] = true
			used[b] = true
			made += 1


## 去掉传送点的副本：生成规则只管「路」，传送点本来就跨很远、可以交叉
static func without_portals(g: MapGraph) -> MapGraph:
	var copy := MapGraph.from_dict(g.to_dict())
	for e in copy.edges.duplicate():
		if (e as MapEdge).is_portal():
			copy.remove_edge(e)
	return copy


#region 1–3 节点
func _make_core() -> void:
	var n := MapNode.new()
	n.id = CORE_ID
	n.type = &"core"
	n.tier = _cfg.ring_count()
	n.erosion_band = _cfg.ring_count()
	n.content_seed = _rng.randi()
	n.layout = {"ring": 0, "order": 0, "kind": "core"}
	_graph.add_node(n)
	_ring_slots.append({0: CORE_ID})   # r = 0


## 逐环建点。id 按「外环先、槽位升序」递增 —— 与加点顺序无关的确定性由 MapGraph 保证，
## 但 id 本身也得是确定的，不然同种子两次跑出来的存档对不上。
func _make_ring_nodes() -> bool:
	var count := _cfg.ring_count()
	for _i in count:
		_ring_slots.append({})
	# 先由内向外挑每环填哪些槽位：外环的点要尽量落在内环某个点「正上方」附近，
	# 不然边长上限之内没有向内的邻居，这个点就只能靠弧连到别处
	var chosen: Array = []
	chosen.resize(count + 1)
	chosen[0] = [0] as Array[int]
	# 总数在规模模板的范围里抽（是范围不是定数），各环按配置里的基准比例分；
	# 没有规模就照配置里每环写的数
	var counts: Array[int] = []
	var lim := _cfg.node_range()
	if lim.y > 0:
		counts = _cfg.counts_for_total(_rng.randi_range(lim.x, lim.y) - 1)     # 减掉核心
	for r in range(1, count + 1):
		var spec := _cfg.spec_for_ring(r)
		var slots := _cfg.slots_for_ring(r)
		var inner_slots := _cfg.slots_for_ring(r - 1) if r > 1 else 1
		var want := counts[count - r] if not counts.is_empty() else (spec.node_count if spec != null else 0)
		var filled := _choose_filled_slots(slots, want, chosen[r - 1], inner_slots)
		if filled.is_empty():
			return false
		chosen[r] = filled
	# 再由外向内建点：id 按「外环先、槽位升序」递增，与加点顺序无关的确定性由 MapGraph 保证，
	# 但 id 本身也得是确定的，不然同种子两次跑出来的存档对不上
	for r in range(count, 0, -1):
		var spec := _cfg.spec_for_ring(r)
		var map := {}
		for slot in (chosen[r] as Array[int]):
			var n := MapNode.new()
			n.id = _next_id
			_next_id += 1
			n.type = &"battle"          # 占位，RingTypeAssigner 会改
			n.tier = count - r          # 越内层越高
			n.erosion_band = count - r  # 最外环 0，最先被侵蚀
			n.content_seed = _rng.randi()
			n.layout = {
				"ring": r, "order": slot,
				"kind": String(spec.kind) if spec != null else "",
			}
			_graph.add_node(n)
			map[slot] = n.id
		_ring_slots[r] = map
		# 记下槽位数。从节点上推不出来：末尾几个槽位空着时，max(order)+1 比真实值小
		(_graph.layout_meta["ring_slots"] as Dictionary)[r] = _cfg.slots_for_ring(r)
	return true


## 在 slots 个槽位里挑出 want 个（0 或 ≥ slots = 全填）。
##
## **匀着放**：按 slots / want 的步长绕环一圈，随机转一个角度；每个位置再在半步之内
## 挪到「内环有点正对着」的槽位上（边长上限之内），这样它才有向内的边可连。
## 空槽因此散在点与点之间；隔得超过 tangential_span_max 的地方弧就断了，那就是空白区 ——
## 空白区是稀疏的结果，不是先挖再填。
func _choose_filled_slots(slots: int, want: int, inner: Array[int], inner_slots: int) -> Array[int]:
	var out: Array[int] = []
	# 0 = 自动：填到 fill_cap 允许的上限为止 —— 环上总有空位，内环也一样
	var n := _cfg.fill_count(slots, 1.0) if want <= 0 or want >= slots else want
	n = mini(n, _cfg.fill_count(slots, 1.0))
	if n >= slots:
		for s in slots:
			out.append(s)
		return out

	# 内环各点投到本环上的位置（本环槽位为单位）
	var anchors: Array[float] = []
	for s in inner:
		anchors.append(float(s) / float(maxi(1, inner_slots)) * float(slots))
	var reach := float(_cfg.edge_max_slot_offset) + 0.5

	var stride := float(slots) / float(n)
	var offset := _rng.randf() * stride
	var picked := {}
	for k in n:
		var ideal := offset + float(k) * stride
		var base := posmod(roundi(ideal), slots)
		var best := -1
		var d := 0
		# 先在半步之内找正对着内环点的槽位，找不到再放宽到一整步 —— 挪远一点总比没有向内的边好
		while d <= floori(stride) and best < 0:
			for sign in [1, -1]:
				var s := posmod(base + sign * d, slots)
				if picked.has(s) or not _anchored(s, anchors, reach, slots):
					continue
				best = s
				break
			d += 1
		if best < 0:
			# 一步之内没有正对着内环点的槽位：就放在理想位置，靠弧连到别处
			best = base
			var tries := 0
			while picked.has(best) and tries < slots:
				best = posmod(best + 1, slots)
				tries += 1
		picked[best] = true
	for s in slots:
		if picked.has(s):
			out.append(s)
	return out


static func _anchored(slot: int, anchors: Array[float], reach: float, slots: int) -> bool:
	for a in anchors:
		var diff := fposmod(float(slot) - a, float(slots))
		if minf(diff, float(slots) - diff) <= reach:
			return true
	return false


## 第 r 环上从 slot 出发朝 dir 方向、在 tangential_span_max 个空槽之内的下一个有点的槽位；
## 没有（那一边是空白区）返回 -1。
func _ring_next(r: int, slot: int, dir: int) -> int:
	var slots := maxi(1, _cfg.slots_for_ring(r))
	var map: Dictionary = _ring_slots[r]
	for k in range(1, mini(slots - 1, _cfg.tangential_span_max + 1) + 1):
		var s := posmod(slot + dir * k, slots)
		if map.has(s):
			return s
	return -1
#endregion


#region 4 骨架
## 全部路线**同步**向内生长：一环一环地推，每一环上所有路线一起落子。
##
## 以前是一条路线从头走到尾再走下一条。那样后走的路线只能捡前面挑剩的，
## 挤不挤得下要走到那一环才知道；同步生长时，每一环落子之前各条路线的位置都在手上，
## 剩多少空间当场算得出来 —— 候选最少的先挑，间距按环的长度等比缩小。
##
## 全图连通由骨架天然成立（每个点最终都靠径向边挂到内层），不必事后修。
func _lay_skeleton() -> bool:
	var outer := _cfg.ring_count()
	var entries := _choose_entries()
	if entries.is_empty():
		return false

	var paths: Array = []       # 每条路线一个 Array[int]
	var styles: Array[RouteStyle] = []
	var stops: Array[int] = []  # 每条路线走到第几环为止
	for i in entries.size():
		paths.append([entries[i]] as Array[int])
		styles.append(_cfg.routes[i % _cfg.routes.size()])
		stops.append(0 if styles[i].is_core_route() else _exit_ring())
		_protected_nodes[entries[i]] = true
		_graph.entry_ids.append(entries[i])
		# 去撤离点的路线只走到撤离环间：多出来的步数全撒在它走得到的那几环上（停下的那一环走的是出口弧），
		# 不然一半步数撒进了它不去的内圈，路线短到没什么可搜
		_extra_steps.append(_schedule_extra_steps(outer, maxi(1, stops[i] + 1)))

	# 最外环上也可以先横着走几步再向内
	var all_routes: Array[int] = []
	for i in paths.size():
		all_routes.append(i)
	_walk_extra(outer, all_routes, paths, outer - 1 < _cfg.converge_after_ring)

	for r in range(outer - 1, -1, -1):
		# 这一环还在走的路线：去核心的走到 0，去撤离点的停在撤离环间
		var active: Array[int] = []
		for i in paths.size():
			if r >= stops[i]:
				active.append(i)
		if active.is_empty():
			break
		if not _advance_ring(r, outer - 1 - r, active, paths):
			return false
		for i in active:
			if r == stops[i] and not styles[i].is_core_route():
				_lay_exit_arc(i, r, paths)

	_paths = paths
	_styles = styles
	var routes: Array[Dictionary] = []
	for i in paths.size():
		var route := {
			"entry_id": entries[i],
			"style": String(styles[i].id),
			"ends_at": String(styles[i].ends_at),
			"node_ids": paths[i],
			"zone_ids": [] as Array[int],
		}
		if _exit_tails.has(i):
			# 撤离点之后到相邻路线之前的换乘区：商店放第一个，出口之后成了继续走的诱因
			route["exit_ids"] = _exit_tails[i]
		routes.append(route)
	_graph.routes = routes
	_graph.goal_ids = [CORE_ID] as Array[int]
	return true


## 去撤离点的路线停在哪一环：撤离环间；偶数环的图环间有两环，取内侧那环（作者定，报告 053）——
## 4 环图向内能走两步而不是一步，6 环图正好停在换乘环上。
## 没有撤离环间（大型图的两道还没定）就还是停在核心前一环
func _exit_ring() -> int:
	var band := _cfg.extract_band()
	if band.is_empty():
		return 1
	var inner: int = band[0]
	for r in band:
		inner = mini(inner, int(r))
	return maxi(1, inner)


## 去撤离点的路线走到撤离环间之后，沿这一环朝一条相邻路线横着走一段弧：
## 弧上的点归这条路线、最后一个点就是它的尽头（撤离点）；尽头到相邻路线之间剩下的点是换乘区，
## 整段保护起来当换乘弧 —— 撤离点因此由两条路线共用。
##
## 朝哪边：两边都量一量，**能碰上相邻路线、且中间空着的点多的那边**（作者定，报告 053）。
## 内圈槽位少，弧长是最紧的约束。两边都碰不上别的路线（空白区隔开了），就朝空点多的那边走，没有换乘区。
## 弧长：大约补上不再向内走的那几环（含横着多走的步数），至少给换乘区留一个点
func _lay_exit_arc(i: int, r: int, paths: Array) -> void:
	var path: Array[int] = paths[i]
	var head := path[-1]
	var map: Dictionary = _ring_slots[r]
	var best := {}
	for dir in [1, -1]:
		var free: Array[int] = []
		var meets := -1
		var meets_route := -1
		var slot := int(_graph.get_node(head).layout["order"])
		for _k in map.size():
			slot = _ring_next(r, slot, dir)
			if slot < 0:
				break
			var id := int(map[slot])
			if id == head:
				break
			if _protected_nodes.has(id) or _graph.get_node(id).zone != 0:
				meets_route = _other_route_of(id, paths, i)
				if meets_route >= 0:
					meets = id
				break
			free.append(id)
		var option := {"free": free, "meets": meets, "route": meets_route}
		if best.is_empty() or _better_exit(option, best):
			best = option
	var free: Array[int] = best["free"]
	var meets := int(best["meets"])
	var arc_max := roundi(float(r - 1) * _cfg.route_length_factor) + 1
	var take := mini(arc_max, free.size() - 1) if meets >= 0 else mini(arc_max, free.size())
	take = maxi(0, take)
	for k in take:
		_protect_edge(path[-1], free[k], &"tangential")
		_protected_nodes[free[k]] = true
		path.append(free[k])
	var end := path[-1]
	_route_ends[end] = true
	if meets < 0:
		return
	var tail: Array[int] = []
	var prev := end
	for k in range(take, free.size()):
		tail.append(free[k])
	for id in tail + [meets]:
		_protect_edge(prev, id, &"tangential")
		_protected_nodes[id] = true
		prev = id
	_exit_tails[i] = tail
	var j := int(best["route"])
	var arc: Array[int] = [end]
	arc.append_array(tail)
	arc.append(meets)
	(_graph.layout_meta["pivot_arcs"] as Array).append({"routes": [mini(i, j), maxi(i, j)], "node_ids": arc})
	# 这一环上的换乘就是这段弧了，不再另外拉一段
	for k in _pivot_rings.size():
		if _pivot_rings[k] == r:
			_pivot_done["%d:%d:%d" % [i, j, k]] = true
			_pivot_done["%d:%d:%d" % [j, i, k]] = true


## 能碰上相邻路线的优先，其次中间空着的点多的
static func _better_exit(a: Dictionary, b: Dictionary) -> bool:
	var ma := int(a["meets"]) >= 0
	var mb := int(b["meets"]) >= 0
	if ma != mb:
		return ma
	return (a["free"] as Array).size() > (b["free"] as Array).size()


## id 在哪条别的路线上（不是 self_index 那条）；都不在返回 -1
static func _other_route_of(id: int, paths: Array, self_index: int) -> int:
	for j in paths.size():
		if j != self_index and (paths[j] as Array[int]).has(id):
			return j
	return -1


## 一条路线多出来的步数（环数 × (route_length_factor - 1)）撒在哪几环：环 -> 几步。
## 随机撒，一环可以摊到好几步 —— 同一环上横着走几步不致命，路线长一点沿路才放得下东西
func _schedule_extra_steps(outer: int, lowest: int = 1) -> Dictionary:
	var out := {}
	var extra := maxi(0, roundi(float(outer) * (_cfg.route_length_factor - 1.0)))
	for _k in extra:
		var r := _rng.randi_range(mini(lowest, outer), outer)
		out[r] = int(out.get(r, 0)) + 1
	return out


## 第 r 环上，active 里各条路线按安排横着走几步：只走没人占的、不在高危区里的点，
## 合流之前还得离别的路线在这一环上的落点够远。走不动就算了 —— 这是尽力而为，不是硬指标。
func _walk_extra(r: int, active: Array[int], paths: Array, exclusive: bool) -> void:
	if r < 1:
		return
	var slots := maxi(1, _cfg.slots_for_ring(r))
	var outer_slots := maxi(1, _cfg.slots_for_ring(_cfg.ring_count()))
	var need := maxi(1, floori(float(_cfg.entry_min_gap) * float(slots) / float(outer_slots))) if exclusive else 1
	var map: Dictionary = _ring_slots[r]
	for i in active:
		var steps := int((_extra_steps[i] as Dictionary).get(r, 0))
		if steps <= 0:
			continue
		var path: Array[int] = paths[i]
		if int(_graph.get_node(path[-1]).layout.get("ring", -1)) != r:
			continue
		# 别的路线在这一环上占的槽位
		var others: Array[int] = []
		for j in active:
			if j == i:
				continue
			for id in (paths[j] as Array[int]):
				var n := _graph.get_node(id)
				if int(n.layout.get("ring", -1)) == r:
					others.append(int(n.layout["order"]))
		var dir := 1 if _rng.randf() < 0.5 else -1
		for _k in steps:
			var moved := false
			for d in [dir, -dir]:
				var slot := _ring_next(r, int(_graph.get_node(path[-1]).layout["order"]), d)
				if slot < 0:
					continue
				var id := int(map[slot])
				if _protected_nodes.has(id) or _graph.get_node(id).zone != 0 \
						or not _far_enough(slot, others, need, slots):
					continue
				# 不走进死角：挪过去之后还得有向内的落点（去撤离点的路线到了第 1 环不用再向内）
				if r > 1 and _inward_candidates(id, r - 1).is_empty():
					continue
				_protect_edge(path[-1], id, &"tangential")
				_protected_nodes[id] = true
				path.append(id)
				dir = d
				moved = true
				break
			if not moved:
				break


## 在最外环上挑出生点：两两之间的环形距离不小于 entry_min_gap 个槽位。
##
## 返回按槽位升序排好的节点 id —— 下标相邻即角度相邻，换乘点靠这个认「相邻路线」。
func _choose_entries() -> Array[int]:
	var outer := _cfg.ring_count()
	var slots := maxi(1, _cfg.slots_for_ring(outer))
	var map: Dictionary = _ring_slots[outer]
	var filled := _sorted_keys(map)
	var want := clampi(_cfg.effective_entry_count(), 1, filled.size())
	var gap := maxi(1, _cfg.entry_min_gap) if want > 1 else 0
	if want * gap > slots:
		build_note = "出生点放不下：%d 个出生点 × 间隔 %d > 最外环 %d 个槽位" % [want, gap, slots]
		return [] as Array[int]

	var stride := float(slots) / float(want)
	var jitter := maxi(0, floori((stride - float(gap)) / 2.0))
	# 贪心地从一个随机起点排过去；排不下就换下一个起点再来 —— 空白区会让某些起点走进死角，
	# 但只要有解，总有一个起点排得下
	var first := _rng.randi_range(0, filled.size() - 1)
	var picked: Array[int] = []     # 槽位
	for k in filled.size():
		picked = _place_entries(filled[(first + k) % filled.size()], filled, want, gap, slots, stride, jitter)
		if not picked.is_empty():
			break
	if picked.is_empty():
		build_note = "出生点放不下：空白区把最外环切得太碎，凑不出 %d 个间隔 %d 的点" % [want, gap]
		return [] as Array[int]
	picked.sort()
	var out: Array[int] = []
	for s in picked:
		out.append(int(map[s]))
	return out


func _place_entries(
	start: int, filled: Array[int], want: int, gap: int, slots: int, stride: float, jitter: int
) -> Array[int]:
	var picked: Array[int] = []
	for i in want:
		var target := posmod(start + roundi(stride * i), slots)
		var near: Array[int] = []   # 理想位置 ± jitter 之内的
		var rest: Array[int] = []   # 其余合法的
		for s in filled:
			if not _far_enough(s, picked, gap, slots):
				continue
			if _ring_dist(s, target, slots) <= jitter:
				near.append(s)
			else:
				rest.append(s)
		if not near.is_empty():
			picked.append(near[_rng.randi_range(0, near.size() - 1)])
		elif not rest.is_empty():
			# 理想位置附近没有（多半是空白区），退而求其次挑离它最近的
			var best: int = rest[0]
			for s in rest:
				if _ring_dist(s, target, slots) < _ring_dist(best, target, slots):
					best = s
			picked.append(best)
		else:
			return [] as Array[int]
	return picked


## 第 r 环上，active 里的每条路线各落一子。steps = 已经向内走了几环。
func _advance_ring(r: int, steps: int, active: Array[int], paths: Array) -> bool:
	if r == 0:
		for i in active:
			var core_path: Array[int] = paths[i]
			_protect_edge(core_path[-1], CORE_ID, &"radial")
			core_path.append(CORE_ID)
		return true

	var slots := maxi(1, _cfg.slots_for_ring(r))
	var outer_slots := maxi(1, _cfg.slots_for_ring(_cfg.ring_count()))
	# 允许合流之前各走各的；间距随环的长度等比缩小，至少 1（= 不重合）
	var exclusive := steps < _cfg.converge_after_ring
	var need := 0
	if exclusive:
		need = maxi(1, floori(float(_cfg.entry_min_gap) * float(slots) / float(outer_slots)))

	var approaches := {}
	for i in active:
		var from_path: Array[int] = paths[i]
		approaches[i] = _approach(from_path[-1], r)
	# 候选最少的先挑 —— 先让选择多的挑，可能正好把别人唯一的落点占掉
	var order: Array[int] = active.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca := (approaches[a]["cands"] as Array).size()
		var cb := (approaches[b]["cands"] as Array).size()
		return ca < cb or (ca == cb and a < b))

	var taken: Array[int] = []      # 这一环上已经被挑走的槽位
	for i in order:
		var options: Array[int] = approaches[i]["cands"]
		if options.is_empty():
			build_note = "路线走到第 %d 环没有落点：沿着外面那环怎么挪，正对着的都是空白区" % r
			return false
		var pool := _filter_far(options, taken, need, slots)
		if pool.is_empty() and need > 1:
			pool = _filter_far(options, taken, 1, slots)   # 退一步：不重合就行
		if pool.is_empty():
			if exclusive:
				# 合流之前挤不开 = 这一次作废。以前这里退到「合流」，结果就是提前合流
				build_note = "路线走到第 %d 环挤不开：合流之前的几环里落点全被别的路线占了" % r
				return false
			pool = options      # 允许合流之后，挤不开就合流
		var path: Array[int] = paths[i]
		# 正对着空白区时，先沿当前这环横着挪几步，挪到能向内走的地方
		var walk: Array[int] = approaches[i]["walk"]
		for side in walk:
			_protect_edge(path[-1], side, &"tangential")
			_protected_nodes[side] = true
			path.append(side)
		# 先试挑中的那个；它会和别的路交叉又让不开，就换别的候选
		var tries: Array[int] = _shuffled(pool)
		if not exclusive:
			# 合流之前不许退回到「被别人占了的落点」—— 那就是提前合流；退不了就这次作废
			for other in options:
				if not tries.has(other):
					tries.append(other)
		var landed := false
		for pick in tries:
			var via := _link(path[-1], pick, true)
			if via.is_empty():
				continue
			for id in via:
				_protected_nodes[id] = true
				path.append(id)
			taken.append(int(_graph.get_node(pick).layout["order"]))
			landed = true
			break
		if not landed:
			build_note = "路线走到第 %d 环，每个落点都会和别的路交叉" % r
			return false
	# 都落好了，再各自按安排横着走几步 —— 落点是先定的，横着走不去抢别人的落点
	_walk_extra(r, active, paths, exclusive)
	_try_adjacent_pivots(r, active, paths)
	return true


func _shuffled_indices(count: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(i)
	return _shuffled(out)


func _shuffled(ids: Array[int]) -> Array[int]:
	var out: Array[int] = ids.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## 从 from_id 怎么走到第 to_ring 环：`{walk, cands}`。
##
## 正常情况 walk 为空，cands 是向内一环里够得着的点（边长上限之内，且不超过 route_drift）。
## 正对着一段空白区时一个都够不着 —— 那就沿当前这环向两边找最近的、能向内走的点，
## walk 是横着挪过去经过的点。**不拉一条长边跳过空白区**：单条路径有长度上限。
func _approach(from_id: int, to_ring: int) -> Dictionary:
	var direct := _inward_candidates(from_id, to_ring)
	if not direct.is_empty():
		return {"walk": [] as Array[int], "cands": direct}

	var node := _graph.get_node(from_id)
	var r := int(node.layout["ring"])
	var slots := maxi(1, _cfg.slots_for_ring(r))
	var map: Dictionary = _ring_slots[r]
	var best := {"walk": [] as Array[int], "cands": [] as Array[int]}
	for dir in [1, -1]:
		var walk: Array[int] = []
		var slot := int(node.layout["order"])
		for _k in slots:
			slot = _ring_next(r, slot, dir)
			if slot < 0 or _graph.get_node(int(map[slot])).zone != 0 \
					or _protected_nodes.has(int(map[slot])):
				break       # 这一边被空白区、高危区或别的路线截断了 —— 横着挪不能挪到别人的路上去
			walk.append(int(map[slot]))
			var cands := _inward_candidates(int(map[slot]), to_ring)
			if not cands.is_empty():
				if (best["cands"] as Array).is_empty() or walk.size() < (best["walk"] as Array).size():
					best = {"walk": walk, "cands": cands}
				break
	return best


## 从 from_id 向内一环够得着的点：边长上限之内，且槽位偏移不超过 route_drift。
func _inward_candidates(from_id: int, to_ring: int) -> Array[int]:
	if to_ring <= 0:
		return [CORE_ID] as Array[int]
	var reach := float(mini(_cfg.route_drift, _cfg.edge_max_slot_offset)) + 0.5
	var out: Array[int] = []
	for id in _reachable_in_ring(from_id, to_ring):
		# 已经被高危区占走的点不走 —— 路线与高危区是实时抢地方的
		if _slot_offset(from_id, id) <= reach and _graph.get_node(id).zone == 0:
			out.append(id)
	return out


func _filter_far(ids: Array[int], taken: Array[int], need: int, slots: int) -> Array[int]:
	var out: Array[int] = []
	for id in ids:
		if _far_enough(int(_graph.get_node(id).layout["order"]), taken, need, slots):
			out.append(id)
	return out


static func _far_enough(slot: int, others: Array[int], need: int, slots: int) -> bool:
	for o in others:
		if _ring_dist(slot, o, slots) < need:
			return false
	return true


## 环上两个槽位之间的距离（走短的那一边）。
static func _ring_dist(a: int, b: int, slots: int) -> int:
	var f := posmod(a - b, slots)
	return mini(f, slots - f)


## 换乘安排在哪几环：次数来自规模模板（小图 1 次，中图 1~2 次……），沿路线均分。
func _schedule_pivots() -> Array[int]:
	var out: Array[int] = []
	var outer := _cfg.ring_count()
	var profile := _cfg.scale()
	var count := _rng.randi_range(profile.pivots.x, profile.pivots.y) if profile != null else 1
	for k in count:
		var r := clampi(roundi(float(outer) - float(k + 1) * float(outer) / float(count + 1)), 1, outer)
		if not out.has(r):
			out.append(r)
	return out


## 相邻的路线对：[[i, j], ...]。两条路线只有一对，三条以上首尾也相邻。
func _route_pairs(route_count: int) -> Array:
	var out: Array = []
	if route_count == 2:
		out.append([0, 1])
	elif route_count > 2:
		for i in route_count:
			out.append([i, (i + 1) % route_count])
	return out


## 换乘窗口：两条路线刚落的子如果**恰好相邻**，而此刻正在某次换乘的窗口里
## （安排的那一环 ± pivot_window，不必严格踩在那一环上）、这一次又还没换乘过 ——
## 直接把这两个点连起来当换乘，不再另外拉一整段换乘弧。
func _try_adjacent_pivots(r: int, active: Array[int], paths: Array) -> void:
	for pair in _route_pairs(paths.size()):
		var i := int(pair[0])
		var j := int(pair[1])
		if not active.has(i) or not active.has(j):
			continue
		for k in _pivot_rings.size():
			var key := "%d:%d:%d" % [i, j, k]
			if _pivot_done.has(key) or absi(r - _pivot_rings[k]) > _cfg.pivot_window:
				continue
			var a: int = (paths[i] as Array[int])[-1]
			var b: int = (paths[j] as Array[int])[-1]
			if a != b:
				var sa := int(_graph.get_node(a).layout["order"])
				var sb := int(_graph.get_node(b).layout["order"])
				if _ring_next(r, sa, 1) != sb and _ring_next(r, sa, -1) != sb:
					continue        # 相邻 = 这一环上挨着的两个点（中间没有别的点，也没隔着空白区）
				_protect_edge(a, b, &"tangential")
				# [a, b, 路线 i, 路线 j]：撤离点想落在两条路线共用的地方，得知道这是谁和谁的换乘
				(_graph.layout_meta["pivot_links"] as Array).append([mini(a, b), maxi(a, b), i, j])
			_pivot_done[key] = true     # 落在同一个点上（合流）当然也算换乘过了
			break


## 兜底的换乘弧：窗口里始终没碰上相邻的，就在安排的那一环上把两条路线之间
## **较短的那段弧**整条保护起来 —— 断边时不碰它。没有换乘，
## 「搜到好东西转去打」「打不动了转去撤」都做不到，风格就成了开局定终身。
func _lay_pivots() -> void:
	var routes := _graph.routes
	for pair in _route_pairs(routes.size()):
		var a: Dictionary = routes[int(pair[0])]
		var b: Dictionary = routes[int(pair[1])]
		for k in _pivot_rings.size():
			if _pivot_done.has("%d:%d:%d" % [pair[0], pair[1], k]):
				continue
			var slot_a := _route_slot_on_ring(a, _pivot_rings[k])
			var slot_b := _route_slot_on_ring(b, _pivot_rings[k])
			if slot_a < 0 or slot_b < 0 or slot_a == slot_b:
				continue
			var arc := _protect_arc(_pivot_rings[k], slot_a, slot_b)
			if not arc.is_empty():
				# 撤离点想落在两条路线之间的换乘弧上，得记下这段弧是谁和谁的
				(_graph.layout_meta["pivot_arcs"] as Array).append(
					{"routes": [int(pair[0]), int(pair[1])], "node_ids": arc})


func _route_slot_on_ring(route: Dictionary, r: int) -> int:
	for id in (route["node_ids"] as Array):
		var n := _graph.get_node(int(id))
		if n != null and int(n.layout.get("ring", -1)) == r:
			return int(n.layout["order"])
	return -1


## 保护第 r 环上 slot_a → slot_b 之间较短的那段弧上的全部相邻边。返回弧上的点（含两端）；
## 两头都不通返回空。
func _protect_arc(r: int, slot_a: int, slot_b: int) -> Array[int]:
	var slots := maxi(1, _cfg.slots_for_ring(r))
	var forward := posmod(slot_b - slot_a, slots)
	var dir := 1 if forward <= slots - forward else -1
	# 短的那段被空白区或高危区挡住了，就走长的那段；两头都不通才作罢
	var path := _arc_path(r, slot_a, slot_b, dir)
	if path.is_empty():
		path = _arc_path(r, slot_a, slot_b, -dir)
	if path.is_empty():
		return path
	var prev := -1
	for id in path:
		_protected_nodes[id] = true
		if prev >= 0:
			_protect_edge(prev, id, &"tangential")
		prev = id
	return path


## 沿第 r 环从 slot_a 朝 dir 走到 slot_b 经过的点（含两端）；中间断了（空白区、高危区）返回空。
func _arc_path(r: int, slot_a: int, slot_b: int, dir: int) -> Array[int]:
	var map: Dictionary = _ring_slots[r]
	var out: Array[int] = [int(map[slot_a])]
	var slot := slot_a
	var guard := 0
	while slot != slot_b and guard < map.size() + 1:
		slot = _ring_next(r, slot, dir)
		if slot < 0 or _graph.get_node(int(map[slot])).zone != 0:
			return [] as Array[int]
		out.append(int(map[slot]))
		guard += 1
	return out if slot == slot_b else [] as Array[int]
#endregion


#region 6 高危区
func _rules() -> ZoneRules:
	return _cfg.zone_rules if _cfg.zone_rules != null else ZoneRules.new()


## 这个点还能不能被高危区占走。
func _zone_free(id: int) -> bool:
	if id == CORE_ID or _protected_nodes.has(id) or _graph.entry_ids.has(id):
		return false
	var n := _graph.get_node(id)
	return n != null and n.zone == 0


## 路线铺完之后再长高危区（报告 053 第三条）。岔出的规矩不变，只是从「边铺边岔」挪到「铺完再挑锚点」：
## 从过了半程的那一环起逐环向内，每环按概率从这一环上的路线节点岔出还没长的区，最内环兜底；
## 每走一环，已经岔出的区各长一个点 —— 先岔出的区长得大些，和以前一样。
## 只有风格允许（[member RouteStyle.spawns_zones]）的路线岔：搜索路线不岔
func _lay_zones() -> void:
	var outer := _cfg.ring_count()
	var spec := _cfg.zone_spec
	if spec != null and _zones_pending > 0:
		for r in range(outer - 1, 0, -1):
			var progress := float(outer - r) / float(maxi(1, outer - 1))
			if progress < spec.start_after_progress:
				continue
			_grow_zones_once()
			var last_chance := r <= 1
			for _k in _zones_pending:
				if (last_chance or _rng.randf() < spec.spawn_chance) and _spawn_zone(r):
					_zones_pending -= 1
	# 接着长到软上限或没地方为止
	while _grow_zones_once():
		pass
	_finalize_zones()
	for i in _graph.routes.size():
		_graph.routes[i]["zone_ids"] = _surviving_zones(i)


## 从第 r 环上某条路线的节点岔出一片。要求「周围空间充足」：
## 第一个点旁边至少还有一个空点，保证立刻能再长一步（一片高危区生下来就至少两个点）。
## 每条路线身上岔出的片数有上限（规模模板的 zones_per_route）。
func _spawn_zone(r: int) -> bool:
	var profile := _cfg.scale()
	var per_route := profile.zones_per_route if profile != null else 1
	var options: Array = []      # [anchor, first, route]
	for i in _paths.size():
		if not _styles[i].spawns_zones:
			continue
		if (_zones_on_route.get(i, []) as Array).size() >= per_route:
			continue
		for anchor in (_paths[i] as Array[int]):
			var n := _graph.get_node(anchor)
			if anchor == CORE_ID or int(n.layout.get("ring", 0)) != r or _graph.entry_ids.has(anchor):
				continue
			# 路线的尽头是它的出口：不从它岔出，收尾时也就不会把它吸进去。
			# 「岔出点不能是必须存在点」（唯一的休息区、唯一的精英……）这里查不了 —— 这一步节点还没有类型；
			# 约束落在 [RingTypeAssigner]：被高危区吸收进去的路线节点，类型分配时不许拿去当必须型
			if n.zone != 0 or _route_ends.has(anchor):
				continue
			for first in _spatial_neighbors(anchor):
				if not _zone_free(first):
					continue
				for second in _spatial_neighbors(first):
					if second != anchor and _zone_free(second):
						options.append([anchor, first, i])
						break
	if options.is_empty():
		return false
	# 岔出来的那条路当场建：会和别的路交叉的不要，换一个
	var pick: Array = []
	for i in _shuffled_indices(options.size()):
		var option: Array = options[i]
		if not _link(int(option[0]), int(option[1]), true, false).is_empty():
			pick = option
			break
	if pick.is_empty():
		return false
	var head := {
		"id": _zone_heads.size() + 1,
		"cap": clampi(_cfg.effective_zone_soft_cap(), _rules().min_size, _rules().max_size),
		"anchor": int(pick[0]), "first": int(pick[1]), "members": [] as Array[int],
	}
	if not _zones_on_route.has(int(pick[2])):
		_zones_on_route[int(pick[2])] = [] as Array[int]
	(_zones_on_route[int(pick[2])] as Array[int]).append(int(head["id"]))
	_zone_heads.append(head)
	_claim(head, int(pick[1]))
	_grow_zone_once(head)       # 视作新起点并立刻推算一次
	return true


func _surviving_zones(route_index: int) -> Array[int]:
	var out: Array[int] = []
	for zone_id in (_zones_on_route.get(route_index, []) as Array):
		if _graph.zones.has(int(zone_id)):
			out.append(int(zone_id))
	return out


func _claim(head: Dictionary, id: int) -> void:
	var n := _graph.get_node(id)
	n.zone = int(head["id"])
	n.danger = 2
	(head["members"] as Array[int]).append(id)


## 每片在长的高危区各长一个点。有任何一片长了就返回 true。
func _grow_zones_once() -> bool:
	var grew := false
	for head in _zone_heads:
		if _grow_zone_once(head):
			grew = true
	return grew


func _grow_zone_once(head: Dictionary) -> bool:
	var members: Array[int] = head["members"]
	if members.size() >= int(head["cap"]):
		return false
	var frontier: Array[int] = []
	var came_from := {}
	for id in members:
		for n_id in _spatial_neighbors(id):
			if _zone_free(n_id) and not frontier.has(n_id):
				frontier.append(n_id)
				came_from[n_id] = id
	if frontier.is_empty():
		return false
	# 每长一步，那条路当场建出来 —— 区是沿着真的路长的，不是先圈地再补路。
	# 会和别的路交叉的那一步不走，换一个方向
	for i in _shuffled_indices(frontier.size()):
		var pick: int = frontier[i]
		if _link(int(came_from[pick]), pick, true, false).is_empty():
			continue
		_claim(head, pick)
		_zone_links.append([int(came_from[pick]), pick])
		return true
	return false


## 收尾。只长到两个点的，把它岔出来的那个路线节点也划进去凑成三个 ——
## 那个点原本的路线边就成了出入口，哪怕这让一片三个点的小区有两个口也没关系。
func _finalize_zones() -> void:
	var rules := _rules()
	for head in _zone_heads:
		var members: Array[int] = head["members"]
		var anchor := int(head["anchor"])
		var absorbed := false
		if members.size() < rules.min_size and _graph.get_node(anchor).zone == 0 \
				and anchor != CORE_ID and not _graph.entry_ids.has(anchor) and not _route_ends.has(anchor):
			_claim(head, anchor)
			_zone_links.append([anchor, int(head["first"])])
			absorbed = true
		if members.size() < rules.min_size:
			# 还是不够（岔出点被别的区占了，或者它是出生点）。这一片不要了，点还回去
			for id in members:
				_graph.get_node(id).zone = 0
				_graph.get_node(id).danger = 0
			continue
		if not absorbed:
			_zone_gate_links.append([anchor, int(head["first"])])
		members.sort()
		_graph.zones[int(head["id"])] = {"node_ids": members, "gate_ids": [] as Array[int]}
	# 必须有的那几片没凑齐 → 这一次尝试作废；多出来的没长成 → 跳过，但记一笔
	var made := _graph.zones.size()
	_zones_missing = maxi(0, _zone_range.x - made)
	_zones_skipped = 0 if _zones_missing > 0 else maxi(0, _zone_target - made)
	if _zones_skipped > 0:
		_graph.layout_meta["zones_skipped"] = _zones_skipped


## 空间上挨着的点：同环相邻槽位，以及相邻环上边长上限之内的。
##
## 用的是槽位关系而不是图上的边 —— 这一步边还没建，而「挨着」本来就是几何概念。
func _spatial_neighbors(id: int) -> Array[int]:
	var out: Array[int] = []
	var n := _graph.get_node(id)
	if n == null:
		return out
	var r := int(n.layout.get("ring", 0))
	if r <= 0:
		return out
	var slot := int(n.layout["order"])
	var map: Dictionary = _ring_slots[r]
	for d in [-1, 1]:
		var s := _ring_next(r, slot, d)
		if s >= 0 and not out.has(int(map[s])):
			out.append(int(map[s]))
	for rr in [r - 1, r + 1]:
		if rr >= 1 and rr <= _cfg.ring_count():
			out.append_array(_reachable_in_ring(id, rr))
	return out


## 第 to_ring 环上，从 from_id 拉一条边过去不超长的全部点，由近到远。
func _reachable_in_ring(from_id: int, to_ring: int) -> Array[int]:
	var out: Array[int] = []
	if to_ring < 1 or to_ring > _cfg.ring_count():
		return out
	for id in _slots_sorted(to_ring):
		if _within_limit(from_id, id):
			out.append(id)
	out.sort_custom(func(a: int, b: int) -> bool:
		var da := _slot_offset(from_id, a)
		var db := _slot_offset(from_id, b)
		return da < db or (da == db and a < b))
	return out


## 一条边的长度上限（5.4「单条路径的长度」）：环位偏移与槽位偏移各不超过配置值。
func _within_limit(a: int, b: int) -> bool:
	return edge_within_limit(_graph, a, b, _cfg.edge_max_ring_offset, _cfg.edge_max_slot_offset)


func _slot_offset(a: int, b: int) -> float:
	return slot_offset(_graph, a, b)


## 两点之间的槽位偏移。同环 = 环上隔几个槽位；跨环 = 把【里面那个点】按比例投到外面那环上，
## 看它与外面那个点差几个槽位（小数）。连着核心的边没有槽位可言，算 0。
##
## 用外环的槽位当尺子，因为它更细：内环只有六个槽位时一格就是 60°，
## 拿它量「± 1 格」等于什么都没限制。
static func slot_offset(graph: MapGraph, a: int, b: int) -> float:
	var na := graph.get_node(a)
	var nb := graph.get_node(b)
	var ra := int(na.layout.get("ring", 0))
	var rb := int(nb.layout.get("ring", 0))
	if ra == 0 or rb == 0:
		return 0.0
	var outer := na if ra >= rb else nb
	var inner := nb if ra >= rb else na
	var table: Dictionary = graph.layout_meta.get("ring_slots", {})
	var r_out := int(outer.layout["ring"])
	var r_in := int(inner.layout["ring"])
	if r_out == r_in:
		# 同环用整数算。走下面的浮点投影的话，6 / 25 * 25 会得到 6.000000001，
		# 相邻槽位量出来是 1.0000001，恰好超限
		return float(_ring_dist(int(na.layout["order"]), int(nb.layout["order"]),
			maxi(1, int(table.get(r_out, table.get(str(r_out), 1))))))
	var s_out := float(int(table.get(r_out, table.get(str(r_out), 1))))
	var s_in := float(int(table.get(r_in, table.get(str(r_in), 1))))
	var projected := float(int(inner.layout["order"])) / maxf(1.0, s_in) * s_out
	var diff := fposmod(projected - float(int(outer.layout["order"])), s_out)
	return minf(diff, s_out - diff)


## 半个槽位的余量：跨环投影是小数，「正对着的那个 ± 1」量出来最多 1.5。
static func edge_within_limit(
	graph: MapGraph, a: int, b: int, max_ring: int, max_slot: int
) -> bool:
	var ra := int(graph.get_node(a).layout.get("ring", 0))
	var rb := int(graph.get_node(b).layout.get("ring", 0))
	if absi(ra - rb) > max_ring:
		return false
	if ra == rb:
		# 同环的弧可以跨过几个空槽（5.4.1 的 1----1）；上限跟着图走
		var span := int(graph.layout_meta.get("edge_max_arc_span", 0))
		return slot_offset(graph, a, b) <= float(span + 1)
	return slot_offset(graph, a, b) <= float(max_slot) + 0.5
#endregion


#region 7–9 边
## 候选边：同环相邻槽位连弧（不跨空白区），每个点向内连 radial_links 条。
func _link_candidates() -> void:
	var count := _cfg.ring_count()
	for r in range(1, count + 1):
		var slots := maxi(1, _cfg.slots_for_ring(r))
		var map: Dictionary = _ring_slots[r]
		# 同环：连【挨着的两个点】—— 中间可以隔几个空槽（一段弧），
		# 隔得超过 tangential_span_max 就是空白区，弧在那里断开
		for slot in _sorted_keys(map):
			var nxt := _ring_next(r, slot, 1)
			if slots > 1 and nxt >= 0 and slot != nxt \
					and _graph.edge_between(int(map[slot]), int(map[nxt])) == null:
				_graph.connect_nodes(int(map[slot]), int(map[nxt]), &"tangential")
		# 向内：次序最近的若干个
		for slot in _sorted_keys(map):
			var from_id := int(map[slot])
			var want := _rng.randi_range(
				maxi(1, _cfg.radial_links.x), maxi(1, _cfg.radial_links.y))
			for target in _nearest_inward(from_id, r - 1, want):
				_link(from_id, target, false)      # 会交叉又让不开的就不连


## 内侧一环里够得着的、最近的 want 个点（r-1 == 0 时就是核心）。
##
## 一个都够不着（正对着空白区）就一条向内的边也没有 —— 它靠同环的弧连到别处，
## 断边那一步保证不会把它断成孤岛。
func _nearest_inward(from_id: int, to_ring: int, want: int) -> Array[int]:
	if to_ring <= 0:
		return [CORE_ID] as Array[int]
	var near := _reachable_in_ring(from_id, to_ring)
	return near.slice(0, mini(want, near.size()))


## 把高危区的生长树补成真的边，并保护起来 —— 区内别的边照样可断（断成死胡同没关系，
## 走回头路就是），但生长树断了区就散成几片，里面的点谁也到不了。
func _link_zone_trees() -> void:
	for link in _zone_links:
		var a := int(link[0])
		var b := int(link[1])
		var same_ring: bool = _graph.get_node(a).layout["ring"] == _graph.get_node(b).layout["ring"]
		_protect_edge(a, b, &"tangential" if same_ring else &"radial")
	# 岔出来的那条边是天然的第一个出入口
	for link in _zone_gate_links:
		var a := int(link[0])
		var b := int(link[1])
		var same_ring: bool = _graph.get_node(a).layout["ring"] == _graph.get_node(b).layout["ring"]
		_protect_edge(a, b, &"tangential" if same_ring else &"radial")


## 高危区隔离：只留几个**出入口节点**，其余跨界的边删掉。
##
## 出入口是「区内连着区外的那个点」，不是边：一个点身上有三条路通向区外，也只算一个口 ——
## 玩家站在那个点上，出去就是出去了，从哪条路出去没差别。
## 留几个：1 到「这个规模允许的上限」之间随机。带受保护跨界边的点（岔出来的那条边的区内头、
## 被吸收的路线节点）必须是口。再要添的话，**挑离已有出入口最远的点** ——
## 多个口挤在一起，和一个口没区别。定为口的点，它全部跨界的边都留。
func _isolate_zones() -> void:
	var rules := _rules()
	var zone_ids: Array = _graph.zones.keys()
	zone_ids.sort()
	for zone_id in zone_ids:
		var info: Dictionary = _graph.zones[zone_id]
		var members: Array = info["node_ids"]
		var inside := {}
		for id in members:
			inside[int(id)] = true
		var by_gate := {}       # 区内节点 -> 它的跨界边
		var forced := {}        # 必须留的口
		for e in ZoneRules.crossing_edges(_graph, members):
			var gate := e.from_id if inside.has(e.from_id) else e.to_id
			var outside := e.other(gate)
			if _graph.get_node(outside).zone != 0 and not _protected_edges.has(_edge_key(e.from_id, e.to_id)):
				# 两片高危区之间不直接开口：那条边两边各算一个出入口，
				# 后处理的那片会把先处理的那片算好的数目顶破
				_graph.remove_edge(e)
				continue
			if not by_gate.has(gate):
				by_gate[gate] = [] as Array[MapEdge]
			(by_gate[gate] as Array[MapEdge]).append(e)
			if _protected_edges.has(_edge_key(e.from_id, e.to_id)):
				forced[gate] = true

		var keep: Array[int] = _sorted_keys(forced)
		var spare: Array[int] = []
		for gate in _sorted_keys(by_gate):
			if not forced.has(gate):
				spare.append(gate)
		var want := _rng.randi_range(1, maxi(1, rules.max_gates_for(members.size())))
		while keep.size() < want and not spare.is_empty():
			var best := -1
			var best_dist := -1
			for i in spare.size():
				var dist := _gate_spread(spare[i], keep, inside)
				if dist > best_dist:
					best = i
					best_dist = dist
			keep.append(spare[best])
			spare.remove_at(best)

		for gate in spare:
			for e in (by_gate[gate] as Array[MapEdge]):
				_graph.remove_edge(e)
		for gate in keep:
			for e in (by_gate[gate] as Array[MapEdge]):
				_protected_edges[_edge_key(e.from_id, e.to_id)] = true
		info["gate_ids"] = ZoneRules.gate_ids(_graph, members)


## 这个区内节点离已有出入口最近的有几步 —— 只沿区内的路走。
## 还没有任何出入口时返回一个大数：第一个随便哪个都一样远。
func _gate_spread(gate: int, kept: Array[int], inside: Dictionary) -> int:
	if kept.is_empty():
		return 1 << 20
	var dist := {gate: 0}
	var queue: Array[int] = [gate]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for n in _graph.neighbors(id):
			if inside.has(n) and not dist.has(n):
				dist[n] = int(dist[id]) + 1
				queue.append(n)
	var nearest := 1 << 20
	for g in kept:
		nearest = mini(nearest, int(dist.get(g, 1 << 20)))
	return nearest


## 隔离之后补一刀：区外的点如果向内的边全都通进了高危区，隔离时就一并被删光了，
## 它只剩同环的弧可走 —— 而弧随后还要按概率断。给它重连一条通向【区外】内环点的边，
## 「每个点都有向内的径向边」这条连通性的根基才重新成立。
func _repair_inward() -> void:
	for r in range(1, _cfg.ring_count() + 1):
		var slots := maxi(1, _cfg.slots_for_ring(r))
		var map: Dictionary = _ring_slots[r]
		for slot in _sorted_keys(map):
			var id := int(map[slot])
			if _graph.get_node(id).zone != 0 or _has_inward_edge(id, r):
				continue
			var target := _nearest_free_inward(id, r - 1)
			if target >= 0:
				_link(id, target, false)


## 隔离之后一条边都不剩的点：它的邻居全在高危区里，跨界的边被删光了。
## 旁边有区外的点就连过去；真被高危区围死了，就划进那片区（没超规模上限的话）——
## 一个只能穿过高危区才到得了的点，本来就是高危区的一部分。
func _rescue_stranded() -> void:
	var rules := _rules()
	for id in _graph.node_ids():
		if id == CORE_ID or not _graph.edges_of(id).is_empty():
			continue
		var node := _graph.get_node(id)
		var joined := false
		for n_id in _spatial_neighbors(id):
			# 连不上（会交叉）就试下一个邻居，不能试一个就当成功了
			if _graph.get_node(n_id).zone == 0 and not _link(id, n_id, false).is_empty():
				joined = true
				break
		if joined or node.zone != 0:
			continue
		for n_id in _spatial_neighbors(id):
			var z := _graph.get_node(n_id).zone
			if z == 0 or not _graph.zones.has(z):
				continue
			var members: Array = _graph.zones[z]["node_ids"]
			if members.size() >= rules.max_size:
				continue
			node.zone = z
			node.danger = 2
			members.append(id)
			members.sort()
			_link(id, n_id, false)
			_protected_edges[_edge_key(id, n_id)] = true
			break


## 「路不许交叉」之后，候选边会因为让路而少连几条，偶尔让一小撮点整个脱离主图。
## 从核心能走到的算主图；没连上的点里，谁挨着主图上同一片区的点，就把谁接上去，
## 一轮一轮接到接不动为止。
func _reconnect_islands() -> void:
	var progressed := true
	while progressed:
		progressed = false
		var reached := reachable_from(_graph, [CORE_ID] as Array[int])
		for id in _graph.node_ids():
			if reached.has(id):
				continue
			for n_id in _spatial_neighbors(id):
				if reached.has(n_id) and _graph.get_node(n_id).zone == _graph.get_node(id).zone 						and not _link(id, n_id, false).is_empty():
					progressed = true
					break
			if progressed:
				break


func _has_inward_edge(id: int, r: int) -> bool:
	for n_id in _graph.neighbors(id):
		if int(_graph.get_node(n_id).layout.get("ring", -1)) == r - 1:
			return true
	return false


## 内侧一环里够得着、且不在任何高危区里的最近的点。没有就 -1。
func _nearest_free_inward(from_id: int, to_ring: int) -> int:
	if to_ring <= 0:
		return CORE_ID
	for id in _reachable_in_ring(from_id, to_ring):
		if _graph.get_node(id).zone == 0:
			return id
	return -1


#region 不交叉
## 把 p 和 t 连起来，**不许和别的路交叉**。返回从 p 走到 t 经过的点（不含 p）：
## `[t]` 直接连上了；`[x, t]` 绕了一个点；`[]` 连不上。
##
## 两条路在图上交叉，玩家看到的是一个十字，分不清那是路口还是两条互不相干的路叠在一起。
## 只有一种交叉是说得清的：**四个点两两相连** —— 那就是一个四岔路口，渲染时画成一个路口四条腿。
##
## 斜着走（环与槽位都有偏移）时，拦在中间的只可能是另一条对角线 q–u：
## q 是 p 同环、朝 t 那一侧的邻居，u 是 t 同环、朝 p 那一侧的邻居。碰上了就按这个顺序试：
## 1. q、u 各自的路都不到 3 条 → 把四个点连满，成一个四岔路口；
## 2. 否则轮流看 q、u 谁的路不到 4 条 → 借道：p–x、x–t 两条路代替 p–t；
## 3. 都不行 → 连不上，调用方换别的落点。
func _link(p: int, t: int, protect: bool, may_reroute: bool = true) -> Array[int]:
	var none: Array[int] = []
	if p == t:
		return none
	var rp := int(_graph.get_node(p).layout.get("ring", 0))
	var rt := int(_graph.get_node(t).layout.get("ring", 0))
	if _graph.edge_between(p, t) != null or rp == rt:
		_join(p, t, protect)
		return [t] as Array[int]
	var blockers := _crossers(p, t, {})
	if blockers.is_empty():
		_join(p, t, protect)
		return [t] as Array[int]
	if blockers.size() > 1 or not may_reroute:
		return none     # 高危区的路不许借道也不许凑四岔：借来的点不在区里，区就断了

	var e: MapEdge = blockers[0]
	var q := e.from_id if int(_graph.get_node(e.from_id).layout["ring"]) == rp else e.to_id
	var u := e.other(q)
	if _can_quad(p, t, q, u) and _graph.edges_of(q).size() < 3 and _graph.edges_of(u).size() < 3:
		for pair in [[p, t], [q, u], [p, q], [u, t], [p, u], [q, t]]:
			_join(int(pair[0]), int(pair[1]), true)     # 四岔的六条边少一条就又成了交叉，全都保护
		for id in [q, u]:
			_protected_nodes[id] = true
		return [t] as Array[int]

	for x in [q, u]:
		if _graph.edges_of(x).size() >= 4 or not _zones_agree([p, t, x]):
			continue
		if not _within_limit(p, x) or not _within_limit(x, t):
			continue
		if not _crossers(p, x, {}).is_empty() or not _crossers(x, t, {}).is_empty():
			continue
		_join(p, x, protect)
		_join(x, t, protect)
		return [x, t] as Array[int]
	return none


func _join(a: int, b: int, protect: bool) -> void:
	if _graph.edge_between(a, b) == null:
		var same_ring: bool = _graph.get_node(a).layout["ring"] == _graph.get_node(b).layout["ring"]
		_graph.connect_nodes(a, b, &"tangential" if same_ring else &"radial")
	if protect:
		_protected_edges[_edge_key(a, b)] = true


## 四个点能不能连满：每条边都在长度上限之内、两条同环的边确实是相邻槽位、
## 四个点同属一片（不跨高危区边界），而且补上的两条直边自己不会再和别的路交叉。
func _can_quad(p: int, t: int, q: int, u: int) -> bool:
	if not _zones_agree([p, t, q, u]):
		return false
	for pair in [[p, q], [u, t], [p, u], [q, t]]:
		if not _within_limit(int(pair[0]), int(pair[1])):
			return false
	var own := {_edge_key(p, t): true, _edge_key(q, u): true}
	return _crossers(p, u, own).is_empty() and _crossers(q, t, own).is_empty()


func _zones_agree(ids: Array) -> bool:
	var zone := _graph.get_node(int(ids[0])).zone
	for id in ids:
		if _graph.get_node(int(id)).zone != zone:
			return false
	return true


## 如果连上 a–b，会和哪些已有的路交叉。ignore 里的边（"小id:大id"）不算。
##
## 生成一张图要问几千次，所以先用环号把不相干的边筛掉，剩下的才去算几何。
func _crossers(a: int, b: int, ignore: Dictionary) -> Array[MapEdge]:
	var out: Array[MapEdge] = []
	var ra := int(_graph.get_node(a).layout.get("ring", 0))
	var rb := int(_graph.get_node(b).layout.get("ring", 0))
	if ra == rb or mini(ra, rb) == 0:
		return out
	var hi := maxi(ra, rb)
	for e in _graph.edges:
		if e.kind != &"radial":
			continue
		var r1 := int(_graph.get_node(e.from_id).layout.get("ring", 0))
		if r1 != hi and r1 != hi - 1:
			continue
		if not ignore.has(_edge_key(e.from_id, e.to_id)) 				and edges_cross(_graph, a, b, e.from_id, e.to_id):
			out.append(e)
	return out


## 两条跨环的路是否交叉：它们得夹在同一对环之间，没有公共端点，而且两条线段真的相交。
##
## 直接按几何算（第 r 环半径 r，角度 = 槽位 / 槽位数）。只比「在外环上的先后与在内环上的先后
## 是否相反」是不够的：环上正对面的两条路，先后关系本身就是含糊的，会被误判成交叉。
static func edges_cross(graph: MapGraph, a1: int, b1: int, a2: int, b2: int) -> bool:
	if a1 == a2 or a1 == b2 or b1 == a2 or b1 == b2:
		return false
	# 这个函数在生成时被调几万次，所以不建中间字典，先用最便宜的判断把大多数情况筛掉
	var na1 := graph.get_node(a1)
	var nb1 := graph.get_node(b1)
	var ra1 := int(na1.layout.get("ring", 0))
	var rb1 := int(nb1.layout.get("ring", 0))
	if ra1 == rb1 or mini(ra1, rb1) == 0:
		return false
	var na2 := graph.get_node(a2)
	var nb2 := graph.get_node(b2)
	var ra2 := int(na2.layout.get("ring", 0))
	var rb2 := int(nb2.layout.get("ring", 0))
	if maxi(ra1, rb1) != maxi(ra2, rb2) or mini(ra1, rb1) != mini(ra2, rb2):
		return false
	return Geometry2D.segment_intersects_segment(
		_polar(ra1, _fraction(graph, na1)), _polar(rb1, _fraction(graph, nb1)),
		_polar(ra2, _fraction(graph, na2)), _polar(rb2, _fraction(graph, nb2))) != null


static func _polar(ring: int, fraction: float) -> Vector2:
	return Vector2.from_angle(TAU * fraction) * float(ring)


static func _fraction(graph: MapGraph, n: MapNode) -> float:
	var r := int(n.layout.get("ring", 0))
	var table: Dictionary = graph.layout_meta.get("ring_slots", {})
	var slots := maxi(1, int(table.get(r, table.get(str(r), 1))))
	return float(int(n.layout.get("order", 0))) / float(slots)


## 四个点是不是两两相连（那样的交叉是个四岔路口，不算交叉）。
static func is_full_quad(graph: MapGraph, ids: Array) -> bool:
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if graph.edge_between(int(ids[i]), int(ids[j])) == null \
					and graph.edge_between(int(ids[j]), int(ids[i])) == null:
				return false
	return true


## 图上全部「说不清的交叉」：[[边, 边], ...]。
static func bad_crossings(graph: MapGraph) -> Array:
	# 按「夹在哪一对环之间」分桶：不同桶里的路不可能交叉，桶内才两两比
	var buckets := {}
	for e in graph.edges:
		var ra := int(graph.get_node(e.from_id).layout.get("ring", 0))
		var rb := int(graph.get_node(e.to_id).layout.get("ring", 0))
		if ra == rb or mini(ra, rb) == 0:
			continue
		var key := maxi(ra, rb)
		if not buckets.has(key):
			buckets[key] = [] as Array[MapEdge]
		(buckets[key] as Array[MapEdge]).append(e)
	var out: Array = []
	var keys: Array = buckets.keys()
	keys.sort()
	for key in keys:
		var radial: Array[MapEdge] = buckets[key]
		for i in radial.size():
			for j in range(i + 1, radial.size()):
				var x := radial[i]
				var y := radial[j]
				if edges_cross(graph, x.from_id, x.to_id, y.from_id, y.to_id) 						and not is_full_quad(graph, [x.from_id, x.to_id, y.from_id, y.to_id]):
					out.append([x, y])
	return out


## 收尾：隔离高危区、断边都可能拆掉四岔路口的某一条边，剩下的两条对角线就成了真交叉。
## 拆掉其中一条 —— 先挑没保护的；拆了会断连通就换另一条。
func _fix_crossings() -> void:
	for pair in bad_crossings(_graph):
		var done := false
		for e in pair:
			var edge: MapEdge = e
			if done or not _graph.edges.has(edge) \
					or _protected_edges.has(_edge_key(edge.from_id, edge.to_id)):
				continue
			_graph.remove_edge(edge)
			if reachable_from(_graph, [edge.from_id] as Array[int]).has(edge.to_id):
				done = true
			else:
				_graph.add_edge(edge)
#endregion


## 断边：同环弧按概率断开。**骨架边与换乘弧不碰，也不许断出孤岛。**
##
## 边有长度上限之后，「每个点都有向内的径向边」不再成立（正对着空白区的点够不着内环），
## 连通性不能再指望径向边兜底。所以每断一条之前先看：断了它两头还连得上吗？
## 连不上就留着。区内断成死胡同没关系，走回头路就是 —— 但死胡同得进得去。
func _break_tangentials() -> void:
	var doomed: Array[MapEdge] = []
	for e in _graph.edges:
		if e.kind != &"tangential" or _protected_edges.has(_edge_key(e.from_id, e.to_id)):
			continue
		if _rng.randf() < _cfg.tangential_break_chance:
			doomed.append(e)
	for e in doomed:
		_graph.remove_edge(e)
		if not reachable_from(_graph, [e.from_id] as Array[int]).has(e.to_id):
			_graph.add_edge(e)
#endregion


#region 校验
## 通用校验之上，再看这一章自己的拓扑规矩。类型相关的（配额、覆盖、路线风险收益）
## 属于 M3-3c，这里一条都不查 —— 那时候类型还全是 battle。
## 传送点不是路（8-1）：先把 portal 边摘下来、按生成规则校验、再装回去（不复制图：复制会丢生成期挂在图上的东西）
func validate(graph: MapGraph, v: MapValidation) -> void:
	var portals: Array = []
	if graph != null:
		for e in graph.edges.duplicate():
			if (e as MapEdge).is_portal():
				graph.remove_edge(e)
				portals.append(e)
	_validate_roads(graph, v)
	for e in portals:
		graph.add_edge(e)


func _validate_roads(graph: MapGraph, v: MapValidation) -> void:
	super.validate(graph, v)
	if graph == null or graph.node_count() == 0:
		return

	# --- 槽位数、tier、侵蚀分档随环单调 ---
	var ring_of := {}
	for id in graph.node_ids():
		var n := graph.get_node(id)
		var r := int(n.layout.get("ring", -1))
		ring_of[id] = r
		if r > 0 and n.tier != n.erosion_band:
			v.fail(&"bands", "节点 %d 的 tier 与 erosion_band 对不上" % id)

	# 看的是【槽位数】而不是节点数：外环挖了一段空白之后，它的节点可以比内环还少，
	# 那是合法的（示意图里就是这样）。「环越靠里越短」说的是环本身的长度
	var slot_table: Dictionary = graph.layout_meta.get("ring_slots", {})
	var prev_slots := -1
	for r in range(int(graph.layout_meta.get("ring_count", 0)), 0, -1):
		var slots := int(slot_table.get(r, slot_table.get(str(r), -1)))
		if slots < 0:
			continue
		if prev_slots >= 0 and slots > prev_slots:
			v.fail(&"ring_slots", "第 %d 环 %d 个槽位，比它外面那环的 %d 还多 —— 环越靠里越短"
				% [r, slots, prev_slots])
		prev_slots = slots

	# --- 每环都不填满：节点 / 槽位 ≤ fill_cap（< 1），内环也一样 ---
	var cap := float(graph.layout_meta.get("fill_cap", 1.0))
	if cap < 1.0:
		var per_ring := {}
		for id in graph.node_ids():
			var r := int(ring_of.get(id, -1))
			per_ring[r] = int(per_ring.get(r, 0)) + 1
		for r in per_ring:
			var slots := int(slot_table.get(r, slot_table.get(str(r), 0)))
			if int(r) > 0 and slots > 0 and int(per_ring[r]) > floori(float(slots) * cap):
				v.fail(&"ring_fill", "第 %d 环 %d 个槽位放了 %d 个点，超过 %.0f%% —— 内环也不能填满"
					% [r, slots, per_ring[r], cap * 100.0])

	# 【路线不在这里查。】路线是用来生成地图的规则，不是一张图合不合格的条件 ——
	# 它们留在 graph.routes 里只是标注（开局给玩家挑出生点时看的），
	# 手改过的图、手绘的图完全可以没有，或者对不上。

	# --- 单条路径的长度上限 ---
	var max_ring := int(graph.layout_meta.get("edge_max_ring_offset", 1))
	var max_slot := int(graph.layout_meta.get("edge_max_slot_offset", 1))
	for e in graph.edges:
		if not edge_within_limit(graph, e.from_id, e.to_id, max_ring, max_slot):
			v.fail(&"edge_length", "%d ↔ %d 这条路太长：最多差 %d 环、%d 个槽位"
				% [e.from_id, e.to_id, max_ring, max_slot])

	# --- 路不交叉。四个点两两相连的那种交叉是四岔路口，不算 ---
	for pair in bad_crossings(graph):
		var x: MapEdge = pair[0]
		var y: MapEdge = pair[1]
		v.fail(&"edge_crossing", "%d↔%d 与 %d↔%d 交叉了，而这四个点没有两两相连"
			% [x.from_id, x.to_id, y.from_id, y.to_id])

	# --- 高危区：规模、区内连通、出入口数目（规则从图上读；与手绘图共用）---
	ZoneRules.validate(graph, v)

	# --- 类型：配额、覆盖、喘气处不进高危区、不许相邻、高危区内容、撤离点（规则从图上读）---
	RingTypeAssigner.validate(graph, v)

	if graph == _graph and _zones_missing > 0:
		v.fail(&"zone_missing", "有 %d 片必须有的高危区没长起来 —— 路线过半程之后旁边没有空地"
			% _zones_missing)

	# --- 出生点间隔 ---
	_validate_entry_gap(graph, v, ring_of)


func _validate_entry_gap(graph: MapGraph, v: MapValidation, ring_of: Dictionary) -> void:
	if _cfg == null or graph.entry_ids.size() < 2:
		return
	var outer := int(graph.layout_meta.get("ring_count", 0))
	var slot_table: Dictionary = graph.layout_meta.get("ring_slots", {})
	var slots := int(slot_table.get(outer, slot_table.get(str(outer), 0)))
	if slots <= 0:
		return
	for i in graph.entry_ids.size():
		for j in range(i + 1, graph.entry_ids.size()):
			var a := graph.get_node(graph.entry_ids[i])
			var b := graph.get_node(graph.entry_ids[j])
			if a == null or b == null \
					or int(ring_of.get(a.id, -1)) != outer or int(ring_of.get(b.id, -1)) != outer:
				continue
			var dist := _ring_dist(int(a.layout["order"]), int(b.layout["order"]), slots)
			if dist < _cfg.entry_min_gap:
				v.fail(&"entry_gap", "出生点 %d 与 %d 只隔 %d 个槽位，要求至少 %d"
					% [a.id, b.id, dist, _cfg.entry_min_gap])

#endregion


#region 小工具
func _slots_sorted(r: int) -> Array[int]:
	if r < 0 or r >= _ring_slots.size():
		return [] as Array[int]
	var out: Array[int] = []
	for slot in _sorted_keys(_ring_slots[r]):
		out.append(int((_ring_slots[r] as Dictionary)[slot]))
	return out


static func _sorted_keys(d: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for k in d:
		out.append(int(k))
	out.sort()
	return out


static func _edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


## 「进骨架并标 protected」：边**当场建出来**，再记一笔不许断。
##
## 不能只记一笔等后面的候选边去建 —— 骨架挑的落点未必落在「次序最近的那几个」里，
## 那条边就永远不存在，而校验会咬着「路线断了」不放，一路重试到用尽。
func _protect_edge(a: int, b: int, kind: StringName) -> void:
	if kind == &"radial":
		_link(a, b, true)
		return
	if _graph.edge_between(a, b) == null:
		_graph.connect_nodes(a, b, kind)
	_protected_edges[_edge_key(a, b)] = true
#endregion
