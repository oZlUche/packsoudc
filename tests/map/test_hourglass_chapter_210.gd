## 210（作者 21:30 夜间六条之四，待定按推荐）：沙漏地图实装为第二张图 —— 章节「机关沙漏」+ 机关池
extends RefCounted

const Setup := preload("res://ui/game/setup_screen.gd")


static func _chapter() -> ChapterDef:
	return load(ContentPaths.asset_file("chapters", "clockwork_hourglass"))


static func _row(g: MapGraph, id: int) -> int:
	return int(g.get_node(id).layout.get("row", -1))


static func _col(g: MapGraph, id: int) -> int:
	return int(g.get_node(id).layout.get("col", -1))


static func run_chapter(t: TestCase) -> void:
	t.begin("210 · ① 章节：沙漏生成器 + 配置过校验；开局屏排在魔法废墟后面（第二张）、同一把锁；281 §六：三档规模，越大层越多、倒计时越长")
	var c := _chapter()
	t.not_null(c, "章节在")
	if c == null:
		return
	t.eq(c.map_source.generator_id, &"hourglass", "沙漏生成器")
	t.check(c.map_source.generator_config is HourglassMapConfig, "配置是沙漏的")
	t.eq(c.enemy_pool, &"clockwork", "机关池")
	t.eq(c.requires_unlock, &"prologue3_done", "序章三通关解锁")
	t.eq(c.step_limit, 40, "兜底倒计时 40 步")
	t.eq(c.map_skin, &"clockwork", "底图 clockwork")
	t.check(MapSkin.texture(c.map_skin) != null, "底图在")
	var opts := Setup.scale_options_of(c)
	var ids_s: Array = opts.map(func(o: Dictionary) -> StringName: return StringName(o["id"]))
	t.eq(ids_s, [&"small", &"medium", &"large"], "三档：小 / 中 / 大")
	t.eq(opts.map(func(o: Dictionary) -> int: return int(o["step_limit"])), [24, 40, 60], "倒计时 24 / 40 / 60")
	var cfg := c.map_source.generator_config as HourglassMapConfig
	var rows: Array[int] = []
	for id in ids_s:
		rows.append(LatticeMapLayout.rows_of(c.map_source.resolve(5, id)))
	t.check(rows[0] < rows[1] and rows[1] < rows[2], "越大层越多（%s）" % [rows])
	t.eq(rows[1], cfg.row_count(), "中档 = 配置本身")
	var listed: Array[ChapterDef] = []
	for ch in GameFlow.load_chapters():
		if ch.hidden_by_unlock == &"":
			listed.append(ch)
	listed.sort_custom(func(a: ChapterDef, b: ChapterDef) -> bool: return a.order < b.order)
	var ids: Array[StringName] = []
	for ch in listed:
		ids.append(ch.id)
	t.eq(ids.slice(0, 2), [&"free_mode", &"clockwork_hourglass"] as Array[StringName], "地图列表：魔法废墟、机关沙漏（%s）" % [ids])
	var r := ImportReport.new()
	ContentImporter.import_chapter(JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/chapters/clockwork_hourglass.json")), ContentImporter.Context.new(), r)
	t.check(r.ok(), "导得进：%s" % r.to_text())


static func run_generate(t: TestCase) -> void:
	t.begin("210 · ② 生成（281 §六）：两头各一个入口、各一排撤离点；核心在中轴正中，钟房在它下方、只连下面那条线段；危险两头浅中间深；三档都过校验")
	var c := _chapter()
	for scale in [&"small", &"medium", &"large"]:
		var cfg := (c.map_source.generator_config as HourglassMapConfig).duplicate(true) as HourglassMapConfig
		cfg.apply_scale(scale)
		for seed_ in [3, 11, 29]:
			var g := c.map_source.resolve(seed_, scale)
			var tag := "%s / 种子 %d" % [scale, seed_]
			t.not_null(g, "%s 生成得出来" % tag)
			if g == null:
				continue
			t.eq(g.layout_kind, &"hourglass", "横置沙漏")
			var last := cfg.row_count() - 1
			t.eq(int(g.layout_meta["rows"]), last + 1, "%s：层数 = 两半 + 颈部" % tag)
			var widths: Array[int] = []
			for row in g.layout_meta["cells"]:
				widths.append((row as Array).size())
			var back := widths.duplicate()
			back.reverse()
			t.eq(widths, back, "%s：两半对称（%s）" % [tag, widths])
			var entry_rows: Array = g.entry_ids.map(func(id: int) -> int: return _row(g, id))
			entry_rows.sort()
			t.eq(entry_rows, [0, last], "%s：入口一左一右" % tag)
			var core := -1
			var exits := {0: 0, last: 0}
			for id in g.goal_ids:
				var n := g.get_node(id)
				if n.type == &"core":
					core = id
				elif n.type == &"extract":
					exits[_row(g, id)] = int(exits.get(_row(g, id), 0)) + 1
			t.eq(exits, {0: cfg.exit_count, last: cfg.exit_count}, "%s：两头各 %d 个撤离点" % [tag, cfg.exit_count])
			t.check(core >= 0 and _row(g, core) == cfg.axis_row() and _col(g, core) == cfg.axis_col(), "%s：核心在中轴正中" % tag)
			var room := -1
			for id in g.node_ids():
				if String(g.get_node(id).content.get("event", "")) == String(HourglassMapConfig.CLOCK_ROOM_EVENT):
					room = id
			t.check(room >= 0, "%s：有钟房" % tag)
			if room >= 0 and core >= 0:
				t.eq(g.get_node(room).type, &"event", "钟房是事件点")
				t.eq(_row(g, room), cfg.axis_row(), "钟房在中轴")
				t.check(_col(g, room) > _col(g, core), "在核心下方")
				t.check(not g.neighbors(room).has(core), "和核心不相连")
				var lanes := cfg.lane_cols()
				t.eq(g.neighbors(room).map(func(id: int) -> int: return _col(g, id)), [lanes.max()], "只连下面那条线段")
			for id in g.node_ids():
				var n := g.get_node(id)
				var tier := mini(_row(g, id), last - _row(g, id))
				t.eq(n.tier, tier, "点 %d 的 tier = 离最近一头几层" % id)
				if n.type != &"core" and n.type != &"extract" and n.type != &"spawn":
					t.eq(n.danger, cfg.danger_by_row[mini(tier, cfg.danger_by_row.size() - 1)], "点 %d 的危险按 tier" % id)
			var v := MapValidation.new()
			HourglassMapGenerator.new().validate(g, v)
			t.check(v.ok(), "%s 过校验：%s" % [tag, v.to_text()])


static func run_pick_side(t: TestCase) -> void:
	t.begin("210 · ⑤ 281 §六：挑了哪头出生，那头的撤离点变搜索点、撤离只在对侧；挑右边侵蚀从右边起；付费点在对侧重标")
	var c := TestSupport.load_content("clockwork_hourglass")
	for side in [0, 1]:
		var run := RunState.start(c.chapter, 11, c.items, c.enemies, c.sets)
		t.eq(run.phase, RunState.Phase.PICK_SPAWN, "两个入口：先挑")
		var g := run.map
		var last := int(g.layout_meta["rows"]) - 1
		var want := 0 if side == 0 else last
		var pick := -1
		for id in g.entry_ids:
			if _row(g, id) == want:
				pick = id
		t.check(pick >= 0 and run.pick_spawn(pick), "挑第 %d 层那个" % want)
		var far := last - want
		var exits := 0
		for id in g.node_ids():
			var n := g.get_node(id)
			if _row(g, id) == want and n.type == &"extract":
				t.check(false, "出生那头还有撤离点 %d" % id)
			if n.type == &"extract":
				exits += 1
				t.eq(_row(g, id), far, "撤离点在对侧")
				t.check(g.goal_ids.has(id), "对侧撤离点是终点")
		t.eq(exits, 2, "对侧两个撤离点")
		t.check(g.goal_ids.all(func(id: int) -> bool: return g.get_node(id).type in [&"extract", &"core"]), "终点只剩撤离点和核心")
		t.check(g.node_ids().any(func(id: int) -> bool: return g.get_node(id).type == &"extract" and int(g.get_node(id).content.get("fee", 0)) > 0), "对侧有一个付费撤离点")
		t.eq(g.get_node(pick).erosion_band, 0, "侵蚀从出生那头起")
		t.eq(run.current_node().id, pick, "站在挑的那个入口")


static func run_axis_guard(t: TestCase) -> void:
	t.begin("210 · ⑥ 281 §六：中轴正中撞上线段（双数宽度）就不生成，说清原因")
	var cfg := (_chapter().map_source.generator_config as HourglassMapConfig).duplicate(true) as HourglassMapConfig
	cfg.width = 4
	var gen := HourglassMapGenerator.new()
	t.eq(gen.shape(cfg), null, "形状不成立")
	t.check(gen.build_note.contains("中轴"), "原因说的是中轴（%s）" % gen.build_note)


static func run_pool(t: TestCase) -> void:
	t.begin("210 · ③ 机关池：格阵没有 kind 也挑得到人；核心只出大钟、精英是钟摆卫士或炮台；越深档位越高")
	var c := TestSupport.load_content("clockwork_hourglass")
	t.not_null(c.pool, "池在")
	var seen := {}
	var depth_strength := {}
	for seed_ in [3, 11, 29, 41]:
		var g := c.chapter.map_source.resolve(seed_)
		if g == null:
			continue
		var done := EnemyPlacer.fill(g, c.pool, c.enemies, c.items, 0, &"")
		t.check((done["skipped"] as Array).is_empty(), "种子 %d：每个战斗点都挑到了人（%s）" % [seed_, done["skipped"]])
		for id in g.node_ids():
			var n := g.get_node(id)
			if not EnemyKit.has_enemy(n.content):
				continue
			var e := StringName(String(n.content["enemy"]))
			seen[e] = true
			if n.type == &"core":
				t.eq(e, &"great_clock", "核心是大钟")
			elif n.type == &"elite":
				t.check([&"pendulum_warden", &"steam_turret", &"clockwork_sentry", &"tinker_apprentice", &"gear_golem", &"clock_keeper"].has(e) and e != &"great_clock", "精英不是大钟（%s）" % e)
			var row := n.tier     # 281 §六：两头浅、中间深
			depth_strength[row] = maxi(int(depth_strength.get(row, 0)), int(n.content["strength"]))
	t.check(seen.has(&"clockwork_sentry") and seen.has(&"great_clock"), "哨兵与大钟都出现了（%s）" % [seen.keys()])
	t.check(int(depth_strength.get(4, 0)) >= int(depth_strength.get(1, 0)), "深处档位不低于入口附近（%s）" % [depth_strength])


const GAME := "res://ui/game/game.tscn"
const Support := preload("res://tests/run/flow_support.gd")


static func frame_setup_and_depart(t: TestCase, root: Window) -> void:
	t.begin("210 · ④ 开局屏：选到机关沙漏，三档规模按钮；出发进得了沙漏图，站在左边的出生点")
	Support.cleanup("hg210")
	var game = load(GAME).instantiate()
	game.save_path = "user://test_hg210_run.json"
	game.meta_path = "user://test_hg210_meta.json"
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	var at := -1
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"clockwork_hourglass":
			at = gi
	t.eq(at, 1, "地图列表第二项")
	setup.choose_chapter(at)
	while setup.page() < Setup.PAGE_MAP:
		if not setup.next_page():
			break
	t.eq(setup.page(), Setup.PAGE_MAP, "到了选地图那一页")
	t.eq(setup._scale_btns.size(), 3, "三档规模按钮")
	# 213 起开局屏也画沙漏的入口：先在第三页挑一个，再出发
	var went := false
	var pick := -1
	for seed_ in range(1, 20):
		setup.set_run_seed(seed_)
		var ids: Array[int] = setup.preview().entry_ids()
		if ids.is_empty() or not setup.pick_spawn(ids[0]):
			continue
		pick = ids[0]
		if Support.depart(setup):
			went = true
			break
	t.check(went, "出发（%s）" % setup.can_depart())
	if went:
		var run: RunState = flow.run
		t.eq(run.chapter.id, &"clockwork_hourglass", "这一局是机关沙漏")
		t.eq(run.map.layout_kind, &"hourglass", "沙漏图")
		t.eq(run.phase, RunState.Phase.ON_MAP, "直接在图上（出生点在开局屏挑过了）")
		t.eq(run.map.entry_ids, [pick] as Array[int], "图上只剩挑的那个入口")
		t.eq(int(run.map.get_node(pick).layout.get("row", -1)), 0, "入口在第 0 层（左边）")
		var node := run.current_node()
		t.check(node != null and int(node.layout.get("row", -1)) == 0, "站在第 0 层（出生那一侧）")
	game.queue_free()
	Support.cleanup("hg210")
