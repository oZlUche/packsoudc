## 303 第 2 步（材料方案 2026-11-11 §6.1 A 批）：材料供给审计 —— 每张铁匠铺配方的每一格要什么、库里哪几件顶得上、它们从哪儿来。
## 规则全用生产函数（[method SmithRecipeDef.material_fits]、[method SearchSession.candidates] / [method SearchSession.in_kind]、
## [method ShopSession.candidates]、[method DropResolver.treasure_candidates]、[method RewardPool.probabilities]、[method Market.catalogue] /
## [method Market.loose_candidates]），这里不另写一套。敌人身上背的从真生成的图里数（[method RunState.start]），不按身份标签猜。
##
## 来源分两种：**外部**（搜索、材料节点、宝箱、局内商店、敌人携带、珍宝掉落、事件奖励池、集市）和**派生**（铁匠铺配方、局内拼接配方）。
## 可达性 = 从外部来源出发在配方上做不动点闭包：算两遍 —— 「不要门槛」（不认 requires_unlock 的道具、不认要科技的配方）和「全开」。
## 每一格的结论（方案 §6.1 的 1～4；第 5 种「仓库里有但锁着」是存档状态，静态审计不管）：
## - `no_item`：库里没有顶得上的道具
## - `no_source`：有道具，但外部来源和配方都给不出（断路 / 只有自己产自己的环）
## - `gated`：只有解锁成就 / 点科技之后才拿得到
## - `thin`：不要门槛拿得到，但只有一种外部渠道（或只靠配方派生），记一笔
## - `ok`
## 命令行外壳 `tools/audit_material_supply.gd`；单元测试读 [method audit] 的结果
class_name MaterialSupplyAudit
extends RefCounted

const CHAPTERS: Array[StringName] = [&"free_mode", &"clockwork_hourglass"]
## 数敌人携带、材料节点用的种子
const SEEDS := 6
## 奖励池按最深、最难算候选上限（min_depth 另记）
const POOL_DEPTH := 1.0
const POOL_LEVEL := 3
## 搜索 / 材料节点里一件的份额低于这个记「低概率」
const LOW_SHARE := 0.005

const OK := "ok"
const THIN := "thin"
const GATED := "gated"
const NO_SOURCE := "no_source"
const NO_ITEM := "no_item"


## 全部外部来源：道具 id（String）→ [{"kind", "where", "share"}]。share 是那条渠道里这件的份额（算不出 = -1）
static func external_sources(items: ItemDatabase, enemies: EnemyDatabase, chapters: Array[StringName] = CHAPTERS, seeds: int = SEEDS) -> Dictionary:
	var out := {}
	for ch_id in chapters:
		var ch := ContentPaths.load_asset("chapters", String(ch_id)) as ChapterDef
		if ch == null:
			continue
		var kinds := {}
		var carried := {}
		var s0: RunState = null
		for seed_ in range(1, seeds + 1):
			var s := RunState.start(ch, seed_, items, enemies)
			if s == null:
				continue
			for nid in s.map.node_ids():
				var node := s.map.get_node(nid)
				var k := String(node.content.get("search_kind", ""))
				if k != "":
					kinds[k] = true
				for id in DropResolver.carried_ids(node.content):
					carried[String(id)] = true
			if s0 == null:
				s0 = s
			else:
				s.dispose()
		if s0 == null:
			continue
		var where := String(ch_id)
		var nr := s0.node_rules
		if nr != null and nr.search != null:
			_add_weighted(out, items, SearchSession.candidates(nr.search, items), nr.search, "search", where)
			var kind_ids: Array = kinds.keys()
			kind_ids.sort()
			for k in kind_ids:
				var spec: Dictionary = nr.search_kinds.get(k, {})
				var tags: Array = spec.get("tags", [])
				var only: Array[StringName] = []
				for id in SearchSession.candidates(nr.search, items):
					if SearchSession.in_kind(items.get_def(id), tags):
						only.append(id)
				_add_weighted(out, items, only, nr.search, "node:" + String(k), where)
			if nr.chest != null:
				var sr := nr.search.duplicate() as SearchRules
				var excl: Array[StringName] = sr.exclude_tags.duplicate()
				if nr.chest.include_treasure:
					excl.erase(&"treasure")
				sr.exclude_tags = excl
				_add_weighted(out, items, SearchSession.candidates(sr, items), sr, "chest", where)
		if s0.economy != null:
			for id in ShopSession.candidates(s0.economy, items):
				_add(out, id, "shop", where, -1.0)
		var cids: Array = carried.keys()
		cids.sort()
		for id in cids:
			_add(out, StringName(String(id)), "enemy", where, -1.0)
		var dr := s0.drop_rule
		if dr != null and dr.treasure_chance > 0.0:
			for r in dr.treasure_rarities():
				for id in DropResolver.treasure_candidates(dr, items, r, [] as Array[StringName]):
					_add(out, id, "treasure", where, -1.0)
		var live := live_pools()
		var pools := RewardPool.load_all()
		var pids: Array = pools.keys()
		Ids.sort(pids)
		for pid in pids:
			if not live.has(String(pid)):
				continue
			var probs := (pools[pid] as RewardPool).probabilities(items, ch_id, POOL_DEPTH, POOL_LEVEL)
			for id in probs:
				_add(out, StringName(String(id)), "pool:" + String(pid), where, float(probs[id]))
		s0.dispose()
	var rules := Market.load_rules()
	for st in Market.stalls():
		if st.fixed:
			for id in Market.catalogue(rules, items, st, rules.rarity_cap_per_level.size()):
				_add(out, id, "market:" + String(st.id), "base", -1.0)
	for id in Market.loose_candidates(rules, items):
		_add(out, id, "market:loose", "base", -1.0)
	return out


