## 360 第二批 A5（作者难度表「休息点变少，只剩一个半途关闭的撤离点」）：开局时改图的两步。
## 拿掉的点变成路口（[code]junction[/code]）：边不动，路照样走得通，只是这里没有事。
class_name DifficultyMap
extends RefCounted

const JUNCTION := &"junction"


## 休息点只留 [param keep_percent]%（向下取整，至少 1 个）；留哪几个按种子定，可复现。返回拿掉了几个
static func trim_rests(graph: MapGraph, keep_percent: int, p_seed: int) -> int:
	if graph == null or keep_percent >= 100:
		return 0
	var rests: Array[int] = []
	for id in graph.node_ids():
		if graph.get_node(id).type == &"rest":
			rests.append(id)
	if rests.size() <= 1:
		return 0
	rests.sort()
	@warning_ignore("integer_division")
	var keep := maxi(1, rests.size() * maxi(0, keep_percent) / 100)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_seed, "rest_trim"])
	for i in range(rests.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := rests[i]
		rests[i] = rests[j]
		rests[j] = t
	var removed := 0
	for k in range(keep, rests.size()):
		_to_junction(graph.get_node(rests[k]))
		removed += 1
	return removed


## 撤离点只留一个：倒计时过半关闭的那个（`closes_at`）；没有就留不收费的里 id 最小的；都收费就留 id 最小的、免掉费用。返回留下的 id（没有撤离点 -1）
static func keep_one_extract(graph: MapGraph) -> int:
	if graph == null:
		return -1
	var extracts: Array[int] = []
	for id in graph.node_ids():
		if graph.get_node(id).type == &"extract":
			extracts.append(id)
	if extracts.is_empty():
		return -1
	extracts.sort()
	var keep := -1
	for id in extracts:
		if graph.get_node(id).content.has("closes_at"):
			keep = id
			break
	if keep < 0:
		for id in extracts:
			if PaidExtracts.fee_of(graph.get_node(id)) == 0:
				keep = id
				break
	if keep < 0:
		keep = extracts[0]
	graph.get_node(keep).content.erase("fee")
	for id in extracts:
		if id != keep:
			_to_junction(graph.get_node(id))
	return keep


static func _to_junction(node: MapNode) -> void:
	node.type = JUNCTION
	node.content = {}


## 360 A10（作者难度表「首领变成强化版，增加独有道具」；名字见报告 365）：核心点的首领按 [member DifficultyDef.boss_upgrades] 换名、多带一件。
## 道具还没进库（报告 366 那边在做）就只换名。多带的那件写进 `guaranteed_drops`：打赢必掉。返回强化了几个
const TITLE_KEY := "title"
const TITLES_KEY := "titles"


static func upgrade_bosses(graph: MapGraph, def: DifficultyDef, items: ItemDatabase) -> int:
	if graph == null or def == null or def.boss_upgrades.is_empty():
		return 0
	var n := 0
	for id in graph.node_ids():
		var node := graph.get_node(id)
		if node.type != &"core" or not EnemyKit.has_enemy(node.content):
			continue
		var up: Variant = def.boss_upgrades.get(String(node.content.get("enemy", "")), null)
		if not (up is Dictionary):
			continue
		var d := up as Dictionary
		if String(d.get(TITLE_KEY, "")) != "":
			node.content[TITLE_KEY] = String(d[TITLE_KEY])
		if d.get(TITLES_KEY, {}) is Dictionary and not (d.get(TITLES_KEY, {}) as Dictionary).is_empty():
			node.content[TITLES_KEY] = (d[TITLES_KEY] as Dictionary).duplicate()
		var item := StringName(String(d.get("item", "")))
		if item != &"" and items != null and items.get_def(item) != null:
			(node.content.get_or_add("items", []) as Array).append({"id": String(item)})
			(node.content.get_or_add("guaranteed_drops", []) as Array).append(String(item))
		node.content["upgraded"] = true
		n += 1
	return n


## 360 A12（作者难度表「守卫核心」；报告 363、365、366）：在绕得开的支路上挑一名精英当守卫 —— 拿掉这个点，每个出生点照样走得到首领。
## 守卫的内容写 `guard`（名牌与边框读它）和 `guard_link`（带的联动道具，打赢掉它的失效版）；首领的内容写 `reinforce`（守卫是哪个点、增援是哪份 buff）。
## 挑哪名按种子定，可复现。没有合适的精英就不设。返回守卫的点 id（没设 -1）
const GUARD_KEY := "guard"
const LINK_KEY := "guard_link"
const REINFORCE_KEY := EnemyKit.REINFORCE_KEY
const SPENT_SUFFIX := "_spent"
const ELEMENTS: Array[StringName] = [&"fire", &"ice", &"lightning", &"poison"]


static func place_guard(graph: MapGraph, def: DifficultyDef, pool: EnemyPool, enemies: EnemyDatabase, items: ItemDatabase, p_seed: int) -> int:
	if graph == null or def == null or def.guard_core.is_empty():
		return -1
	var cores: Array[int] = []
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.type == &"core" and EnemyKit.has_enemy(n.content):
			cores.append(id)
	if cores.is_empty():
		return -1
	var picks: Array = []     # [点 id, 联动道具 id, 增援 buff id]
	for id in graph.node_ids():
		var n := graph.get_node(id)
		if n.type != &"elite" or not EnemyKit.has_enemy(n.content) or not bypassable(graph, id, cores):
			continue
		var enemy := enemies.enemy(StringName(String(n.content.get("enemy", "")))) if enemies != null else null
		var link := link_of(def, pool, enemy)
		var buff := reinforce_of(def, link, enemy)
		if link == &"" or buff == &"" or items == null or items.get_def(link) == null:
			continue
		picks.append([id, link, buff])
	if picks.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_seed, "guard"])
	var pick: Array = picks[rng.randi_range(0, picks.size() - 1)]
	var guard := graph.get_node(int(pick[0]))
	guard.content[GUARD_KEY] = true
	guard.content[LINK_KEY] = String(pick[1])
	for cid in cores:
		graph.get_node(cid).content[REINFORCE_KEY] = {"guard": int(pick[0]), "buff": String(pick[2]), "link": String(pick[1])}
	return int(pick[0])


