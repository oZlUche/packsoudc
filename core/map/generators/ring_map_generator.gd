## 第一章的同心环地图 —— **拓扑与骨架**（架构文档 5.4，M3-3）。
##
## [b]骨架先行[/b]：不是生成一张图再从里面找路线，而是先从每个出生点逐环向内铺一条路线，
## 再往路线周围长出地图。否则「偏战斗的路线」只能靠事后给一条碰巧存在的路径贴标签，
## 贴不贴得上看运气。
##
## 这一步只做到拓扑：槽位、骨架、换乘点、高危区、候选边、隔离、断边。
## [b]节点类型全部先填 `battle`[/b]（核心除外），留给 M3-3c ——
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
var _grow_links: Array = []


func default_config() -> Resource:
	return RingMapConfig.sample(5)


func build(cfg: Resource, rng: RandomNumberGenerator) -> MapGraph:
	_cfg = cfg as RingMapConfig
	if _cfg == null or _cfg.ring_count() <= 0 or _cfg.routes.is_empty():
		return null
	_rng = rng
	_graph = MapGraph.new()
	_graph.layout_kind = &"ring"
	_graph.layout_meta = {"ring_count": _cfg.ring_count(), "ring_slots": {}}
	_ring_slots = []
	_protected_nodes = {}
	_protected_edges = {}
	_next_id = 1
	_zones_missing = 0
	_zone_links = []

	_make_core()
	if not _make_ring_nodes():
		return null
	if not _lay_skeleton():
		return null
	_lay_pivots()
	_carve_danger_zones()
	_link_candidates()
	_link_zone_trees()
	_isolate_zones()
	_repair_inward()
	_break_tangentials()
	return _graph


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
	# 外→内
	for r in range(count, 0, -1):
		var spec := _cfg.spec_for_ring(r)
		var slots := _cfg.slots_for_ring(r)
		var filled := _choose_filled_slots(slots, spec.node_count if spec != null else 0)
		if filled.is_empty():
			return false
		var map := {}
		for slot in filled:
			var n := MapNode.new()
			n.id = _next_id
			_next_id += 1
			n.type = &"battle"          # 类型是 M3-3c 的事，这里先占位
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
		(_graph.layout_meta["ring_slots"] as Dictionary)[r] = slots
	return true


## 在 slots 个槽位里挑出 want 个（0 或 ≥ slots = 全填）。
##
## 空槽**连成 1～2 段连续的弧**，不是撒胡椒面式的随机缺口 ——
## 参照示意图，一环本来就可以有一整段没有东西。
func _choose_filled_slots(slots: int, want: int) -> Array[int]:
	var out: Array[int] = []
	var n := slots if want <= 0 or want >= slots else want
	var empty_total := slots - n
	if empty_total <= 0:
		for s in slots:
			out.append(s)
		return out

	# 先在一条直线上排好「空 · 填 · 空 · 填」，再整体旋转一个随机角度。
	# 两段空白因此天然分得开 —— 各挑一个随机起点的话它们会压在一起，
	# 实际空出来的槽位比要的少，而那是不声不响的
	var two := empty_total >= 2 and n >= 2 and _rng.randf() < 0.5
	var gap_a := _rng.randi_range(1, empty_total - 1) if two else empty_total
	var gap_b := empty_total - gap_a
	var fill_a := n / 2 if two else n

	var pattern: Array[bool] = []          # true = 有节点
	for _k in gap_a:
		pattern.append(false)
	for _k in fill_a:
		pattern.append(true)
	for _k in gap_b:
		pattern.append(false)
	while pattern.size() < slots:
		pattern.append(true)

	var offset := _rng.randi_range(0, slots - 1)
	for s in slots:
		if pattern[posmod(s - offset, slots)]:
			out.append(s)
	return out
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
	for i in entries.size():
		paths.append([entries[i]] as Array[int])
		styles.append(_cfg.routes[i % _cfg.routes.size()])
		_protected_nodes[entries[i]] = true
		_graph.entry_ids.append(entries[i])

	for r in range(outer - 1, -1, -1):
		# 这一环还在走的路线：去核心的走到 0，去撤离点的停在 1
		var active: Array[int] = []
		for i in paths.size():
			if r >= (0 if styles[i].is_core_route() else 1):
				active.append(i)
		if active.is_empty():
			break
		if not _advance_ring(r, outer - 1 - r, active, paths):
			return false

	var routes: Array[Dictionary] = []
	for i in paths.size():
		routes.append({
			"entry_id": entries[i],
			"style": String(styles[i].id),
			"ends_at": String(styles[i].ends_at),
			"node_ids": paths[i],
		})
	_graph.routes = routes
	_graph.goal_ids = [CORE_ID] as Array[int]
	return true