## 事件里真用到（`give_pool_item` 引用）的奖励池 id；没被事件用的池不算已有来源（方案 §5.1「未上线不计」）
static func live_pools() -> Dictionary:
	var out := {}
	var dir := "res://data/authoring/events"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(dir + "/" + f)
		var re := RegEx.create_from_string("\"pool\"\\s*:\\s*\"([a-z0-9_]+)\"")
		for m in re.search_all(text):
			out[m.get_string(1)] = true
	return out


static func _add_weighted(out: Dictionary, items: ItemDatabase, ids: Array[StringName], sr: SearchRules, kind: String, where: String) -> void:
	var total := 0.0
	var w := {}
	for id in ids:
		var d := items.get_def(id)
		var x := float(sr.rarity_weights[clampi(d.rarity, 0, sr.rarity_weights.size() - 1)])
		w[id] = x
		total += x
	for id in ids:
		_add(out, id, kind, where, float(w[id]) / total if total > 0.0 else -1.0)


static func _add(out: Dictionary, id: StringName, kind: String, where: String, share: float) -> void:
	var list: Array = out.get_or_add(String(id), [])
	for e in list:
		if e["kind"] == kind and e["where"] == where:
			return
	list.append({"kind": kind, "where": where, "share": share})


## 不动点闭包：外部来源 + 配方产出。[param open] = 不要门槛（锁着的道具不算外部来源、要科技的配方不打）。
## 返回 道具 id（String）→ true
static func reachable(items: ItemDatabase, recipes: Array, merges: Array, ext: Dictionary, open: bool) -> Dictionary:
	var got := {}
	for id in ext:
		var d := items.get_def(StringName(String(id)))
		if d != null and (not open or d.requires_unlock == &""):
			got[String(id)] = true
	var changed := true
	while changed:
		changed = false
		for r in recipes:
			var rd := r as SmithRecipeDef
			if got.has(String(rd.output)) or (open and rd.tech != &""):
				continue
			if _recipe_ready(rd, items, got, open):
				got[String(rd.output)] = true
				changed = true
		for m in merges:
			var md := m as RecipeDef
			if got.has(String(md.output)):
				continue
			if md.inputs.all(func(i: StringName) -> bool: return got.has(String(i))):
				got[String(md.output)] = true
				changed = true
	return got


