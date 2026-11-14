## 320 A4（危险敌人）：开局时把一部分普通战斗点换成「本色档位更高」的敌人 —— 道具档位、节点类型、奖励都不变，
## 只是来的是更强的一种（地图预览看得见）。按配额挑，不逐点掷硬币；离入口最近的几场不换；换上的点互不相邻、尽量不重样。
## 池子就是这一章的池（只取本色比想要的高的那些行），没有合适的就留着原来的敌人，记进回报。
class_name AdvancedPool
extends RefCounted

## 换上的点内容里记一笔（预览 / 诊断用）
const KEY := "advanced"


## 先挑普通池够不着的（本色比 [param wanted] 高出容差以上），没有就退一步挑本色比想要的高的；[param avoid] 里的敌人能避就避。没人返回 null
static func pick(
	pool: EnemyPool, enemies: EnemyDatabase, node: MapNode, wanted: int, rng: RandomNumberGenerator, avoid: Array[StringName] = []
) -> EnemyPoolEntry:
	var tol := pool.strength_rule.tolerance if pool.strength_rule != null else 0
	var beyond: Array[EnemyPoolEntry] = []
	var above: Array[EnemyPoolEntry] = []
	for e in pool.entries:
		if e == null or e.weight <= 0.0 or not e.fits(node) or enemies.enemy(e.enemy) == null:
			continue
		var d := enemies.enemy(e.enemy).strength - wanted
		if d > tol:
			beyond.append(e)
		elif d >= 1:
			above.append(e)
	var cands: Array[EnemyPoolEntry] = beyond if not beyond.is_empty() else above
	var fresh: Array[EnemyPoolEntry] = []
	for e in cands:
		if not avoid.has(e.enemy):
			fresh.append(e)
	if not fresh.is_empty():
		cands = fresh
	if cands.is_empty():
		return null
	var weights: Array[float] = []
	for e in cands:
		weights.append(e.weight)
	return cands[MapRng.pick_index(weights, rng)]


## 换。[param share] 是普通战斗点里换掉的份额（四舍五入成场数），[param skip_first] 是离入口最近的几场不换。
## 返回 {"battles": 普通战斗点几个, "target": 该换几个, "replaced": [点 id], "missed": [想换但没合适敌人的点 id]}
static func apply(
	graph: MapGraph, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase, share: float, skip_first: int, seed_value: int,
	carry: CarryRule = null, bag_pool: BagPool = null
) -> Dictionary:
	var out := {"battles": 0, "target": 0, "replaced": [] as Array[int], "missed": [] as Array[int]}
	if graph == null or pool == null or enemies == null or items == null or share <= 0.0:
		return out
	var dist := {}
	var queue: Array[int] = []
	for e in graph.entry_ids:
		dist[e] = 0
		queue.append(e)
	graph.spread(dist, queue)
	var battles: Array[int] = []
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.type == &"battle" and EnemyKit.has_enemy(n.content):
			battles.append(id)
	out["battles"] = battles.size()
	var target := roundi(share * float(battles.size()))
	out["target"] = target
	# 离入口最近的几场留着（同距离按 id）
	battles.sort_custom(func(a: int, b: int) -> bool:
		var da := int(dist.get(a, 1 << 20))
		var db := int(dist.get(b, 1 << 20))
		return da < db or (da == db and a < b))
	var open := battles.slice(mini(skip_first, battles.size()))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("advanced:%d" % seed_value)
	for i in range(open.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = open[i]
		open[i] = open[j]
		open[j] = t
	var used: Array[StringName] = []
	var taken: Array[int] = []
	for id in open:
		if taken.size() >= target:
			break
		if graph.neighbors(id).any(func(nb: int) -> bool: return taken.has(nb)):
			continue
		var n := graph.get_node(id)
		var wanted := int(n.content.get("strength", 0))
		var r := RandomNumberGenerator.new()
		r.seed = n.content_seed ^ 0x320A4
		var entry := pick(pool, enemies, n, wanted, r, used)
		if entry == null:
			(out["missed"] as Array[int]).append(id)
			continue
		var built := EnemyPlacer.build_content(enemies.enemy(entry.enemy), pool, items, wanted, r, carry, bag_pool)
		if built.is_empty():
			(out["missed"] as Array[int]).append(id)
			continue
		var content: Dictionary = built["content"]
		content[KEY] = true
		n.content = content
		taken.append(id)
		used.append(entry.enemy)
	out["replaced"] = taken
	return out
