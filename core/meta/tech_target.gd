## 319 D：追踪一项科技 —— 还差什么。数值树：还差的材料（仓库里已有的扣掉）和能在哪种材料节点找到；
## 机制树：还差几点见识。只写看得见的（材料节点按标签对上），不提配方。
class_name TechTarget
extends RefCounted


## 还差：`{"insight": n, "items": {道具 id（字符串）: 件数}}`；满级 / 没这项返回空
static func shortfall(meta: MetaState, def: TechDef) -> Dictionary:
	if meta == null or def == null:
		return {}
	var tier := TechService.next_tier(meta, def)
	if tier == null:
		return {}
	var out := {"insight": maxi(0, tier.insight - meta.insight) if def.is_mechanism() else 0, "items": {}}
	var owned := {}
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		if it.def != null:
			owned[String(it.def.id)] = int(owned.get(String(it.def.id), 0)) + 1
	var need := TechService.needed(meta, def)
	var keys := need.keys()
	keys.sort()
	for key in keys:
		var short := int(need[key]) - int(owned.get(key, 0))
		if short > 0:
			(out["items"] as Dictionary)[key] = short
	return out


## 这件材料能在哪种材料节点找到（[member NodeRules.search_kinds] 的标签对上）：节点名，按种类 id 排
static func sources_of(item_def: ItemDef, kinds: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if item_def == null:
		return out
	var ids := kinds.keys()
	ids.sort()
	for kind in ids:
		for tag in (kinds[kind] as Dictionary).get("tags", []):
			if item_def.has_tag(StringName(String(tag))):
				out.append(NodeText.label_of(StringName("search_" + String(kind))))
				break
	return out


## 各章节点规则里的材料节点合在一起：种类 → `{tags, ...}`
static func search_kinds(chapters: Array) -> Dictionary:
	var out := {}
	for c in chapters:
		var ch := c as ChapterDef
		if ch == null or ch.node_rules == &"":
			continue
		var rules := ContentPaths.load_asset("node_rules", String(ch.node_rules)) as NodeRules
		if rules == null:
			continue
		for kind in rules.search_kinds:
			if not out.has(kind):
				out[kind] = rules.search_kinds[kind]
	return out


## 结算小纸那一行：「目标：名字」+ 还差什么；满级 / 没追踪返回空
static func line(meta: MetaState, defs: Array, items: ItemDatabase, kinds: Dictionary) -> String:
	if meta == null or meta.tracked_tech == &"":
		return ""
	var def := TechService.find(defs, meta.tracked_tech)
	var short := shortfall(meta, def)
	if short.is_empty():
		return ""
	var parts: Array[String] = []
	if int(short["insight"]) > 0:
		parts.append(UiText.t("tech.target_insight") % int(short["insight"]))
	for key in short["items"]:
		var item_def := items.get_def(StringName(String(key))) if items != null else null
		var part := UiText.t("tech.target_item") % [Names.of(item_def) if item_def != null else String(key), int(short["items"][key])]
		var from := sources_of(item_def, kinds)
		if not from.is_empty():
			part += UiText.t("tech.target_from") % UiText.t("hud.buff_sep").join(from)
		parts.append(part)
	var head := UiText.t("tech.target_head") % Names.of(def)
	if parts.is_empty():
		return head + UiText.t("tech.target_ready_insight" if def.is_mechanism() else "tech.target_ready_items")
	return head + UiText.t("tech.target_short") % UiText.t("hud.buff_sep").join(parts)