## 在最外环上挑出生点：两两之间的环形距离不小于 entry_min_gap 个槽位。
##
## 返回按槽位升序排好的节点 id —— 下标相邻即角度相邻，换乘点靠这个认「相邻路线」。
func _choose_entries() -> Array[int]:
	var outer := _cfg.ring_count()
	var slots := maxi(1, _cfg.slots_for_ring(outer))
	var map: Dictionary = _ring_slots[outer]
	var filled := _sorted_keys(map)
	var want := clampi(_cfg.entry_count, 1, filled.size())
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

	var cands := {}
	for i in active:
		var from_path: Array[int] = paths[i]
		cands[i] = _inward_candidates(from_path[-1], r)
	# 候选最少的先挑 —— 先让选择多的挑，可能正好把别人唯一的落点占掉
	var order: Array[int] = active.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca := (cands[a] as Array).size()
		var cb := (cands[b] as Array).size()
		return ca < cb or (ca == cb and a < b))

	var taken: Array[int] = []      # 这一环上已经被挑走的槽位
	for i in order:
		var options: Array[int] = cands[i]
		if options.is_empty():
			build_note = "路线走到第 %d 环没有落点（空白区挡住了，或 route_drift 太小）" % r
			return false
		var pool := _filter_far(options, taken, need, slots)
		if pool.is_empty() and need > 1:
			pool = _filter_far(options, taken, 1, slots)   # 退一步：不重合就行
		if pool.is_empty():
			pool = options      # 再退一步：挤不开就合流，总好过整张图作废
		var pick: int = pool[_rng.randi_range(0, pool.size() - 1)]
		var path: Array[int] = paths[i]
		_protect_edge(path[-1], pick, &"radial")
		_protected_nodes[pick] = true
		path.append(pick)
		taken.append(int(_graph.get_node(pick).layout["order"]))
	return true


## 从 from_id 向内一环的候选落点：次序比例最接近的槽位 ± 漂移量。
func _inward_candidates(from_id: int, to_ring: int) -> Array[int]:
	var from_node := _graph.get_node(from_id)
	var from_ring := int(from_node.layout["ring"])
	var from_slot := int(from_node.layout["order"])
	var from_slots := maxi(1, _cfg.slots_for_ring(from_ring))
	var to_slots := maxi(1, _cfg.slots_for_ring(to_ring))
	var target := roundi(float(from_slot) / float(from_slots) * float(to_slots))

	# 漂移量以【最外环的槽位】为单位，随环的长度等比缩小（至少 1）。
	# 不缩的话，内环只有六个槽位，±2 就是 ±120° —— 路线会横着穿过半张图
	var outer_slots := maxi(1, _cfg.slots_for_ring(_cfg.ring_count()))
	var drift := maxi(1, roundi(float(_cfg.route_drift) * float(to_slots) / float(outer_slots)))

	var slot_map: Dictionary = _ring_slots[to_ring]
	var candidates: Array[int] = []
	for d in range(-drift, drift + 1):
		var slot := posmod(target + d, to_slots)
		if not slot_map.has(slot):
			continue
		var id := int(slot_map[slot])
		if not candidates.has(id):
			candidates.append(id)
	if candidates.is_empty():
		# 正对着一段空白区。绕到离得最近的那个点，而不是判这一次尝试作废 ——
		# 空白区是配出来的，撞上它不是运气问题，重试也还会撞
		var near := _nearest_in_ring(from_slot, from_slots, to_ring)
		if near >= 0:
			candidates.append(near)
	return candidates


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


