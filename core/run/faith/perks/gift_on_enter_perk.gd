## 大地 3 级（093）：头一回踩上一个点立刻得到一件对应类型的道具（说明按 [member by_type] 生成），到地上
class_name GiftOnEnterPerk
extends FaithPerk

## 点类型 → 任一标签命中即可（空数组 = 任何非包道具）
@export var by_type: Dictionary = {"battle": ["weapon"], "elite": ["armor", "shield"], "event": ["trinket", "material"], "extract": [], "core": ["valuable"]}
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
		if d == null or d.is_bag or d.is_bullion() or (rarity_cap >= 0 and d.rarity > rarity_cap):     # 244：金银只有商店出
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
	return UiText.t("perk.gift_done") % Names.of(def)


## 288：按 [member by_type] 拼（「战斗-武器 / 精英-防具或盾 / ……」），数据改了文字跟着改
func _summary() -> String:
	var parts: Array[String] = []
	for key in by_type:
		var tags: Array[String] = []
		for t in by_type[key]:
			tags.append(Glossary.tag_name(StringName(String(t))))
		var what := UiText.t("perk.gift_or").join(tags) if not tags.is_empty() else UiText.t("perk.gift_any")
		parts.append(UiText.t("perk.gift_pair") % [NodeText.label_of(StringName(String(key))), what])
	return UiText.t("perk.gift_summary") % " / ".join(parts)
