## 材料供给复测（报告 303，材料与难度方案 §6.2 / §7.2 M1 / M2）：照正式开局生成地图，把每个搜索点都按正式的搜索会话搜满
## （同一套节点随机数、保底、产物加权、材料节点过滤、魔晶换品），数配方材质格顶得上的材料各拿到几件。
##
## 这是方案说的**地图机会**层：假设每个搜索点都去、都搜满、不遭遇（遭遇照样掷随机数，只是不打断），是供给上限，不是玩家真拿得到的量。
## 宝箱、敌人掉落、商店、事件不在这里数（宝箱另有一套会话；其他见审计 [MaterialSupplyAudit]）。
##
## 变体（`opts`）：
## - `hide`：这几件道具当作没有（[method ItemDatabase.set_locked]，搜索候选就不给）—— M1 的对照组「没有三件新材料」；
## - `kind_share`：材料节点里「从这一类抽」的份额乘几（上限 1）—— M2「只改目标来源内的材料份额」，同时数被挤掉的别的东西
class_name MaterialSupplySurvey
extends RefCounted

const CHAPTERS: Array[StringName] = [&"free_mode", &"clockwork_hourglass"]
const NEW_MATERIALS: Array[StringName] = [&"straight_ash_branch", &"seasoned_timber", &"dense_basalt"]


