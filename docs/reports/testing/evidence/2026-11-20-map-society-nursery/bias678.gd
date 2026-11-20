extends SceneTree
## 游戏测试 v6.78（报告 351）：材料倾向只在普通搜索里、只在材料之间重分。用本章的搜索规则直接抽，不走界面。
## 每个方向（无 / 五个方向）× 深度 0.2 / 0.9 各 6000 次，同一随机数种子。记：件数、非材料件数、材料件数、
## 目标系占材料的比、材料每档稀有度的件数。另外把材料节点（only_tags 非空）带倾向和不带倾向用同一种子各抽 5000 次，逐次比对。
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


func _initialize() -> void:
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var st := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, kit.items)
	var rules: SearchRules = st.events.rules.search
	var items: ItemDatabase = c.items
	print("B678 章 %s；候选 %d 件；倍率 %s" % [String(c.chapter.id), SearchSession.candidates(rules, items).size(), str(MaterialBias.MULT)])
	var rng := RandomNumberGenerator.new()
	for depth in [0.2, 0.9]:
		for dir in MaterialBias.ORDER:
			var tags := MaterialBias.tags_of(dir)
			rng.seed = 678
			var total := 0
			var non := 0
			var mats := 0
			var hit := 0
			var byr := {}
			var hit_any := {}
			for i in 6000:
				for id in SearchSession.draw_items(rules, items, depth, 0, rng, -1, [] as Array[int], {}, [], 0.0, tags, MaterialBias.MULT):
					total += 1
					var d := items.get_def(id)
					if not SearchSession.is_material(d):
						non += 1; continue
					mats += 1
					byr[d.rarity] = int(byr.get(d.rarity, 0)) + 1
					for k in MaterialBias.ORDER:
						if k != MaterialBias.NONE and MaterialBias.is_target(d, k): hit_any[k] = int(hit_any.get(k, 0)) + 1
			var shares := []
			for k in MaterialBias.ORDER:
				if k == MaterialBias.NONE: continue
				shares.append("%s %.1f%%" % [String(k), 100.0 * int(hit_any.get(k, 0)) / maxf(1, mats)])
			var rs := []
			for r in [0, 1, 2, 3, 4, 5]:
				if byr.has(r): rs.append("%d档 %d" % [r, int(byr[r])])
			print("B678 深度 %.1f 方向 %-8s：共 %d 件，非材料 %d，材料 %d；材料里各系 %s；材料稀有度 %s" % [depth, String(dir) if dir != &"" else "无", total, non, mats, "、".join(shares), "、".join(rs)])
	# 材料节点：带不带倾向逐次相同
	var kinds: Dictionary = st.events.rules.search_kinds
	for kk in kinds.keys():
		var only: Array = kinds[kk].get("tags", [])
		var share := float(kinds[kk].get("other_share", 0.0))
		var diff := 0
		var r1 := RandomNumberGenerator.new()
		var r2 := RandomNumberGenerator.new()
		r1.seed = 99; r2.seed = 99
		for i in 2000:
			var a := SearchSession.draw_items(rules, items, 0.5, 0, r1, -1, [] as Array[int], {}, only, share)
			var b := SearchSession.draw_items(rules, items, 0.5, 0, r2, -1, [] as Array[int], {}, only, share, MaterialBias.tags_of(&"plant"), MaterialBias.MULT)
			if a != b: diff += 1
		print("B678 材料节点 %s（%s，从普通池抽 %.2f）：带「草木」倾向和不带，2000 次里不一样的 %d 次" % [kk, str(only), share, diff])
	quit(0)
