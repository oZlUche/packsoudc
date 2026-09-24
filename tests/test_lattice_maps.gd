## 第二章的两个底层模板（第 8 阶段 8-2，报告 078）：沙漏（对称长方形、中间收紧成平行线段）与塔（等腰三角形、
## 可选不回头）。都是分层格阵：形状由配置算出，铺点 / 连边 / 断边 / 定类型 / 校验共用一套；布局登记了；
## 编辑器的下拉里能选；正式的一局能在上面跑。期望从配置推：几层、几条线段、线段在哪几列都读配置。
extends RefCounted

const CHAPTER := "res://data/chapters/chapter_01.tres"


static func _hourglass(seed: int, cfg: HourglassMapConfig = null) -> MapGraph:
	return HourglassMapGenerator.new().generate(cfg if cfg != null else HourglassMapConfig.sample(), seed)


static func _tower(seed: int, cfg: TowerMapConfig = null) -> MapGraph:
	return TowerMapGenerator.new().generate(cfg if cfg != null else TowerMapConfig.sample(), seed)


static func _row(g: MapGraph, id: int) -> int:
	return int(g.get_node(id).layout.get("row", -1))


static func _col(g: MapGraph, id: int) -> int:
	return int(g.get_node(id).layout.get("col", -1))


static func _nodes_in_row(g: MapGraph, r: int) -> Array[int]:
	var out: Array[int] = []
	for id in g.node_ids():
		if _row(g, id) == r:
			out.append(id)
	out.sort()
	return out


