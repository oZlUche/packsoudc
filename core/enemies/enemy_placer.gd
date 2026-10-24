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
## 165：位置只有相邻组合是「定」的（整组摆、彼此挨着生效），其余散件随机落位；预设图没写位置的件开局由 [method arrange_map] 摆一次。
class_name EnemyPlacer
extends RefCounted


## 给整张图放敌人。返回 {"placed": 放了几个, "skipped": [没挑到人的节点 id],
## "dropped": 补完之后总共还差几件, "short": [差了件的点：{id, enemy, strength, missing}]}
static func fill(
	graph: MapGraph, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase,
	difficulty: int = 0, scale_id: StringName = &"", carry: CarryRule = null, bag_pool: BagPool = null
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
		var built := place_one(n, pool, enemies, items, float(depth.get(id, 0.0)), difficulty, scale_id, rng, {}, carry, bag_pool)
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
	exploration: Dictionary = {}, carry: CarryRule = null, bag_pool: BagPool = null
) -> Dictionary:
	var wanted := wanted_strength(pool, node, depth, difficulty, scale_id, exploration)
	var entry := pick(pool, enemies, node, wanted, rng)
	if entry == null:
		return {}
	return build_content(enemies.enemy(entry.enemy), pool, items, wanted, rng, carry, bag_pool)


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


## 放不下时最多再试几件来补（候选已按小到大排好；试了这么多件还塞不进，就是棋盘 / 包真的满了）
const REFILL_TRIES := 24


## 组装：招牌 → 流派 → 通用，摆上棋盘。包先摆；165：相邻组合（[method auto_groups]）整组先摆、其余散件随机摆（[method _arrange]）；
## 放不下的换一件再试。
## 返回 {"content": Dictionary, "dropped": 补完之后还差几件（战斗道具）, "carry_short": 126 携带品放不下跳过了几件,
## "ungrouped": 165 摆不开、拆成散件的组数}
static func build_content(
	def: EnemyDef, pool: EnemyPool, items: ItemDatabase, strength: int, rng: RandomNumberGenerator,
	carry: CarryRule = null, bag_pool: BagPool = null
) -> Dictionary:
	var tier := pool.tier_of(strength)
	var rule := def.loadout if def.loadout != null else pool.loadout
	if rule == null:
		rule = EnemyLoadout.new()
	var size := def.board if def.board != Vector2i.ZERO else (tier.board if tier != null else Vector2i(4, 3))
	var count := rng.randi_range(tier.item_count.x, tier.item_count.y) if tier != null else 2
	if def.is_wild():
		count = maxi(count, def.signature_at(strength).size())     # 212：魔兽的招牌是它的器官，一件不少；档位多出来的再补
	var cap := rarity_cap_of(rule, tier)
	var build := pick_build(def, rule, strength, rng)
	var picks := choose_items(def, rule, items, count, rng, cap, strength, build)
	count = maxi(count, picks.size())     # 211：套路是设计者写的，比档位件数长也全带上
	_sort_big_first(picks, items)
	# 摆的是草稿实例（内容只记 id 与位置），uid 计数原样还回去 —— 摆几次、重来几次都不影响之后的编号
	var uid_mark := ItemInstance._next_uid

	# 084：敌人也背包 —— 先摆包（档位的，敌人自己的覆盖），道具只能摆进包里（棋盘 requires_bag，和玩家一样）
	var bag_ids: Array[StringName] = def.bags if not def.bags.is_empty() else (tier.bags if tier != null else [] as Array[StringName])
	if def.bagless:
		bag_ids = [] as Array[StringName]     # 212：魔兽没有包，器官直接摆
	var rolled := not def.bagless and bag_ids.is_empty() and tier != null
	var brng := RandomNumberGenerator.new()
	if rolled:
		# 209：没写死就从包池抽（随机数另起一条，不消耗主随机数）；够装下挑好的东西为止
		brng.seed = hash([rng.state, String(def.id), strength, "bags"])
	var bpool := bag_pool if bag_pool != null else BagPool.standard()
	# 包里地方有限：招牌与流派道具（会打的那几件）先摆，护甲补给后摆 —— 不然一件 2×2 的甲先占了包，1×3 的剑就横竖都塞不进（084）
	# 143：招牌再排在流派道具前面 —— 异形装备大了，同样大的流派道具（按 id 排）先占了唯一放得下的包，招牌就塞不进了
	# 211：套路骨架紧跟招牌 —— 设计者写的组合先占地方，抽来的件放不下再换
	var signature: Array[StringName] = []
	var skeleton: Array[StringName] = []
	var first: Array[StringName] = []
	var later: Array[StringName] = []
	var sig := def.signature_at(strength)
	var bone: Array[StringName] = []
	if build != null:
		bone.assign(build.items)
	for item_id in picks:
		var idef := items.get_def(item_id)
		if idef == null:
			continue
		if sig.has(item_id):
			signature.append(item_id)
		elif bone.has(item_id):
			bone.erase(item_id)
			skeleton.append(item_id)
		elif _shares_tag(idef.tags, def.schools):
			first.append(item_id)
		else:
			later.append(item_id)
	var order: Array[StringName] = signature + skeleton + first + later
	var defs: Array[ItemDef] = []
	for id in order:
		defs.append(items.get_def(id))
	# 211：`loose` 的套路整盘不成组 —— 摆成散件（「学徒把晶石放错了地方」）
	var groups: Array = [] if build != null and build.loose else auto_groups(order, items, rng, def)
	# 209：抽来的包摆不下招牌或唯一的武器，就重抽一套包（最多 [constant BAG_ROLLS] 次，取差得最少的那套）
	var board: GridInventory
	var placed: Array = []
	var got := {}
	var bag_count := 0
	var best_miss := -1
	for attempt in (BAG_ROLLS if rolled else 1):
		var ids: Array[StringName] = roll_enemy_bags(tier, picks, items, bpool, cap, brng) if rolled else bag_ids
		var b := GridInventory.new(size, 0, not ids.is_empty())
		var p: Array = []
		for bag_id in ids:
			var bdef := items.get_def(bag_id)
			if bdef != null and bdef.is_bag:
				_try_place(b, bdef, p)
		var n_bags := p.size()
		# 165：相邻组合整组摆、散件随机摆（顺序仍是招牌 → 流派 → 其余：散件按这个先后挑位置）
		var g := _arrange(b, defs, groups, rng)
		var miss := _arrange_miss(g["left"], defs, sig)
		if best_miss < 0 or miss < best_miss:
			board = b
			placed = p
			placed.append_array(g["placed"])
			got = g
			bag_count = n_bags
			best_miss = miss
		if best_miss == 0:
			break
	count += bag_count     # 包不计入件数：件数说的是包里的东西
	# 放不下就换一件：从同一批候选里按小到大补（同样大的随机排），小件总有地方塞。流派道具不够先补流派的。
	# 只有棋盘真的满了才会差件数，回报里看得见 —— 那是档位表的棋盘 / 包配小了
	if placed.size() < count:
		var school_pool := school_items(def.schools, items, cap, def)
		var refill: Array[StringName] = []
		if _school_count(placed, items, def.schools) < rule.min_school:
			refill.append_array(_small_first(school_pool, items, rng))
		var general := school_pool.duplicate()
		general.append_array(common_items(def.schools, rule, items, cap, def))
		refill.append_array(_small_first(general, items, rng))
		var tries := 0
		for id in refill:
			if placed.size() >= count or tries >= REFILL_TRIES:
				break
			tries += 1
			_place_random(board, items.get_def(id), placed, rng)
	# 126：战斗道具摆完再摆携带品（非战斗道具，越值钱越少见）—— 同一块棋盘 / 同一些包，小件先摆，放不下的跳过（计入差件）。
	# 随机数另起一条（由主随机数的当前状态派生、不消耗它）：加不加携带规则，敌人本身与战斗道具都不变
	var carry_short := 0
	if carry != null and not def.is_wild():     # 212：魔兽 / 机关不揣金器
		var crng := RandomNumberGenerator.new()
		crng.seed = hash([rng.state, String(def.id), strength, "carry"])
		var carried := carry.roll(items, strength, cap, crng, def.carry_mult)
		for id in _small_first(carried, items, crng):
			if _place_random(board, items.get_def(id), placed, crng):
				(placed[placed.size() - 1] as Dictionary)["carried"] = true
			else:
				carry_short += 1
	elif def.is_wild() and not def.loot_filler.is_empty():
		# 210：机关不揣携带品，改为必带 1～2 件替身（齿轮），同样标 carried 必掉；随机数同样另起一条
		var frng := RandomNumberGenerator.new()
		frng.seed = hash([rng.state, String(def.id), strength, "filler"])
		for i in frng.randi_range(1, 2):
			var fid: StringName = def.loot_filler[frng.randi_range(0, def.loot_filler.size() - 1)]
			if _place_random(board, items.get_def(fid), placed, frng):
				(placed[placed.size() - 1] as Dictionary)["carried"] = true
			else:
				carry_short += 1
	ItemInstance._next_uid = uid_mark
	var content := {
		"enemy": String(def.id),
		"strength": strength,
		"board": [size.x, size.y],
		"items": placed,
	}
	if build != null:
		content["build"] = String(build.id)     # 211：回放 / 测试看得见，不进玩家可见的摘要
	if def.is_wild():
		content["wild"] = true     # 212：棋盘上的道具是魔兽持有的那一面（悬浮窗按它写，[constant EnemyKit.WILD_META]）
	return {"content": content, "dropped": maxi(0, count - (placed.size() - _carried_count(placed))), "carry_short": carry_short,
		"ungrouped": int(got["ungrouped"])}


