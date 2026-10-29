## 267（作者 2026-10-29 16:49 认可推荐）：材料定向 —— B 环的产物表、C 材料节点四种（矿脉 / 林地 / 遗骸 / 符文堆）、A 出征倾向。
## 搜索 / 宝箱 / 事件掷道具时权重多乘两层（产物命中的取最大、倾向只碰材料类），材料节点只出那一类材料（每件 1/4 从普通池抽）；
## 节点类型一个不动（材料种类是内容不是拓扑），地图上换图标与色，图例多「倾向」一行与「产物」一段
extends RefCounted

const Records := preload("res://tests/ui/test_records_board_260.gd")
const Rings := preload("res://tests/map/test_ring_type_assigner.gd")

const SEEDS := 96
const KIND_TAGS := {"mine": ["mineral", "bullion"], "grove": ["plant", "beast_part"], "remains": ["crafted"], "runes": ["crystal", "magic"]}


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _rules() -> NodeRules:
	return load(ContentPaths.asset_file("node_rules", "standard"))


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func run_tags(t: TestCase) -> void:
	t.begin("267 §一 · 两个新标签【矿物】【草木】：17 种材料贴上；四种材料节点的标签照配置")
	var db := _db()
	for id in [&"copper_ore", &"iron_ore", &"silver_ore", &"flint", &"raw_salt", &"gravestone_shard", &"gold_nugget", &"silver_nugget"]:
		t.check(db.get_def(id).tags.has(&"mineral"), "%s 是矿物" % id)
	for id in [&"oak_log", &"wooden_stick", &"ironwood_branch", &"pine_resin", &"beeswax", &"honey_jar", &"dried_herbs", &"mint_bundle", &"datura_flower"]:
		t.check(db.get_def(id).tags.has(&"plant"), "%s 是草木" % id)
	t.eq(TagRegistry.name_of(&"mineral"), "矿物", "矿物的名")
	t.eq(TagRegistry.name_of(&"plant"), "草木", "草木的名")
	var kinds := _rules().search_kinds
	t.eq(kinds.keys().size(), 4, "四种材料节点")
	for k in KIND_TAGS:
		t.eq(Array((kinds[k] as Dictionary)["tags"]), KIND_TAGS[k], "%s 的标签" % k)
		t.eq(float((kinds[k] as Dictionary)["other_share"]), 0.25, "%s 四分之一从普通池抽" % k)
	t.check((load(ContentPaths.asset_file("node_rules", "prologue")) as NodeRules).search_kinds.is_empty(), "序章没有材料节点")