static func run_hourglass(t: TestCase) -> void:
	t.begin("沙漏 · 上下两块对称的长方形、中间几层只有平行线段；线段层不横连、只直上直下；出生在底、终点在顶正中；多种子都过校验")
	var cfg := HourglassMapConfig.sample()
	var g := _hourglass(3, cfg)
	t.not_null(g, "默认配置生成得出来")
	if g == null:
		return
	t.eq(g.layout_kind, &"hourglass", "layout_kind 是生成器 id")
	t.eq(int(g.layout_meta["rows"]), cfg.row_count(), "层数 = 每半 %d × 2 + 颈部 %d" % [cfg.half_rows, cfg.neck_rows])
	var lanes := cfg.lane_cols()
	t.eq(lanes, [1, 3] as Array[int], "默认两条线段在对称的两列（宽 %d）" % cfg.width)
	for r in range(cfg.half_rows, cfg.half_rows + cfg.neck_rows):
		var ids := _nodes_in_row(g, r)
		var cols: Array[int] = []
		for id in ids:
			cols.append(_col(g, id))
		t.eq(cols, lanes, "颈部第 %d 层正好是线段的那几列" % r)
		for id in ids:
			for e in g.edges_of(id):
				var o := e.other(id)
				t.check(_row(g, o) != r, "颈部第 %d 层没有横边" % r)
				t.eq(_col(g, o), _col(g, id), "线段只直上直下")
	# 两头那两层全填、线段口都在
	for r in [cfg.half_rows - 1, cfg.half_rows + cfg.neck_rows]:
		t.eq(_nodes_in_row(g, r).size(), cfg.width, "颈部两头的第 %d 层全填（不对着线段的点靠横边走到口）" % r)
	t.eq(_nodes_in_row(g, 0).size(), cfg.width, "第 0 层全填")
	t.eq(g.entry_ids.size(), cfg.entry_count, "出生点数按配置")
	for id in g.entry_ids:
		t.check(_row(g, id) == 0 and g.get_node(id).type == &"spawn", "出生点在第 0 层、类型 spawn")
	t.eq(g.goal_ids.size(), 1, "一个终点")
	var goal: int = g.goal_ids[0]
	t.check(_row(g, goal) == cfg.row_count() - 1 and _col(g, goal) == (cfg.width - 1) / 2 and g.get_node(goal).type == &"core", "终点在顶层正中、类型 core")
	# 咽喉：拿掉线段的点，上下两块就断开
	var cut := MapGraph.from_dict(g.to_dict())
	for r in range(cfg.half_rows, cfg.half_rows + cfg.neck_rows):
		for id in _nodes_in_row(cut, r):
			cut.remove_node(id)
	var seen := MapGenerator.reachable_from(cut, cut.entry_ids)
	t.check(not seen.has(goal), "线段是必经之路：拿掉它们终点就到不了")
	# tier / 侵蚀分档 = 层号
	for id in g.node_ids():
		t.check(g.get_node(id).tier == _row(g, id) and g.get_node(id).erosion_band == _row(g, id), "tier 与侵蚀分档都是层号")
	var v := MapValidation.new()
	HourglassMapGenerator.new().validate(g, v)
	t.check(v.ok(), "过自己的校验：%s" % v.to_text())
	# 多种子
	var gen := HourglassMapGenerator.new()
	var made := 0
	var attempts := 0
	for seed in range(1, 25):
		var gg := gen.generate(cfg, seed)
		if gg != null:
			made += 1
			attempts += gen.attempts_used
			var vv := MapValidation.new()
			gen.validate(gg, vv)
			t.check(vv.ok(), "种子 %d 过校验：%s" % [seed, vv.to_text()])
	t.check(made >= 22, "24 个种子里生成出 %d 张" % made)
	t.check(made == 0 or float(attempts) / float(made) < 3.0, "平均尝试次数 %.1f（配置与校验不打架）" % (float(attempts) / float(maxi(1, made))))
	# 同种子同图；反向侵蚀；指定线段列
	t.eq(_hourglass(7, cfg).to_dict(), _hourglass(7, cfg).to_dict(), "同种子同图")
	var cfg2 := HourglassMapConfig.sample()
	cfg2.erosion_reversed = true
	cfg2.neck_cols = [0, 4] as Array[int]
	cfg2.neck_lanes = 3     # 给了列就不看条数
	var g2 := _hourglass(3, cfg2)
	t.not_null(g2, "反向侵蚀 + 指定线段列也生成得出来")
	if g2 != null:
		var top := cfg2.row_count() - 1
		for id in g2.node_ids():
			t.eq(g2.get_node(id).erosion_band, top - _row(g2, id), "反向：终点那层先被侵蚀")
		var cols: Array[int] = []
		for id in _nodes_in_row(g2, cfg2.half_rows):
			cols.append(_col(g2, id))
		t.eq(cols, [0, 4] as Array[int], "线段在指定的两列")
	# 配置不对直说
	var bad := HourglassMapConfig.sample()
	bad.neck_cols = [9] as Array[int]
	var gen_bad := HourglassMapGenerator.new()
	t.is_null(gen_bad.generate(bad, 1, 2), "线段列超出宽度：生成失败")
	t.check(gen_bad.build_note.contains("超出宽度") or str(gen_bad.failure_tally).contains("build"), "失败原因说得出（%s）" % gen_bad.build_note)


