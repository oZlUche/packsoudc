## 宝箱点（154，作者定）：生成地图之后的一遍，给每个 `chest` 点定好稀有度与皮肤，写进 `node.content.chest`（5.10：内容生成时就定）。
##
## 稀有度按节点档位掷（[method ChestRules.roll_rarity]），皮肤跟章节走（[member ChapterDef.chest_skin]）。
## 已经写好的（预设图里画死的）不动。随机点踩上去揭成宝箱时，[NodeEvents] 用 [method roll_one] 补同一步。
## 随机数只用节点的 `content_seed`：同一张图每次一样。
class_name ChestPlacer
extends RefCounted

## 节点内容里的键
const KEY := "chest"


## 给图上全部宝箱点定稀有度与皮肤（[param rules] 为空用默认），返回定过的点的 id
static func roll(graph: MapGraph, rules: ChestRules, skin: StringName) -> Array[int]:
	var out: Array[int] = []
	if graph == null:
		return out
	var r := rules if rules != null else ChestRules.new()
	for id in graph.node_ids():
		var node := graph.get_node(id)
		if node.type == &"chest" and roll_one(node, r, skin):
			out.append(id)
	return out


## 给一个点定宝箱（已经有了就不动，返回 false）
static func roll_one(node: MapNode, rules: ChestRules, skin: StringName) -> bool:
	if node == null or node.content.get(KEY, null) is Dictionary:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:chest" % node.content_seed)
	var rarity := (rules if rules != null else ChestRules.new()).roll_rarity(node.tier, node.danger, rng)
	node.content[KEY] = {"rarity": rarity, "skin": String(skin if skin != &"" else &"ruins")}
	return true


## 这个点的宝箱：{rarity, skin, opened}；不是宝箱或还没定返回空字典
static func chest_of(node: MapNode) -> Dictionary:
	if node == null:
		return {}
	var c = node.content.get(KEY, null)
	return c if c is Dictionary else {}


static func rarity_of(node: MapNode) -> int:
	return clampi(int(chest_of(node).get("rarity", 0)), 0, 5)


static func skin_of(node: MapNode) -> StringName:
	return StringName(String(chest_of(node).get("skin", "ruins")))


## 锁开过了（开锁后的搜索会话可能还没结束，或者存档时视为离开）
static func is_opened(node: MapNode) -> bool:
	return bool(chest_of(node).get("opened", false))