## 换乘点：相邻两条路线每 pivot_every_rings 环之间连通一次。
##
## 做法是把那一环上两条路线之间**较短的那段弧**整条保护起来 —— 断边时不碰它。
## 于是换乘是真的走得过去，而不是界面上给个提示。没有换乘点，
## 「搜到好东西转去打」「打不动了转去撤」都做不到，风格就成了开局定终身。
func _lay_pivots() -> void:
	var step := _cfg.pivot_every_rings
	var routes := _graph.routes
	if step <= 0 or routes.size() < 2:
		return
	for i in routes.size():
		var a: Dictionary = routes[i]
		var b: Dictionary = routes[(i + 1) % routes.size()]
		for r in range(_cfg.ring_count(), 0, -step):
			var slot_a := _route_slot_on_ring(a, r)
			var slot_b := _route_slot_on_ring(b, r)
			if slot_a < 0 or slot_b < 0 or slot_a == slot_b:
				continue
			_protect_arc(r, slot_a, slot_b)


func _route_slot_on_ring(route: Dictionary, r: int) -> int:
	for id in (route["node_ids"] as Array):
		var n := _graph.get_node(int(id))
		if n != null and int(n.layout.get("ring", -1)) == r:
			return int(n.layout["order"])
	return -1


## 保护第 r 环上 slot_a → slot_b 之间较短的那段弧上的全部相邻边。
func _protect_arc(r: int, slot_a: int, slot_b: int) -> void:
	var slots := maxi(1, _cfg.slots_for_ring(r))
	var forward := posmod(slot_b - slot_a, slots)
	var backward := slots - forward
	var dir := 1 if forward <= backward else -1
	var span := mini(forward, backward)
	var slot_map: Dictionary = _ring_slots[r]
	var prev := -1
	for k in span + 1:
		var slot := posmod(slot_a + dir * k, slots)
		if not slot_map.has(slot):
			# 弧上有空白区，这一段连不过去；已保护的部分留着，不强求
			prev = -1
			continue
		var id := int(slot_map[slot])
		_protected_nodes[id] = true
		if prev >= 0:
			_protect_edge(prev, id, &"tangential")
		prev = id
#endregion


#region 6 高危区
## 一片与外界只有一条边相连的区域。**避开骨架与换乘弧** ——
## 高危区是岔出去的诱惑，不能横在必经之路上。
func _carve_danger_zones() -> void:
	var zone_id := 0
	var skipped := 0
	for spec in _cfg.danger_zones:
		if not spec.applies_to(_cfg.ring_count()):
			continue    # 环数不够，这一片本来就不该有 —— 不算缺
		var members := _grow_zone(spec)
		if members.size() < spec.size.x:
			# 长不起来。必须有的 → 这一次尝试作废；可选的 → 跳过，但记一笔
			if spec.required:
				_zones_missing += 1
			else:
				skipped += 1
			continue
		zone_id += 1
		_zone_links.append_array(_grow_links)
		for id in members:
			var n := _graph.get_node(id)
			n.zone = zone_id
			n.danger = 2
		_graph.zones[zone_id] = {"node_ids": members, "gate_id": -1}
	if skipped > 0:
		_graph.layout_meta["zones_skipped"] = skipped


func _grow_zone(spec: DangerZoneSpec) -> Array[int]:
	var want := _rng.randi_range(maxi(1, spec.size.x), maxi(1, spec.size.y))
	var pool := _zone_seed_pool(spec)
	if pool.is_empty():
		return [] as Array[int]

	var members: Array[int] = [pool[_rng.randi_range(0, pool.size() - 1)]]
	var taken := {members[0]: true}
	_grow_links = []
	while members.size() < want:
		var frontier: Array[int] = []
		var came_from := {}
		for id in members:
			for n_id in _spatial_neighbors(id):
				if taken.has(n_id) or not _zone_eligible(n_id, spec):
					continue
				if not frontier.has(n_id):
					frontier.append(n_id)
					came_from[n_id] = id
		if frontier.is_empty():
			break
		var pick: int = frontier[_rng.randi_range(0, frontier.size() - 1)]
		members.append(pick)
		taken[pick] = true
		_grow_links.append([int(came_from[pick]), pick])
	members.sort()
	return members


func _zone_seed_pool(spec: DangerZoneSpec) -> Array[int]:
	var pool: Array[int] = []
	for r in range(maxi(1, spec.ring_range.x), mini(_cfg.ring_count(), spec.ring_range.y) + 1):
		for id in _slots_sorted(r):
			if _zone_eligible(id, spec):
				pool.append(id)
	return pool


