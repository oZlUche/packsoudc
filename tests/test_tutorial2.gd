## 序章二「岔路」（作者定，报告 085）：分岔的教程图、节点浮窗开着、两件护具装不下、四个针对性的敌人、毒药瓶 + 匕首合成涂毒匕首、
## 两场都输也死不了、章节收起与顶上（序章通关 → 直接开序章二 → 通关 → 第一章）。期望从数据推、克制关系用真的战斗模拟验。
extends RefCounted

const SAVE := "user://test_t2_run.json"
const META := "user://test_t2_meta.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var prologue: ChapterDef
	var chapter1: ChapterDef
	var brutus: CharacterDef
	var events: Dictionary
	var recipes: Array[RecipeDef]
	var graph: MapGraph


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "prologue_2"))
	c.prologue = load(ContentPaths.asset_file("chapters", "prologue"))
	c.chapter1 = load(ContentPaths.asset_file("chapters", "chapter_01"))
	for ch in GameFlow.load_characters():
		if ch.id == &"brutus":
			c.brutus = ch
	c.events = GameFlow.load_events()
	c.recipes = GameFlow.load_recipes()
	c.graph = c.chapter.map_source.resolve(1) if c.chapter != null and c.chapter.map_source != null else null
	return c


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)


## 布鲁图斯背着这些东西的战斗单位
static func _player(c: Content, ids: Array[StringName]) -> CombatantSpec:
	var board := GridInventory.new(c.brutus.board_size, 1, true)
	for bag_id in c.brutus.starting_bags:
		board.try_add(ItemInstance.create(c.items.get_def(bag_id), 0), true)
	for id in ids:
		board.try_add(ItemInstance.create(c.items.get_def(id), 0), true)
	var ctx := RunContext.new()
	for e in c.brutus.run_effects():
		e.modify(ctx)
	var base := c.brutus.baseline()
	for key in ctx.stat_bonus:
		base.base_stats[String(key)] = float(base.base_stats.get(String(key), 0.0)) + float(ctx.stat_bonus[key])
	return BattleCompiler.compile(board, base)


## 五个种子：赢几场、平均剩多少血
static func _fight(c: Content, ids: Array[StringName], content: Dictionary) -> Dictionary:
	var me := _player(c, ids)
	var foe := EnemyKit.spec_of(content, c.enemies, null, c.items)
	var wins := 0
	var hp := 0.0
	for seed in range(1, 6):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var r := BattleSim.run(me, foe, rng, 60.0)
		if r.winner == 0:
			wins += 1
		hp += float(((r.final["sides"][0] as Dictionary)["resources"] as Dictionary)["hp"][0])
	return {"wins": wins, "hp": hp / 5.0, "hp_max": me.max_hp_int()}


static func _node_of(g: MapGraph, type: StringName, nth: int) -> MapNode:
	var seen := 0
	for id in g.node_ids():
		var n := g.get_node(id)
		if n.type == type:
			if seen == nth:
				return n
			seen += 1
	return null


