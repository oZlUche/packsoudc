## 127（作者定）：搜索点保底 —— 常规点每次至少两件（稀有度不保）；进阶点（高危区）用高一阶难度那一行；
## 每行是逐件稀有度下限（[2, 1, 1] = 一蓝两绿）；难度覆盖 > 阶梯，节点内容 > 难度
extends RefCounted


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


static func _node(danger: int, content: Dictionary = {}) -> MapNode:
	var n := MapNode.new()
	n.type = &"search"
	n.danger = danger
	n.content = content
	return n


static func _diff(level: int, floors: Dictionary = {}) -> DifficultyDef:
	var d := DifficultyDef.new()
	d.level = level
	d.search_floors = floors
	return d


## 抽出来的稀有度从高到低，和下限从高到低逐项比：每一项都够才算满足（「一蓝两绿」= 至少一件 ≥ 蓝、再两件 ≥ 绿）
static func _meets(got: Array[StringName], items: ItemDatabase, p_floor: Array[int]) -> bool:
	var rs: Array[int] = []
	for id in got:
		rs.append(items.get_def(id).rarity)
	rs.sort()
	rs.reverse()
	var fs := p_floor.duplicate()
	fs.sort()
	fs.reverse()
	if rs.size() < fs.size():
		return false
	for i in fs.size():
		if rs[i] < fs[i]:
			return false
	return true