func _zone_eligible(id: int, spec: DangerZoneSpec) -> bool:
	if _protected_nodes.has(id) or _graph.entry_ids.has(id):
		return false
	var n := _graph.get_node(id)
	if n == null or n.zone != 0 or id == CORE_ID:
		return false
	var r := int(n.layout.get("ring", 0))
	return r >= spec.ring_range.x and r <= spec.ring_range.y


## 空间上挨着的点：同环相邻槽位，以及相邻环次序最近的。
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
	var slots := maxi(1, _cfg.slots_for_ring(r))
	var map: Dictionary = _ring_slots[r]
	for d in [-1, 1]:
		var s := posmod(slot + d, slots)
		if map.has(s):
			out.append(int(map[s]))
	for rr in [r - 1, r + 1]:
		if rr < 1 or rr > _cfg.ring_count():
			continue
		var near := _nearest_in_ring(slot, slots, rr)
		if near >= 0:
			out.append(near)
	return out


func _nearest_in_ring(slot: int, from_slots: int, to_ring: int) -> int:
	var to_slots := maxi(1, _cfg.slots_for_ring(to_ring))
	var target := roundi(float(slot) / float(from_slots) * float(to_slots))
	var map: Dictionary = _ring_slots[to_ring]
	for d in to_slots:
		for sign in [1, -1]:
			var s := posmod(target + d * sign, to_slots)
			if map.has(s):
				return int(map[s])
	return -1
#endregion


#region 7–9 边
## 候选边：同环相邻槽位连弧（不跨空白区），每个点向内连 radial_links 条。
func _link_candidates() -> void:
	var count := _cfg.ring_count()
	for r in range(1, count + 1):
		var slots := maxi(1, _cfg.slots_for_ring(r))
		var map: Dictionary = _ring_slots[r]
		# 同环：只连【相邻槽位】—— 隔着空白区的两点不连，弧不跨空白
		for slot in _sorted_keys(map):
			var nxt := posmod(slot + 1, slots)
			if slots > 1 and map.has(nxt) and slot != nxt \
					and _graph.edge_between(int(map[slot]), int(map[nxt])) == null:
				_graph.connect_nodes(int(map[slot]), int(map[nxt]), &"tangential")
		# 向内：次序最近的若干个
		for slot in _sorted_keys(map):
			var from_id := int(map[slot])
			var want := _rng.randi_range(
				maxi(1, _cfg.radial_links.x), maxi(1, _cfg.radial_links.y))
			for target in _nearest_inward(slot, slots, r - 1, want):
				if _graph.edge_between(from_id, target) == null:
					_graph.connect_nodes(from_id, target, &"radial")


## 内侧一环里次序最近的 want 个点（r-1 == 0 时就是核心）。
func _nearest_inward(slot: int, from_slots: int, to_ring: int, want: int) -> Array[int]:
	if to_ring <= 0:
		return [CORE_ID] as Array[int]
	var to_slots := maxi(1, _cfg.slots_for_ring(to_ring))
	var target := roundi(float(slot) / float(from_slots) * float(to_slots))
	var out: Array[int] = []
	var map: Dictionary = _ring_slots[to_ring]
	# 第一条无论多远都要连上（连通性靠它）；多出来的只连近处的 ——
	# 正对着空白区时「第二近」可能在环的另一头，那条边会横穿半张图
	var reach := 1 + to_slots / 8
	for d in to_slots:
		if not out.is_empty() and d > reach:
			break
		for sign in [1, -1]:
			if out.size() >= want:
				return out
			var s := posmod(target + d * sign, to_slots)
			if map.has(s) and not out.has(int(map[s])):
				out.append(int(map[s]))
	return out


## 把高危区的生长树补成真的边，并保护起来 —— 区内别的边照样可断（断成死胡同没关系，
## 走回头路就是），但生长树断了区就散成几片，里面的点谁也到不了。
func _link_zone_trees() -> void:
	for link in _zone_links:
		var a := int(link[0])
		var b := int(link[1])
		var same_ring: bool = _graph.get_node(a).layout["ring"] == _graph.get_node(b).layout["ring"]
		_protect_edge(a, b, &"tangential" if same_ring else &"radial")