static func _recipe_ready(rd: SmithRecipeDef, items: ItemDatabase, got: Dictionary, open: bool) -> bool:
	for id in rd.inputs:
		if not got.has(String(id)):
			return false
	for slot in rd.slots():     # 310：件数只看「有没有」，供给审计不数件
		if fitting_slot(slot, items).filter(func(d: ItemDef) -> bool:
			return got.has(String(d.id)) and (not open or d.requires_unlock == &"")).is_empty():
			return false
	return true


## [param rd] 那一格（材质类 / 魔晶石）库里顶得上的道具，按稀有度、id 排
static func fitting(rd: SmithRecipeDef, mat: String, items: ItemDatabase) -> Array[ItemDef]:
	return fitting_slot({"material": mat, "min": int(rd.material_inputs.get(mat, 0))}, items)


## 310：[method SmithRecipeDef.slots] 里的一格库里顶得上的道具，按稀有度、id 排
static func fitting_slot(slot: Dictionary, items: ItemDatabase) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	var ids: Array = items.ids(true)
	Ids.sort(ids)
	for id in ids:
		var d := items.get_def(StringName(String(id)))
		if SmithRecipeDef.slot_fits(slot, d):
			out.append(d)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.rarity < b.rarity if a.rarity != b.rarity else String(a.id) < String(b.id))
	return out


## 全审计：{"slots": [每张配方每一格一行], "sources": 外部来源, "open": 不要门槛可达, "full": 全开可达}
## 一行：{"recipe", "group", "level", "tech", "slot", "need", "items": [{"id", "rarity", "gate", "sources": [...], "open", "full"}], "status", "kinds"}
static func audit(items: ItemDatabase, enemies: EnemyDatabase, recipes: Array = [], merges: Array = [], ext: Dictionary = {}) -> Dictionary:
	if recipes.is_empty():
		recipes = SmithRecipeDef.load_all()
	if merges.is_empty():
		merges = RecipeDef.load_all()
	if ext.is_empty():
		ext = external_sources(items, enemies)
	var open := reachable(items, recipes, merges, ext, true)
	var full := reachable(items, recipes, merges, ext, false)
	var producers := {}     # 道具 id → 产出它的配方 id
	for r in recipes:
		(producers.get_or_add(String((r as SmithRecipeDef).output), []) as Array).append("smith:" + String((r as SmithRecipeDef).id))
	for m in merges:
		(producers.get_or_add(String((m as RecipeDef).output), []) as Array).append("merge:" + String((m as RecipeDef).id))
	var rows: Array = []
	for r in recipes:
		var rd := r as SmithRecipeDef
		var fixed: Array = rd.inputs.keys()
		Ids.sort(fixed)
		for id in fixed:
			var d := items.get_def(StringName(String(id)))
			rows.append(_row(rd, "id:" + String(id), "%s ×%d" % [id, int(rd.inputs[id])], [d] if d != null else [], ext, producers, open, full))
		var slots := rd.slots()
		for i in slots.size():
			var slot := slots[i]
			var key := String(slot["material"]) if i < rd.material_inputs.size() else "%s@%d" % [slot["material"], i]
			var need := "%s ≥ %d" % [slot["material"], int(slot["min"])] + ("" if int(slot["count"]) == 1 else " ×%d" % int(slot["count"]))
			rows.append(_row(rd, key, need, fitting_slot(slot, items), ext, producers, open, full))
	return {"slots": rows, "sources": ext, "open": open, "full": full}


static func _row(rd: SmithRecipeDef, slot: String, need: String, defs: Array, ext: Dictionary, producers: Dictionary, open: Dictionary, full: Dictionary) -> Dictionary:
	var its: Array = []
	var kinds := {}
	var any_open := false
	var any_full := false
	for d in defs:
		var def := d as ItemDef
		var id := String(def.id)
		var src: Array = ext.get(id, [])
		var o := open.has(id)
		var f := full.has(id)
		if o:
			any_open = true
		any_full = any_full or f
		if f:
			for e in src:
				kinds[String(e["kind"]).get_slice(":", 0)] = true
			if src.is_empty():
				kinds["derived"] = true
		its.append({"id": id, "rarity": def.rarity, "gate": String(def.requires_unlock), "sources": src,
			"made_by": producers.get(id, []), "open": o, "full": f})
	var status := OK
	if defs.is_empty():
		status = NO_ITEM
	elif not any_full:
		status = NO_SOURCE
	elif not any_open:
		status = GATED
	elif kinds.size() <= 1 and its.filter(func(i: Dictionary) -> bool: return i["open"]).size() == its.filter(func(i: Dictionary) -> bool: return i["full"]).size():
		status = THIN
	var k: Array = kinds.keys()
	k.sort()
	return {"recipe": String(rd.id), "group": rd.group, "level": rd.level, "tech": String(rd.tech), "slot": slot, "need": need,
		"items": its, "status": status, "kinds": k}