static func run(t: TestCase) -> void:
	var items := ItemDatabase.new()
	items.load_dir()
	var rules: SearchRules = (load(ContentPaths.asset_file("node_rules", "standard")) as NodeRules).search
	var floors := rules.search_floors

	t.begin("127 · 标准节点规则的阶梯：普通 [0,0]、进阶 1 [1,0]、进阶 2 [1,1,0]、进阶 3 [2,1,1]")
	t.eq(floors, [[0, 0], [1, 0], [1, 1, 0], [2, 1, 1]], "四行")
	t.eq(rules.floor_row(4), [3, 1, 1] as Array[int], "超出表长：末行、第一项抬一阶")
	var five := SearchRules.new()
	five.search_floors = [[5, 0]]
	t.eq(five.floor_row(3), [5, 0] as Array[int], "抬到 5 封顶")
	var prologue: NodeRules = load(ContentPaths.asset_file("node_rules", "prologue"))
	t.check(prologue.search == null or prologue.search.search_floors.is_empty(), "序章不保底")

	t.begin("127 · 哪种点用哪一行：常规 = level 行，高危 = level + 1 行；search_tier 能压回 / 指定")
	t.eq(SearchSession.floor_for(_node(0), rules, null), [0, 0] as Array[int], "普通难度、常规点：两件任意")
	t.eq(SearchSession.floor_for(_node(1), rules, null), [1, 0] as Array[int], "普通难度、高危点：进阶 1 的行")
	t.eq(SearchSession.floor_for(_node(0), rules, _diff(1)), [1, 0] as Array[int], "进阶 1、常规点：进阶 1 的行")
	t.eq(SearchSession.floor_for(_node(2), rules, _diff(1)), [1, 1, 0] as Array[int], "进阶 1、高危点：进阶 2 的行")
	t.eq(SearchSession.floor_for(_node(1, {"search_tier": "normal"}), rules, null), [0, 0] as Array[int], "search_tier normal 压回常规")
	t.eq(SearchSession.floor_for(_node(0, {"search_tier": "advanced"}), rules, null), [1, 0] as Array[int], "search_tier advanced 直接指定")
	t.check(SearchSession.is_advanced(_node(2)) and not SearchSession.is_advanced(_node(0)), "高危区里的是进阶")

	t.begin("127 · 优先级：节点内容 > 难度覆盖 > 阶梯")
	var over := _diff(1, {"normal": [2, 2]})
	t.eq(SearchSession.floor_for(_node(0), rules, over), [2, 2] as Array[int], "难度覆盖盖过阶梯（常规）")
	t.eq(SearchSession.floor_for(_node(1), rules, over), [1, 1, 0] as Array[int], "没写 advanced：高危点沿用阶梯")
	t.eq(SearchSession.floor_for(_node(0, {"search_floor": [3]}), rules, over), [3] as Array[int], "节点内容盖过难度")

	t.begin("127 · 普通难度常规点：每次至少两件，稀有度不保（大样本里有全白的）")
	var rng := _rng(1)
	var all_white := 0
	var short := 0
	for i in 400:
		var got := SearchSession.draw_items(rules, items, 0.0, 0, rng, -1, [0, 0] as Array[int])
		if got.size() < 2:
			short += 1
		var white := true
		for id in got:
			if items.get_def(id).rarity > 0:
				white = false
		if white:
			all_white += 1
	t.eq(short, 0, "四百次都至少两件")
	t.check(all_white > 0, "有全白的（%d 次）—— 稀有度不保" % all_white)

	t.begin("127 · 逐件下限：[1,0] 第一件 ≥ 绿；[2,1,1] 三件分别达标（一蓝两绿，不是全蓝或全绿）")
	var f2_mix: Array[int] = [2, 1, 1]
	for p_floor in [[1, 0], [2, 1, 1], [1, 1, 0]]:
		var f: Array[int] = []
		f.assign(p_floor)
		var bad := 0
		var exact_mix := 0
		rng = _rng(7)
		for i in 400:
			var got := SearchSession.draw_items(rules, items, 0.0, 0, rng, -1, f)
			if not _meets(got, items, f):
				bad += 1
			if f == f2_mix and got.size() == 3:
				var rs: Array[int] = []
				for id in got:
					rs.append(items.get_def(id).rarity)
				if rs.min() < 2:
					exact_mix += 1
		t.eq(bad, 0, "%s：四百次都达标" % [f])
		if f == f2_mix:
			t.check(exact_mix > 0, "[2,1,1] 不是要么全蓝：有 %d 次里有件低于蓝" % exact_mix)

	t.begin("127 · 那一档以上没有就往下放宽；rarity_cap 夹住地板")
	var narrow := SearchRules.new()
	narrow.rarity_weights = rules.rarity_weights
	narrow.items_per_search = Vector2i(1, 1)
	var got_cap := SearchSession.draw_items(narrow, items, 0.0, 0, _rng(3), 0, [3, 3] as Array[int])
	t.eq(got_cap.size(), 2, "两件")
	for id in got_cap:
		t.eq(items.get_def(id).rarity, 0, "rarity_cap 0：地板夹到 0、不卡死")
	var got_hi := SearchSession.draw_items(narrow, items, 0.0, 0, _rng(3), -1, [5] as Array[int])
	t.eq(got_hi.size(), 1, "下限 5（库里可能没有）：放宽后照样抽到一件")

	t.begin("127 · 同种子两次一样；没有保底时和以前一样（不多耗随机数）")
	var f2: Array[int] = [2, 1, 1]
	t.eq(SearchSession.draw_items(rules, items, 0.3, 1, _rng(9), -1, f2), SearchSession.draw_items(rules, items, 0.3, 1, _rng(9), -1, f2), "同种子相同")
	var a := SearchSession.draw_items(rules, items, 0.3, 1, _rng(9))
	var b := SearchSession.draw_items(rules, items, 0.3, 1, _rng(9), -1, [] as Array[int])
	t.eq(a, b, "空保底 = 老抽法")

	t.begin("127 · 说明文字：一件绿及以上、两件任意")
	t.eq(SearchSession.floor_text([1, 0, 0] as Array[int]), "一件绿及以上、两件任意", "[1,0,0]")
	t.eq(SearchSession.floor_text([2, 1, 1] as Array[int]), "一件蓝及以上、两件绿及以上", "[2,1,1]")
	t.eq(SearchSession.floor_text([0, 0] as Array[int]), "两件任意", "[0,0]")

	t.begin("127 · 导入器：保底行每项 0～5；难度覆盖的键只认 normal / advanced")
	var ctx := ContentImporter.Context.new()
	for pair in [[{"id": "x", "level": 1, "search_floors": {"normal": [1, 0]}}, true], [{"id": "x", "level": 1, "search_floors": {"hard": [1]}}, false], [{"id": "x", "level": 1, "search_floors": {"advanced": [9]}}, false]]:
		var report := ImportReport.new()
		var d := ContentImporter.import_difficulty(pair[0], ctx, report)
		t.eq(report.ok(), pair[1], "%s：%s" % [pair[0]["search_floors"], "通过" if pair[1] else "拦下"])
		if pair[1]:
			t.eq(d.search_floors["normal"], [1, 0], "读成整数")

	t.begin("127 · 节点浮窗：进阶搜索点第一行写明")
	var tip := NodeTooltip.text_for(null, null, _node(1))
	t.check(tip.begins_with("[color=#f0ad4e]进阶搜索点"), "高危区的搜索点：%s" % tip.left(30))
	t.check(not NodeTooltip.text_for(null, null, _node(0)).contains("进阶搜索点"), "常规点不写")