## 配方材质格里出现过的（材质键, 最低稀有度），去重，按键名、档排
static func slots(recipes: Array) -> Array:
	var seen := {}
	for r in recipes:
		var rd := r as SmithRecipeDef
		if rd == null:
			continue
		for mat in rd.material_inputs:
			seen["%s|%d" % [String(mat), int(rd.material_inputs[mat])]] = true
	var out: Array = []
	for k in seen:
		out.append({"material": String(k).get_slice("|", 0), "min": String(k).get_slice("|", 1).to_int()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["material"] < b["material"] if a["material"] != b["material"] else int(a["min"]) < int(b["min"]))
	return out


## 一格的判定器：生产的 [method SmithRecipeDef.material_fits]
static func slot_recipe(slot: Dictionary) -> SmithRecipeDef:
	var rd := SmithRecipeDef.new()
	rd.material_inputs = {slot["material"]: int(slot["min"])}
	return rd


## 一张图搜满拿到的东西：道具 id 数组（重复的照记）。只走生成时就是搜索点的点（随机点揭成搜索的不算）
static func haul_of(s: RunState, kind_share: float = 1.0) -> Array[StringName]:
	var out: Array[StringName] = []
	var ev := s.events
	var sr := ev.rules.search if ev != null and ev.rules != null else null
	if sr == null:
		return out
	for id in s.map.node_ids():
		var node := s.map.get_node(id)
		if node.type != &"search":
			continue
		var session := SearchSession.new(node, sr, s.items, ev._rng_for(node, "search"), ev._depth_of(node))
		session.search_floor = SearchSession.floor_for(node, sr, ev.difficulty_def)
		session.produce = node.produce
		var kind := ev.search_kind_of(node)
		session.only_tags = kind.get("tags", [])
		var share := float(kind.get("other_share", 0.0))
		if kind_share != 1.0 and not session.only_tags.is_empty():
			share = maxf(0.0, 1.0 - (1.0 - share) * kind_share)
		session.other_share = share
		var guard := 0
		while session.can_search() and guard < 32:
			session.search()
			guard += 1
		out.append_array(session.found)
	return out


## 一章 × 一个变体：{"maps", "failed", "slots": {格: {"maps_with": 几张图至少一件, "counts": [每张图几件]}}, "items": {id: 总件数}, "found": 总件数, "materials": 其中材料类}
static func survey(chapter: ChapterDef, items: ItemDatabase, enemies: EnemyDatabase, seeds: Array, slot_list: Array, opts: Dictionary = {}) -> Dictionary:
	var hide: Array = opts.get("hide", [])
	items.set_locked(hide)
	var out := {"maps": 0, "failed": 0, "slots": {}, "items": {}, "found": 0, "materials": 0}
	var fits := {}
	for slot in slot_list:
		var key := slot_key(slot)
		fits[key] = slot_recipe(slot)
		out["slots"][key] = {"maps_with": 0, "counts": []}
	for seed_ in seeds:
		var s := RunState.start(chapter, int(seed_), items, enemies)
		if s == null:
			out["failed"] = int(out["failed"]) + 1
			continue
		out["maps"] = int(out["maps"]) + 1
		var got := haul_of(s, float(opts.get("kind_share", 1.0)))
		s.dispose()
		var per := {}
		for id in got:
			var d := items.get_def(id)
			out["found"] = int(out["found"]) + 1
			out["items"][String(id)] = int(out["items"].get(String(id), 0)) + 1
			if d != null and SearchSession.is_material(d):
				out["materials"] = int(out["materials"]) + 1
			for key in fits:
				if (fits[key] as SmithRecipeDef).material_fits(key.get_slice("≥", 0), d):
					per[key] = int(per.get(key, 0)) + 1
		for key in fits:
			var n := int(per.get(key, 0))
			(out["slots"][key]["counts"] as Array).append(n)
			if n > 0:
				out["slots"][key]["maps_with"] = int(out["slots"][key]["maps_with"]) + 1
	items.set_locked([])
	return out


static func slot_key(slot: Dictionary) -> String:
	return "%s≥%d" % [slot["material"], int(slot["min"])]


## 两个变体逐格对照（同一套种子）：至少一件的图占比、每图件数中位 / 平均
static func compare_rows(base: Dictionary, other: Dictionary) -> Array:
	var out: Array = []
	for key in base["slots"]:
		var b: Dictionary = base["slots"][key]
		var o: Dictionary = other["slots"].get(key, {})
		if o.is_empty():
			continue
		out.append({"slot": key, "base_maps": _share(int(b["maps_with"]), int(base["maps"])), "maps": _share(int(o["maps_with"]), int(other["maps"])),
			"base_mean": BalanceStatistics.mean(b["counts"]), "mean": BalanceStatistics.mean(o["counts"]),
			"base_p50": BalanceStatistics.quantiles(b["counts"]).get("p50"), "p50": BalanceStatistics.quantiles(o["counts"]).get("p50")})
	return out


static func _share(k: int, n: int) -> float:
	return float(k) / float(n) if n > 0 else 0.0


## 一章的对照表（markdown）：[param runs] 是 {变体名: [method survey] 的结果}，第一个当基线
static func markdown(chapter_id: String, runs: Dictionary, names: Array) -> String:
	var lines: Array[String] = ["## %s" % chapter_id, ""]
	var base: Dictionary = runs[names[0]]
	lines.append("%d 张图（开不出 %d）。每张图搜满平均拿到 %.1f 件，其中材料类 %.1f 件（基线 %s）。" % [base["maps"], base["failed"],
		float(base["found"]) / maxf(1.0, float(base["maps"])), float(base["materials"]) / maxf(1.0, float(base["maps"])), names[0]])
	lines.append("")
	for v in names.slice(1):
		var o: Dictionary = runs[v]
		lines.append("### %s 对 %s" % [v, names[0]])
		lines.append("")
		lines.append("每张图搜满平均 %.1f 件，材料类 %.1f 件；非材料 %.1f → %.1f 件（被挤掉的量）。" % [
			float(o["found"]) / maxf(1.0, float(o["maps"])), float(o["materials"]) / maxf(1.0, float(o["maps"])),
			float(int(base["found"]) - int(base["materials"])) / maxf(1.0, float(base["maps"])), float(int(o["found"]) - int(o["materials"])) / maxf(1.0, float(o["maps"]))])
		lines.append("")
		lines.append("| 材质格 | 至少一件的图（基线 → 变体） | 每图件数平均（基线 → 变体） | 中位（基线 → 变体） |")
		lines.append("|---|---|---|---|")
		for row in compare_rows(base, o):
			var r := row as Dictionary
			lines.append("| %s | %.0f%% → %.0f%% | %.2f → %.2f | %s → %s |" % [r["slot"], float(r["base_maps"]) * 100.0, float(r["maps"]) * 100.0,
				float(r["base_mean"]) if r["base_mean"] != null else 0.0, float(r["mean"]) if r["mean"] != null else 0.0, str(r["base_p50"]), str(r["p50"])])
		lines.append("")
	var last: Dictionary = runs[names[names.size() - 1]]
	lines.append("新材料（%s）每张图平均：%s" % [names[names.size() - 1], "，".join(NEW_MATERIALS.map(func(id: StringName) -> String:
		return "%s %.2f" % [id, float(last["items"].get(String(id), 0)) / maxf(1.0, float(last["maps"]))]))])
	lines.append("")
	return "\n".join(lines) + "\n"
