## 165（作者定）：敌人棋盘只写死「相邻组合」，其余道具按整理的办法随机摆 ——
## 组合（箭挨着弓、魔晶石挨着法杖）整组摆、组内真的挨着生效；散件在放得下的位置里随机挑；同一个种子永远一样；
## 摆不开就重来、最后按老办法保底；预设图的敌人不写位置，开局摆一次、记进内容
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode")


static func _ids(a: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for x in a:
		out.append(StringName(String(x)))
	return out


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## 内容 → 棋盘上第一件 id 的实例
static func _find(board: GridInventory, id: StringName) -> ItemInstance:
	for inst in board.items():
		if (inst as ItemInstance).def.id == id:
			return inst
	return null


## [param giver] 的增益格（按编译器的点亮规则）照得到哪几件
static func _lit_by(board: GridInventory, giver: ItemInstance) -> Array[int]:
	var p := giver.def.adjacency
	return BattleCompiler._lit_neighbors(board, giver, p.grant_cells, p.grant_filter)


static func run_auto_groups(t: TestCase) -> void:
	t.begin("165 · 组合从道具定义里推：箭配弓、晶石配法杖；没有对象的箭是散件；combos 写了的整组、不参与自动配对")
	var c := _content()
	var picks := _ids(["longbow", "arrows", "salve"])
	var g := EnemyPlacer.auto_groups(picks, c.items, _rng(1))
	t.eq(g.size(), 1, "一组")
	if g.size() == 1:
		t.eq(_ids((g[0] as Array).map(func(i): return picks[i])), _ids(["longbow", "arrows"]), "长弓是锚、箭跟着；药膏是散件")
	g = EnemyPlacer.auto_groups(_ids(["arrows", "knife", "salve"]), c.items, _rng(1))
	t.eq(g.size(), 0, "抽到箭没有弓：箭当散件")
	picks = _ids(["magic_staff", "fire_crystal", "knife"])
	g = EnemyPlacer.auto_groups(picks, c.items, _rng(1))
	t.eq(g.size(), 1, "法杖 + 火晶石（站在杖的受益格上供给）成组")
	if g.size() == 1:
		t.check((g[0] as Array).has(0) and (g[0] as Array).has(1) and not (g[0] as Array).has(2), "小刀不在组里")
	picks = _ids(["longbow", "arrows", "arrows", "salve"])
	g = EnemyPlacer.auto_groups(picks, c.items, _rng(1))
	t.eq(g.size(), 1, "两袋箭都配给同一把弓：一组三件")
	if g.size() == 1:
		t.eq((g[0] as Array).size(), 3, "三件")
	var who := EnemyDef.new()
	who.combos = [["salve", "knife"]]
	picks = _ids(["knife", "salve", "longbow", "arrows"])
	g = EnemyPlacer.auto_groups(picks, c.items, _rng(1), who)
	t.eq(g.size(), 2, "写了的组合一组 + 自动的一组")
	if g.size() == 2:
		t.eq(_ids((g[0] as Array).map(func(i): return picks[i])), _ids(["salve", "knife"]), "combos 照写的先后")
	who.combos = [["salve", "shortbow"]]
	g = EnemyPlacer.auto_groups(picks, c.items, _rng(1), who)
	t.eq(g.size(), 1, "组合里的件没抽全：不成组，只剩自动的那组")


static func run_group_lands_adjacent(t: TestCase) -> void:
	t.begin("165 · 组整组摆进包里、箭的增益格真压在弓上（编译器的点亮规则）；散件随机但同种子一样")
	var c := _content()
	var defs: Array[ItemDef] = []
	for id in ["longbow", "arrows", "salve", "knife"]:
		defs.append(c.items.get_def(StringName(id)))
	var positions := {}
	var linked := 0
	for s in 12:
		var board := GridInventory.new(Vector2i(7, 5), 0, true)
		board.try_add(ItemInstance.create(c.items.get_def(&"bag_long")))
		board.try_add(ItemInstance.create(c.items.get_def(&"bag_long")))
		board.try_add(ItemInstance.create(c.items.get_def(&"bag_leather")))
		var got := EnemyPlacer._arrange(board, defs, [[0, 1]], _rng(s))
		t.eq((got["left"] as Array).size(), 0, "种子 %d：四件都摆上了" % s)
		t.eq(int(got["ungrouped"]), 0, "种子 %d：组没拆" % s)
		var bow := _find(board, &"longbow")
		var arrows := _find(board, &"arrows")
		if bow != null and arrows != null and _lit_by(board, arrows).has(bow.uid):
			linked += 1
		positions[str(got["placed"])] = true
		# 同一个种子再摆一次：一模一样
		var again := GridInventory.new(Vector2i(7, 5), 0, true)
		again.try_add(ItemInstance.create(c.items.get_def(&"bag_long")))
		again.try_add(ItemInstance.create(c.items.get_def(&"bag_long")))
		again.try_add(ItemInstance.create(c.items.get_def(&"bag_leather")))
		t.eq(EnemyPlacer._arrange(again, defs, [[0, 1]], _rng(s))["placed"], got["placed"], "种子 %d：可复现" % s)
	t.eq(linked, 12, "十二个种子箭都照得到弓")
	t.check(positions.size() > 3, "换种子位置不同（%d 种摆法）" % positions.size())


static func run_retry_and_fallback(t: TestCase) -> void:
	t.begin("165 · 随机摆把地方切碎了就重来，还不行按老办法贴左上：件数不比之前少")
	var c := _content()
	var bar := ItemDef.new()
	bar.id = &"t_bar"
	bar.shape = ItemShape.from_ascii(["11"])
	var defs: Array[ItemDef] = [bar, bar]
	for s in 30:
		var board := GridInventory.new(Vector2i(4, 1))     # 4 × 1：第一根落在中间，第二根就没地方
		var got := EnemyPlacer._arrange(board, defs, [], _rng(s))
		t.eq((got["left"] as Array).size(), 0, "种子 %d：两根都摆上" % s)
		t.eq(board.item_count(), 2, "结果留在棋盘上")
	# 组摆不开：拆成散件，件数照旧
	var board := GridInventory.new(Vector2i(2, 4))     # 长弓缺口那两格禁用：长弓一放就满，箭没处挨着
	board.set_blocked(Vector2i(1, 1), true)
	board.set_blocked(Vector2i(1, 2), true)
	var d2: Array[ItemDef] = [c.items.get_def(&"longbow"), c.items.get_def(&"arrows")]
	var got := EnemyPlacer._arrange(board, d2, [[0, 1]], _rng(3))
	t.eq(int(got["ungrouped"]), 1, "组拆了")
	t.eq((got["left"] as Array).size(), 1, "箭摆不下（棋盘满了）—— 和之前一样算差件")


static func run_build_content(t: TestCase) -> void:
	t.begin("165 · 随机图的敌人：弓箭同在时箭挨着弓；同一个种子内容一样；记下的位置都摆得下")
	var c := _content()
	# 现有的神射手抽不到箭（箭不带 ranged）：造一个招牌就是弓 + 箭的弓手，别的照神射手
	var who := (c.enemies.enemy(&"marksman") as EnemyDef).duplicate() as EnemyDef
	who.id = &"t_archer"
	who.signature_by_strength = {}
	who.signature = _ids(["longbow", "arrows", "arrows"])
	who.item_tags = _ids(["ranged", "ammo", "remedy"])
	var together := 0
	var linked := 0
	for s in 40:
		var built := EnemyPlacer.build_content(who, c.pool, c.items, 2, _rng(s))
		var again := EnemyPlacer.build_content(who, c.pool, c.items, 2, _rng(s))
		t.eq(again["content"], built["content"], "种子 %d：可复现" % s)
		var board := EnemyKit.board_of(built["content"], c.items, false)
		t.eq(EnemyKit.unplaced_items(built["content"], c.items).size(), 0, "种子 %d：记下的位置都摆得下" % s)
		var bows: Array[int] = []
		var arrows: Array[ItemInstance] = []
		for inst in board.items():
			var i := inst as ItemInstance
			if i.def.tags.has(&"ranged"):
				bows.append(i.uid)
			elif i.def.adjacency != null and i.def.adjacency.grant_filter.has(&"ranged"):
				arrows.append(i)
		if bows.is_empty() or arrows.is_empty() or int(built["ungrouped"]) > 0:     # 组拆了（包里实在挤不下）的不算
			continue
		together += 1
		var all_lit := true
		for a in arrows:
			var hit := false
			for uid in _lit_by(board, a):
				hit = hit or bows.has(uid)
			all_lit = all_lit and hit
		if all_lit:
			linked += 1
	t.check(together >= 36, "四十个种子里组没拆的 %d 个" % together)
	t.eq(linked, together, "弓箭同在的每一个，箭都照得到弓")


static func run_preset_arrange(t: TestCase) -> void:
	t.begin("165 · 预设图：没写位置的件开局摆一次、写回内容；写死的组当刚体（能转）；写了 at 的原样；序章一不动")
	var c := _content()
	var content := {"enemy": "marksman", "strength": 1, "board": [7, 5],
		"items": [{"id": "bag_long"}, {"id": "bag_long"}, {"id": "bag_leather"}, {"id": "salve"}],
		"groups": [[{"id": "longbow", "at": [0, 0]}, {"id": "arrows", "at": [0, 4]}]]}
	t.check(EnemyPlacer.needs_arrange(content), "要摆")
	var pre := EnemyKit.board_of(content, c.items)
	t.eq(pre.item_count(), 6, "还没摆的内容重建时也自己找空位（组里的件也算）")
	var report := EnemyPlacer.arrange(content, c.items, _rng(5))
	t.eq((report["left"] as Array).size(), 0, "全摆上")
	t.check(not content.has("groups"), "组展开进 items")
	t.eq((content["items"] as Array).size(), 6, "六件")
	for raw in content["items"]:
		t.check((raw as Dictionary).has("at"), "%s 记下了位置" % raw["id"])
	t.check(not EnemyPlacer.needs_arrange(content), "摆过了不再摆")
	var board := EnemyKit.board_of(content, c.items, false)
	t.eq(EnemyKit.unplaced_items(content, c.items).size(), 0, "照记下的位置重建，一件不差")
	var bow := _find(board, &"longbow")
	var arrows := _find(board, &"arrows")
	t.check(bow != null and arrows != null and _lit_by(board, arrows).has(bow.uid), "写死的组：箭照得到弓")
	# 刚体能转：只有横着放得下的棋盘
	var turned := {"enemy": "marksman", "strength": 1, "board": [5, 2],
		"groups": [[{"id": "longbow", "at": [0, 0]}, {"id": "arrows", "at": [0, 4]}]]}
	EnemyPlacer.arrange(turned, c.items, _rng(2))
	var tb := EnemyKit.board_of(turned, c.items, false)
	var tbow := _find(tb, &"longbow")
	var tarr := _find(tb, &"arrows")
	t.check(tbow != null and tarr != null and _lit_by(tb, tarr).has(tbow.uid), "整组横过来也照得到")
	# 写了 at 的原样
	var pinned := {"enemy": "raider", "strength": 0, "board": [4, 3],
		"items": [{"id": "bag_leather", "at": [0, 0], "rot": 0}, {"id": "knife", "at": [2, 1], "rot": 0}, {"id": "salve"}]}
	EnemyPlacer.arrange(pinned, c.items, _rng(9))
	t.eq(pinned["items"][1]["at"], [2, 1], "写死的小刀没挪")
	t.check((pinned["items"][2] as Dictionary).has("at"), "没写的药膏摆了")
	# 序章一：位置都写着 —— 不摆、原样
	var g := MapPreset.load_graph(MapPreset.path_for("prologue"))
	var before := JSON.stringify(g.to_dict())
	t.eq(EnemyPlacer.arrange_map(g, c.items), 0, "序章一没有要摆的点")
	t.eq(JSON.stringify(g.to_dict()), before, "原样")


static func run_tutorials(t: TestCase) -> void:
	t.begin("165 · 序章二 / 三的六个敌人不写位置：开局摆一次，全部摆上、同一张图永远一样、数值不变")
	var c := _content()
	for preset in ["tutorial2", "tutorial3"]:
		var raw := MapPreset.load_graph(MapPreset.path_for(preset))
		var n_enemy := 0
		for id in raw.node_ids():
			var content: Dictionary = raw.get_node(id).content
			if not EnemyKit.has_enemy(content):
				continue
			n_enemy += 1
			for e in content["items"]:
				var d := c.items.get_def(StringName(String(e["id"])))
				t.check(d.is_bag or not (e as Dictionary).has("at"), "%s 点 %d：%s 不写位置" % [preset, id, e["id"]])
		var g := MapPreset.load_graph(MapPreset.path_for(preset))
		var g2 := MapPreset.load_graph(MapPreset.path_for(preset))
		t.eq(EnemyPlacer.arrange_map(g, c.items), n_enemy, "%s：%d 个敌人都摆了" % [preset, n_enemy])
		EnemyPlacer.arrange_map(g2, c.items)
		t.eq(JSON.stringify(g.to_dict()), JSON.stringify(g2.to_dict()), "%s：同一张图摆两次一样" % preset)
		for id in g.node_ids():
			var content: Dictionary = g.get_node(id).content
			if not EnemyKit.has_enemy(content):
				continue
			t.eq(EnemyKit.unplaced_items(content, c.items).size(), 0, "%s 点 %d：全部摆上" % [preset, id])
			var spec := EnemyKit.spec_of(content, c.enemies, null, c.items)
			var raw_spec := EnemyKit.spec_of(raw.get_node(id).content, c.enemies, null, c.items)
			t.eq(spec.max_hp_int(), raw_spec.max_hp_int(), "%s 点 %d：生命不变" % [preset, id])
			t.check(absf(spec.rough_dps() - raw_spec.rough_dps()) < 0.001, "%s 点 %d：DPS 不变" % [preset, id])


static func run_combos_validation(t: TestCase) -> void:
	t.begin("165 · 导入校验：combos 每组至少两件、id 得存在、不是包")
	var c := _content()
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.register_item(c.items.get_def(id))
	var base := {"id": "t_165", "strength": 0, "schools": ["ranged"]}
	var cases := [
		[[["longbow", "arrows"]], true, "弓 + 箭"],
		[[["longbow"]], false, "只有一件"],
		[[["longbow", "no_such_item"]], false, "找不到道具"],
		[[["longbow", "bag_small"]], false, "包"],
	]
	for cs in cases:
		var data := base.duplicate()
		data["combos"] = cs[0]
		var r := ImportReport.new()
		var def := ContentImporter.import_enemy(data, ctx, r)
		t.eq(r.ok(), cs[1], "%s → %s" % [cs[2], "过" if cs[1] else "错"])
		if cs[1]:
			t.eq(str(def.combo_list()), str([_ids(["longbow", "arrows"])]), "读成 id 列表")
	var data := base.duplicate()
	data["combos"] = [["salve", "knife"]]
	var r := ImportReport.new()
	ContentImporter.import_enemy(data, ctx, r)
	t.check(r.to_text().contains("没有相邻加成"), "互相没有相邻加成的组合：提醒一声")