static func run_tower(t: TestCase) -> void:
	t.begin("塔 · 等腰：每层两边各收 shrink 列直到塔尖；塔尖是唯一终点；不回头 = 层间的路只许向上、每个点都到得了塔尖；校验守着方向")
	var cfg := TowerMapConfig.sample()
	t.eq(cfg.widths(), [7, 5, 3, 1] as Array[int], "默认底宽 7、每层收 1：宽度 7 / 5 / 3 / 1")
	var g := _tower(3, cfg)
	t.not_null(g, "默认配置生成得出来")
	if g == null:
		return
	t.eq(g.layout_kind, &"tower", "layout_kind")
	var widths := cfg.widths()
	for r in widths.size():
		var ids := _nodes_in_row(g, r)
		t.check(ids.size() <= widths[r] and ids.size() >= 1, "第 %d 层 %d 个点，不超过宽度 %d" % [r, ids.size(), widths[r]])
		for id in ids:
			var c := _col(g, id)
			var offset := (cfg.base_width - widths[r]) / 2
			t.check(c >= offset and c < offset + widths[r], "第 %d 层的点都在居中的 %d 列里" % [r, widths[r]])
	t.eq(_nodes_in_row(g, widths.size() - 1), g.goal_ids, "塔尖那一层只有终点")
	t.eq(g.get_node(g.goal_ids[0]).type, &"core", "塔尖是 core")
	for e in g.edges:
		t.check(not e.directed, "默认不是单向")
	var v := MapValidation.new()
	TowerMapGenerator.new().validate(g, v)
	t.check(v.ok(), "过校验：%s" % v.to_text())

	# 不回头
	var one := TowerMapConfig.sample()
	one.one_way = true
	one.base_width = 9
	var g1 := _tower(5, one)
	t.not_null(g1, "单向的塔生成得出来")
	if g1 != null:
		var forward := 0
		for e in g1.edges:
			var ra := _row(g1, e.from_id)
			var rb := _row(g1, e.to_id)
			if ra == rb:
				t.check(not e.directed, "同层的路不单向")
			else:
				forward += 1
				t.check(e.directed and rb == ra + 1, "层间的路单向、从下往上")
		t.check(forward > 0, "有层间的路")
		# 走：从出生点只能往上
		var entry: int = g1.entry_ids[0]
		var up := -1
		for n in MapNavigator.available_moves(g1, entry):
			if _row(g1, n) == 1:
				up = n
		t.check(up >= 0, "出生点能往上走")
		if up >= 0:
			t.check(not MapNavigator.available_moves(g1, up).has(entry), "上去了就回不来")
		var can := LatticeMapGenerator._reaches_goal(g1)
		t.eq(can.size(), g1.node_count(), "每个点顺着单向路都到得了塔尖")
		var vv := MapValidation.new()
		TowerMapGenerator.new().validate(g1, vv)
		t.check(vv.ok(), "单向的图过校验：%s" % vv.to_text())
		# 校验守着方向：把一条层间路翻过来 → one_way；拿掉某点唯一的向上路 → goal_from_all
		var flipped := MapGraph.from_dict(g1.to_dict())
		for e in flipped.edges:
			if e.directed:
				var tmp := e.from_id
				e.from_id = e.to_id
				e.to_id = tmp
				break
		var v2 := MapValidation.new()
		TowerMapGenerator.new().validate(flipped, v2)
		t.check(v2.rules().has(&"one_way"), "向下的单向路：校验报 one_way（%s）" % v2.to_text())
		# 一个点只留一条从下面来的单向路（上去的、横着的全拿掉）：进得去出不来
		var stuck := MapGraph.from_dict(g1.to_dict())
		var victim := -1
		for id in stuck.node_ids():
			if _row(stuck, id) == 0 or _row(stuck, id) >= widths.size() - 1 or stuck.goal_ids.has(id):
				continue
			var keep: MapEdge = null
			for e in stuck.edges_of(id):
				if e.directed and e.to_id == id:
					keep = e
					break
			if keep == null:
				continue
			victim = id
			for e in stuck.edges_of(id):
				if e != keep:
					stuck.remove_edge(e)
			break
		t.check(victim >= 0, "找得到一个能困住的点")
		if victim >= 0:
			var v3 := MapValidation.new()
			TowerMapGenerator.new().validate(stuck, v3)
			t.check(v3.rules().has(&"goal_from_all"), "只剩一条进来的单向路：校验报 goal_from_all（%s）" % v3.to_text())
			t.check(not v3.rules().has(&"reachable"), "它从出生点还是到得了（困住 ≠ 到不了）")
		# 从第 2 层起才单向
		var late := TowerMapConfig.sample()
		late.one_way = true
		late.one_way_from_floor = 2
		late.base_width = 9
		var g3 := _tower(5, late)
		if g3 != null:
			for e in g3.edges:
				var lo := mini(_row(g3, e.from_id), _row(g3, e.to_id))
				if _row(g3, e.from_id) != _row(g3, e.to_id):
					t.eq(e.directed, lo >= 2, "第 %d 层往上的路 %s单向" % [lo, "" if lo >= 2 else "不"])
	# 指定层数、多种子
	var tall := TowerMapConfig.sample()
	tall.floors = 6
	tall.base_width = 9
	tall.rules.extract_rows = tall.default_extract_rows()
	t.eq(tall.widths(), [9, 7, 5, 3, 1, 1] as Array[int], "指定 6 层：收到 1 列之后一直 1 列")
	var gen := TowerMapGenerator.new()
	var made := 0
	for seed in range(1, 25):
		var gg := gen.generate(tall, seed)
		if gg != null:
			made += 1
			var vv := MapValidation.new()
			gen.validate(gg, vv)
			t.check(vv.ok(), "6 层塔种子 %d 过校验：%s" % [seed, vv.to_text()])
	t.check(made >= 22, "24 个种子里生成出 %d 张 6 层塔" % made)
	var flat := TowerMapConfig.sample()
	flat.shrink_per_row = 0
	var gen_flat := TowerMapGenerator.new()
	t.is_null(gen_flat.generate(flat, 1, 2), "不收窄又不限层数：只一层，生成失败")