static func run_draw_items(t: TestCase) -> void:
	t.begin("267 §2.1 · 掷物：产物命中取最大不连乘；倾向三系对、只碰材料类；材料节点只出那一类、空了退回全池；什么都不传和原来一样")
	var db := _db()
	var sr := _rules().search
	var oak := db.get_def(&"oak_log")
	var outskirts := {"plant": 2.0, "beast_part": 1.5, "mineral": 1.2}
	t.eq(SearchSession.weight_mult(oak, outskirts, {}), 2.0, "橡木在外环：草木 ×2（不乘 1.5 / 1.2）")
	t.eq(SearchSession.bias_table(&"nature"), {"nature": 2.5, "crafted": 0.6, "magic": 0.6}, "倾向自然：×2.5 / ×0.6 / ×0.6")
	t.eq(SearchSession.bias_table(&""), {}, "没选：空")
	t.eq(SearchSession.bias_table(&"weapon"), {}, "三系以外：空")
	t.eq(SearchSession.weight_mult(oak, outskirts, SearchSession.bias_table(&"nature")), 5.0, "再选自然：×2 × 2.5")
	t.eq(SearchSession.weight_mult(db.get_def(&"hardwood_plank"), {}, SearchSession.bias_table(&"nature")), 0.6, "工艺材料在倾向自然时 ×0.6")
	t.eq(SearchSession.weight_mult(db.get_def(&"longsword"), {}, SearchSession.bias_table(&"crafted")), 1.0, "非材料道具不受倾向影响")
	var plain := SearchSession.draw_items(sr, db, 0.3, 1, _rng(11))
	t.eq(SearchSession.draw_items(sr, db, 0.3, 1, _rng(11), -1, [] as Array[int], {}, {}, [], 0.0), plain, "什么都不传：同一种子掷的一样")
	for k in KIND_TAGS:
		var bad: Array[String] = []
		var n := 0
		for s in 40:
			for id in SearchSession.draw_items(sr, db, 0.5, 0, _rng(100 + s), -1, [] as Array[int], {}, {}, KIND_TAGS[k], 0.0):
				n += 1
				if not SearchSession.in_kind(db.get_def(id), KIND_TAGS[k]):
					bad.append(String(id))
		t.check(n > 0 and bad.is_empty(), "%s（纯）：%d 件全是这一类材料（不对的 %s）" % [k, n, bad])
	var weapons := 0
	for s in 40:
		for id in SearchSession.draw_items(sr, db, 0.5, 0, _rng(300 + s), -1, [] as Array[int], {}, {}, ["crafted"], 0.0):
			if db.get_def(id).tags.has(&"weapon") or db.get_def(id).tags.has(&"armor"):
				weapons += 1
	t.eq(weapons, 0, "遗骸：带「工艺」的武器防具不出")
	var none := SearchSession.draw_items(sr, db, 0.5, 0, _rng(7), -1, [] as Array[int], {}, {}, ["no_such_tag_267"], 0.0)
	t.check(not none.is_empty(), "过滤后空了：退回全池，不空手")
	var inside := 0
	var total := 0
	for s in 120:
		for id in SearchSession.draw_items(sr, db, 0.5, 0, _rng(500 + s), -1, [] as Array[int], {}, {}, KIND_TAGS["mine"], 0.25):
			total += 1
			if SearchSession.in_kind(db.get_def(id), KIND_TAGS["mine"]):
				inside += 1
	var share := float(inside) / maxf(1.0, float(total))
	t.check(share > 0.65 and share < 0.95, "矿脉 other_share 0.25：%d / %d 件是矿物（%.2f）" % [inside, total, share])
	var floored := SearchSession.draw_items(sr, db, 0.5, 0, _rng(9), -1, [2, 2] as Array[int], {}, {}, KIND_TAGS["runes"], 0.0)
	t.check(floored.size() >= 2 and floored.all(func(id): return SearchSession.in_kind(db.get_def(id), KIND_TAGS["runes"])), "有保底也从那一类里抽（%s）" % [floored])
	var natural := 0
	var magic := 0
	for s in 200:
		for id in SearchSession.draw_items(sr, db, 0.4, 0, _rng(900 + s), -1, [] as Array[int], {}, SearchSession.bias_table(&"nature")):
			var d := db.get_def(id)
			if SearchSession.is_material(d) and d.has_tag(&"nature"):
				natural += 1
			elif SearchSession.is_material(d) and d.has_tag(&"magic"):
				magic += 1
	var natural0 := 0
	for s in 200:
		for id in SearchSession.draw_items(sr, db, 0.4, 0, _rng(900 + s)):
			var d := db.get_def(id)
			if SearchSession.is_material(d) and d.has_tag(&"nature"):
				natural0 += 1
	t.check(natural > natural0, "倾向自然：自然材料比不选时多（%d > %d）" % [natural, natural0])


static func run_ring_assigner(t: TestCase) -> void:
	t.begin("267 §2.3 · 生成：每环材料节点数照配置（搜索点够时）、只挑普通搜索点；类型和没有材料节点时一模一样；每个点记着所在环的产物表")
	for pair in [[&"small", 5], [&"medium", 6]]:
		var cfg: RingMapConfig = Rings._free_mode_cfg(pair[0], pair[1])
		var bare: RingMapConfig = cfg.duplicate(true)
		for spec in bare.rings:
			(spec as RingSpec).produce = {}
			(spec as RingSpec).material_nodes = {}
		var tag := "%s %d 环" % [pair[0], pair[1]]
		var bad: Array[String] = []
		var wanted := 0
		var got := 0
		var kinds := {}
		for s in SEEDS:
			var g := RingMapGenerator.new().generate(cfg, s)
			var g0 := RingMapGenerator.new().generate(bare, s)
			if g == null or g0 == null:
				bad.append("种子 %d 没生成出来" % s)
				continue
			for id in g.node_ids():
				var n := g.get_node(id)
				if n.type != g0.get_node(id).type:
					bad.append("种子 %d 点 %d：类型 %s ≠ %s" % [s, id, n.type, g0.get_node(id).type])
				var spec := cfg.spec_for_ring(int(n.layout.get("ring", 0)))
				if spec != null and n.produce != spec.produce:
					bad.append("种子 %d 点 %d：产物表 %s" % [s, id, n.produce])
				var k := String(n.content.get("search_kind", ""))
				if k != "":
					kinds[k] = int(kinds.get(k, 0)) + 1
					if n.type != &"search":
						bad.append("种子 %d 点 %d：%s 不是搜索点" % [s, id, k])
					if spec == null or not spec.material_nodes.has(k):
						bad.append("种子 %d 点 %d：%s 不是这一环的种类" % [s, id, k])
			for r in range(cfg.ring_count(), 0, -1):
				var spec := cfg.spec_for_ring(r)
				var want := 0
				for k in spec.material_nodes:
					want += int(spec.material_nodes[k])
				var have := 0
				var searches := 0
				for id in g.node_ids():
					var n := g.get_node(id)
					if int(n.layout.get("ring", 0)) != r:
						continue
					if n.type == &"search" and n.zone == 0:     # 高危区里为凑数改的搜索点是固定的，不挑；区外的一定能挑
						searches += 1
					if n.content.has("search_kind"):
						have += 1
				if have > want:
					bad.append("种子 %d 第 %d 环：%d 个材料节点 > 配置 %d" % [s, r, have, want])
				if have < mini(want, searches):
					bad.append("种子 %d 第 %d 环：区外搜索点 %d 个，材料节点却只有 %d" % [s, r, searches, have])
				wanted += want
				got += have
		t.check(bad.is_empty(), "%s：%d 种子（%s）" % [tag, SEEDS, bad.slice(0, 5)])
		t.check(got >= int(wanted * 0.6), "%s：材料节点 %d / 配置 %d（内环搜索点少，挑不够有几个算几个）" % [tag, got, wanted])
		t.check(kinds.has("mine") and kinds.has("grove") and kinds.has("remains") and kinds.has("runes"), "%s：四种都出现（%s）" % [tag, kinds])


