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
