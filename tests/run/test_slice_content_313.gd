## 313（试玩切片 S1 第一批）：切片章节只在切片档案里列；预设地图 13 点一处分支；每个点写的道具都在可得清单里；
## 敌人棋盘摆得下；赐福替换在切片的掉落、搜索规则里关掉；能从出生点开局
extends RefCounted

## 切片可得道具：正式清单 data/manifests/slice_ruins.json（313 第三批起）
static func _allowed() -> Array:
	return SliceAudit.load_manifest("slice_ruins").get("allowed_item_ids", [])


static func _map() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/slice_ruins.json"))


static func _ids_in(content: Dictionary) -> Array:
	var out: Array = []
	for e in content.get("items", []):
		out.append(String(e["id"]))
	for id in content.get("guaranteed_drops", []):
		out.append(String(id))
	for round_ in content.get("search_finds", []):
		for id in round_:
			out.append(String(id))
	for id in content.get("shop_stock", []):
		out.append(String(id))
	if content.has("encounter"):
		out.append_array(_ids_in(content["encounter"]))
	return out


static func run_chapter(t: TestCase) -> void:
	t.begin("313 · 切片章节：只在 slice 档案里列，正式版看不到；只有安德烈乌斯、开局匕首纱布口粮、不带东西进、倒计时 20、免费撤离点不关")
	var ch := ContentPaths.load_asset("chapters", "slice_ruins") as ChapterDef
	t.not_null(ch, "有切片章节")
	if ch == null:
		return
	t.eq(ch.profile, &"slice", "属于 slice 档案")
	t.check(GameFlow.load_chapters().all(func(c: ChapterDef) -> bool: return c.id != &"slice_ruins"), "正式版的章节表里没有它")
	var only := GameFlow.load_chapters(&"slice")
	t.eq(only.map(func(c: ChapterDef) -> StringName: return c.id), [&"slice_ruins"], "切片档案只有它")
	t.eq(ch.characters, [&"andreus"] as Array[StringName], "只有安德烈乌斯")
	t.eq(ch.starting_items, [&"knife", &"bandage", &"ration"] as Array[StringName], "开局道具")
	t.check(not ch.allow_carry_in and ch.step_limit == 20 and not ch.closing_extract, "不带东西进、倒计时 20、撤离点不随时间关")
	var drop := ContentPaths.load_asset("drop_rules", String(ch.drop_rule)) as DropRule
	var rules := ContentPaths.load_asset("node_rules", String(ch.node_rules)) as NodeRules
	var econ := ContentPaths.load_asset("economy_rules", String(ch.economy_rules)) as EconomyRules
	t.check(drop != null and drop.bless_chance == 0.0 and drop.bless_chance_active == 0.0 and drop.treasure_chance == 0.0, "掉落不换赐福版、不掉宝物")
	t.check(rules != null and rules.search.bless_chance == 0.0 and rules.search.bless_chance_active == 0.0, "搜索不换赐福版")
	t.check(econ != null and econ.paid_extracts == 0, "没有付费撤离点")
	# S2：切片自己的引导 —— 地图一段、战前一段，各不超过两步（不搬三张序章）
	t.eq(ch.coaches.keys(), ["map", "prebattle"], "只在地图、战前放引导")
	for key in ch.coaches:
		var steps := CoachOverlay.load_steps(StringName(String(ch.coaches[key])))
		t.check(steps.size() >= 1 and steps.size() <= 2, "%s 的引导 1～2 步（%d）" % [key, steps.size()])
		for s in steps:
			t.check(String(s.get("text", "")) != "" and String((s.get("texts", {}) as Dictionary).get("en", "")) != "", "%s 每步有中英两句" % key)