static func run_map_node_save(t: TestCase) -> void:
	t.begin("267 · 节点存读：产物表与材料种类跟着图走；老存档没有这两项 = 空")
	var n := MapNode.new()
	n.id = 3
	n.type = &"search"
	n.produce = {"plant": 2.0, "mineral": 1.2}
	n.content["search_kind"] = "grove"
	var back := MapNode.from_dict(JSON.parse_string(JSON.stringify(n.to_dict())))
	t.eq(back.produce, {"plant": 2.0, "mineral": 1.2}, "产物表存读")
	t.eq(String(back.content.get("search_kind", "")), "grove", "材料种类存读")
	var old := n.to_dict()
	old.erase("produce")
	t.eq(MapNode.from_dict(old).produce, {}, "老存档：没有产物表")
	t.check(not MapNode.new().to_dict().has("produce"), "没有产物表的点不写这一项")


static func run_run_state_bias(t: TestCase) -> void:
	t.begin("267 §2.4 · 出征倾向：一局记着、存读、交给节点事件；旗标 0～3 对应 无 / 自然 / 工艺 / 魔法；搜索会话拿到产物、倾向与种类")
	var c := TestSupport.load_content("free_mode")
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	t.eq(s.material_bias, &"", "默认没选")
	s.material_bias = &"magic"
	t.eq(s.events.material_bias, &"magic", "交给节点事件")
	t.eq(s.bias_table(), {"nature": 0.6, "crafted": 0.6, "magic": 2.5}, "倍率表")
	var d := s.to_dict()
	t.eq(String(d["material_bias"]), "magic", "进存档")
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(d)), c.chapter, c.items, c.enemies, c.sets)
	t.eq(back.material_bias, &"magic", "读回来")
	t.eq(back.events.material_bias, &"magic", "读回来也交给节点事件")
	d.erase("material_bias")
	t.eq(RunState.from_dict(d, c.chapter, c.items, c.enemies, c.sets).material_bias, &"", "老存档：没选")
	s.material_bias = &"weapon"
	t.eq(s.material_bias, &"", "不认的系：当没选")
	t.eq([GameFlow.bias_of(0), GameFlow.bias_of(1), GameFlow.bias_of(2), GameFlow.bias_of(3), GameFlow.bias_of(9)], [&"", &"nature", &"crafted", &"magic", &""], "旗标对应")
	s.material_bias = &"nature"
	var kind_node: MapNode = null
	for id in s.map.node_ids():
		if s.map.get_node(id).type == &"search" and s.map.get_node(id).content.has("search_kind"):
			kind_node = s.map.get_node(id)
			break
	t.not_null(kind_node, "自由模式的图上有材料节点")
	if kind_node == null:
		return
	s.events._open_search(kind_node)
	var session := s.events.current_search
	var kind := String(kind_node.content["search_kind"])
	t.eq(session.only_tags, KIND_TAGS[kind], "会话只出 %s 那一类" % kind)
	t.eq(session.other_share, 0.25, "四分之一从普通池")
	t.eq(session.produce, kind_node.produce, "带着这一环的产物表")
	t.eq(session.bias, SearchSession.bias_table(&"nature"), "带着倾向")


