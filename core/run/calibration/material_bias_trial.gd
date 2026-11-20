## 342 B3：材料倾向的配对试验 —— 同一张图（同种子）、同一条「每个搜索点都搜满」的路线，比较无倾向、×1.25、×1.5。
## 和 [MaterialSupplySurvey] 同一套假设：是地图机会的上限，不是玩家真拿得到的量；遭遇照样掷随机数，只是不打断。
## 每章每个方向出四个数：每图目标材料件数、每图材料总件数、材料的稀有度分布、目标材料里来自材料点的份额
## （「专属材料点访问率」要看玩家怎么走，这里只能给出材料点在目标材料里占多少）
class_name MaterialBiasTrial
extends RefCounted

const CHAPTERS: Array[StringName] = [&"free_mode", &"clockwork_hourglass"]
const MULTS: Array[float] = [1.0, 1.25, 1.5]


## 一张图搜满：[{"id", "kind": 材料点那一类（普通点 = 空）}]。搜过的次数事后清回去，同一张图能再搜一遍
static func haul_of(s: RunState, bias: Array, mult: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ev := s.events
	var sr := ev.rules.search if ev != null and ev.rules != null else null
	if sr == null:
		return out
	for id in s.map.node_ids():
		var node := s.map.get_node(id)
		if node.type != &"search":
			continue
		var before: Variant = node.content.get("searches", null)
		var session := SearchSession.new(node, sr, s.items, ev._rng_for(node, "search"), ev._depth_of(node))
		session.search_floor = SearchSession.floor_for(node, sr, ev.difficulty_def)
		session.produce = node.produce
		var kind := ev.search_kind_of(node)
		session.only_tags = kind.get("tags", [])
		session.other_share = float(kind.get("other_share", 0.0))
		session.bias_tags = bias
		session.bias_mult = mult
		var guard := 0
		while session.can_search() and guard < 32:
			session.search()
			guard += 1
		for got in session.found:
			out.append({"id": got, "kind": String(node.content.get("search_kind", ""))})
		if before == null:
			node.content.erase("searches")
		else:
			node.content["searches"] = before
	return out


## 一章：{方向: {倍率: {"maps", "target", "materials", "rarity": {档: 件}, "target_from_nodes"}}}
static func trial(chapter: ChapterDef, items: ItemDatabase, enemies: EnemyDatabase, seeds: Array) -> Dictionary:
	var out := {}
	for dir in MaterialBias.ORDER:
		if dir == MaterialBias.NONE:
			continue
		out[dir] = {}
		for m in MULTS:
			out[dir][m] = {"maps": 0, "target": 0, "materials": 0, "rarity": {}, "target_from_nodes": 0}
	for seed_ in seeds:
		var s := RunState.start(chapter, int(seed_), items, enemies)
		if s == null:
			continue
		for dir in out:
			for m in MULTS:
				var row: Dictionary = out[dir][m]
				row["maps"] = int(row["maps"]) + 1
				for got in haul_of(s, MaterialBias.tags_of(dir), m):
					var d := items.get_def(StringName(got["id"]))
					if d == null or not SearchSession.is_material(d):
						continue
					row["materials"] = int(row["materials"]) + 1
					row["rarity"][d.rarity] = int(row["rarity"].get(d.rarity, 0)) + 1
					if MaterialBias.is_target(d, dir):
						row["target"] = int(row["target"]) + 1
						if String(got["kind"]) != "":
							row["target_from_nodes"] = int(row["target_from_nodes"]) + 1
		s.dispose()
	return out


static func markdown(chapter_id: String, res: Dictionary) -> String:
	var lines: Array[String] = ["## %s" % chapter_id, ""]
	lines.append("| 方向 | 倍率 | 每图目标材料 | 其中普通搜索点 | 每图材料总数 | 材料稀有度（普通 / 优良 / 稀有 / 史诗 / 传说） | 目标材料里来自材料点 |")
	lines.append("|---|---|---|---|---|---|---|")
	for dir in res:
		for m in res[dir]:
			var r: Dictionary = res[dir][m]
			var maps := maxf(1.0, float(r["maps"]))
			var mats := maxf(1.0, float(r["materials"]))
			var shares: Array[String] = []
			for k in range(0, 5):
				shares.append("%.0f%%" % (100.0 * float(r["rarity"].get(k, 0)) / mats))
			lines.append("| %s | ×%.2f | %.2f | %.2f | %.1f | %s | %.0f%% |" % [String(dir), float(m), float(r["target"]) / maps,
				float(int(r["target"]) - int(r["target_from_nodes"])) / maps, float(r["materials"]) / maps,
				" / ".join(shares), 100.0 * float(r["target_from_nodes"]) / maxf(1.0, float(r["target"]))])
	return "\n".join(lines) + "\n"
