## 搜索点（M4-3，架构文档 6.2 / 5.4.2）：搜几次是玩家的旋钮，每搜一次更险、找到的东西随深度更稀有。
extends RefCounted


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _rules() -> SearchRules:
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var nr: NodeRules = load(ContentPaths.asset_file("node_rules", String(chapter.node_rules)))
	return nr.search


static func _node(danger: int = 0) -> MapNode:
	var n := MapNode.new()
	n.id = 1
	n.type = &"search"
	n.danger = danger
	n.content_seed = 77
	return n


static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


static func run_draw(t: TestCase) -> void:
	t.begin("搜索 · 找到什么：件数在范围内、不带排除标签、不是包、稀有度随深度上偏")

	var items := _items()
	var rules := _rules()
	var cands := SearchSession.candidates(rules, items)
	t.check(cands.size() > 5, "候选有 %d 件" % cands.size())
	for id in cands:
		var d := items.get_def(id)
		t.check(rules.include_bags or not d.is_bag, "'%s' 不是包" % id)
		for tag in rules.exclude_tags:
			t.check(not d.tags.has(tag), "'%s' 不带排除标签 %s" % [id, tag])
	t.check(SearchSession.candidates(rules, items, 0).size() < cands.size(), "稀有度上限 0 收窄候选")
	for id in SearchSession.candidates(rules, items, 0):
		t.eq(items.get_def(id).rarity, 0, "上限 0 下只有普通品")

	var rng := _rng(1)
	var bad_count := 0
	var bad_id := 0
	for i in 50:
		var got := SearchSession.draw_items(rules, items, 0.5, 0, rng)
		if got.size() < rules.items_per_search.x or got.size() > rules.items_per_search.y:
			bad_count += 1
		for id in got:
			if not cands.has(id):
				bad_id += 1
	t.eq(bad_count, 0, "五十次里每次找到的件数都在 [%d, %d] 里" % [rules.items_per_search.x, rules.items_per_search.y])
	t.eq(bad_id, 0, "找到的都在候选里")

	# 深度把稀有度往上推（depth_gain > 0 时）
	var sum_out := 0.0
	var sum_in := 0.0
	var n := 0
	rng = _rng(2)
	for i in 1500:
		for id in SearchSession.draw_items(rules, items, 0.0, 0, rng):
			sum_out += items.get_def(id).rarity
			n += 1
	var m := 0
	rng = _rng(2)
	for i in 1500:
		for id in SearchSession.draw_items(rules, items, 1.0, 0, rng):
			sum_in += items.get_def(id).rarity
			m += 1
	if rules.depth_gain > 0.0:
		t.check(sum_in / m > sum_out / n, "最内（平均稀有度 %.2f）比最外（%.2f）稀有" % [sum_in / m, sum_out / n])
	var w0 := rules.rarity_weight(3, 0.0, 0)
	t.check(rules.rarity_weight(3, 1.0, 0) >= w0 and rules.rarity_weight(3, 0.0, 2) >= w0, "深度与危险都只往上偏")
	t.eq(rules.rarity_weight(0, 1.0, 2), rules.rarity_weights[0], "稀有度 0 的权重不受深度与危险影响（乘的是稀有度）")

	# 同种子同结果
	t.eq(SearchSession.draw_items(rules, items, 0.3, 1, _rng(5)), SearchSession.draw_items(rules, items, 0.3, 1, _rng(5)), "同种子找到的一样")