## 209：敌人开战背的包 —— 从包池按权重抽 [member StrengthTier.bag_count] 个（稀有度 ≤ [param rarity_cap]；只收某些标签的包，
## 挑好的东西里得有它收的才进候选）。两条兜底，各最多多补 [constant BAG_TOPUP] 个：最大的那件得有一个包放得下（看外框），
## 包的格数得够装 [param picks] / [member BagPool.fill_target]。大的排前面（先摆）
const BAG_TOPUP := 2
const BAG_ROLLS := 6


## 一盘摆下来差多少：差一件招牌记 100、差了唯一的武器记 10、其余每件记 1（越小越好，0 = 全摆上）
static func _arrange_miss(left: Array, defs: Array[ItemDef], sig: Array[StringName]) -> int:
	var miss := 0
	var armed := false
	var had_weapon := false
	for i in defs.size():
		var d := defs[i]
		if d == null:
			continue
		var is_weapon := d.tags.has(&"weapon")
		had_weapon = had_weapon or is_weapon
		if not left.has(i):
			armed = armed or is_weapon
			continue
		miss += 100 if sig.has(d.id) else 1
	if had_weapon and not armed:
		miss += 10
	return miss

static func roll_enemy_bags(
	tier: StrengthTier, picks: Array[StringName], items: ItemDatabase, bag_pool: BagPool, rarity_cap: int, rng: RandomNumberGenerator
) -> Array[StringName]:
	var out: Array[StringName] = []
	if bag_pool == null or tier == null:
		return out
	var cands: Array[BagPoolEntry] = []
	for e in bag_pool.candidates(items, rarity_cap):
		if _bag_takes_any(items.get_def(e.bag), picks, items):
			cands.append(e)
	if cands.is_empty():
		return out
	var n := rng.randi_range(maxi(0, tier.bag_count.x), maxi(tier.bag_count.x, tier.bag_count.y))
	for i in n:
		out.append(BagPool.pick(cands, rng))
	# 最大的那件（外框最长边）要有个包放得下
	var biggest: ItemDef = null
	for id in picks:
		var d := items.get_def(id)
		if d != null and d.shape != null and (biggest == null or _long_side(d) > _long_side(biggest)):
			biggest = d
	if biggest != null and not out.any(func(b): return bag_fits(items.get_def(b), biggest)):
		var fitting: Array[BagPoolEntry] = []
		for e in cands:
			if bag_fits(items.get_def(e.bag), biggest):
				fitting.append(e)
		if not fitting.is_empty():
			out.append(BagPool.pick(fitting, rng))
	var room := 0
	for id in out:
		room += items.get_def(id).cell_count()
	var want := ceili(float(_cells_of_ids(picks, items)) / maxf(0.01, bag_pool.fill_target))
	var extra := 0
	while room < want and extra < BAG_TOPUP:
		var id := BagPool.pick(cands, rng)
		out.append(id)
		room += items.get_def(id).cell_count()
		extra += 1
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ca := items.get_def(a).cell_count()
		var cb := items.get_def(b).cell_count()
		return ca > cb or (ca == cb and String(a) < String(b)))
	return out


