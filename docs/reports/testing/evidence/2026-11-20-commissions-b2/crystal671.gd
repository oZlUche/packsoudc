extends SceneTree
## 游戏测试 v6.71（报告 347）：四种晶石在搜索里出不出、出多少。用本章的搜索规则直接抽（和 test_author_093 同样开局），不走界面。
## 普通搜索点：深度 0.2 / 0.5 / 0.9 各 20000 次；符文堆（材料节点 runes：crystal / magic，other_share 0.25）同样。
## 记：每种晶石的件数和占比、碎晶对照、普通搜索里全部素材的件数
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const IDS := ["mist_crystal", "smoky_crystal", "prism_crystal", "amethyst_pillar", "crystal_shards"]


func _initialize() -> void:
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var st := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, kit.items)
	var rules: SearchRules = st.events.rules.search
	var items: ItemDatabase = c.items
	var cands := SearchSession.candidates(rules, items)
	var inpool := []
	for id in IDS:
		var d := items.get_def(StringName(id))
		inpool.append("%s（%s，稀有度 %d，%s，在候选里 %s）" % [id, Names.of(d), d.rarity, "%d 格" % ItemVolume.cells_of(d), str(cands.has(StringName(id)))])
	print("C671 章 %s；候选 %d 件；%s" % [String(c.chapter.id), cands.size(), "；".join(inpool)])
	var kinds: Dictionary = st.events.rules.search_kinds
	print("C671 材料节点种类：%s" % str(kinds.keys()))
	var rng := RandomNumberGenerator.new()
	for mode in ["普通", "符文堆"]:
		var only: Array = []
		var share := 0.0
		if mode == "符文堆":
			if not kinds.has("runes"): print("C671 没找到 runes"); continue
			only = kinds["runes"].get("tags", [])
			share = float(kinds["runes"].get("other_share", 0.0))
		for depth in [0.2, 0.5, 0.9]:
			rng.seed = 671
			var cnt := {}
			var total := 0
			var mats := 0
			for i in 20000:
				for id in SearchSession.draw_items(rules, items, depth, 0, rng, -1, [] as Array[int], {}, only, share):
					total += 1
					var k := String(id)
					cnt[k] = int(cnt.get(k, 0)) + 1
					var d := items.get_def(id)
					if d != null and d.tags.has(&"material"): mats += 1
			var row := []
			for id in IDS:
				var n := int(cnt.get(id, 0))
				row.append("%s %d（%.2f%%）" % [Names.of(items.get_def(StringName(id))), n, 100.0 * n / maxf(1, total)])
			print("C671 %s 深度 %.1f：共 %d 件、素材 %d 件；%s" % [mode, depth, total, mats, "；".join(row)])
	quit(0)
