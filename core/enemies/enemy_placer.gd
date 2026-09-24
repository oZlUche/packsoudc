## 把敌人放进地图：每个战斗点在**生成地图时**就定好是谁、背什么（架构文档 5.10 / 6.0，M4-1）。
##
## 生成器不认识敌人 —— 它只造拓扑与类型。这里是第二遍：拿着一章的敌人池，对每个
## `combat_types` 里的节点按 [StrengthRule] 算想要的档位、按 [EnemyPoolEntry] 的过滤挑人、
## 按 [EnemyLoadout] 组装棋盘，写进 [member MapNode.content]。
##
## 随机数只用节点自己的 `content_seed`：同一张图、同一个点，放出来的永远是同一个敌人；
## 预设图 `reroll_content_seeds` 关掉时连内容都原样照搬（5.3.1）。
##
## 内容字典的形状（JSON 友好，跟着图存）：
## [codeblock]
## {"enemy": "raider", "strength": 1, "board": [4, 4],
##  "items": [{"id": "pistol", "at": [0, 0], "rot": 0}, ...]}
## [/codeblock]
## 「放不下」的道具直接跳过 —— 棋盘该比件数宽裕，跳过了 fill 的回报里能看见。
class_name EnemyPlacer
extends RefCounted


## 给整张图放敌人。返回 {"placed": 放了几个, "skipped": [没挑到人的节点 id],
## "dropped": 补完之后总共还差几件, "short": [差了件的点：{id, enemy, strength, missing}]}
static func fill(
	graph: MapGraph, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase,
	difficulty: int = 0, scale_id: StringName = &""
) -> Dictionary:
	var out := {"placed": 0, "skipped": [] as Array[int], "dropped": 0, "short": [] as Array[Dictionary]}
	if graph == null or pool == null or enemies == null or items == null:
		return out
	var depth := depths_of(graph)
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if not pool.combat_types.has(n.type):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = n.content_seed
		var built := place_one(n, pool, enemies, items, float(depth.get(id, 0.0)), difficulty, scale_id, rng)
		if built.is_empty():
			(out["skipped"] as Array[int]).append(id)
			continue
		n.content = built["content"]
		out["dropped"] = int(out["dropped"]) + int(built["dropped"])
		if int(built["dropped"]) > 0:
			(out["short"] as Array[Dictionary]).append({
				"id": id, "enemy": String(built["content"]["enemy"]), "strength": int(built["content"]["strength"]),
				"missing": int(built["dropped"])})
		out["placed"] = int(out["placed"]) + 1
	return out


## 给一个点造一个敌人：算档位 → 挑人 → 组装。返回 build_content 的结果；没挑到人返回空字典。
## 生成时 fill 逐点调它；随机点揭成战斗、搜索点遭遇时 [NodeEvents] 现调它（那时 [param node] 是按目标类型看的视图）
static func place_one(
	node: MapNode, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase,
	depth: float, difficulty: int, scale_id: StringName, rng: RandomNumberGenerator,
	exploration: Dictionary = {}
) -> Dictionary:
	var wanted := wanted_strength(pool, node, depth, difficulty, scale_id, exploration)
	var entry := pick(pool, enemies, node, wanted, rng)
	if entry == null:
		return {}
	return build_content(enemies.enemy(entry.enemy), pool, items, wanted, rng)


## 每个点的深度 0～1：tier 在全图 tier 范围里的位置。形态无关 —— 环形图、手绘图都只看 tier
static func depths_of(graph: MapGraph) -> Dictionary:
	var lo := 1 << 30
	var hi := -(1 << 30)
	for id in graph.node_ids():
		var t := graph.get_node(id).tier
		lo = mini(lo, t)
		hi = maxi(hi, t)
	var out := {}
	for id in graph.node_ids():
		out[id] = 0.0 if hi <= lo else float(graph.get_node(id).tier - lo) / float(hi - lo)
	return out


## 这个点想要几档（夹进档位表的范围）
static func wanted_strength(
	pool: EnemyPool, node: MapNode, depth: float, difficulty: int, scale_id: StringName,
	exploration: Dictionary = {}
) -> int:
	var raw := pool.strength_rule.wanted(node, depth, difficulty, scale_id, exploration) \
		if pool.strength_rule != null else 0
	return pool.clamp_strength(raw)


## 能在这个点出现、且本色档位离想要的最近的那些行
static func candidates(pool: EnemyPool, enemies: EnemyDatabase, node: MapNode, wanted: int) -> Array[EnemyPoolEntry]:
	var fitting: Array[EnemyPoolEntry] = []
	for e in pool.entries:
		if e == null or e.weight <= 0.0 or not e.fits(node):
			continue
		if enemies.enemy(e.enemy) == null:
			continue
		fitting.append(e)
	if fitting.is_empty():
		return fitting
	var tol := pool.strength_rule.tolerance if pool.strength_rule != null else 0
	var best_d := 1 << 30
	for e in fitting:
		best_d = mini(best_d, absi(enemies.enemy(e.enemy).strength - wanted))
	var limit := maxi(tol, best_d)  # 容差内有人就取容差内的，没有就取最近的那一档
	var out: Array[EnemyPoolEntry] = []
	for e in fitting:
		if absi(enemies.enemy(e.enemy).strength - wanted) <= limit:
			out.append(e)
	return out