## 拿掉 [param id] 之后，每个出生点还走得到每个首领点吗（出生点本身、首领点本身不算绕得开）
static func bypassable(graph: MapGraph, id: int, cores: Array[int]) -> bool:
	if graph.entry_ids.has(id) or cores.has(id) or graph.entry_ids.is_empty():
		return false
	for entry in graph.entry_ids:
		var seen := {entry: true, id: true}
		var queue: Array[int] = [entry]
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for nb in graph.neighbors(cur):
				if not seen.has(nb):
					seen[nb] = true
					queue.append(nb)
		for c in cores:
			if not seen.has(c):
				return false
	return true


## 属性兽（魔兽、带一种元素流派）当守卫用 `beast`，否则按敌人池给
static func link_of(def: DifficultyDef, pool: EnemyPool, enemy: EnemyDef) -> StringName:
	if element_of(enemy) != &"" and String(def.guard_core.get("beast", "")) != "":
		return StringName(String(def.guard_core["beast"]))
	var pools: Variant = def.guard_core.get("pools", {})
	if pool == null or not (pools is Dictionary):
		return &""
	return StringName(String((pools as Dictionary).get(String(pool.id), "")))


static func reinforce_of(def: DifficultyDef, link: StringName, enemy: EnemyDef) -> StringName:
	var table: Variant = def.guard_core.get("reinforce", {})
	if link == &"" or not (table is Dictionary):
		return &""
	var v: Variant = (table as Dictionary).get(String(link), "")
	if v is Dictionary:
		return StringName(String((v as Dictionary).get(String(element_of(enemy)), "")))
	return StringName(String(v))


## 那只兽的属性（不是魔兽、没有元素流派 = 空）
static func element_of(enemy: EnemyDef) -> StringName:
	if enemy == null or enemy.species != &"beast":
		return &""
	for s in enemy.schools:
		if ELEMENTS.has(s):
			return s
	return &""


## 首领现在还带着增援吗：写了增援、守卫那个点还有敌人
static func reinforced(graph: MapGraph, core_content: Dictionary) -> bool:
	var r: Variant = core_content.get(REINFORCE_KEY, null)
	if not (r is Dictionary) or graph == null:
		return false
	var g := graph.get_node(int((r as Dictionary).get("guard", -1)))
	return g != null and EnemyKit.has_enemy(g.content) and bool(g.content.get(GUARD_KEY, false))


## 打赢守卫：首领身上的增援撤掉。返回撤了几个首领的
static func guard_down(graph: MapGraph, guard_id: int) -> int:
	if graph == null:
		return 0
	var n := 0
	for id in graph.node_ids():
		var c := graph.get_node(id).content
		var r: Variant = c.get(REINFORCE_KEY, null)
		if r is Dictionary and int((r as Dictionary).get("guard", -1)) == guard_id:
			c.erase(REINFORCE_KEY)
			n += 1
	return n