## 包收不收得下 [param picks] 里的任何一件（不限标签的包都收）
static func _bag_takes_any(bag: ItemDef, picks: Array[StringName], items: ItemDatabase) -> bool:
	if bag == null or bag.bag_accept_tags.is_empty():
		return bag != null
	for id in picks:
		var d := items.get_def(id)
		if d != null and bag.bag_accept_tags.any(func(t): return d.tags.has(t)):
			return true
	return false


static func _long_side(d: ItemDef) -> int:
	var sz := d.shape.size_rotated(0)
	return maxi(sz.x, sz.y)


## 包（矩形）的外框装得下这件的外框（可转 90°），而且不限标签或收它
static func bag_fits(bag: ItemDef, d: ItemDef) -> bool:
	if bag == null or bag.shape == null or d.shape == null:
		return false
	if not bag.bag_accept_tags.is_empty() and not bag.bag_accept_tags.any(func(t): return d.tags.has(t)):
		return false
	var b := bag.shape.size_rotated(0)
	var s := d.shape.size_rotated(0)
	return (b.x >= s.x and b.y >= s.y) or (b.x >= s.y and b.y >= s.x)


## 一串道具 id 一共占几格
static func _cells_of_ids(ids: Array[StringName], items: ItemDatabase) -> int:
	var n := 0
	for id in ids:
		var d := items.get_def(id)
		if d != null:
			n += d.cell_count()
	return n


## 126：已摆上的里有几件是携带品
static func _carried_count(placed: Array) -> int:
	var n := 0
	for raw in placed:
		if bool((raw as Dictionary).get("carried", false)):
			n += 1
	return n


## 已摆上的里有几件流派道具（不含包）
static func _school_count(placed: Array, items: ItemDatabase, schools: Array[StringName]) -> int:
	var n := 0
	for raw in placed:
		var d := items.get_def(StringName(String((raw as Dictionary).get("id", ""))))
		if d != null and not d.is_bag and _shares_tag(d.tags, schools):
			n += 1
	return n


## 按占格小到大（同样大的随机排），摆得进的概率高的在前
static func _small_first(ids: Array[StringName], items: ItemDatabase, rng: RandomNumberGenerator) -> Array[StringName]:
	var out := ids.duplicate()
	var order := {}
	for id in out:
		order[id] = [items.get_def(id).shape.cell_count(), rng.randf()]
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return order[a][0] < order[b][0] if order[a][0] != order[b][0] else order[a][1] < order[b][1])
	return out


## 第一个放得下的格（包用它：包先贴左上，道具再往包里随机摆）
static func _try_place(board: GridInventory, idef: ItemDef, placed: Array) -> bool:
	if idef == null:
		return false
	var inst := ItemInstance.create(idef, 0)
	if not board.try_add(inst, true):
		return false
	placed.append(_entry(inst))
	return true


## 165：在所有放得下的位置里随机挑一个（补件、携带品）
static func _place_random(board: GridInventory, idef: ItemDef, placed: Array, rng: RandomNumberGenerator) -> bool:
	if idef == null:
		return false
	var fits := _fits(board, idef, false)
	if fits.is_empty():
		return false
	var f: Array = fits[rng.randi_range(0, fits.size() - 1)]
	var inst := ItemInstance.create(idef, int(f[1]))
	if not board.place(inst, f[0], int(f[1])):
		return false
	placed.append(_entry(inst))
	return true


## 内容里的一件：{id, at, rot}
static func _entry(inst: ItemInstance) -> Dictionary:
	return {"id": String(inst.def.id), "at": [inst.origin.x, inst.origin.y], "rot": inst.rotation}


## 占格多的先摆；同样大的按 id 的**文本** —— 顺序稳定，摆出来的才可复现。
##
## 这里不能写 `a < b`：`StringName` 比的是内部指针（见 [Ids]），那是「这个名字在进程里第几次出现」。
## 长弓和赐福的长弓都是 4 格，谁先摆就由它决定；加一个无关的脚本就能让神射手的招牌换成普通长弓
static func _sort_big_first(picks: Array[StringName], items: ItemDatabase) -> void:
	picks.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ca := items.get_def(a).shape.cell_count()
		var cb := items.get_def(b).shape.cell_count()
		return ca > cb if ca != cb else String(a) < String(b))


## 实际生效的稀有度上限：组装规则与档位各给一个，取小；都不限就是 -1
static func rarity_cap_of(rule: EnemyLoadout, tier: StrengthTier) -> int:
	var a := rule.rarity_cap if rule != null else -1
	var b := tier.rarity_cap if tier != null else -1
	if a < 0:
		return b
	return a if b < 0 else mini(a, b)


## 211：这一档掷不掷套路、掷哪套。随机数另起一条（由主随机数的当前状态派生、不消耗它）：没写套路、或没掷中，敌人与老路一模一样。
## 没掷中 / 这一档没有可用的套路返回 null
static func pick_build(def: EnemyDef, rule: EnemyLoadout, strength: int, rng: RandomNumberGenerator) -> EnemyBuild:
	var cands := def.builds_at(strength)
	if cands.is_empty() or rule == null or rule.build_chance <= 0.0:
		return null
	var brng := RandomNumberGenerator.new()
	brng.seed = hash([rng.state, String(def.id), strength, "build"])
	if brng.randf() >= rule.build_chance:
		return null
	var weights: Array[float] = []
	var total := 0.0
	for b in cands:
		var w := build_weight(b, rule, strength)
		weights.append(w)
		total += w
	if total <= 0.0:
		return null
	var r := brng.randf() * total
	for i in cands.size():
		r -= weights[i]
		if r <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


