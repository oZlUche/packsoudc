## 大地 3 级（093）：头一回踩上一个点立刻得到一件对应类型的道具（战斗-武器 / 精英-防具 / 事件-饰品 / 撤离点-随机 / BOSS-珍宝），进暂存区
class_name GiftOnEnterPerk
extends FaithPerk

## 点类型 → 任一标签命中即可（空数组 = 任何非包道具）
@export var by_type: Dictionary = {"battle": ["weapon"], "elite": ["gear", "armor", "shield"], "event": ["sigil", "part"], "extract": [], "core": ["treasure"]}
@export var rarity_cap: int = -1


func on_node_entered(run: RunState, node: MapNode, first_visit: bool) -> String:
	if not first_visit or run == null or node == null or run.items == null or run.storage == null:
		return ""
	var key := String(NodeEvents.effective_type(node))
	if not by_type.has(key):
		return ""
	var wanted: Array = by_type[key]
	var cands: Array[StringName] = []
	for id in run.items.ids():
		var d := run.items.get_def(id)
		if d == null or d.is_bag or (rarity_cap >= 0 and d.rarity > rarity_cap):
			continue
		var ok := wanted.is_empty()
		for t in wanted:
			if d.tags.has(StringName(String(t))):
				ok = true
		if ok:
			cands.append(id)
	if cands.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:gift:%d" % [run.run_seed, node.id])
	var def := run.items.get_def(cands[rng.randi_range(0, cands.size() - 1)])
	run.storage.admit(ItemInstance.create(def))
	return "大地之神赐下「%s」（进了暂存区）" % Names.of(def)


func describe() -> String:
	return note if note != "" else "头一回踩上一个点就得一件对应类型的道具（战斗-武器 / 精英-防具 / 事件-饰品 / 撤离点-随机 / BOSS-珍宝）"
