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
	t.begin("210 · ① 章节：沙漏生成器 + 配置过校验；开局屏排在魔法废墟后面（第二张）、同一把锁；没有规模档；倒计时 40")
	var c := _chapter()
	t.not_null(c, "章节在")
	if c == null:
		return
	t.eq(c.map_source.generator_id, &"hourglass", "沙漏生成器")
	t.check(c.map_source.generator_config is HourglassMapConfig, "配置是沙漏的")
	t.eq(c.enemy_pool, &"clockwork", "机关池")
	t.eq(c.requires_unlock, &"prologue3_done", "序章三通关解锁")
	t.eq(c.step_limit, 40, "倒计时 40 步")
	t.eq(c.map_skin, &"clockwork", "底图 clockwork")
	t.check(MapSkin.texture(c.map_skin) != null, "底图在")
	t.check(Setup.scale_options_of(c).is_empty(), "没有规模档：开局屏不列规模")
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
	t.begin("210 · ② 生成：十层、对侧最后一层两个撤离点 + 正中核心、过校验；危险按 danger_by_row")
	var c := _chapter()
	var cfg := c.map_source.generator_config as HourglassMapConfig
	for seed in [3, 11, 29]:
		var g := c.map_source.resolve(seed)
		t.not_null(g, "种子 %d 生成得出来" % seed)
		if g == null:
			continue
		t.eq(g.layout_kind, &"hourglass", "横置沙漏")
		t.eq(int(g.layout_meta["rows"]), 10, "十层")
		var cores := 0
		var exits := 0
		for id in g.goal_ids:
			var n := g.get_node(id)
			t.eq(_row(g, id), 9, "终点在最后一层")
			if n.type == &"core":
				cores += 1
				t.eq(_col(g, id), (cfg.width - 1) / 2, "核心在正中")
			elif n.type == &"extract":
				exits += 1
		t.eq([cores, exits], [1, 2], "一个核心、两个撤离点（种子 %d）" % seed)
		for id in g.node_ids():
			var n := g.get_node(id)
			if n.type != &"core" and n.type != &"extract" and n.type != &"spawn":
				t.eq(n.danger, cfg.danger_by_row[_row(g, id)], "点 %d 的危险按层（第 %d 层）" % [id, _row(g, id)])
		var v := MapValidation.new()
		HourglassMapGenerator.new().validate(g, v)
		t.check(v.ok(), "种子 %d 过校验：%s" % [seed, v.to_text()])


static func run_pool(t: TestCase) -> void:
	t.begin("210 · ③ 机关池：格阵没有 kind 也挑得到人；核心只出大钟、精英是钟摆卫士或炮台；越深档位越高")
	var c := TestSupport.load_content("clockwork_hourglass")
	t.not_null(c.pool, "池在")
	var seen := {}
	var depth_strength := {}
	for seed in [3, 11, 29, 41]:
		var g := c.chapter.map_source.resolve(seed)
		if g == null:
			continue
		var done := EnemyPlacer.fill(g, c.pool, c.enemies, c.items, 0, &"")
		t.check((done["skipped"] as Array).is_empty(), "种子 %d：每个战斗点都挑到了人（%s）" % [seed, done["skipped"]])
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
			var row := _row(g, id)
			depth_strength[row] = maxi(int(depth_strength.get(row, 0)), int(n.content["strength"]))
	t.check(seen.has(&"clockwork_sentry") and seen.has(&"great_clock"), "哨兵与大钟都出现了（%s）" % [seen.keys()])
	t.check(int(depth_strength.get(8, 0)) >= int(depth_strength.get(1, 0)), "深处档位不低于入口附近（%s）" % [depth_strength])


const GAME := "res://ui/game/game.tscn"
const Support := preload("res://tests/run/flow_support.gd")


static func frame_setup_and_depart(t: TestCase, root: Window) -> void:
	t.begin("210 · ④ 开局屏：选到机关沙漏，没有规模按钮；出发进得了沙漏图，站在左边的出生点")
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
	t.eq(setup._scale_btns.size(), 0, "没有规模按钮")
	var went := false
	for seed in range(1, 20):
		setup.set_run_seed(seed)
		if setup.depart():
			went = true
			break
	t.check(went, "出发（%s）" % setup.can_depart())
	if went:
		var run: RunState = flow.run
		t.eq(run.chapter.id, &"clockwork_hourglass", "这一局是机关沙漏")
		t.eq(run.map.layout_kind, &"hourglass", "沙漏图")
		# 开局屏的入口印记只画同心环（182）；沙漏在地图屏上挑出生点（老路），入口都在第 0 层
		t.eq(run.phase, RunState.Phase.PICK_SPAWN, "进图先挑出生点")
		for id in run.map.entry_ids:
			t.eq(int(run.map.get_node(id).layout.get("row", -1)), 0, "入口 %d 在第 0 层（左边）" % id)
		t.check(flow.pick_spawn(run.map.entry_ids[0]), "挑一个入口")
		var node := run.current_node()
		t.check(node != null and int(node.layout.get("row", -1)) == 0, "站在第 0 层（出生那一侧）")
	game.queue_free()
	Support.cleanup("hg210")