## 211：一套在这一档的抽取权重：坏套路乘 bad_build_mult，档位 ≥ 2 再乘一次
static func build_weight(b: EnemyBuild, rule: EnemyLoadout, strength: int) -> float:
	var w := b.weight
	if b.is_bad():
		w *= rule.bad_build_mult
		if strength >= 2:
			w *= rule.bad_build_mult
	return maxf(0.0, w)


## 挑哪几件（还没摆）：招牌先占位（含这一档的招牌，087），再抽流派道具，剩下的抽通用道具。
## 211：给了套路 [param build] 就招牌之后先放它的骨架（不受稀有度上限约束，导入器 warn），余数照抽；骨架和招牌一样不被信仰统一 / 保底武器换掉；
## 坏套路不补保底武器（「根本不成套」）
## 流派池空了就全从通用池抽，通用池也空了就从流派池补 —— 池子太小不是这里该报的错，导入器会拦。
## 087：两个池子都先过身份标签（[method EnemyDef.allows_item]）—— 神射手只在弓箭里抽
static func choose_items(
	def: EnemyDef, rule: EnemyLoadout, items: ItemDatabase, count: int, rng: RandomNumberGenerator,
	rarity_cap: int = -1, strength: int = -1, build: EnemyBuild = null
) -> Array[StringName]:
	var picks: Array[StringName] = []
	var sig := def.signature_at(strength if strength >= 0 else def.strength)     # 算一次，下面三处共用
	for sid in sig:
		if items.has_def(sid) and picks.size() < count:
			picks.append(sid)
	if build != null:
		for bid in build.items:
			if items.has_def(bid):
				picks.append(bid)
	var fixed := picks.size()     # 招牌 + 套路骨架：后面的信仰统一与保底武器都不动它们
	var school_pool := school_items(def.schools, items, rarity_cap, def)
	var common_pool := common_items(def.schools, rule, items, rarity_cap, def)
	var room := maxi(0, count - picks.size())
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
		var faith := _unify_faith(picks, fixed, items, rng, school_pool, common_pool, def.schools)
		school_pool = _same_faith(school_pool, faith, items)
		common_pool = _same_faith(common_pool, faith, items)
	if build == null or not build.is_bad():
		_ensure_weapons(picks, fixed, school_pool, common_pool, rule, items, rng)
	return picks


## 一个敌人只信一个神：信仰 = 流派标签里的那个（`faith:xxx`），没有就是招牌 / 抽到的第一件信仰道具的；
## 别的信仰的换成同信仰或无信仰的（先流派池再通用池），换不了就去掉。返回那个信仰标签
static func _unify_faith(
	picks: Array[StringName], fixed: int, items: ItemDatabase, rng: RandomNumberGenerator,
	school_pool: Array[StringName], common_pool: Array[StringName], schools: Array[StringName] = [] as Array[StringName]
) -> StringName:
	var faith := &""
	for s in schools:
		if String(s).begins_with(FaithTags.PREFIX):
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


## 带任一流派标签的道具（不含包），id 升序 —— 顺序稳定，抽出来的才可复现。[param who] 给了就再过它的身份标签（087）
static func school_items(schools: Array[StringName], items: ItemDatabase, rarity_cap: int, who: EnemyDef = null) -> Array[StringName]:
	return _item_pool(items, rarity_cap, who, func(d: ItemDef) -> bool: return _shares_tag(d.tags, schools))


## 带通用标签、且不带本敌人任一流派标签的道具（不含包），id 升序。[param who] 给了就再过它的身份标签（087）
static func common_items(
	schools: Array[StringName], rule: EnemyLoadout, items: ItemDatabase, rarity_cap: int = -1, who: EnemyDef = null
) -> Array[StringName]:
	return _item_pool(items, rarity_cap, who,
		func(d: ItemDef) -> bool: return _shares_tag(d.tags, rule.common_tags) and not _shares_tag(d.tags, schools))


## 两个池子共用的筛选：能生成的道具里去掉包（160：随身技能不是道具，本来就不在库里）、过稀有度上限与身份标签（087），再过 [param pred]；id 按文本升序
static func _item_pool(items: ItemDatabase, rarity_cap: int, who: EnemyDef, pred: Callable) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in items.ids():
		var d := items.get_def(id)
		if d == null or d.is_bag or d.is_bullion() or (rarity_cap >= 0 and d.rarity > rarity_cap):     # 244：金银不进敌人的装备
			continue
		if who != null and not who.allows_item(d):
			continue
		if pred.call(d):
			out.append(id)
	Ids.sort(out)     # 按文本排，不是 StringName 的指针序（见 [Ids]）
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


#region 165：相邻组合整组摆、散件随机摆
## 散件有放不下（或组拆了）就整盘重来，最多几次（每次随机数接着用）；都不行再按「整理」那样贴左上摆一遍，还不行按老办法，取摆得最好的
const ARRANGE_TRIES := 4


