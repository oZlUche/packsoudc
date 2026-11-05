## 283（作者 2026-11-05 12:42）：出征页「倾向」删了，改成每张地图自带自己的材料节点 —— 机关沙漏按段配：
## 两半各 mine 1 + remains 1（产物 crafted 2 / mineral 1.5），颈部 runes 1（crystal 2），不放 grove；每章材料节点至少 2 个
extends RefCounted


static func _chapter() -> ChapterDef:
	return load(ContentPaths.asset_file("chapters", "clockwork_hourglass"))


static func run_config(t: TestCase) -> void:
	t.begin("283 · 机关沙漏的配置：两半 mine 1 + remains 1、颈部 runes 1，一共 5 个；魔法废墟也够 2 个")
	var cfg := _chapter().map_source.generator_config as HourglassMapConfig
	t.eq(cfg.side_material_nodes, {"mine": 1, "remains": 1}, "两半各一份")
	t.eq(cfg.neck_material_nodes, {"runes": 1}, "颈部符文堆")
	t.check(not cfg.side_material_nodes.has("grove") and not cfg.neck_material_nodes.has("grove"), "不放林地")
	t.eq(cfg.material_node_count(), 5, "一共 5 个")
	var ring: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	t.check((ring.map_source.generator_config as RingMapConfig).material_node_count() >= ContentImporter.MIN_MATERIAL_NODES, "魔法废墟够数")


static func run_generate(t: TestCase) -> void:
	t.begin("283 · 生成：每段的点带这段的产物表；材料节点只落在普通搜索点上、种类对得上段；每段配额落满（搜索点不够时普通战斗点改搜索点，再不够用事件 / 随机 / 宝箱，v5.30），别的类型和不配材料时一模一样")
	var c := _chapter()
	for scale in [&"small", &"medium", &"large"]:
		var cfg := (c.map_source.generator_config as HourglassMapConfig).duplicate(true) as HourglassMapConfig
		cfg.apply_scale(scale)
		var bare := cfg.duplicate(true) as HourglassMapConfig
		bare.side_material_nodes = {}
		bare.neck_material_nodes = {}
		bare.side_produce = {}
		bare.neck_produce = {}
		var last := cfg.row_count() - 1
		var kinds := 0
		for seed_ in [3, 11, 29]:
			var g := HourglassMapGenerator.new().generate(cfg, seed_)
			var g0 := HourglassMapGenerator.new().generate(bare, seed_)
			var tag := "%s / 种子 %d" % [scale, seed_]
			t.check(g != null and g0 != null, "%s 生成得出来" % tag)
			if g == null or g0 == null:
				continue
			t.check(g.node_ids().all(func(id: int) -> bool: return g.get_node(id).type == g0.get_node(id).type or (["battle", "event", "random", "chest"].has(String(g0.get_node(id).type)) and g.get_node(id).type == &"search" and g.get_node(id).content.has("search_kind"))), "%s：改了类型的只有战斗 / 事件 / 随机 / 宝箱点，改成材料节点" % tag)
			for seg in cfg.segments():
				var got := {}
				for id in g.node_ids():
					var r := int(g.get_node(id).layout.get("row", 0))
					var k := String(g.get_node(id).content.get("search_kind", ""))
					if k != "" and r >= int(seg["from"]) and r <= int(seg["to"]):
						got[k] = int(got.get(k, 0)) + 1
				t.eq(got, seg.get("material_nodes", {}), "%s：第 %d–%d 层配额落满" % [tag, int(seg["from"]), int(seg["to"])])
			for id in g.node_ids():
				var n := g.get_node(id)
				var r := int(n.layout.get("row", 0))
				var neck := r >= cfg.half_rows and r <= last - cfg.half_rows
				t.eq(n.produce, {"crystal": 2.0} if neck else {"crafted": 2.0, "mineral": 1.5}, "%s：点 %d 的产物表按段" % [tag, id])
				var k := String(n.content.get("search_kind", ""))
				if k == "":
					continue
				kinds += 1
				t.eq(n.type, &"search", "材料节点是普通搜索点")
				t.check(not n.layout.has("fixed"), "不是固定点")
				t.check((["runes"] if neck else ["mine", "remains"]).has(k), "%s：%s 落在%s" % [tag, k, "颈部" if neck else "半边"])
		t.check(kinds > 0, "%s：有材料节点" % scale)


static func run_import_warns(t: TestCase) -> void:
	t.begin("283 · 校验：随机图的章节材料节点不到 2 个就警告；预设图的序章不查")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/chapters/clockwork_hourglass.json"))
	var r := ImportReport.new()
	ContentImporter.import_chapter(data, ContentImporter.Context.new(), r)
	t.check(not r.to_text().contains("材料节点"), "机关沙漏不警告")
	var few: Dictionary = data.duplicate(true)
	few["map_source"]["generator_config"]["side_material_nodes"] = {}
	few["map_source"]["generator_config"]["neck_material_nodes"] = {"runes": 1}
	var r2 := ImportReport.new()
	ContentImporter.import_chapter(few, ContentImporter.Context.new(), r2)
	t.check(r2.to_text().contains("材料节点一共 1 个"), "只有 1 个：警告（%s）" % r2.to_text())
	var pro: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/chapters/prologue.json"))
	var r3 := ImportReport.new()
	ContentImporter.import_chapter(pro, ContentImporter.Context.new(), r3)
	t.check(not r3.to_text().contains("材料节点"), "序章（预设图）不查")


static func run_ring(t: TestCase) -> void:
	t.begin("283 §四 4（v5.31）· 魔法废墟：材料节点只落在路线外或搜索路线上，混合 / 战斗路线一个不动；放不下的溢到外环，种类不变；中档 6 环每张落满 8 个")
	var ch: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	for pair in [[&"small", 4], [&"medium", 6]]:
		var cfg := (ch.map_source.generator_config as RingMapConfig).duplicate(true) as RingMapConfig
		cfg.apply_scale(pair[0], pair[1])
		var kinds_want := {}
		for r in range(1, cfg.ring_count() + 1):
			var sp := cfg.spec_for_ring(r)
			if sp != null:
				for k in sp.material_nodes:
					kinds_want[String(k)] = int(kinds_want.get(String(k), 0)) + int(sp.material_nodes[k])
		for seed_ in [2, 7, 19]:
			var g := RingMapGenerator.new().generate(cfg, seed_)
			var tag := "%s %d 环 / 种子 %d" % [pair[0], pair[1], seed_]
			t.not_null(g, "%s 生成得出来" % tag)
			if g == null:
				continue
			var kinds := {}
			var bad := []
			for id in g.node_ids():
				var n := g.get_node(id)
				var k := String(n.content.get("search_kind", ""))
				if k == "":
					continue
				kinds[k] = int(kinds.get(k, 0)) + 1
				if n.type != &"search":
					bad.append(id)
				for r in g.routes:
					if (r["node_ids"] as Array).has(id) and String(r.get("style", "")) != "search":
						bad.append(id)
			t.eq(bad, [], "%s：材料节点都是搜索点、不在混合 / 战斗路线上" % tag)
			t.check(kinds.keys().all(func(k) -> bool: return int(kinds[k]) <= int(kinds_want.get(k, 0))), "%s：每种不超过配置（%s）" % [tag, kinds])
			if pair[0] == &"medium":
				t.eq(kinds, kinds_want, "%s：落满" % tag)