static func run_data(t: TestCase) -> void:
	t.begin("序章二 · 数据：分岔再归一的图（line 布局带 row）、浮窗开着、序章通关才开、通关收起自己解锁第一章、两件护具装不下两个皮革包、敌人都带包、配方在、新道具在")
	var c := _content()
	t.not_null(c.chapter, "有序章二")
	if c.chapter == null:
		return
	t.check(c.chapter.requires_unlock == c.prologue.grants_unlock, "要序章通关")
	t.check(c.chapter.grants_unlock == c.chapter1.requires_unlock, "通关解锁第一章")
	t.check(c.chapter.hidden_by_unlock == c.chapter.grants_unlock and c.prologue.hidden_by_unlock == c.prologue.grants_unlock, "教程通关就收起")
	t.check(c.chapter.skip_setup and c.chapter.auto_spawn and c.chapter.intro_event == &"tut2_intro", "不走开局屏、开局在出生点、先过 intro")
	t.check(c.chapter.node_tooltips, "节点浮窗开着（这一张教它）")
	t.check(c.chapter.vitality_bonus >= 2, "体力多给至少 2（两场都输也死不了）")
	t.check(c.prologue.order < c.chapter.order and c.chapter.order < c.chapter1.order, "顺序：序章、序章二、第一章")
	t.not_null(c.graph, "预设载入并过了校验：%s" % c.chapter.map_source.last_error)
	if c.graph == null:
		return
	var g := c.graph
	t.eq(g.layout_kind, &"line", "line 布局")
	var rows := {}
	for id in g.node_ids():
		rows[int(g.get_node(id).layout.get("row", 0))] = true
	t.check(rows.size() >= 3, "分了几行（岔路上下错开）")
	var layout := MapLayout.for_graph(g)
	var pos := layout.positions(g, Rect2(Vector2.ZERO, layout.canvas_size(g)))
	var ys := {}
	for id in pos:
		ys[roundi(pos[id].y)] = true
	t.check(ys.size() >= 3, "画出来上下有别")
	# 岔路：搜索点 1 通向两个战斗点，两个战斗点汇到搜索点 2；再分到两个战斗点、汇到事件点；最后撤离
	var s1 := _node_of(g, &"search", 0)
	var s2 := _node_of(g, &"search", 1)
	var lesson := _node_of(g, &"event", 0)
	var ext := _node_of(g, &"extract", 0)
	t.check(s1 != null and s2 != null and lesson != null and ext != null, "四个关键点都在")
	if s1 == null or s2 == null or lesson == null or ext == null:
		return
	var fork1: Array[int] = []
	for nid in g.neighbors(s1.id):
		if g.get_node(nid).type == &"battle":
			fork1.append(nid)
	t.eq(fork1.size(), 2, "第一个岔路口分到两个战斗点")
	for nid in fork1:
		t.check(g.neighbors(nid).has(s2.id), "战斗点 %d 归到搜索点 2" % nid)
	var fork2: Array[int] = []
	for nid in g.neighbors(s2.id):
		if g.get_node(nid).type == &"battle" and not fork1.has(nid):
			fork2.append(nid)
	t.eq(fork2.size(), 2, "第二个岔路口分到两个战斗点")
	for nid in fork2:
		t.check(g.neighbors(nid).has(lesson.id), "战斗点 %d 归到事件点" % nid)
	t.check(g.neighbors(lesson.id).has(ext.id), "事件点接撤离点")
	t.eq(g.goal_ids, [ext.id] as Array[int], "终点是撤离点")
	# 每个点都配了事件、战斗点有敌人与浮窗文字
	for id in g.node_ids():
		var n := g.get_node(id)
		if n.type == &"spawn":
			continue
		var eid := String(n.content.get("event", ""))
		t.check(eid != "" and c.events.has(StringName(eid)), "点 %d 配了事件 %s" % [id, eid])
		if n.type == &"battle":
			t.check(EnemyKit.has_enemy(n.content) and c.enemies.enemy(StringName(String(n.content["enemy"]))) != null, "点 %d 有敌人" % id)
			t.check(String(n.content.get("tooltip", "")).contains("{battle_data}"), "点 %d 的浮窗写了对手数据" % id)
			var board := EnemyKit.board_of(n.content, c.items)
			t.check(board.requires_bag and board.item_count() == (n.content["items"] as Array).size(), "点 %d 的敌人带包、都摆上了" % id)
	# 搜索点 1：两件护具，加起来装不下布鲁图斯的两个包
	var armors: Array[StringName] = []
	for round in s1.content["search_finds"]:
		for id in round:
			armors.append(StringName(String(id)))
	t.eq(armors.size(), 2, "两件护具")
	var cells := 0
	for id in armors:
		t.not_null(c.items.get_def(id), "护具 %s 在" % id)
		cells += c.items.get_def(id).shape.cell_count()
	var bag_cells := 0
	for b in c.brutus.starting_bags:
		bag_cells += c.items.get_def(b).shape.cell_count()
	t.check(cells > bag_cells, "两件护具 %d 格 > 两个包 %d 格：只能带一件" % [cells, bag_cells])
	# 搜索点 2：毒药瓶、长剑、长条包；配方
	var finds2: Array[StringName] = []
	for round in s2.content["search_finds"]:
		for id in round:
			finds2.append(StringName(String(id)))
	t.check(finds2.has(&"poison_vial") and finds2.has(&"longsword") and finds2.has(&"bag_long"), "毒药瓶、长剑、长条包（%s）" % str(finds2))
	var recipe := RecipeDef.find(c.recipes, &"knife", &"poison_vial")
	t.check(recipe != null and recipe.output == &"poisoned_knife", "匕首 + 毒药瓶 → 涂毒匕首")
	t.check(RecipeDef.find(c.recipes, &"poison_vial", &"knife") == recipe, "顺序无关")
	t.is_null(RecipeDef.find(c.recipes, &"knife", &"longsword"), "没有的配方是 null")
	var long_bag := c.items.get_def(&"bag_long").shape.cell_count()
	t.check(long_bag >= c.items.get_def(&"longsword").shape.cell_count() and long_bag >= 2, "长条包装得下长剑，或匕首 + 毒药")


