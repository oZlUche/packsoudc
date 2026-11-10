## 267（作者 2026-10-29 16:49 认可推荐）：材料定向 —— B 环的产物表、C 材料节点四种（矿脉 / 林地 / 遗骸 / 符文堆）；A 出征倾向 283 删了。
## 搜索 / 宝箱 / 事件掷道具时权重多乘产物表（命中的取最大），材料节点只出那一类材料（每件 1/4 从普通池抽）；
## 节点类型一个不动（材料种类是内容不是拓扑），地图上换图标与色，图例多「产物」一段
extends RefCounted

const Records := preload("res://tests/ui/test_records_board_260.gd")

const SEEDS := 32
const KIND_TAGS := {"mine": ["mineral", "bullion"], "grove": ["plant", "beast_part"], "remains": ["crafted"], "runes": ["crystal", "magic"]}


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _rules() -> NodeRules:
	return load(ContentPaths.asset_file("node_rules", "standard"))


static func _floats(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = float(d[k])
	return out


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


static func run_tags(t: TestCase) -> void:
	t.begin("267 §一 · 两个新标签【矿物】【草木】：15 种材料贴上（金银块已是「金银」、搜索不出，244 补充一只许两枚标签，不贴）；四种材料节点的标签照配置")
	var db := _db()
	for id in [&"copper_ore", &"iron_ore", &"silver_ore", &"flint", &"raw_salt", &"gravestone_shard"]:
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
	t.begin("267 §2.1 · 掷物：产物命中取最大不连乘；材料节点只出那一类、空了退回全池；什么都不传和原来一样")
	var db := _db()
	var sr := _rules().search
	var oak := db.get_def(&"oak_log")
	var outskirts := {"plant": 2.0, "beast_part": 1.5, "mineral": 1.2}
	t.eq(SearchSession.weight_mult(oak, outskirts), 2.0, "橡木在外环：草木 ×2（不乘 1.5 / 1.2）")
	t.eq(SearchSession.weight_mult(db.get_def(&"longsword"), outskirts), 1.0, "没命中：×1")
	var plain := SearchSession.draw_items(sr, db, 0.3, 1, _rng(11))
	t.eq(SearchSession.draw_items(sr, db, 0.3, 1, _rng(11), -1, [] as Array[int], {}, [], 0.0), plain, "什么都不传：同一种子掷的一样")
	for k in KIND_TAGS:
		var bad: Array[String] = []
		var n := 0
		for s in 40:
			for id in SearchSession.draw_items(sr, db, 0.5, 0, _rng(100 + s), -1, [] as Array[int], {}, KIND_TAGS[k], 0.0):
				n += 1
				if not SearchSession.in_kind(db.get_def(id), KIND_TAGS[k]):
					bad.append(String(id))
		t.check(n > 0 and bad.is_empty(), "%s（纯）：%d 件全是这一类材料（不对的 %s）" % [k, n, bad])
	var weapons := 0
	for s in 40:
		for id in SearchSession.draw_items(sr, db, 0.5, 0, _rng(300 + s), -1, [] as Array[int], {}, ["crafted"], 0.0):
			if db.get_def(id).tags.has(&"weapon") or db.get_def(id).tags.has(&"armor"):
				weapons += 1
	t.eq(weapons, 0, "遗骸：带「工艺」的武器防具不出")
	var none := SearchSession.draw_items(sr, db, 0.5, 0, _rng(7), -1, [] as Array[int], {}, ["no_such_tag_267"], 0.0)
	t.check(not none.is_empty(), "过滤后空了：退回全池，不空手")
	var inside := 0
	var total := 0
	for s in 120:
		for id in SearchSession.draw_items(sr, db, 0.5, 0, _rng(500 + s), -1, [] as Array[int], {}, KIND_TAGS["mine"], 0.25):
			total += 1
			if SearchSession.in_kind(db.get_def(id), KIND_TAGS["mine"]):
				inside += 1
	var share := float(inside) / maxf(1.0, float(total))
	t.check(share > 0.65 and share < 0.95, "矿脉 other_share 0.25：%d / %d 件是矿物（%.2f）" % [inside, total, share])
	var floored := SearchSession.draw_items(sr, db, 0.5, 0, _rng(9), -1, [2, 2] as Array[int], {}, KIND_TAGS["runes"], 0.0)
	t.check(floored.size() >= 2 and floored.all(func(id): return SearchSession.in_kind(db.get_def(id), KIND_TAGS["runes"])), "有保底也从那一类里抽（%s）" % [floored])


static func run_session_kind(t: TestCase) -> void:
	t.begin("267 §2.4 / 283 · 搜索会话拿到产物与种类；出征倾向删了：存档不再写，老档写了也照读")
	var c := TestSupport.load_content("free_mode")
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var d := s.to_dict()
	t.check(not d.has("material_bias"), "存档没有倾向")
	d["material_bias"] = "magic"
	t.not_null(RunState.from_dict(JSON.parse_string(JSON.stringify(d)), c.chapter, c.items, c.enemies, c.sets), "老档带着倾向：读得回来")
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


static func run_tooltip(t: TestCase) -> void:
	t.begin("267 §三 · 悬浮句：材料节点说它出什么（不再接环的产物句）；普通搜索 / 宝箱点后面加一句「这一带多翻出【…】」（倍率最高的那个，> 1 才说）")
	var c := TestSupport.load_content("free_mode")
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var seen := {}
	for id in s.map.node_ids():
		var n_ := s.map.get_node(id)
		var kind := String(n_.content.get("search_kind", "")) if n_.type == &"search" else ""
		if kind == "" or seen.has(kind):
			continue
		seen[kind] = true
		var text := NodeTooltip.text_for(s, s.chapter, n_)
		t.check(text.contains(UiText.t("node.hint.search_" + kind)), "%s：说它出什么（%s）" % [kind, text])
		t.check(NodeTooltip.produce_line(n_) != "" and not text.contains(NodeTooltip.produce_line(n_)), "%s：不再接环的产物句（复测 v4.77：前后矛盾）" % kind)
	for id in s.map.node_ids():
		var plain := s.map.get_node(id)
		if plain.type == &"search" and not plain.content.has("search_kind") and NodeTooltip.produce_line(plain) != "" and not plain.is_visited():
			t.check(NodeTooltip.text_for(s, s.chapter, plain).contains(NodeTooltip.produce_line(plain)), "普通搜索点：接环的产物句")
			break
	var n := MapNode.new()
	n.produce = {"plant": 2.0, "beast_part": 1.5, "mineral": 1.2}
	t.eq(NodeTooltip.produce_line(n), "这一带多翻出【草木】。", "取倍率最高的")
	n.produce = {"mineral": 1.0}
	t.eq(NodeTooltip.produce_line(n), "", "倍率不过 1 不说")


static func frame_legend(t: TestCase, root: Window) -> void:
	t.begin("267 §三 · 图例：材料节点各一行（排在搜索后面）、最下面「产物」一段由外到内")
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
	t.eq(legend.produce_lines(), ["外：草木、兽材", "中：工艺、矿物", "内：晶石、魔法"] as Array[String], "产物三行")
	t.check(names.has("产物"), "产物段头")
	t.eq(MapNodeStyle.of(&"search_mine")["color"], Color("c48a3a"), "矿脉赭色")
	t.not_null(MapNodeStyle.icon(&"search_runes"), "符文堆有图标")
	t.eq(NodeText.label_of(&"search_remains"), "遗骸", "遗骸的名")
	legend.free()


static func frame_expedition_no_bias(t: TestCase, root: Window) -> void:
	t.begin("283 · 出征页没有「倾向」木牌（267 A 整层删了），开局照常")
	var f := Records._flow()
	var screen = Records._screen(f, root)
	var board: ExpeditionBoard = screen.expedition_board()
	t.check(not ("bias_plate" in board) and not ("bias_keys" in board), "没有倾向木牌")
	screen.free()
	var chapter: ChapterDef = null
	for ch in f.chapters:
		if (ch as ChapterDef).id == &"free_mode":
			chapter = ch
	t.not_null(f.begin(chapter, null, 7) if chapter != null else null, "开局照常")
	Records._cleanup()