static func run_map(t: TestCase) -> void:
	t.begin("313 · 切片地图：13 点（出生、两个撤离、10 个内容点）、商店线和精英线在歇脚点合流；写的道具都在清单里；敌人的东西都摆得下")
	var d := _map()
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var nodes: Array = d["nodes"]
	t.eq(nodes.size(), 13, "13 个点")
	t.eq(nodes.filter(func(n) -> bool: return n["type"] == "extract").size(), 2, "两个撤离点")
	t.eq((d["entry_ids"] as Array).map(func(x) -> int: return int(x)), [0], "出生点 0")
	var g := MapGraph.from_dict(d)
	t.not_null(g, "读得成图")
	if g == null:
		return
	t.check(g.edge_between(3, 4) != null and g.edge_between(3, 6) != null and g.edge_between(5, 8) != null and g.edge_between(7, 8) != null, "蛮兵之后分两路（商店 / 精英），在歇脚点合流")
	for n in nodes:
		var c: Dictionary = n["content"]
		for id in _ids_in(c):
			t.check(_allowed().has(id), "点 %d 的 %s 在可得清单里" % [n["id"], id])
			t.not_null(items.get_def(StringName(id)), "点 %d 的 %s 存在" % [n["id"], id])
		for foe in ([c] if c.has("enemy") else []) + ([c["encounter"]] if c.has("encounter") else []):
			t.not_null(enemies.enemy(StringName(String(foe["enemy"]))), "点 %d 的敌人 %s 存在" % [n["id"], foe["enemy"]])
			t.eq(EnemyKit.unplaced_items(foe, items), [] as Array[StringName], "点 %d 的敌人东西都摆得下" % n["id"])
			t.check((foe["base_stats"] as Dictionary).has("block"), "点 %d 写明格挡（不写会沿用敌人定义里的）" % n["id"])
	var ch := ContentPaths.load_asset("chapters", "slice_ruins") as ChapterDef
	var shortswords := 0
	for n in nodes:
		shortswords += _ids_in(n["content"]).count("shortsword")
	t.eq(shortswords, 1, "制式短剑全图只有一把（商店）：拼不出双手剑")
	for id in ch.starting_items:
		t.check(_allowed().has(String(id)), "开局 %s 在清单里" % id)


static func run_start(t: TestCase) -> void:
	t.begin("313 · 切片能开局：安德烈乌斯站在出生点，开局道具到手")
	var c := TestSupport.load_content("slice_ruins")
	var ch := ContentPaths.load_asset("characters", "andreus") as CharacterDef
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], ch)
	t.not_null(s, "开得出来")
	if s == null:
		return
	if s.travel.current_id < 0:
		s.pick_spawn(s.map.entry_ids[0])
	t.eq(s.travel.current_id, 0, "站在出生点")
	var have: Array = []
	for inst in s.board.items() + s.storage.items():
		have.append(String((inst as ItemInstance).def.id))
	for id in ["knife", "bandage", "ration"]:
		t.check(have.has(id), "开局有 %s（%s）" % [id, have])
	s.dispose()


static func run_loss_line(t: TestCase) -> void:
	t.begin("313 · S2 战后得失：打输扣了体力，回地图说一句扣几点、剩几点；赢了、没扣、等求饶都不说")
	var c := TestSupport.load_content("slice_ruins")
	var ch := ContentPaths.load_asset("characters", "andreus") as CharacterDef
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], ch)
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new(GameFlow.load_meta_rules()))
	f.run = s
	var screen = load("res://ui/game/battle_screen.gd").new()
	screen.flow = f
	screen._won = false
	s.events.last_battle = {"before": s.events.state_brief()}
	t.eq(screen.loss_line(), "", "没扣：不说")
	s.vitality.spend(1, &"battle_lost")
	t.eq(screen.loss_line(), UiText.t("battle.lost_vitality") % [1, s.vitality.current, s.vitality.maximum], "扣了一点：说扣几点、剩几点")
	screen._won = true
	t.eq(screen.loss_line(), "", "赢了：不说（有战利品屏）")
	screen.free()
	s.dispose()