## 每种结论几格
static func counts(result: Dictionary) -> Dictionary:
	var out := {OK: 0, THIN: 0, GATED: 0, NO_SOURCE: 0, NO_ITEM: 0}
	for row in result["slots"]:
		out[row["status"]] = int(out[row["status"]]) + 1
	return out


## 份额低于 [constant LOW_SHARE] 的搜索 / 材料节点渠道（只看那件在任一章、任一渠道里最大的份额）
static func best_share(src: Array) -> float:
	var best := -1.0
	for e in src:
		best = maxf(best, float(e["share"]))
	return best


## 配方材质格用到的材质 × 稀有度：[{"mat", "rarity", "open", "all", "ids", "chapters": {章: {"search", "node", "node_share"}}}]
static func tier_table(result: Dictionary, items: ItemDatabase) -> Array:
	var mats := {}
	for row in result["slots"]:
		if not String(row["slot"]).begins_with("id:"):
			mats[String(row["slot"])] = true
	var keys: Array = mats.keys()
	keys.sort()
	var ext: Dictionary = result["sources"]
	var out: Array = []
	var probe := SmithRecipeDef.new()
	for mat in keys:
		probe.material_inputs = {mat: 0}
		for r in 6:
			var ids: Array[String] = []
			var n_open := 0
			var all_ids: Array = items.ids(true)
			Ids.sort(all_ids)
			for id in all_ids:
				var d := items.get_def(StringName(String(id)))
				if d.rarity == r and probe.material_fits(String(mat), d):
					ids.append(String(id))
					n_open += 1 if (result["open"] as Dictionary).has(String(id)) else 0
			if ids.is_empty():
				continue
			var per := {}
			for ch in CHAPTERS:
				var search := 0.0
				var nodes := {}
				for id in ids:
					for e in ext.get(id, []):
						if e["where"] != String(ch) or float(e["share"]) < 0.0:
							continue
						if e["kind"] == "search":
							search += float(e["share"])
						elif String(e["kind"]).begins_with("node:"):
							nodes[e["kind"]] = float(nodes.get(e["kind"], 0.0)) + float(e["share"])
				var best := ""
				var best_v := 0.0
				var nk: Array = nodes.keys()
				nk.sort()
				for k in nk:
					if float(nodes[k]) > best_v:
						best_v = float(nodes[k])
						best = String(k).substr(5)
				per[String(ch)] = {"search": search, "node": best, "node_share": best_v}
			out.append({"mat": String(mat), "rarity": r, "open": n_open, "all": ids.size(), "ids": ids, "chapters": per})
	return out