## 高危区隔离：删掉所有跨区边界的边，只留 gate 那一条。
func _isolate_zones() -> void:
	for zone_id in _graph.zones:
		var info: Dictionary = _graph.zones[zone_id]
		var inside := {}
		for id in (info["node_ids"] as Array):
			inside[int(id)] = true
		var crossing: Array[MapEdge] = []
		for e in _graph.edges:
			var a_in := inside.has(e.from_id)
			var b_in := inside.has(e.to_id)
			if a_in != b_in:
				crossing.append(e)
		if crossing.is_empty():
			# 候选边恰好一条都没跨出去。给它开一个口，否则整片区谁也进不去
			var opened := _open_gate(inside)
			if opened != null:
				crossing.append(opened)
			else:
				continue
		# 留一条当入口。M3-3 没有精英，任挑一条；gate_prefers_elite 是 M3-3c 的事
		var keep: MapEdge = crossing[_rng.randi_range(0, crossing.size() - 1)]
		info["gate_id"] = keep.from_id if inside.has(keep.from_id) else keep.to_id
		# 入口是这片区唯一的路，断边不许碰它
		_protected_edges[_edge_key(keep.from_id, keep.to_id)] = true
		for e in crossing:
			if e != keep:
				_graph.remove_edge(e)


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
			var target := _nearest_free_inward(slot, slots, r - 1)
			if target >= 0:
				_graph.connect_nodes(id, target, &"radial")


func _has_inward_edge(id: int, r: int) -> bool:
	for n_id in _graph.neighbors(id):
		if int(_graph.get_node(n_id).layout.get("ring", -1)) == r - 1:
			return true
	return false


## 内侧一环里次序最近、且不在任何高危区里的点。
func _nearest_free_inward(slot: int, from_slots: int, to_ring: int) -> int:
	if to_ring <= 0:
		return CORE_ID
	var to_slots := maxi(1, _cfg.slots_for_ring(to_ring))
	var target := roundi(float(slot) / float(from_slots) * float(to_slots))
	var map: Dictionary = _ring_slots[to_ring]
	for d in to_slots:
		for sign in [1, -1]:
			var s := posmod(target + d * sign, to_slots)
			if map.has(s) and _graph.get_node(int(map[s])).zone == 0:
				return int(map[s])
	return -1


## 从区内找一个空间上挨着区外（且不属于别的区）的点，连一条边出去。
func _open_gate(inside: Dictionary) -> MapEdge:
	for id in _sorted_keys(inside):
		for n_id in _spatial_neighbors(id):
			if inside.has(n_id) or _graph.get_node(n_id).zone != 0:
				continue
			var same_ring: bool = _graph.get_node(id).layout["ring"] == _graph.get_node(n_id).layout["ring"]
			return _graph.connect_nodes(id, n_id, &"tangential" if same_ring else &"radial")
	return null


## 断边：同环弧按概率断开。**骨架边与换乘弧不碰。**
##
## 区内的边也可断 —— 区内断成死胡同没关系，走回头路就是。
func _break_tangentials() -> void:
	var doomed: Array[MapEdge] = []
	for e in _graph.edges:
		if e.kind != &"tangential" or _protected_edges.has(_edge_key(e.from_id, e.to_id)):
			continue
		if _rng.randf() < _cfg.tangential_break_chance:
			doomed.append(e)
	for e in doomed:
		_graph.remove_edge(e)
#endregion