## 按权重抽一行。没人返回 null
static func pick(
	pool: EnemyPool, enemies: EnemyDatabase, node: MapNode, wanted: int, rng: RandomNumberGenerator
) -> EnemyPoolEntry:
	var cands := candidates(pool, enemies, node, wanted)
	if cands.is_empty():
		return null
	var total := 0.0
	for e in cands:
		total += e.weight
	var r := rng.randf() * total
	for e in cands:
		r -= e.weight
		if r <= 0.0:
			return e
	return cands[cands.size() - 1]


## 放不下时最多再抽几件来补
const REFILL_TRIES := 12


## 组装：招牌 → 流派 → 通用，摆上棋盘。大件先摆（摆得下的概率高），放不下的换一件再试。
## 返回 {"content": Dictionary, "dropped": 补完之后还差几件}
static func build_content(
	def: EnemyDef, pool: EnemyPool, items: ItemDatabase, strength: int, rng: RandomNumberGenerator
) -> Dictionary:
	var tier := pool.tier_of(strength)
	var rule := def.loadout if def.loadout != null else pool.loadout
	if rule == null:
		rule = EnemyLoadout.new()
	var size := def.board if def.board != Vector2i.ZERO else (tier.board if tier != null else Vector2i(4, 3))
	var count := rng.randi_range(tier.item_count.x, tier.item_count.y) if tier != null else 2
	var cap := rarity_cap_of(rule, tier)
	var picks := choose_items(def, rule, items, count, rng, cap)
	_sort_big_first(picks, items)

	var board := GridInventory.new(size, 0, false)
	var placed: Array = []
	for item_id in picks:
		_try_place(board, items.get_def(item_id), placed)
	# 放不下就换一件：从同一批候选里按小到大补（同样大的随机排），小件总有地方塞。
	# 只有棋盘真的满了才会差件数，回报里看得见 —— 那是档位表的棋盘配小了
	if placed.size() < count:
		var refill := school_items(def.schools, items, cap)
		refill.append_array(common_items(def.schools, rule, items, cap))
		var order := {}
		for id in refill:
			order[id] = [items.get_def(id).shape.cell_count(), rng.randf()]
		refill.sort_custom(func(a: StringName, b: StringName) -> bool:
			return order[a][0] < order[b][0] if order[a][0] != order[b][0] else order[a][1] < order[b][1])
		var tries := 0
		for id in refill:
			if placed.size() >= count or tries >= REFILL_TRIES:
				break
			tries += 1
			_try_place(board, items.get_def(id), placed)
	var content := {
		"enemy": String(def.id),
		"strength": strength,
		"board": [size.x, size.y],
		"items": placed,
	}
	return {"content": content, "dropped": maxi(0, count - placed.size())}


static func _try_place(board: GridInventory, idef: ItemDef, placed: Array) -> bool:
	if idef == null:
		return false
	var inst := ItemInstance.create(idef, 0)
	if not board.try_add(inst, true):
		return false
	placed.append({"id": String(idef.id), "at": [inst.origin.x, inst.origin.y], "rot": inst.rotation})
	return true


## 占格多的先摆；同样大的按 id —— 顺序稳定，摆出来的才可复现
static func _sort_big_first(picks: Array[StringName], items: ItemDatabase) -> void:
	picks.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ca := items.get_def(a).shape.cell_count()
		var cb := items.get_def(b).shape.cell_count()
		return ca > cb if ca != cb else a < b)


## 实际生效的稀有度上限：组装规则与档位各给一个，取小；都不限就是 -1
static func rarity_cap_of(rule: EnemyLoadout, tier: StrengthTier) -> int:
	var a := rule.rarity_cap if rule != null else -1
	var b := tier.rarity_cap if tier != null else -1
	if a < 0:
		return b
	return a if b < 0 else mini(a, b)


## 挑哪几件（还没摆）：招牌先占位，再抽流派道具，剩下的抽通用道具。
## 流派池空了就全从通用池抽，通用池也空了就从流派池补 —— 池子太小不是这里该报的错，导入器会拦
static func choose_items(
	def: EnemyDef, rule: EnemyLoadout, items: ItemDatabase, count: int, rng: RandomNumberGenerator,
	rarity_cap: int = -1
) -> Array[StringName]:
	var picks: Array[StringName] = []
	for sid in def.signature:
		if items.has_def(sid) and picks.size() < count:
			picks.append(sid)
	var school_pool := school_items(def.schools, items, rarity_cap)
	var common_pool := common_items(def.schools, rule, items, rarity_cap)
	var room := count - picks.size()
	var n_school := 0
	if not school_pool.is_empty():
		n_school = clampi(maxi(rule.min_school, roundi(float(count) * rule.school_share)), 0, room)
	if common_pool.is_empty():
		n_school = room if not school_pool.is_empty() else 0
	_draw(picks, school_pool, n_school, rule.allow_repeat, rng)
	var rest := count - picks.size()
	if not common_pool.is_empty():
		_draw(picks, common_pool, rest, rule.allow_repeat, rng)
	elif not school_pool.is_empty():
		_draw(picks, school_pool, rest, rule.allow_repeat, rng)
	if rule.single_faith:
		var faith := _unify_faith(picks, def.signature.size(), items, rng, school_pool, common_pool, def.schools)
		school_pool = _same_faith(school_pool, faith, items)
		common_pool = _same_faith(common_pool, faith, items)
	_ensure_weapons(picks, def.signature.size(), school_pool, common_pool, rule, items, rng)
	return picks