static func run_matchups(t: TestCase) -> void:
	t.begin("序章二 · 克制：游兵只有塔盾扛得住（板甲被磨光而死）；重击手板甲轻伤、塔盾重伤；持符者只有毒；药师只有长剑；两场都输也死不了")
	var c := _content()
	if c.graph == null:
		t.check(false, "没有图")
		return
	var g := c.graph
	var swarm := g.get_node(2).content
	var heavy := g.get_node(3).content
	var ward := g.get_node(5).content
	var cure := g.get_node(6).content
	var r1 := _fight(c, [&"knife", &"tower_shield"], swarm)
	var r2 := _fight(c, [&"knife", &"plate_cuirass"], swarm)
	t.eq(int(r1["wins"]), 5, "游兵 vs 匕首 + 塔盾：全赢")
	t.eq(int(r2["wins"]), 0, "游兵 vs 匕首 + 板甲：全输（护盾磨光之后一直掉血）")
	var h1 := _fight(c, [&"knife", &"tower_shield"], heavy)
	var h2 := _fight(c, [&"knife", &"plate_cuirass"], heavy)
	t.check(int(h1["wins"]) == 5 and int(h2["wins"]) == 5, "重击手：两种护具都能赢（血不多）")
	t.check(float(h2["hp"]) > float(h1["hp"]) + 20.0, "板甲轻伤（剩 %.0f）、塔盾重伤（剩 %.0f）" % [h2["hp"], h1["hp"]])
	t.check(float(h2["hp"]) >= float(h2["hp_max"]) * 0.7, "板甲接住了重锤：剩七成以上的血")
	# 第二个岔路口时身上有第一个岔路口带的那件护具：两种都验
	for armor in [&"tower_shield", &"plate_cuirass"]:
		var w1 := _fight(c, [&"poisoned_knife", armor, &"bag_long"], ward)
		var w2 := _fight(c, [&"longsword", armor, &"bag_long"], ward)
		var w3 := _fight(c, [&"knife", armor, &"bag_long"], ward)
		t.eq(int(w1["wins"]), 5, "持符者 vs 涂毒匕首 + %s：全赢（毒无视护盾）" % armor)
		t.eq(int(w2["wins"]), 0, "持符者 vs 长剑 + %s：赢不了（砍不过叠盾）" % armor)
		t.eq(int(w3["wins"]), 0, "持符者 vs 普通匕首 + %s：赢不了（流血被回血抵掉）" % armor)
		var k1 := _fight(c, [&"longsword", armor, &"bag_long"], cure)
		var k2 := _fight(c, [&"poisoned_knife", armor, &"bag_long"], cure)
		t.eq(int(k1["wins"]), 5, "药师 vs 长剑 + %s：全赢" % armor)
		t.eq(int(k2["wins"]), 0, "药师 vs 涂毒匕首 + %s：赢不了（毒一冒头就被清）" % armor)
	# 两场都输也死不了：体力 = 角色的 + 坚韧 + 章节加成，输一场扣 loss_cost.battle
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	t.not_null(s, "开得了局")
	if s != null:
		var cost := s.node_rules.loss_cost_of(&"battle")
		t.check(s.vitality.maximum > cost * 2, "体力 %d > 两场战败的 %d" % [s.vitality.maximum, cost * 2])
		t.eq(s.vitality.maximum, c.brutus.vitality_max + s.buff_context().vitality_max_bonus + c.chapter.vitality_bonus, "体力 = 角色 + 技能 + 章节加成")