#region 校验
## 通用校验之上，再看这一章自己的拓扑规矩。类型相关的（配额、覆盖、路线风险收益）
## 属于 M3-3c，这里一条都不查 —— 那时候类型还全是 battle。
func validate(graph: MapGraph, v: MapValidation) -> void:
	super(graph, v)
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

	# --- 骨架完整：每条路线仍是一条走得通的简单路径 ---
	for route in graph.routes:
		var ids: Array = route["node_ids"]
		var seen := {}
		for i in ids.size():
			var id := int(ids[i])
			if seen.has(id):
				v.fail(&"skeleton", "路线 %s 上节点 %d 出现两次，不是简单路径"
					% [route.get("style", "?"), id])
			seen[id] = true
			if i > 0 and graph.edge_between(int(ids[i - 1]), id) == null:
				v.fail(&"skeleton", "路线 %s 断了：%d 与 %d 之间没有边"
					% [route.get("style", "?"), ids[i - 1], id])
		if ids.is_empty() or int(ids[0]) != int(route["entry_id"]):
			v.fail(&"skeleton", "路线 %s 的起点不是它的出生点" % route.get("style", "?"))
		elif String(route.get("ends_at", "core")) == "core" and int(ids[-1]) != CORE_ID:
			v.fail(&"skeleton", "路线 %s 说要去核心，末端却不是核心" % route.get("style", "?"))
		elif String(route.get("ends_at", "core")) == "extract" \
				and int(ring_of.get(int(ids[-1]), -1)) != 1:
			v.fail(&"skeleton", "路线 %s 该停在核心前一环" % route.get("style", "?"))

	# --- 高危区：区内连通、与区外恰好一条边、不含骨架节点 ---
	var skeleton := {}
	for route in graph.routes:
		for id in (route["node_ids"] as Array):
			skeleton[int(id)] = true
	for zone_id in graph.zones:
		var info: Dictionary = graph.zones[zone_id]
		var ids: Array = info["node_ids"]
		var inside := {}
		for id in ids:
			inside[int(id)] = true
			if skeleton.has(int(id)):
				v.fail(&"zone_skeleton", "高危区 %s 占了骨架节点 %d —— 它该是岔出去的诱惑，不是路障"
					% [zone_id, id])
		var gates := 0
		for e in graph.edges:
			if inside.has(e.from_id) != inside.has(e.to_id):
				gates += 1
		if gates != 1:
			v.fail(&"zone_gate", "高危区 %s 与区外有 %d 条边，该只有一条" % [zone_id, gates])
		if not _zone_connected(graph, ids, inside):
			v.fail(&"zone_connected", "高危区 %s 内部断成了几片" % zone_id)

	if graph == _graph and _zones_missing > 0:
		v.fail(&"zone_missing", "有 %d 片必须有的高危区没长起来 —— 多半是被骨架与换乘弧占满了"
			% _zones_missing)

	# --- 出生点间隔 ---
	_validate_entry_gap(graph, v, ring_of)

	# --- 换乘点：相邻路线每 N 环至少能在那一环上走通 ---
	_validate_pivots(graph, v, ring_of)


static func _zone_connected(graph: MapGraph, ids: Array, inside: Dictionary) -> bool:
	if ids.size() <= 1:
		return true
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


func _validate_pivots(graph: MapGraph, v: MapValidation, ring_of: Dictionary) -> void:
	var step := _cfg.pivot_every_rings if _cfg != null else 0
	if step <= 0 or graph.routes.size() < 2:
		return
	for i in graph.routes.size():
		var a: Dictionary = graph.routes[i]
		var b: Dictionary = graph.routes[(i + 1) % graph.routes.size()]
		var linked := false
		for r in range(int(graph.layout_meta.get("ring_count", 0)), 0, -step):
			var id_a := _node_on_ring(graph, a, r, ring_of)
			var id_b := _node_on_ring(graph, b, r, ring_of)
			if id_a < 0 or id_b < 0:
				continue
			if id_a == id_b or _connected_within_ring(graph, id_a, id_b, r, ring_of):
				linked = true
				break
		if not linked:
			v.fail(&"pivot", "路线 %s 与 %s 之间没有换乘点 —— 风格会变成开局定终身"
				% [a.get("style", "?"), b.get("style", "?")])


static func _node_on_ring(graph: MapGraph, route: Dictionary, r: int, ring_of: Dictionary) -> int:
	for id in (route["node_ids"] as Array):
		if int(ring_of.get(int(id), -1)) == r:
			return int(id)
	return -1


## 只沿着这一环上的点走，看 a 到不到得了 b。
static func _connected_within_ring(
	graph: MapGraph, a: int, b: int, r: int, ring_of: Dictionary
) -> bool:
	var seen := {a: true}
	var queue: Array[int] = [a]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		if id == b:
			return true
		for n in graph.neighbors(id):
			if int(ring_of.get(n, -1)) == r and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return false
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
	if _graph.edge_between(a, b) == null:
		_graph.connect_nodes(a, b, kind)
	_protected_edges[_edge_key(a, b)] = true
#endregion