## 从挑出的道具里**推**相邻组合（2.3）：先认 [member EnemyDef.combos]（这几件都在就成一组、不再参与自动配对），
## 再给每件「给得出东西」的道具（增益格的 / 站在别人受益格上有东西给的）在同一批里找一件收得下的，配成一对；
## 连在一起的对并成一组（长弓上面一袋箭、右边一个护符，三件一组）。找不到对象的照旧是散件。
## 返回组的列表，每组是 [param picks] 的下标，第一件是锚（组里占格最多的）、后面每件都和前面某件配过对
static func auto_groups(
	picks: Array[StringName], items: ItemDatabase, rng: RandomNumberGenerator, who: EnemyDef = null
) -> Array:
	var defs: Array[ItemDef] = []
	for id in picks:
		defs.append(items.get_def(id))
	var groups: Array = []
	var taken := {}
	if who != null:
		for combo in who.combo_list():
			var idxs: Array[int] = []
			for id in combo:
				for i in defs.size():
					if not taken.has(i) and not idxs.has(i) and picks[i] == id:
						idxs.append(i)
						break
			if idxs.size() == (combo as Array).size():
				for i in idxs:
					taken[i] = true
				groups.append(idxs)
	# 自动配对：每件给得出东西的配一个收得下的（多个候选随机挑）；按下标走，结果只看 picks 与随机数
	var edges := {}     # i -> [j, ...]（无向）
	for i in defs.size():
		if taken.has(i) or not _pairable(defs[i]):
			continue
		var cands: Array[int] = []
		for j in defs.size():
			if j != i and not taken.has(j) and _pairable(defs[j]) and _gives(defs[i], defs[j]):
				cands.append(j)
		if cands.is_empty():
			continue
		var j := cands[rng.randi_range(0, cands.size() - 1)]
		if not edges.has(i):
			edges[i] = []
		if not edges.has(j):
			edges[j] = []
		(edges[i] as Array).append(j)
		(edges[j] as Array).append(i)
	var seen := {}
	for i in defs.size():
		if not edges.has(i) or seen.has(i):
			continue
		# 一个连通块：先收齐，锚 = 占格最多的（同样大取下标小的），再从锚起按宽度优先排 —— 每件都挨着前面配过对的那件
		var comp: Array[int] = []
		var stack: Array[int] = [i]
		seen[i] = true
		while not stack.is_empty():
			var k: int = stack.pop_back()
			comp.append(k)
			for nb in edges[k]:
				if not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
		comp.sort()
		var anchor := comp[0]
		for k in comp:
			if defs[k].shape.cell_count() > defs[anchor].shape.cell_count():
				anchor = k
		var ordered: Array[int] = [anchor]
		var at := 0
		while at < ordered.size():
			var nbs: Array = (edges[ordered[at]] as Array).duplicate()
			nbs.sort()
			for nb in nbs:
				if not ordered.has(nb):
					ordered.append(nb)
			at += 1
		groups.append(ordered)
	return groups


## 能不能进相邻组合：有形状、不是包
static func _pairable(d: ItemDef) -> bool:
	return d != null and d.shape != null and not d.is_bag


## [param g] 挨着 [param r] 时给不给得出东西（不看位置）：g 的增益格收 r；或者 r 的受益格收 g（r 本身有受益加成）；或者 r 的装载格收 g（g 站上去有供给给 r，148 / 171）
static func _gives(g: ItemDef, r: ItemDef) -> bool:
	var ga := g.adjacency
	if ga != null and ga.has_grant() and ga.grant_accepts(r):
		return true
	return _receives_from(r, g) or _loads_from(r, g)


## [param r] 的受益格收不收 [param g]
static func _receives_from(r: ItemDef, g: ItemDef) -> bool:
	var ra := r.adjacency
	return ra != null and ra.has_receive() and AdjacencyProfile.accepts(ra.receive_filter, g)


## 171：[param r] 的装载格装不装 [param g]（g 有供给、互相接受）
static func _loads_from(r: ItemDef, g: ItemDef) -> bool:
	var ra := r.adjacency
	if ra == null or not ra.has_load() or not AdjacencyProfile.accepts(ra.load_tags(), g):
		return false
	var ga := g.adjacency
	return ga != null and ga.has_feed() and AdjacencyProfile.accepts(ga.feed_filter, r)


## 在已经摆好包（与钉死件）的棋盘上摆 [param defs]：组（[param groups]，每组是 defs 的下标，第一件为锚）占格大的先，
## 再摆散件（按 defs 的先后），都在放得下的位置里**随机挑**。[param fixed]：下标 → [相对锚点的格, 朝向]（预设图写死的组内位置）；
## 组里有没写的就按相邻关系现搭。散件有放不下、或者组摆不开拆了，就整盘重来（最多 [constant ARRANGE_TRIES] 次）；
## 还不行就同样的步骤不随机、每件取第一个放得下的格（「整理」那样贴左上，地方最省）再摆一遍；
## 还差件就按老办法（按 defs 的先后逐件第一个放得下的格、不成组）摆一遍。取摆上件数最多、拆的组最少的 —— 件数不会比 165 之前少。
## 结果留在 [param board] 上。返回 {"placed": [{id, at, rot}]（按 defs 的先后）, "left": [没摆上的下标], "ungrouped": 拆散的组数}
static func _arrange(
	board: GridInventory, defs: Array[ItemDef], groups: Array, rng: RandomNumberGenerator, fixed: Dictionary = {}
) -> Dictionary:
	var best := {}
	for attempt in ARRANGE_TRIES:
		best = _better(best, _attempt(board, defs, groups, rng, fixed))
		if _perfect(best):
			break
	if not _perfect(best):
		best = _better(best, _attempt(board, defs, groups, null, fixed))
	if not (best["left"] as Array).is_empty():
		var plain := _attempt_first_fit(board, defs)
		if (plain["left"] as Array).size() < (best["left"] as Array).size():
			best = plain
	# 选中的那一盘落到棋盘上（每一盘试完都撤干净了）
	var placed: Array = []
	var spots: Dictionary = best["spots"]
	for i in defs.size():
		if not spots.has(i):
			continue
		var inst := ItemInstance.create(defs[i], int(spots[i][1]))
		if board.place(inst, spots[i][0], int(spots[i][1])):
			placed.append(_entry(inst))
	return {"placed": placed, "left": best["left"], "ungrouped": int(best["ungrouped"])}


## 一件不差、组都没拆
static func _perfect(got: Dictionary) -> bool:
	return (got["left"] as Array).is_empty() and int(got["ungrouped"]) == 0