static func run_types_and_rules(t: TestCase) -> void:
	t.begin("格阵 · 类型规则：撤离点只在允许的层、够远、数量在范围里；每层配额；覆盖；不许相邻；规则写进图，手改就红")
	var cfg := HourglassMapConfig.sample()
	var g := _hourglass(11, cfg)
	if g == null:
		t.check(false, "生成不出")
		return
	var rules: Dictionary = g.layout_meta["type_rules"]
	t.eq(rules["extract_rows"], [cfg.half_rows - 1, cfg.half_rows + cfg.neck_rows], "规则写进图：撤离点允许的层 = 颈部两头")
	var extracts: Array[int] = []
	for id in g.node_ids():
		if g.get_node(id).type == &"extract":
			extracts.append(id)
	t.check(extracts.size() >= cfg.rules.extract_count.x and extracts.size() <= cfg.rules.extract_count.y, "撤离点 %d 个，在 %s 里" % [extracts.size(), str(cfg.rules.extract_count)])
	for id in extracts:
		t.check((rules["extract_rows"] as Array).has(_row(g, id)), "撤离点 %d 在允许的层" % id)
	# 每层配额
	for r in cfg.row_count():
		for type in cfg.rules.quota:
			var n := 0
			for id in _nodes_in_row(g, r):
				if g.get_node(id).type == StringName(String(type)):
					n += 1
			var lim: Array = cfg.rules.quota[type]
			t.check(n >= int(lim[0]) and n <= int(lim[1]), "第 %d 层 %s %d 个在 %s 里" % [r, type, n, str(lim)])
	# 手改就红
	var broken := MapGraph.from_dict(g.to_dict())
	var some := -1
	for id in broken.node_ids():
		if _row(broken, id) == 1 and broken.get_node(id).type not in [&"spawn", &"core", &"extract"]:
			some = id
			break
	broken.get_node(some).type = &"extract"
	var v := MapValidation.new()
	HourglassMapGenerator.new().validate(broken, v)
	t.check(v.rules().has(&"extract_row"), "撤离点放到不许的层：报 extract_row")
	var lateral := MapGraph.from_dict(g.to_dict())
	var neck := _nodes_in_row(lateral, cfg.half_rows)
	lateral.connect_nodes(neck[0], neck[1], &"lateral")
	var v2 := MapValidation.new()
	HourglassMapGenerator.new().validate(lateral, v2)
	t.check(v2.rules().has(&"straight"), "线段之间连横边：报 straight")
	var danger := HourglassMapConfig.sample()
	danger.danger_by_row = [0, 0, 2, 2, 2, 2, 0, 0] as Array[int]
	var gd := _hourglass(11, danger)
	t.not_null(gd, "带高危层的沙漏生成得出来")
	if gd != null:
		for id in gd.node_ids():
			var n := gd.get_node(id)
			t.eq(n.danger, danger.danger_by_row[_row(gd, id)], "危险等级按层")
			if n.danger > danger.rules.no_haven_in_danger_above:
				t.check(not danger.rules.coverage.has(String(n.type)), "高危层里没有喘气处（%s）" % n.type)