static func markdown(result: Dictionary, items: ItemDatabase) -> String:
	var c := counts(result)
	var lines: Array[String] = []
	lines.append("# 材料供给审计（303 第 2 步）")
	lines.append("")
	lines.append("章节 %s；敌人携带与材料节点按种子 1..%d 生成的图数；奖励池只算事件真用到的，按深度 %.1f、难度 %d 取候选上限。" % [", ".join(CHAPTERS), SEEDS, POOL_DEPTH, POOL_LEVEL])
	lines.append("")
	lines.append("| 结论 | 格数 | 含义 |")
	lines.append("|---|---|---|")
	lines.append("| ok | %d | 不要门槛拿得到，至少两种渠道 |" % c[OK])
	lines.append("| thin | %d | 不要门槛拿得到，但只有一种渠道 |" % c[THIN])
	lines.append("| gated | %d | 要解锁成就 / 科技之后才拿得到 |" % c[GATED])
	lines.append("| no_source | %d | 有道具，来源全无（断路或只有自产的环） |" % c[NO_SOURCE])
	lines.append("| no_item | %d | 库里没有顶得上的道具 |" % c[NO_ITEM])
	lines.append("")
	lines.append("## 要看的格（非 ok）")
	lines.append("")
	lines.append("| 配方 | 级 / 科技 | 格 | 结论 | 顶得上的（不要门槛拿得到的加粗） | 渠道 |")
	lines.append("|---|---|---|---|---|---|")
	for row in result["slots"]:
		if row["status"] == OK:
			continue
		var names: Array[String] = []
		for it in row["items"]:
			var s := "%s(%d)" % [it["id"], it["rarity"]]
			if it["gate"] != "":
				s += "[%s]" % it["gate"]
			names.append("**%s**" % s if it["open"] else s)
		lines.append("| %s | %d%s | %s | %s | %s | %s |" % [row["recipe"], row["level"], (" / " + row["tech"]) if row["tech"] != "" else "",
			row["need"], row["status"], ", ".join(names) if not names.is_empty() else "—", ", ".join(row["kinds"]) if not (row["kinds"] as Array).is_empty() else "—"])
	lines.append("")
	lines.append("## 材质格的低概率候选")
	lines.append("")
	lines.append("材质类格里不要门槛拿得到、但搜索 / 材料节点份额都低于 %.1f%% 且没有别的渠道的道具。" % (LOW_SHARE * 100.0))
	lines.append("")
	var low := {}
	for row in result["slots"]:
		if String(row["slot"]).begins_with("id:"):
			continue
		for it in row["items"]:
			var src: Array = it["sources"]
			if not it["open"] or src.is_empty():
				continue
			if src.all(func(e: Dictionary) -> bool: return String(e["kind"]) == "search" or String(e["kind"]).begins_with("node:") or String(e["kind"]) == "chest") and best_share(src) < LOW_SHARE:
				low[it["id"]] = best_share(src)
	var lids: Array = low.keys()
	lids.sort()
	for id in lids:
		lines.append("- %s：最高份额 %.2f%%" % [id, float(low[id]) * 100.0])
	if lids.is_empty():
		lines.append("- 没有")
	lines.append("")
	lines.append("## 材质 × 稀有度的供给")
	lines.append("")
	lines.append("配方材质格用到的每种材质、每一档：库里几件（不要门槛拿得到的几件），每章普通搜索里这一档合计份额，和份额最高的材料节点。")
	lines.append("")
	lines.append("| 材质 | 档 | 件（可得 / 库里） | %s |" % " | ".join(CHAPTERS.map(func(ch_: StringName) -> String: return "%s 搜索 / 最好的节点" % ch_)))
	lines.append("|---|---|---|%s" % "---|".repeat(CHAPTERS.size()))
	for row in tier_table(result, items):
		var cells: Array[String] = []
		for ch in CHAPTERS:
			var t: Dictionary = row["chapters"][String(ch)]
			cells.append("%.1f%% / %s" % [float(t["search"]) * 100.0, ("%s %.1f%%" % [t["node"], float(t["node_share"]) * 100.0]) if String(t["node"]) != "" else "—"])
		lines.append("| %s | %d | %d / %d | %s |" % [row["mat"], row["rarity"], row["open"], row["all"], " | ".join(cells)])
	lines.append("")
	lines.append("## 全部格")
	lines.append("")
	lines.append("| 配方 | 格 | 结论 | 顶得上的件数（不要门槛 / 全开 / 库里） | 渠道 |")
	lines.append("|---|---|---|---|---|")
	for row in result["slots"]:
		var its: Array = row["items"]
		lines.append("| %s | %s | %s | %d / %d / %d | %s |" % [row["recipe"], row["need"], row["status"],
			its.filter(func(i: Dictionary) -> bool: return i["open"]).size(), its.filter(func(i: Dictionary) -> bool: return i["full"]).size(), its.size(),
			", ".join(row["kinds"])])
	return "\n".join(lines) + "\n"
