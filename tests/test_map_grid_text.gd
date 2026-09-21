## 手绘地图的网格脚本（架构文档 5.4.1，M3-3b）。
##
## 头一条是**往返不掉字**：`render(parse(text)) == text`。解析丢了信息，往返一定对不上。
extends RefCounted

const DIR := "res://data/authoring/maps"


static func _maps() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".txt"):
			out.append("%s/%s" % [DIR, f])
	out.sort()
	return out


static func run_roundtrip(t: TestCase) -> void:
	t.begin("网格脚本 · 作者画的每一张图：往返逐字节相同，且过校验")

	t.check(not _maps().is_empty(), "data/authoring/maps 里有图")
	for path in _maps():
		var text := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		var g := MapGridText.parse(text)
		t.not_null(g, "%s 解析得出来：%s" % [path.get_file(), MapGridText.last_error])
		if g == null:
			continue
		t.eq(MapGridText.render(g), text, "%s **往返逐字节相同**" % path.get_file())

		# 存档再读回来之后还写得出同样的文本（JSON 会把整数变浮点、键变字符串）
		var back := MapGraph.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
		t.eq(MapGridText.render(back), text, "%s 过一遍 JSON 之后照样写得回去" % path.get_file())

		var v := MapValidation.new()
		GridScriptGenerator.new().validate(g, v)
		t.check(v.ok(), "%s 过通用校验与高危区规则：%s" % [path.get_file(), v.to_text()])

		# 字母数得对：文本里每个类型符号恰好对应一个节点
		var symbols := 0
		var map_part := text.get_slice("[danger]", 0)
		for ch in map_part:
			if ch != MapGridText.END_MARK and ch != "[" and \
					MapGridText._type_of(ch, bool(g.layout_meta["legacy"])) != &"":
				symbols += 1
		# [map] 这个段头里的字母不算
		if not bool(g.layout_meta["legacy"]):
			for ch in "[map]":
				if MapGridText._type_of(ch, false) != &"":
					symbols -= 1
		var typed := 0
		for id in g.node_ids():
			if g.get_node(id).type != MapGridText.JUNCTION:
				typed += 1
		t.eq(typed, symbols, "%s 每个符号一个节点（岔路口另算）" % path.get_file())


static func run_syntax(t: TestCase) -> void:
	t.begin("网格脚本 · 每种写法各是什么意思")

	# 一张最小的图，把每种语法各用一次
	var text := "\n".join([
		"[map]",
		"A-V---Q.S-0",     # 行 0：A–V–(岔)–Q 一段；S 一段；行末 -0 → 首尾相连
		"..|.|......",
		"..|.R-E...0",     # 行 1：第 2 列是穿过去的 |；R–E；行末没有 - 连到 0 → 不闭环
		"..|........",
		"..A------B0",
		"",
		"[danger]",
		"...........",
		"...........",
		"....222....",
		"...........",
		"...........",
		"",
	])
	var g := MapGridText.parse(text)
	t.not_null(g, "解析得出来：%s" % MapGridText.last_error)
	if g == null:
		return
	t.eq(MapGridText.render(g), text, "这张小图也往返相同")

	var at := {}
	for id in g.node_ids():
		var lay := g.get_node(id).layout
		at[Vector2i(int(lay["col"]), int(lay["row"]))] = id

	t.eq(g.get_node(at[Vector2i(0, 0)]).type, &"battle", "A 是战斗")
	t.eq(g.get_node(at[Vector2i(9, 2)]).type, &"core", "B 是核心")
	t.eq(g.goal_ids, [at[Vector2i(9, 2)]] as Array[int], "核心就是终点")

	# | 落在 - 上 → 岔路口，把那段弧一分为二
	t.check(at.has(Vector2i(4, 0)), "第 4 列的 | 落在 V---Q 的 - 上 → 那里多了一个节点")
	var j: int = at[Vector2i(4, 0)]
	t.eq(g.get_node(j).type, MapGridText.JUNCTION, "它是 junction")
	t.not_null(g.edge_between(at[Vector2i(2, 0)], j), "V 连到岔路口")
	t.not_null(g.edge_between(j, at[Vector2i(6, 0)]), "岔路口连到 Q")
	t.is_null(g.edge_between(at[Vector2i(2, 0)], at[Vector2i(6, 0)]), "V 与 Q 不再直接相连")
	t.not_null(g.edge_between(j, at[Vector2i(4, 1)]), "岔路口向下连到 R")

	# 连续的 | → 一条跨环的边
	var long := g.edge_between(at[Vector2i(2, 0)], at[Vector2i(2, 2)])
	t.not_null(long, "第 2 列连续的 | 是一条边，直接从第 0 行连到第 2 行")
	if long != null:
		t.eq(int(long.layout.get("span", 1)), 2, "layout.span = 2")

	# - 只是延长；. 断开；行末 -0 闭环
	t.not_null(g.edge_between(at[Vector2i(2, 2)], at[Vector2i(9, 2)]), "A------B 是一条弧")
	t.is_null(g.edge_between(at[Vector2i(6, 0)], at[Vector2i(8, 0)]), "Q.S 中间是 . → 不相连")
	t.not_null(g.edge_between(at[Vector2i(8, 0)], at[Vector2i(0, 0)]), "行末是 -0 → 最后一个点连回第一个点")
	t.not_null(g.edge_between(at[Vector2i(4, 1)], at[Vector2i(6, 1)]), "R-E 当然还是连着的")

	# 危险层：只有节点那一格算数；同等级相连的一片是一个区域
	t.eq(g.get_node(at[Vector2i(4, 1)]).danger, 2, "R 那一格刷了 2")
	t.eq(g.get_node(at[Vector2i(6, 1)]).danger, 2, "E 那一格刷了 2")
	t.eq(g.get_node(at[Vector2i(4, 1)]).zone, g.get_node(at[Vector2i(6, 1)]).zone, "R 与 E 同一片")
	t.eq(g.zones.size(), 1, "只有一片区域")

	# 出生点：最外环每一段弧的第一个点
	t.eq(g.entry_ids, [at[Vector2i(0, 0)]] as Array[int],
		"最外环首尾相连成了一整段，所以只有一个出生点")