static func run_layout_and_play(t: TestCase) -> void:
	t.begin("格阵 · 布局登记了、位置按行列、空格子能加点、存档往返；正式的一局能在沙漏与单向的塔上开、走、打")
	var g := _hourglass(3)
	var layout := MapLayout.for_graph(g)
	t.check(layout is LatticeMapLayout, "沙漏用格阵布局")
	var rect := Rect2(Vector2.ZERO, layout.canvas_size(g))
	var pos := layout.positions(g, rect)
	t.eq(pos.size(), g.node_count(), "每个点都有位置")
	var seen := {}
	var distinct := true
	for id in pos:
		var key := "%d:%d" % [int(pos[id].x), int(pos[id].y)]
		if seen.has(key):
			distinct = false
		seen[key] = true
	t.check(distinct, "位置两两不同")
	var a: int = g.entry_ids[0]
	var goal: int = g.goal_ids[0]
	t.check(pos[a].y > pos[goal].y, "出生在下、终点在上")
	var cells_total := 0
	for row in g.layout_meta["cells"]:
		cells_total += (row as Array).size()
	t.eq(layout.free_slots(g, rect).size(), cells_total - g.node_count(), "空格子 = 格子 − 点")
	var back := MapGraph.from_dict(g.to_dict())
	var v := MapValidation.new()
	HourglassMapGenerator.new().validate(back, v)
	t.check(v.ok() and back.layout_kind == &"hourglass", "存档往返之后照样过校验")
	t.check(MapLayout.for_graph(_tower(3)) is LatticeMapLayout, "塔也用格阵布局")

	# 正式的一局
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var base: ChapterDef = load(CHAPTER)
	for kind in [&"hourglass", &"tower"]:
		var ch: ChapterDef = base.duplicate(true)
		ch.map_source = MapSource.new()
		ch.map_source.generator_id = kind
		if kind == &"tower":
			var tc := TowerMapConfig.sample()
			tc.one_way = true
			tc.base_width = 9
			ch.map_source.generator_config = tc
		else:
			ch.map_source.generator_config = HourglassMapConfig.sample()
		var s := RunState.start(ch, 5, items, enemies, sets, [&"bag_leather", &"rifle"] as Array[StringName])
		t.not_null(s, "%s：一局开得起来" % kind)
		if s == null:
			continue
		t.eq(s.map.layout_kind, kind, "%s：地图是这种形态" % kind)
		var armed := 0
		for id in s.map.node_ids():
			if EnemyKit.has_enemy(s.map.get_node(id).content):
				armed += 1
		t.check(armed > 0, "%s：节点内容照常定进去了（%d 个点有敌人）" % [kind, armed])
		t.check(s.pick_spawn(s.map.entry_ids[0]), "%s：站到出生点" % kind)
		var from := s.travel.current_id
		var moves := s.travel.available_moves()
		t.check(not moves.is_empty(), "%s：出生点有路" % kind)
		var went := false
		for n in moves:
			if _row(s.map, n) == 1:
				went = s.step_to(n)
				break
		t.check(went, "%s：往上走了一步" % kind)
		if kind == &"tower" and went:
			t.check(not s.travel.available_moves().has(from), "塔（不回头）：上去了回不了出生点")
			t.check(not s.step_to(from), "往回走被拒")
		t.check(s.phase != RunState.Phase.PICK_SPAWN, "%s：在图上" % kind)