## 摆上的多的好；一样多拆的组少的好；都一样留先来的
static func _better(best: Dictionary, got: Dictionary) -> Dictionary:
	if best.is_empty():
		return got
	var a := (best["left"] as Array).size()
	var b := (got["left"] as Array).size()
	if b != a:
		return got if b < a else best
	return got if int(got["ungrouped"]) < int(best["ungrouped"]) else best


## 从候选里挑一个：有随机数随机挑，没有（「整理」那一盘）取第一个
static func _pick(opts: Array, rng: RandomNumberGenerator) -> Array:
	return opts[rng.randi_range(0, opts.size() - 1)] if rng != null else opts[0]


## 摆一盘：组先、散件后（[param rng] 为 null 时每件取第一个放得下的格）。摆完记下每件的落点，再从棋盘上撤掉
static func _attempt(
	board: GridInventory, defs: Array[ItemDef], groups: Array, rng: RandomNumberGenerator, fixed: Dictionary
) -> Dictionary:
	var insts := {}     # 下标 -> ItemInstance
	var in_group := {}
	var loose: Array[int] = []
	var ungrouped := 0
	var by_size: Array = groups.duplicate()
	by_size.sort_custom(func(a: Array, b: Array) -> bool:
		var ca := _cells_of(defs, a)
		var cb := _cells_of(defs, b)
		return ca > cb if ca != cb else int(a[0]) < int(b[0]))
	for g in by_size:
		for i in g:
			in_group[int(i)] = true
		if not _place_group(board, defs, g, rng, fixed, insts):
			ungrouped += 1
			for i in g:
				loose.append(int(i))
	for i in defs.size():
		if not in_group.has(i) and defs[i] != null:
			loose.append(i)
	loose.sort()
	var left: Array[int] = []
	for i in loose:
		var fits := _fits(board, defs[i], false)
		if fits.is_empty():
			left.append(i)
			continue
		_put(board, defs[i], _pick(fits, rng), insts, i)
	return _take_back(board, insts, left, ungrouped)


## 老办法（165 之前）：按 defs 的先后逐件放第一个放得下的格，不成组
static func _attempt_first_fit(board: GridInventory, defs: Array[ItemDef]) -> Dictionary:
	var insts := {}
	var left: Array[int] = []
	for i in defs.size():
		if defs[i] == null:
			continue
		var inst := ItemInstance.create(defs[i], 0)
		if board.try_add(inst, true):
			insts[i] = inst
		else:
			left.append(i)
	return _take_back(board, insts, left, 0)


## 记下这一盘每件的落点，从棋盘上撤掉
static func _take_back(board: GridInventory, insts: Dictionary, left: Array[int], ungrouped: int) -> Dictionary:
	var spots := {}
	for i in insts:
		var inst: ItemInstance = insts[i]
		spots[i] = [inst.origin, inst.rotation]
		board.remove(inst.uid)
	return {"spots": spots, "left": left, "ungrouped": ungrouped}


static func _cells_of(defs: Array[ItemDef], g: Array) -> int:
	var n := 0
	for i in g:
		n += defs[int(i)].shape.cell_count()
	return n


static func _put(board: GridInventory, def: ItemDef, f: Array, insts: Dictionary, i: int) -> ItemInstance:
	var inst := ItemInstance.create(def, int(f[1]))
	if not board.place(inst, f[0], int(f[1])):
		return null
	insts[i] = inst
	return inst


## 这件道具在棋盘上所有放得下的 [origin, rot]（行优先）。[param all_rots]：四个朝向都试 —— 组里的件要它，
## 形状对称、相邻格不对称（箭的增益格朝上）时朝向也算数；散件只试看得出区别的朝向
static func _fits(board: GridInventory, def: ItemDef, all_rots: bool) -> Array:
	var out: Array = []
	if def == null or def.shape == null or not board.accepts(def):
		return out
	var rots := 4 if all_rots and def.adjacency != null else def.shape.distinct_rotation_count()
	for rot in rots:
		var sz := def.shape.size_rotated(rot)
		for y in range(0, board.size.y - sz.y + 1):
			for x in range(0, board.size.x - sz.x + 1):
				var o := Vector2i(x, y)
				if board.can_place_def(def, o, rot):
					out.append([o, rot])
	return out


## 摆一个组：写死了组内位置的整组当刚体（四个朝向）找落点；没写的从锚起现搭 —— 每件都要和组里已摆的某件真的挨着生效。
## 摆上了写进 [param insts]；摆不开返回 false，棋盘原样
static func _place_group(
	board: GridInventory, defs: Array[ItemDef], g: Array, rng: RandomNumberGenerator, fixed: Dictionary, insts: Dictionary
) -> bool:
	var all_fixed := true
	for i in g:
		if not fixed.has(int(i)):
			all_fixed = false
	if all_fixed:
		return _place_rigid(board, defs, g, rng, fixed, insts)
	var anchor := int(g[0])
	var starts := _fits(board, defs[anchor], true)
	if rng != null:
		_shuffle(starts, rng)
	for s in starts:
		var mine: Array[ItemInstance] = []
		var a := _put(board, defs[anchor], s, insts, anchor)
		if a == null:
			continue
		mine.append(a)
		var ok := true
		for k in range(1, g.size()):
			var i := int(g[k])
			var touch := not _pairs_any(defs[i], mine)
			var opts: Array = []
			for f in _fits(board, defs[i], true):
				if _links(defs[i], f[0], int(f[1]), mine, touch):
					opts.append(f)
			if opts.is_empty():
				ok = false
				break
			var m := _put(board, defs[i], _pick(opts, rng), insts, i)
			if m == null:
				ok = false
				break
			mine.append(m)
		if ok:
			return true
		for k in g:
			var inst: ItemInstance = insts.get(int(k), null)
			if inst != null:
				board.remove(inst.uid)
				insts.erase(int(k))
	return false