static func run_bad_input(t: TestCase) -> void:
	t.begin("网格脚本 · 写错了说得出错在哪")

	t.is_null(MapGridText.parse(""), "空文本")
	t.is_null(MapGridText.parse("[map]\nA-A\n..|\n...\n"), "| 的下面什么都没接")
	t.check(MapGridText.last_error.contains("|"), "报错指向那个 |：%s" % MapGridText.last_error)

	var gen := GridScriptGenerator.new()
	var cfg := GridScriptConfig.new()
	cfg.path = "res://no/such/map.txt"
	t.is_null(gen.generate(cfg, 1, 1), "文件不在 → 生成失败")
	t.check(gen.build_note.contains("读不到"), "说得出原因：%s" % gen.build_note)


static func run_generator(t: TestCase) -> void:
	t.begin("网格脚本 · 走的是同一套 MapGenerator 接口")

	t.check(MapGeneratorRegistry.has(&"grid_script"), "注册表里有 grid_script")
	var gen := MapGeneratorRegistry.create(&"grid_script")
	var cfg := gen.default_config()
	var a := gen.generate(cfg, 1)
	var b := gen.generate(cfg, 2)
	t.not_null(a, "默认配置生成得出来")
	if a == null or b == null:
		return
	t.eq(gen.attempts_used, 1, "写死的图，一次就成")
	t.eq(a.layout_kind, MapGridText.LAYOUT_KIND, "layout_kind 与生成器 id 同名 —— 编辑器靠它找校验者与布局")
	t.eq(a.edges.size(), b.edges.size(), "换种子，地形不变")
	var differs := false
	for id in a.node_ids():
		if a.get_node(id).content_seed != b.get_node(id).content_seed:
			differs = true
	t.check(differs, "换种子，内容种子变 —— 同一张手绘图每局刷出来的东西不同")

	# 5.1 的可插拔：MapSource、预设、编辑器的校验都不用知道它是手绘的
	var src := MapSource.new()
	src.generator_id = &"grid_script"
	src.generator_config = cfg
	t.not_null(src.resolve(3), "MapSource 直接用")


static func run_red_zone_report(t: TestCase) -> void:
	t.begin("网格脚本 · 作者画的高危区过得了 ZoneRules")

	for path in _maps():
		var g := MapGridText.parse(FileAccess.get_file_as_string(path))
		if g == null:
			continue
		var rules := ZoneRules.from_graph(g)
		for zone_id in g.zones:
			var ids: Array = g.zones[zone_id]["node_ids"]
			if g.get_node(int(ids[0])).danger < 2:
				continue
			var gates := ZoneRules.crossing_edges(g, ids)
			var where: Array[String] = []
			for gid in (g.zones[zone_id]["gate_ids"] as Array):
				where.append(String(g.get_node(int(gid)).type))
			t.check(ids.size() >= rules.min_size and ids.size() <= rules.max_size
					and gates.size() >= 1 and gates.size() <= rules.max_gates_for(ids.size()),
				"%s 的高危区：%d 个点、%d 个出入口（挂在 %s 上），上限 %d"
				% [path.get_file(), ids.size(), gates.size(), ", ".join(where),
					rules.max_gates_for(ids.size())])


static func run_ring_export(t: TestCase) -> void:
	t.begin("网格脚本 · 随机生成的图也导得出来，读回来是同一张图")

	for s in 8:
		var g := RingMapGenerator.new().generate(RingMapConfig.sample(5), s)
		if g == null:
			continue
		var text := MapGridText.render(g)
		var back := MapGridText.parse(text)
		t.not_null(back, "种子 %d 导出的文本解析得回来：%s" % [s, MapGridText.last_error])
		if back == null:
			continue
		t.eq(MapGridText.render(back), text, "种子 %d：再导一次，文本不变" % s)

		# 拓扑等价：按（行，列）对上号之后，点的类型 / 危险等级与边集完全一样。
		# 不比 to_dict —— 两种形态的 layout 载荷本来就不同，id 的编法也不同
		var place: Dictionary = MapGridText._cells_of(g)["place"]
		var back_at := {}
		for id in back.node_ids():
			var lay := back.get_node(id).layout
			back_at[Vector2i(int(lay["col"]), int(lay["row"]))] = id
		var junctions := 0
		for id in back.node_ids():
			if back.get_node(id).type == MapGridText.JUNCTION:
				junctions += 1
		t.eq(junctions, 0, "种子 %d：导出时不会凭空多出岔路口" % s)
		t.eq(back.node_count(), g.node_count(), "种子 %d：点数相同" % s)
		t.eq(back.edges.size(), g.edges.size(), "种子 %d：边数相同" % s)
		var same := true
		for id in g.node_ids():
			var twin: int = back_at.get(place[id], -1)
			if twin < 0 or back.get_node(twin).danger != g.get_node(id).danger:
				same = false
		for e in g.edges:
			var a: int = back_at.get(place[e.from_id], -1)
			var b: int = back_at.get(place[e.to_id], -1)
			if a < 0 or b < 0 or (back.edge_between(a, b) == null and back.edge_between(b, a) == null):
				same = false
		t.check(same, "种子 %d：每个点、每条边都对得上" % s)
