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
## 正在生长的高危区：{id, spec, cap, anchor, first, members}。anchor 是它岔出来的那个路线节点
var _zone_heads: Array[Dictionary] = []
## 还没岔出来的高危区配置
var _zones_pending: int = 0
## 这一次 build 打算要几片
var _zone_target: int = 0
## 这张图必须有几片、至多几片（来自规模模板）
var _zone_range: Vector2i = Vector2i.ZERO
## 路线下标 -> 它身上岔出的高危区 id
var _zones_on_route: Dictionary = {}
## 高危区岔出来的那条边 [anchor, first]：它是天然的第一个出入口，受保护
var _zone_gate_links: Array = []
var _zones_skipped: int = 0


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

	_make_core()
	if not _make_ring_nodes():
		return null
	if not _lay_skeleton():
		return null
	_lay_pivots()
	_link_candidates()
	_link_zone_trees()
	_isolate_zones()
	_repair_inward()
	_rescue_stranded()
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
		if r >= 1:
			# 高危区也是一个「起点」：和路线同一个节拍，每推进一环长一个点
			_grow_zones_once()
			_maybe_spawn_zones(r, active, paths)

	# 路线走完了，高危区接着长到软上限或没地方为止
	while _grow_zones_once():
		pass
	_finalize_zones()

	var routes: Array[Dictionary] = []
	for i in paths.size():
		routes.append({
			"entry_id": entries[i],
			"style": String(styles[i].id),
			"ends_at": String(styles[i].ends_at),
			"node_ids": paths[i],
			# 这条路线身上岔出了哪几片高危区 —— 开局挑出生点时，这是玩家想知道的事
			"zone_ids": _surviving_zones(i),
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
			pool = options      # 再退一步：挤不开就合流，总好过整张图作废
		var pick: int = pool[_rng.randi_range(0, pool.size() - 1)]
		var path: Array[int] = paths[i]
		# 正对着空白区时，先沿当前这环横着挪几步，挪到能向内走的地方
		var walk: Array[int] = approaches[i]["walk"]
		for side in walk:
			_protect_edge(path[-1], side, &"tangential")
			_protected_nodes[side] = true
			path.append(side)
		# 横着挪过之后，pick 得是从【挪到的那个点】够得着的
		if not walk.is_empty() and not _within_limit(path[-1], pick):
			pick = options[0]
		_protect_edge(path[-1], pick, &"radial")
		_protected_nodes[pick] = true
		path.append(pick)
		taken.append(int(_graph.get_node(pick).layout["order"]))
	return true


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
			slot = posmod(slot + dir, slots)
			if not map.has(slot) or _graph.get_node(int(map[slot])).zone != 0:
				break       # 这一边被空白区（或高危区）截断了
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
		if not slot_map.has(slot) or _graph.get_node(int(slot_map[slot])).zone != 0:
			# 弧上有空白区或高危区，这一段连不过去；已保护的部分留着，不强求
			prev = -1
			continue
		var id := int(slot_map[slot])
		_protected_nodes[id] = true
		if prev >= 0:
			_protect_edge(prev, id, &"tangential")
		prev = id
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


## 「连接点不能是必须存在点」（唯一的休息区、唯一的精英……）。
##
## 这一步节点还没有类型，所以恒为 false；约束实际落在 M3-3c：
## 被高危区吸收进去的路线节点，类型分配时不许拿去当必须型。留这个口子是为了那时候好接。
func _is_mandatory_node(_id: int) -> bool:
	return false


## 过了半程的路线上，按概率岔出还没长的高危区。r = 各条路线刚刚落子的那一环。
func _maybe_spawn_zones(r: int, active: Array[int], paths: Array) -> void:
	var spec := _cfg.zone_spec
	if spec == null or _zones_pending <= 0:
		return
	var outer := _cfg.ring_count()
	var progress := float(outer - r) / float(maxi(1, outer - 1))
	if progress < spec.start_after_progress:
		return
	var last_chance := r <= 1
	for _k in _zones_pending:
		if (last_chance or _rng.randf() < spec.spawn_chance) and _spawn_zone(active, paths):
			_zones_pending -= 1


## 从某条路线刚落子的那个点上岔出一片。要求「周围空间充足」：
## 第一个点旁边至少还有一个空点，保证立刻能再长一步（一片高危区生下来就至少两个点）。
## 每条路线身上岔出的片数有上限（规模模板的 zones_per_route）。
func _spawn_zone(active: Array[int], paths: Array) -> bool:
	var profile := _cfg.scale()
	var per_route := profile.zones_per_route if profile != null else 1
	var options: Array = []      # [anchor, first, route]
	for i in active:
		if (_zones_on_route.get(i, []) as Array).size() >= per_route:
			continue
		var path: Array[int] = paths[i]
		var anchor := path[-1]
		if _is_mandatory_node(anchor) or _graph.get_node(anchor).zone != 0:
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
	var pick: Array = options[_rng.randi_range(0, options.size() - 1)]
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
	var pick: int = frontier[_rng.randi_range(0, frontier.size() - 1)]
	_claim(head, pick)
	_zone_links.append([int(came_from[pick]), pick])
	return true


## 收尾。只长到两个点的，把它岔出来的那个路线节点也划进去凑成三个 ——
## 那个点原本的路线边就成了出入口，哪怕这让一片三个点的小区有两个口也没关系。
func _finalize_zones() -> void:
	var rules := _rules()
	for head in _zone_heads:
		var members: Array[int] = head["members"]
		var anchor := int(head["anchor"])
		var absorbed := false
		if members.size() < rules.min_size and _graph.get_node(anchor).zone == 0 \
				and anchor != CORE_ID and not _graph.entry_ids.has(anchor):
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
	var slots := maxi(1, _cfg.slots_for_ring(r))
	var map: Dictionary = _ring_slots[r]
	for d in [-1, 1]:
		var s := posmod(slot + d, slots)
		if map.has(s) and not out.has(int(map[s])):
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
	var slack := 0.0 if ra == rb else 0.5
	return slot_offset(graph, a, b) <= float(max_slot) + slack
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
			for target in _nearest_inward(from_id, r - 1, want):
				if _graph.edge_between(from_id, target) == null:
					_graph.connect_nodes(from_id, target, &"radial")


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


## 高危区隔离：跨区边界的边只留几条当出入口，其余删掉。
##
## 留几条：1 到「这个规模允许的上限」之间随机。已受保护的跨界边（岔出来的那条、
## 被吸收的路线节点原本的路线边）必须留。再要添的话，**挑区内那一头离已有出入口最远的** ——
## 多个口挤在一起，和一个口没区别。
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
		var keep: Array[MapEdge] = []
		var spare: Array[MapEdge] = []
		for e in ZoneRules.crossing_edges(_graph, members):
			var outside := e.to_id if inside.has(e.from_id) else e.from_id
			if _protected_edges.has(_edge_key(e.from_id, e.to_id)):
				keep.append(e)
			elif _graph.get_node(outside).zone != 0:
				# 两片高危区之间不直接开口：那条边两边各算一个出入口，
				# 后处理的那片会把先处理的那片算好的数目顶破
				_graph.remove_edge(e)
			else:
				spare.append(e)

		var want := _rng.randi_range(1, maxi(1, rules.max_gates_for(members.size())))
		while keep.size() < want and not spare.is_empty():
			var best := -1
			var best_dist := -1
			for i in spare.size():
				var dist := _gate_spread(spare[i], keep, inside)
				if dist > best_dist:
					best = i
					best_dist = dist
			if not keep.is_empty() and best_dist <= 0:
				break       # 剩下的都和已有的口挤在同一个点上，添了也白添
			keep.append(spare[best])
			spare.remove_at(best)

		for e in spare:
			_graph.remove_edge(e)
		for e in keep:
			_protected_edges[_edge_key(e.from_id, e.to_id)] = true
		info["gate_ids"] = ZoneRules.gate_ids(_graph, members)


## 这条跨界边在区内的那一头，离已有出入口（区内那一头）最近的有几步 —— 只沿区内的路走。
## 还没有任何出入口时返回一个大数：第一条随便哪条都一样远。
func _gate_spread(edge: MapEdge, kept: Array[MapEdge], inside: Dictionary) -> int:
	if kept.is_empty():
		return 1 << 20
	var start := edge.from_id if inside.has(edge.from_id) else edge.to_id
	var dist := {start: 0}
	var queue: Array[int] = [start]
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		for n in _graph.neighbors(id):
			if inside.has(n) and not dist.has(n):
				dist[n] = int(dist[id]) + 1
				queue.append(n)
	var nearest := 1 << 20
	for e in kept:
		var g := e.from_id if inside.has(e.from_id) else e.to_id
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
				_graph.connect_nodes(id, target, &"radial")


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
			if _graph.get_node(n_id).zone == 0:
				_connect_by_rings(id, n_id)
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
			_connect_by_rings(id, n_id)
			_protected_edges[_edge_key(id, n_id)] = true
			break


func _connect_by_rings(a: int, b: int) -> void:
	var same_ring: bool = _graph.get_node(a).layout["ring"] == _graph.get_node(b).layout["ring"]
	_graph.connect_nodes(a, b, &"tangential" if same_ring else &"radial")


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

	# --- 高危区：规模、区内连通、出入口数目（规则从图上读；与手绘图共用）---
	ZoneRules.validate(graph, v)

	if graph == _graph and _zones_missing > 0:
		v.fail(&"zone_missing", "有 %d 片必须有的高危区没长起来 —— 路线过半程之后旁边没有空地"
			% _zones_missing)

	# --- 出生点间隔 ---
	_validate_entry_gap(graph, v, ring_of)


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