static func run_crafting(t: TestCase) -> void:
	t.begin("序章二 · 合成：毒药瓶拖到匕首上 → 涂毒匕首落在匕首的位置，两件消失；没有配方的照旧顶替；RunState.craft_output 查配方")
	var c := _content()
	ItemInstance.reset_uid_counter()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	var stash := ItemStash.new(2, 0)
	board.try_add(ItemInstance.create(c.items.get_def(&"bag_leather")), true)
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	t.check(board.try_add(knife, true), "匕首在包里")
	var home := knife.origin
	var vial := ItemInstance.create(c.items.get_def(&"poison_vial"))
	stash.admit(vial)
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	var sview := StashView.new()
	sview.stash = stash
	sview.position = Vector2(400, 0)
	sview.size = Vector2(220, 200)
	var drag := DragLayer.new()
	drag.register_view(view)
	drag.register_view(sview)
	drag.stash = stash
	var recipes := c.recipes
	drag.craft = func(a: ItemInstance, b: ItemInstance) -> ItemDef:
		var r := RecipeDef.find(recipes, a.def.id, b.def.id)
		return c.items.get_def(r.output) if r != null else null
	var made: Array = []
	drag.crafted.connect(func(_a: ItemInstance, _b: ItemInstance, out: ItemInstance): made.append(out))
	sview.grab_requested.emit(sview, vial.uid, Vector2(10, 10))
	t.check(drag.is_dragging(), "抓起毒药瓶")
	var at := (Vector2(home) + Vector2(0.5, 0.5)) * InventoryView.CELL
	drag.update_preview(at)
	t.check(drag.drop_at(at), "放到匕首上：算落入")
	t.eq(made.size(), 1, "合成了一件")
	if made.is_empty():
		return
	var out := made[0] as ItemInstance
	t.eq(out.def.id, &"poisoned_knife", "产物是涂毒匕首")
	t.check(board.has_item(out.uid) and out.origin == home, "落在匕首原来的位置")
	t.check(not board.has_item(knife.uid) and not stash.has_item(vial.uid), "匕首与毒药瓶都没了")
	t.eq(board.item_count(), 2, "棋盘上：包 + 涂毒匕首")
	# 没有配方：照旧顶替
	var other := ItemInstance.create(c.items.get_def(&"salve"))
	stash.admit(other)
	sview.grab_requested.emit(sview, other.uid, Vector2(10, 10))
	drag.update_preview(at)
	t.check(drag.drop_at(at), "伤药放到涂毒匕首上：顶替（放下了）")
	t.check(board.has_item(other.uid) and other.origin == home, "伤药占了那格")
	t.check(drag.is_dragging() and made.size() == 1, "被顶出的涂毒匕首拿在手上，没再合成")
	drag.cancel()
	# RunState 的入口
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	if s != null:
		s.recipes = recipes
		t.check(s.craft_output(c.items.get_def(&"knife"), c.items.get_def(&"poison_vial")) == c.items.get_def(&"poisoned_knife"), "RunState.craft_output 查得到")
		t.is_null(s.craft_output(c.items.get_def(&"knife"), c.items.get_def(&"salve")), "没有的是 null")


static func run_gating(t: TestCase) -> void:
	t.begin("序章二 · 章节的门：序章通关 → 序章收起、只剩序章二 → 「新的一局」直接开它、先过 intro → 通关 → 第一章开、序章二收起")
	var c := _content()
	_cleanup()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = GameFlow.load_chapters()
	f.characters = GameFlow.load_characters()
	f.event_defs = c.events
	f.recipes = c.recipes
	f.save_path = SAVE
	f.meta_path = META
	f.meta.grant_unlock(c.prologue.grants_unlock)
	var avail := f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"prologue_2", "序章通关之后只列序章二（序章收起）：%s" % str(avail.map(func(x: ChapterDef) -> String: return String(x.id))))
	f.new_run()
	var run := f.run
	t.not_null(run, "直接开了序章二")
	if run == null:
		return
	t.check(run.chapter == c.chapter and run.character_id == &"brutus", "章是序章二、角色布鲁图斯")
	t.eq(f.screen, GameFlow.Screen.EVENT, "先过 intro")
	t.check((f.last_payload.get("def", null) as EventDef).id == &"tut2_intro", "是 tut2_intro")
	t.check(f.tooltips_enabled(), "这一章浮窗开着")
	t.check(not run.recipes.is_empty(), "配方进了这一局")
	t.check(f.choose_event(0), "出发")
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.eq(run.travel.available_moves().size(), 1, "出生点只通向搜索点")
	# 直接站到撤离点撤（走一遍的克制在上一组验过了）
	run.travel.start_at(run.map.goal_ids[0])
	t.check(f.extract(), "撤离")
	t.check(f.meta.has_unlock(c.chapter.grants_unlock), "拿到序章二的解锁")
	avail = f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"chapter_01", "序章二收起，只剩第一章：%s" % str(avail.map(func(x: ChapterDef) -> String: return String(x.id))))
	_cleanup()