## 写死了组内位置的组：整组转四个朝向、在棋盘上找所有放得下的锚点，随机挑一个
static func _place_rigid(
	board: GridInventory, defs: Array[ItemDef], g: Array, rng: RandomNumberGenerator, fixed: Dictionary, insts: Dictionary
) -> bool:
	var cands: Array = []     # [[每件的 [origin, rot]], ...]
	for turn in 4:
		var layout := _turn_group(defs, g, fixed, turn)
		if layout.is_empty():
			return false     # 组内自己压着自己：写错了，当散件
		var span := Vector2i.ZERO
		for k in g.size():
			var d := defs[int(g[k])]
			span = Vector2i(maxi(span.x, (layout[k][0] as Vector2i).x + d.shape.size_rotated(int(layout[k][1])).x),
				maxi(span.y, (layout[k][0] as Vector2i).y + d.shape.size_rotated(int(layout[k][1])).y))
		for y in range(0, board.size.y - span.y + 1):
			for x in range(0, board.size.x - span.x + 1):
				var o := Vector2i(x, y)
				var ok := true
				for k in g.size():
					if not board.can_place_def(defs[int(g[k])], o + layout[k][0], int(layout[k][1])):
						ok = false
						break
				if ok:
					var spots: Array = []
					for k in g.size():
						spots.append([o + layout[k][0], int(layout[k][1])])
					cands.append(spots)
	if cands.is_empty():
		return false
	var pick := _pick(cands, rng)
	for k in g.size():
		_put(board, defs[int(g[k])], pick[k], insts, int(g[k]))
	return true


## 组转 [param turn] 个 90°（顺时针）之后每件的 [相对整组左上角的 origin, rot]；组内有重叠返回空。
## 整组的格子一起转、再整体平移回左上 —— 每件的格子转完的最小角就是它新的 origin，形状正是 cells_rotated(rot + turn)（[ItemShape] 同一套规范化），
## 相邻格也跟着转（[method ItemShape.transform_point]），所以组内谁挨着谁转完不变
static func _turn_group(defs: Array[ItemDef], g: Array, fixed: Dictionary, turn: int) -> Array:
	var per: Array = []
	var seen := {}
	var lo := Vector2i(1 << 20, 1 << 20)
	for i in g:
		var d := defs[int(i)]
		var at: Vector2i = fixed[int(i)][0]
		var rot := int(fixed[int(i)][1])
		var cells: Array[Vector2i] = []
		for c in d.cells_rotated(rot):
			var p := at + c
			for t in turn:
				p = Vector2i(-p.y, p.x)
			if seen.has(p):
				return []
			seen[p] = true
			cells.append(p)
		var m := ItemShape.min_of(cells)
		lo = Vector2i(mini(lo.x, m.x), mini(lo.y, m.y))
		per.append([m, rot + turn])
	for e in per:
		e[0] = (e[0] as Vector2i) - lo
		e[1] = posmod(int(e[1]), 4)
	return per


## [param def] 和组里已摆的哪件有相邻关系可言（不看位置）。都没有 = 这组是作者硬配的（[member EnemyDef.combos]），挨着就行
static func _pairs_any(def: ItemDef, mine: Array[ItemInstance]) -> bool:
	for m in mine:
		if _gives(def, m.def) or _gives(m.def, def):
			return true
	return false


## [param def] 摆在 (origin, rot) 时，和组里已摆的某件真的挨着生效（谁给谁都算）；[param touch]：挨着边就算
static func _links(def: ItemDef, origin: Vector2i, rot: int, mine: Array[ItemInstance], touch: bool) -> bool:
	for m in mine:
		if _gives_at(def, origin, rot, m.def, m.origin, m.rotation) or _gives_at(m.def, m.origin, m.rotation, def, origin, rot):
			return true
		if touch and _touching(def.cells_rotated(rot), origin, m):
			return true
	return false


## g 摆在 (go, gr)、r 摆在 (ro, rr) 时 g 给不给得到 r：g 的增益格压在 r 身上，或 r 的受益格压在 g 身上（同编译器的点亮规则）
static func _gives_at(g: ItemDef, go: Vector2i, gr: int, r: ItemDef, ro: Vector2i, rr: int) -> bool:
	var ga := g.adjacency
	if ga != null and ga.has_grant() and ga.grant_accepts(r):
		var r_cells := _cell_set(r.cells_rotated(rr), ro)
		for p in ga.grant_cells:
			if r_cells.has(go + g.shape.transform_point(p, gr)):
				return true
	for pair in [[_receives_from(r, g), "receive_cells"], [_loads_from(r, g), "load_cells"]]:
		if not pair[0]:
			continue
		var g_cells := _cell_set(g.cells_rotated(gr), go)
		for p in r.adjacency.get(pair[1]):
			if g_cells.has(ro + r.shape.transform_point(p, rr)):
				return true
	return false


static func _touching(cells: Array[Vector2i], origin: Vector2i, m: ItemInstance) -> bool:
	var theirs := _cell_set(m.cells(), m.origin)
	for c in cells:
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if theirs.has(origin + c + d):
				return true
	return false


static func _cell_set(cells: Array[Vector2i], origin: Vector2i) -> Dictionary:
	var out := {}
	for c in cells:
		out[origin + c] = true
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
#endregion


#region 165：节点内容摆一次（预设图）
## 这份内容要不要摆：有敌人，且有没写位置的件或者写了组
static func needs_arrange(content: Dictionary) -> bool:
	if not EnemyKit.has_enemy(content):
		return false
	if not (content.get("groups", []) as Array).is_empty():
		return true
	for raw in content.get("items", []):
		if raw is Dictionary and not (raw as Dictionary).has("at"):
			return true
	return false