## 一个敌人只信一个神：信仰 = 流派标签里的那个（`faith:xxx`），没有就是招牌 / 抽到的第一件信仰道具的；
## 别的信仰的换成同信仰或无信仰的（先流派池再通用池），换不了就去掉。返回那个信仰标签
static func _unify_faith(
	picks: Array[StringName], fixed: int, items: ItemDatabase, rng: RandomNumberGenerator,
	school_pool: Array[StringName], common_pool: Array[StringName], schools: Array[StringName] = [] as Array[StringName]
) -> StringName:
	var faith := &""
	for s in schools:
		if String(s).begins_with(FaithDef.TAG_PREFIX):
			faith = s
			break
	for id in picks:
		if faith != &"":
			break
		if items.get_def(id).has_faith():
			faith = items.get_def(id).faith_tag()
			break
	if faith == &"":
		return faith
	var subs := _same_faith(school_pool, faith, items) + _same_faith(common_pool, faith, items)
	var i := picks.size() - 1
	while i >= fixed:
		var d := items.get_def(picks[i])
		if d.has_faith() and d.faith_tag() != faith:
			if subs.is_empty():
				picks.remove_at(i)
			else:
				picks[i] = subs[rng.randi_range(0, subs.size() - 1)]
		i -= 1
	return faith


## 池子里和这个信仰合得来的：无信仰的、同信仰的
static func _same_faith(pool: Array[StringName], faith: StringName, items: ItemDatabase) -> Array[StringName]:
	if faith == &"":
		return pool
	var out: Array[StringName] = []
	for id in pool:
		var d := items.get_def(id)
		if not d.has_faith() or d.faith_tag() == faith:
			out.append(id)
	return out


## 至少 min_weapons 件会打的：不够就把末尾的非招牌、非武器换成武器（先流派池，再通用池）
static func _ensure_weapons(
	picks: Array[StringName], fixed: int, school_pool: Array[StringName], common_pool: Array[StringName],
	rule: EnemyLoadout, items: ItemDatabase, rng: RandomNumberGenerator
) -> void:
	if rule.min_weapons <= 0 or rule.weapon_tag == &"":
		return
	var weapons: Array[StringName] = []
	for id in school_pool + common_pool:
		if items.get_def(id).tags.has(rule.weapon_tag) and not weapons.has(id):
			weapons.append(id)
	if weapons.is_empty():
		return
	var have := 0
	for id in picks:
		if items.get_def(id).tags.has(rule.weapon_tag):
			have += 1
	var i := picks.size() - 1
	while have < rule.min_weapons and i >= fixed:
		if not items.get_def(picks[i]).tags.has(rule.weapon_tag):
			picks[i] = weapons[rng.randi_range(0, weapons.size() - 1)]
			have += 1
		i -= 1


## 带任一流派标签的道具（不含包），id 升序 —— 顺序稳定，抽出来的才可复现
static func school_items(schools: Array[StringName], items: ItemDatabase, rarity_cap: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in items.ids():
		var d := items.get_def(id)
		if d == null or d.is_bag or (rarity_cap >= 0 and d.rarity > rarity_cap):
			continue
		if _shares_tag(d.tags, schools):
			out.append(id)
	out.sort()
	return out


## 带通用标签、且不带本敌人任一流派标签的道具（不含包），id 升序
static func common_items(
	schools: Array[StringName], rule: EnemyLoadout, items: ItemDatabase, rarity_cap: int = -1
) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in items.ids():
		var d := items.get_def(id)
		if d == null or d.is_bag or (rarity_cap >= 0 and d.rarity > rarity_cap):
			continue
		if _shares_tag(d.tags, rule.common_tags) and not _shares_tag(d.tags, schools):
			out.append(id)
	out.sort()
	return out


static func _shares_tag(tags: Array[StringName], wanted: Array[StringName]) -> bool:
	for t in tags:
		if wanted.has(t):
			return true
	return false


static func _draw(
	into: Array[StringName], from: Array[StringName], n: int, allow_repeat: bool, rng: RandomNumberGenerator
) -> void:
	if from.is_empty():
		return
	var bag := from.duplicate()
	for i in n:
		if bag.is_empty():
			if not allow_repeat:
				return
			bag = from.duplicate()
		var k := rng.randi_range(0, bag.size() - 1)
		into.append(bag[k])
		if not allow_repeat:
			bag.remove_at(k)
		# 允许重复也不马上把它放回去：同一件连抽三次的敌人太像 bug
		elif bag.size() > 1:
			bag.remove_at(k)