static func run_tooltip(t: TestCase) -> void:
	t.begin("267 §三 · 悬浮句：材料节点说它出什么，搜索 / 宝箱点后面加一句「这一带多翻出【…】」（倍率最高的那个，> 1 才说）")
	var c := TestSupport.load_content("free_mode")
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var seen := {}
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		var kind := String(n.content.get("search_kind", "")) if n.type == &"search" else ""
		if kind == "" or seen.has(kind):
			continue
		seen[kind] = true
		var text := NodeTooltip.text_for(s, s.chapter, n)
		t.check(text.contains(UiText.t("node.hint.search_" + kind)), "%s：说它出什么（%s）" % [kind, text])
		t.check(text.contains(NodeTooltip.produce_line(n)) and NodeTooltip.produce_line(n) != "", "%s：带产物句" % kind)
	var n := MapNode.new()
	n.produce = {"plant": 2.0, "beast_part": 1.5, "mineral": 1.2}
	t.eq(NodeTooltip.produce_line(n), "这一带多翻出【草木】。", "取倍率最高的")
	n.produce = {"mineral": 1.0}
	t.eq(NodeTooltip.produce_line(n), "", "倍率不过 1 不说")


static func frame_legend(t: TestCase, root: Window) -> void:
	t.begin("267 §三 · 图例：材料节点各一行（排在搜索后面）、选了倾向「你」下面写「倾向：自然」、最下面「产物」一段由外到内")
	var c := TestSupport.load_content("free_mode")
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var legend = load("res://ui/hud/widgets/legend_widget.gd").new()
	legend.run = s
	root.add_child(legend)
	legend.refresh()
	var types: Array[StringName] = legend.types()
	var kinds := types.filter(func(k): return MapNodeStyle.KINDS.has(k))
	t.check(not kinds.is_empty(), "图上有材料节点就列（%s）" % [types])
	if types.has(&"search") and not kinds.is_empty():
		t.check(types.find(kinds[0]) > types.find(&"search"), "排在「搜索」后面")
	var names: Array[String] = legend.row_names()
	for k in kinds:
		t.check(names.has(MapNodeStyle.name_of(k)), "有「%s」一行" % MapNodeStyle.name_of(k))
	t.check(not names.has("倾向：自然"), "没选倾向：不写")
	t.eq(legend.produce_lines(), ["外：草木、兽材", "中：工艺、矿物", "内：晶石、魔法"] as Array[String], "产物三行")
	t.check(names.has("产物"), "产物段头")
	s.material_bias = &"nature"
	legend.refresh()
	names = legend.row_names()
	t.check(names.has("倾向：自然"), "选了自然：写出来")
	t.eq(MapNodeStyle.of(&"search_mine")["color"], Color("c48a3a"), "矿脉赭色")
	t.not_null(MapNodeStyle.icon(&"search_runes"), "符文堆有图标")
	t.eq(NodeText.label_of(&"search_remains"), "遗骸", "遗骸的名")
	legend.free()


static func frame_expedition_bias(t: TestCase, root: Window) -> void:
	t.begin("267 §2.4 · 出征页「倾向」木牌：四颗木牌键单选（默认「无」）、选的存局外旗标、重开页还按着、开局带进一局")
	var f := Records._flow()
	var screen = Records._screen(f, root)
	var board: ExpeditionBoard = screen.expedition_board()
	t.eq(board.bias_plate.custom_minimum_size, Vector2(560, 90), "560 × 90")
	t.eq(board.bias_keys.map(func(b): return (b as Button).text), ["无", "自然", "工艺", "魔法"], "四颗键")
	t.check(board.bias_keys.all(func(b): return (b as Button).custom_minimum_size == Vector2(120, 56)), "每颗 120 × 56")
	t.check(board.bias_keys[0].button_pressed and board.bias_choice() == 0, "默认「无」按着")
	t.eq(board.bias_keys[2].tooltip_text, "这一系材料出得更多（×2.5），另两系少一些（×0.6）", "悬浮窗写倍率")
	board.bias_keys[2].pressed.emit()
	t.eq(f.meta.flag(GameFlow.BIAS_FLAG), 2, "选工艺：旗标 2")
	board.bias_keys[2].button_pressed = true
	t.check(board.bias_keys[2].button_pressed and not board.bias_keys[0].button_pressed, "单选：「无」弹起")
	screen.free()
	var again = Records._screen(f, root)
	var b2: ExpeditionBoard = again.expedition_board()
	t.check(b2.bias_keys[2].button_pressed and not b2.bias_keys[0].button_pressed, "重开页：还按着工艺")
	again.free()
	var chapter: ChapterDef = null
	for ch in f.chapters:
		if (ch as ChapterDef).id == &"free_mode":
			chapter = ch
	var run := f.begin(chapter, null, 7) if chapter != null else null
	t.check(run != null and run.material_bias == &"crafted", "开局带进一局：工艺")
	Records._cleanup()