## 节点内容里没写 `at` 的件随机摆、`groups` 整组摆，位置写回内容（组展开成普通的件，`groups` 删掉）；写了 `at` 的原样钉死。
## 摆一次、记下来：之后的存档、战前、战斗、尸体、掉落都照这份内容重建，和随机图的敌人一样（[method EnemyKit.board_of]）。
## 摆不下的件留在内容里、不带位置（重建时再自己找空位，还不行会告警）。返回 {"left": [摆不下的 id], "ungrouped": 拆散的组数}
static func arrange(content: Dictionary, items: ItemDatabase, rng: RandomNumberGenerator) -> Dictionary:
	var out := {"left": [] as Array[StringName], "ungrouped": 0}
	if not needs_arrange(content) or items == null:
		return out
	var size_raw: Array = content.get("board", [4, 3])
	var size := Vector2i(int(size_raw[0]), int(size_raw[1]))
	var pinned: Array = []     # [def, entry]
	var free: Array = []       # [def, entry]
	var has_bag := false
	for raw in content.get("items", []):
		var entry := (raw as Dictionary).duplicate()
		var d := items.get_def(StringName(String(entry.get("id", ""))))
		if d == null:
			pinned.append([null, entry])     # 认不得的原样留着（内容比道具库新）
			continue
		has_bag = has_bag or d.is_bag
		(pinned if entry.has("at") else free).append([d, entry])
	var group_specs: Array = []     # 每组 [[def, entry], ...]
	for raw in content.get("groups", []):
		var spec: Array = []
		for m in raw:
			var entry := (m as Dictionary).duplicate()
			var d := items.get_def(StringName(String(entry.get("id", ""))))
			if d != null and not d.is_bag:
				spec.append([d, entry])
		if spec.size() >= 2:
			group_specs.append(spec)
		elif spec.size() == 1:
			free.append([spec[0][0], spec[0][1]])
	var uid_mark := ItemInstance._next_uid
	var board := GridInventory.new(size, 0, has_bag)
	var result: Array = []
	# 包先：写了位置的钉在原处，没写的贴左上
	for pass_bags in [true, false]:
		for pair in pinned:
			var d: ItemDef = pair[0]
			if d == null or d.is_bag != pass_bags:
				continue
			var entry: Dictionary = pair[1]
			var at: Array = entry["at"]
			var inst := ItemInstance.create(d, int(entry.get("rot", 0)))
			if board.place(inst, Vector2i(int(at[0]), int(at[1])), int(entry.get("rot", 0))):
				result.append(entry)
			else:
				free.append([d, entry])     # 写的位置摆不下：当没写，下面随机摆
		if pass_bags:
			for pair in free.duplicate():
				var d: ItemDef = pair[0]
				if not d.is_bag:
					continue
				free.erase(pair)
				var placed: Array = []
				if _try_place(board, d, placed):
					result.append(_merge(pair[1], placed[0]))
				else:
					result.append(_unplaced(pair[1]))
					(out["left"] as Array[StringName]).append(d.id)
	# 道具：组 → 散件（散件大件先，同样大按原先后）
	var free_rank := {}
	for k in free.size():
		free_rank[k] = [(free[k][0] as ItemDef).shape.cell_count(), k]
	var free_order: Array = free_rank.keys()
	free_order.sort_custom(func(a: int, b: int) -> bool:
		return free_rank[a][0] > free_rank[b][0] if free_rank[a][0] != free_rank[b][0] else a < b)
	var free_sorted: Array = []
	for k in free_order:
		free_sorted.append(free[k])
	free = free_sorted
	var defs: Array[ItemDef] = []
	var entries: Array = []
	var groups: Array = []
	var fixed := {}
	for spec in group_specs:
		# 组内写了位置的按相对锚点的格记下（锚没写当 [0, 0]）；全写了就整组当刚体摆，有没写的就按相邻关系现搭
		var g: Array[int] = []
		var any_at := false
		for pair in spec:
			any_at = any_at or (pair[1] as Dictionary).has("at")
		var anchor_at := Vector2i.ZERO
		for k in spec.size():
			var entry: Dictionary = spec[k][1]
			var i := defs.size()
			defs.append(spec[k][0])
			entries.append(entry)
			g.append(i)
			if not any_at:
				continue
			var at := Vector2i.ZERO
			if entry.has("at"):
				var a: Array = entry["at"]
				at = Vector2i(int(a[0]), int(a[1]))
			if k == 0:
				anchor_at = at
			if k == 0 or entry.has("at"):
				fixed[i] = [at - anchor_at, int(entry.get("rot", 0))]
		groups.append(g)
	for pair in free:
		if pair[0] == null:
			continue
		defs.append(pair[0])
		entries.append(pair[1])
	for pair in pinned:
		if pair[0] == null:
			result.append(pair[1])
	var got := _arrange(board, defs, groups, rng, fixed)
	ItemInstance._next_uid = uid_mark
	# 写回：按 defs 的先后，摆上了的带位置，摆不下的不带
	var by_index := {}
	var k_placed := 0
	var left_set := {}
	for i in got["left"]:
		left_set[int(i)] = true
	for i in defs.size():
		if left_set.has(i):
			continue
		by_index[i] = (got["placed"] as Array)[k_placed]
		k_placed += 1
	for i in defs.size():
		if by_index.has(i):
			result.append(_merge(entries[i], by_index[i]))
		else:
			result.append(_unplaced(entries[i]))
			(out["left"] as Array[StringName]).append(defs[i].id)
	content["items"] = result
	content.erase("groups")
	out["ungrouped"] = int(got["ungrouped"])
	if not (out["left"] as Array).is_empty():
		push_warning("敌人 %s 的道具摆不下：%s（棋盘 %s）" % [content.get("enemy", "?"), out["left"], size])
	return out


## 一张图上每个要摆的点摆一次（开局时，[RunState]）；随机数用节点自己的 `content_seed` —— 同一张图同一个点永远一样
static func arrange_map(graph: MapGraph, items: ItemDatabase) -> int:
	var n := 0
	if graph == null or items == null:
		return n
	for id in graph.node_ids():
		var node := graph.get_node(id)
		if not needs_arrange(node.content):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = node.content_seed
		arrange(node.content, items, rng)
		n += 1
	return n


## 原条目（可能带别的字段）+ 摆出来的位置
static func _merge(entry: Dictionary, spot: Dictionary) -> Dictionary:
	var out := entry.duplicate()
	out["at"] = spot["at"]
	out["rot"] = spot["rot"]
	return out


static func _unplaced(entry: Dictionary) -> Dictionary:
	var out := entry.duplicate()
	out.erase("at")
	out.erase("rot")
	return out
#endregion