static func run_session(t: TestCase) -> void:
	t.begin("搜索 · 一次会话：搜到满、随时走、遭遇即止、进度跟着图存")

	var items := _items()
	var rules := _rules()

	var node := _node()
	var s := SearchSession.new(node, rules, items, _rng(3), 0.2)
	t.check(s.can_search(), "一开始能搜")
	t.eq(s.searches_left(), rules.max_searches, "还能搜 max_searches 次")
	t.eq(s.next_encounter_chance(), rules.encounter_chance(0), "下一次的遭遇概率是曲线第 0 档")
	var ends: Array[StringName] = []
	s.ended.connect(func(why: StringName): ends.append(why))
	var searched_log: Array = []   # 数组：lambda 捕获的是值，改不了外面的 int
	s.searched.connect(func(_f: Array[StringName], _e: Dictionary): searched_log.append(1))
	# 没有 encounter_builder：掷中也不算遭遇，一路搜到满
	var k := 0
	while s.can_search():
		var r := s.search()
		t.check(not r.is_empty(), "第 %d 次搜得到东西" % k)
		t.check((r["encounter"] as Dictionary).is_empty(), "没有敌人池就没有遭遇")
		k += 1
	t.eq(k, rules.max_searches, "搜了 max_searches 次就停")
	t.eq(searched_log.size(), k, "每次都发了 searched")
	t.check(s.active and s.is_exhausted() and ends.is_empty(), "搜满了会话不自动结束（084：最后一次的收获留给玩家亮出来、拖走）")
	s.leave()
	t.eq(ends, [&"exhausted"] as Array[StringName], "搜满了才走：结束原因是搜满")
	t.check(not s.can_search() and s.search().is_empty(), "满了再搜是空")
	t.eq(int(node.content["searches"]), k, "搜过几次记在节点内容里")
	t.check(s.found.size() >= k * rules.items_per_search.x, "找到的东西累计（%d 件）" % s.found.size())
	var haul := s.haul()
	t.eq(haul.item_count(), s.found.size(), "收获全摆进了容器（%s）" % str(haul.size))

	# 从记录接着搜：剩下的次数少了
	var node2 := _node()
	node2.content["searches"] = rules.max_searches - 1
	var s2 := SearchSession.new(node2, rules, items, _rng(3))
	t.eq(s2.searches_left(), 1, "读档回来只剩一次")
	t.eq(s2.next_encounter_chance(), rules.encounter_chance(rules.max_searches - 1), "遭遇概率按第几次算")

	# 随时走
	var s3 := SearchSession.new(_node(), rules, items, _rng(4))
	var left: Array[StringName] = []
	s3.ended.connect(func(why: StringName): left.append(why))
	s3.search()
	s3.leave()
	t.eq(left, [&"left"] as Array[StringName], "自己走：ended(left)")
	t.check(not s3.can_search(), "走了就不能再搜")
	s3.leave()
	t.eq(left.size(), 1, "再走一次不重复发")

	# 遭遇：曲线全 1 + 有敌人 → 第一次就遭遇、会话结束
	var hot := SearchRules.new()
	hot.encounter_curve = [1.0] as Array[float]
	var s4 := SearchSession.new(_node(), hot, items, _rng(5))
	s4.encounter_builder = func() -> Dictionary: return {"enemy": "raider", "strength": 0, "board": [4, 3], "items": []}
	var why4: Array[StringName] = []
	s4.ended.connect(func(why: StringName): why4.append(why))
	var r4 := s4.search()
	t.check(not (r4["encounter"] as Dictionary).is_empty(), "遭遇了")
	t.eq(String(s4.encounter["enemy"]), "raider", "遭遇的敌人记在会话里")
	t.eq(why4, [&"encounter"] as Array[StringName], "遭遇即止")
	t.check(not s4.can_search(), "遭遇之后不能再搜")

	var cold := SearchRules.new()
	cold.encounter_curve = [0.0] as Array[float]
	cold.max_searches = 5
	var s5 := SearchSession.new(_node(), cold, items, _rng(6))
	s5.encounter_builder = func() -> Dictionary: return {"enemy": "raider"}
	var met := false
	for i in 5:
		if not (s5.search().get("encounter", {}) as Dictionary).is_empty():
			met = true
	t.check(not met, "概率 0 永远不遭遇")

	# 频率对得上曲线：第一次搜按 0.3，一千个会话
	var p := SearchRules.new()
	p.encounter_curve = [0.3] as Array[float]
	var hits := 0
	for i in 1000:
		var sx := SearchSession.new(_node(), p, items, _rng(1000 + i))
		sx.encounter_builder = func() -> Dictionary: return {"enemy": "raider"}
		if not (sx.search()["encounter"] as Dictionary).is_empty():
			hits += 1
	t.check(hits > 240 and hits < 360, "概率 0.3 一千次遭遇 %d 次" % hits)

	# 同种子同结果
	var a := SearchSession.new(_node(), rules, items, _rng(8))
	var b := SearchSession.new(_node(), rules, items, _rng(8))
	a.search()
	b.search()
	t.eq(a.found, b.found, "同种子第一次找到的一样")


static func run_haul_box(t: TestCase) -> void:
	t.begin("搜索 · 收获容器逐次装（M6-2）：亮出来的能拿走；放不下就换高一格的容器，东西原位搬过去")

	var items := _items()
	var rules := _rules()
	var s := SearchSession.new(_node(), rules, items, _rng(3), 0.3)
	t.eq(s.haul_box.size, rules.haul_board, "开着的会话有一个空容器，大小按规则")
	t.eq(s.haul_box.item_count(), 0, "开始是空的")
	s.search()
	t.eq(s.haul_box.item_count(), s.found.size(), "搜一次，找到的都在容器里")
	t.eq(s.haul(), s.haul_box, "haul() 就是这个容器")
	if s.can_search():
		s.search()
	t.eq(s.haul_box.item_count(), s.found.size(), "再搜，累计")
	if s.haul_box.item_count() > 0:
		var first := s.haul_box.items()[0] as ItemInstance
		var stash := ItemStash.new(9)
		t.check(InventoryService.transfer_auto(s.haul_box, first.uid, stash), "从容器里拿走一件")
		t.eq(s.haul().item_count(), s.found.size() - 1, "haul() 少了那一件，found 照旧记着")

	# 小容器：三件放不进 2×1，换高一格的；东西原位搬过去、uid 不变
	var tiny := rules.duplicate() as SearchRules
	tiny.haul_board = Vector2i(2, 1)
	tiny.items_per_search = Vector2i(3, 3)
	tiny.max_searches = 2
	var s2 := SearchSession.new(_node(), tiny, items, _rng(5), 0.3)
	var swaps: Array = []
	s2.haul_changed.connect(func(box: GridInventory): swaps.append(box))
	s2.search()
	t.check(s2.haul_box.size.y > 1, "换了更高的容器（%s）" % str(s2.haul_box.size))
	t.check(s2.haul_box.size.y <= tiny.haul_board.y * 2, "至多加高到两倍")
	t.check(not swaps.is_empty() and swaps[-1] == s2.haul_box, "haul_changed 报的是现在的容器")
	var uids_before: Array = []
	for inst in s2.haul_box.items():
		uids_before.append((inst as ItemInstance).uid)
	s2.search()
	for uid in uids_before:
		t.check(s2.haul_box.has_item(int(uid)), "第二次搜之后，第一次的 uid %d 还在" % uid)

	# LootPacker.add 直接试：加到两倍就停，装不下的报回来
	var box := GridInventory.new(Vector2i(2, 1), 0, false)
	var r := LootPacker.add(box, [&"armor", &"armor", &"armor"] as Array[StringName], items, 1)
	t.eq((r["board"] as GridInventory).size, Vector2i(2, 2), "2×1 加到 2×2 就停")
	t.eq((r["board"] as GridInventory).item_count(), 1, "装进一件防弹衣（2×2）")
	t.eq((r["left"] as Array).size(), 2, "另两件报回来")
