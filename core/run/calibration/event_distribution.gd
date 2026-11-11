## 常规事件的分布（报告 303，事件方案 2026-11-11 §10.3）：固定种子开一批局，数每张图上各事件出现几处、几张图有、
## 有几张图连一处信仰事件都没有、事件点（含随机点揭成事件的可能）有多少。只看生成时定进节点的，随机点揭开时现配的不算（要走到才知道）。
## 命令行外壳 `tools/event_distribution.gd`；单元测试读 [method survey]
class_name EventDistribution
extends RefCounted


## {"maps": 张数, "events": {事件 id: {"maps": 几张图有, "total": 一共几处, "max": 一张图最多几处}}, "faith_maps": 有信仰事件的图, "event_nodes": 事件点总数, "failed": 开不出来的种子}
static func survey(chapter: ChapterDef, items: ItemDatabase, enemies: EnemyDatabase, seeds: Array) -> Dictionary:
	var out := {"maps": 0, "events": {}, "faith_maps": 0, "event_nodes": 0, "failed": 0}
	for seed_ in seeds:
		var s := RunState.start(chapter, int(seed_), items, enemies)
		if s == null:
			out["failed"] = int(out["failed"]) + 1
			continue
		out["maps"] = int(out["maps"]) + 1
		var here := {}
		var faith := false
		for id in s.map.node_ids():
			var node := s.map.get_node(id)
			if node.type == &"event":
				out["event_nodes"] = int(out["event_nodes"]) + 1
			var eid := String(node.content.get("event", ""))
			if eid == "":
				continue
			here[eid] = int(here.get(eid, 0)) + 1
			if String(node.content.get("event_group", "")) == "faith_call":
				faith = true
		if faith:
			out["faith_maps"] = int(out["faith_maps"]) + 1
		for eid in here:
			var row: Dictionary = (out["events"] as Dictionary).get_or_add(eid, {"maps": 0, "total": 0, "max": 0})
			row["maps"] = int(row["maps"]) + 1
			row["total"] = int(row["total"]) + int(here[eid])
			row["max"] = maxi(int(row["max"]), int(here[eid]))
		s.dispose()
	return out


static func markdown(chapter_id: String, r: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("## %s：%d 张图（开不出 %d）" % [chapter_id, r["maps"], r["failed"]])
	lines.append("")
	lines.append("事件点共 %d 个；有信仰事件的图 %d 张。" % [r["event_nodes"], r["faith_maps"]])
	lines.append("")
	lines.append("| 事件 | 有它的图 | 一共几处 | 一张图最多 |")
	lines.append("|---|---|---|---|")
	var ids: Array = (r["events"] as Dictionary).keys()
	ids.sort()
	for eid in ids:
		var row: Dictionary = r["events"][eid]
		lines.append("| %s | %d | %d | %d |" % [eid, row["maps"], row["total"], row["max"]])
	return "\n".join(lines) + "\n"
