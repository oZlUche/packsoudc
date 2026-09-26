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
	var has_weapon := false
	for id in c.chapter.starting_items:
		if c.items.get_def(id) != null and c.items.get_def(id).tags.has(&"weapon"):
			has_weapon = true
	t.check(has_weapon, "开局发一把武器（%s）" % str(c.chapter.starting_items))
	var knife_def := c.items.get_def(&"knife")
	t.check(not knife_def.tags.has(&"bleed") and (knife_def.combat.rules[0] as AbilityRule).effects.size() == 1, "普通匕首只是高频低伤，没有流血")
	t.check(c.items.get_def(&"poison_vial").combat != null and not c.items.get_def(&"poison_vial").combat.rules.is_empty(), "毒药瓶自己也能下毒（慢）")
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
	t.check(float(h2["hp"]) >= float(h2["hp_max"]) * 0.7, "板甲接住了重锤：剩七成以上的血（%.0f/%d）" % [h2["hp"], h2["hp_max"]])
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


static func run_crafting_deferred(t: TestCase) -> void:
	t.begin("序章二 · 合成不是立刻的（085 作者定）：拖到一起只配对（记号「合」、提示）→ 走到下一个点才合成、发提示；装不下进暂存区并提醒；配的那件丢了拖着的进暂存区；跟存档")
	var c := _content()
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	t.not_null(s, "开得了局")
	if s == null:
		return
	s.recipes = c.recipes
	s.event_defs = c.events
	var knife := ItemInstance.create(c.items.get_def(&"knife"))
	t.check(s.board.try_add(knife, true), "匕首在包里")
	var home := knife.origin
	var vial := ItemInstance.create(c.items.get_def(&"poison_vial"))     # 拖着的那件：不在任何容器里
	var queued: Array = []
	s.craft_queued.connect(func(a: ItemInstance, b: ItemInstance, out: ItemDef): queued.append([a.uid, b.uid, out.id]))
	t.check(not s.queue_craft(vial, ItemInstance.create(c.items.get_def(&"salve"))), "没配方 / 不在棋盘上的配不了")
	t.check(s.queue_craft(vial, knife), "毒药瓶配到匕首上")
	t.check(not s.queue_craft(ItemInstance.create(c.items.get_def(&"poison_vial")), knife), "匕首已经配过对")
	t.eq(queued.size(), 1, "发了 craft_queued")
	t.check(s.craft_partner_of(knife.uid) == vial and s.pending_crafts.size() == 1, "记着这一对")
	t.check(s.board.has_item(knife.uid) and not s.storage.has_item(vial.uid), "匕首还在棋盘上，毒药瓶不在暂存区（RunState 保管）")
	# 存档带着
	var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and back.pending_crafts.size() == 1 and int(back.pending_crafts[0]["b_uid"]) == knife.uid, "存档带着配好的对")
	# 走到下一个点：合成发生
	var done: Array = []
	s.craft_done.connect(func(_id: int, detail: Dictionary): done.append(detail))
	var next: int = s.travel.available_moves()[0]
	t.check(s.step_to(next), "走到下一个点")
	t.eq(done.size(), 1, "发了 craft_done")
	if done.is_empty():
		return
	t.eq(String(done[0]["output"]), "poisoned_knife", "产物是涂毒匕首")
	t.eq(String(done[0]["where"]), "board", "落在棋盘上")
	t.check(String((done[0]["log"] as Array)[0]).contains("合成了"), "提示文字")
	var made: ItemInstance = null
	for inst in s.board.items():
		if (inst as ItemInstance).def.id == &"poisoned_knife":
			made = inst
	t.check(made != null and made.origin == home, "涂毒匕首落在匕首原来的位置")
	t.check(not s.board.has_item(knife.uid) and s.pending_crafts.is_empty(), "匕首没了、队列清了")
	# 配的那件在暂存区里：两件都拿出来保管，到了下一个点产物进包
	var s4 := RunState.start(c.chapter, 4, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	s4.recipes = c.recipes
	var knife4 := ItemInstance.create(c.items.get_def(&"knife"))
	s4.storage.admit(knife4)
	var vial4 := ItemInstance.create(c.items.get_def(&"poison_vial"))
	t.check(s4.queue_craft(vial4, knife4), "匕首在暂存区里也能配对")
	t.check(not s4.storage.has_item(knife4.uid), "配对时匕首从暂存区拿出来了（不然一挪步就丢）")
	var back4 := RunState.from_dict(s4.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back4 != null and back4.pending_crafts.size() == 1 and back4.pending_crafts[0]["b"] != null, "保管的两件都跟存档")
	var done4: Array = []
	s4.craft_done.connect(func(_id: int, detail: Dictionary): done4.append(detail))
	s4.step_to(s4.travel.available_moves()[0])
	var made4 := false
	for inst in s4.board.items():
		if (inst as ItemInstance).def.id == &"poisoned_knife":
			made4 = true
	t.check(done4.size() == 1 and String(done4[0]["where"]) == "board" and made4, "到了下一个点：涂毒匕首进了包")
	# 装不下：把包塞满再配一对，产物进暂存区并提醒
	var s2 := RunState.start(c.chapter, 2, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	s2.recipes = c.recipes
	var knife2 := ItemInstance.create(c.items.get_def(&"knife"))
	s2.board.try_add(knife2, true)
	var vial2 := ItemInstance.create(c.items.get_def(&"poison_vial"))
	t.check(s2.queue_craft(vial2, knife2), "配对")
	# 匕首那一格被拿走之后要放得下涂毒匕首（同样 1 格）：所以先把产物换成放不下的情形 —— 用别的东西把包塞满、再把匕首挪到暂存区之外是不行的；
	# 这里直接验「b 不在了」与「进暂存区」两条：把匕首从棋盘拿掉
	s2.board.remove(knife2.uid)
	var done2: Array = []
	s2.craft_done.connect(func(_id: int, detail: Dictionary): done2.append(detail))
	s2.step_to(s2.travel.available_moves()[0])
	t.check(done2.size() == 1 and String(done2[0]["where"]) == "storage" and s2.storage.has_item(vial2.uid), "配的那件不在了：拖着的进暂存区、有提示（%s）" % str(done2[0]["log"] if not done2.is_empty() else []))
	# 产物放不下：配方产物比原件大时才会发生；用一个临时配方验（1 格匕首 → 3×3 板甲），包里塞满
	var s3 := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	var big := RecipeDef.new()
	big.id = &"t_big"
	big.inputs = [&"knife", &"poison_vial"] as Array[StringName]
	big.output = &"plate_cuirass"
	s3.recipes = [big] as Array[RecipeDef]
	var knife3 := ItemInstance.create(c.items.get_def(&"knife"))
	s3.board.try_add(knife3, true)
	while s3.board.try_add(ItemInstance.create(c.items.get_def(&"salve")), true):
		pass     # 塞满
	t.check(s3.queue_craft(ItemInstance.create(c.items.get_def(&"poison_vial")), knife3), "配对")
	var done3: Array = []
	s3.craft_done.connect(func(_id: int, detail: Dictionary): done3.append(detail))
	s3.step_to(s3.travel.available_moves()[0])
	t.check(done3.size() == 1 and String(done3[0]["where"]) == "storage", "产物装不下：进暂存区")
	t.check(not done3.is_empty() and (done3[0]["log"] as Array).size() == 2 and String((done3[0]["log"] as Array)[1]).contains("装不下"), "提醒玩家装不下")
	var in_storage := false
	for inst in s3.storage.items():
		if (inst as ItemInstance).def.id == &"plate_cuirass":
			in_storage = true
	t.check(in_storage, "产物在暂存区里")


static func run_crafting(t: TestCase) -> void:
	t.begin("序章二 · 拖拽层的合成：没给 queue_craft 时立刻合（沙盒 / 测试）；给了就只配对、a 交出去；没有配方的照旧顶替；RunState.craft_output 查配方")
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
	# 配对模式：给了 queue_craft 就不立刻合
	var pairs: Array = []
	drag.queue_craft = func(a: ItemInstance, b: ItemInstance) -> bool:
		pairs.append([a.uid, b.uid])
		return true
	var vial2 := ItemInstance.create(c.items.get_def(&"poison_vial"))
	stash.admit(vial2)
	var knife2 := ItemInstance.create(c.items.get_def(&"knife"))
	t.check(board.try_add(knife2, true), "再放一把匕首")
	var at2 := (Vector2(knife2.origin) + Vector2(0.5, 0.5)) * InventoryView.CELL
	sview.grab_requested.emit(sview, vial2.uid, Vector2(10, 10))
	t.check(view.highlights.has(knife2.uid) and not view.highlights.has(other.uid), "拿起毒药瓶：棋盘上的匕首亮了，伤药没亮（085）")
	t.check(drag.drop_at(at2), "放到匕首上：算落入（配对）")
	t.check(pairs == [[vial2.uid, knife2.uid]] and made.size() == 1, "只配对，没立刻合")
	t.check(board.has_item(knife2.uid) and not stash.has_item(vial2.uid), "匕首还在、毒药瓶交出去了")
	t.check(view.highlights.is_empty(), "放下之后高光熄了")
	# 反过来：拿起匕首，暂存区里的毒药瓶亮；压到它那一行上也配对
	var knife3 := ItemInstance.create(c.items.get_def(&"knife"))
	t.check(board.try_add(knife3, true), "再放一把匕首")
	var vial3 := ItemInstance.create(c.items.get_def(&"poison_vial"))
	stash.admit(vial3)
	view.grab_requested.emit(view, knife3.uid, (Vector2(knife3.origin) + Vector2(0.5, 0.5)) * InventoryView.CELL)
	t.check(sview.highlights.has(vial3.uid), "拿起匕首：暂存区里的毒药瓶亮了")
	var row := stash.index_of(vial3.uid)
	var row_at := sview.position + sview.row_origin_px(row) + Vector2(20, 10)
	drag.update_preview(row_at)
	t.check(drag.drop_at(row_at), "压到毒药瓶那一行：配对")
	t.check(pairs.size() == 2 and pairs[1] == [knife3.uid, vial3.uid], "反过来也配对")
	# RunState 的入口
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	if s != null:
		s.recipes = recipes
		t.check(s.craft_output(c.items.get_def(&"knife"), c.items.get_def(&"poison_vial")) == c.items.get_def(&"poisoned_knife"), "RunState.craft_output 查得到")
		t.is_null(s.craft_output(c.items.get_def(&"knife"), c.items.get_def(&"salve")), "没有的是 null")


static func run_random_mode(t: TestCase) -> void:
	t.begin("085 · 随机一局：第一章的规模可选（配置里的 scales），选了按那一档的环数生成；规模跟存档；预设图没有规模可选；撤离点也走对话")
	var c := _content()
	var options := c.chapter1.map_source.scale_options()
	t.check(options.size() >= 2, "第一章有几种规模可选（%d）" % options.size())
	t.check(c.chapter.map_source.scale_options().is_empty(), "预设图没有规模可选")
	var cfg = c.chapter1.map_source.generator_config
	var default_rings: int = cfg.ring_count()
	for o in options:
		var sid: StringName = o["id"]
		var prof = cfg.scale_by_id(sid)
		var s: RunState = null
		for seed in range(1, 30):
			s = RunState.start(c.chapter1, seed, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], null, {}, sid)
			if s != null:
				break
		if s == null:
			t.check(sid == &"large", "规模 %s 生成不出图（大型是占位，允许）" % sid)
			continue
		var rings := {}
		for id in s.map.node_ids():
			rings[s.map.get_node(id).tier] = true
		t.check(prof.covers(rings.size()), "规模 %s：环数 %d 在 [%d, %d] 里" % [sid, rings.size(), prof.rings.x, prof.rings.y])
		t.eq(s.scale_id(), sid, "这一局记着规模")
		var back := RunState.from_dict(s.to_dict(), c.chapter1, c.items, c.enemies, c.sets)
		t.check(back != null and back.map_scale == sid, "规模跟存档")
	t.eq(cfg.ring_count(), default_rings, "章节资产本身没被改（复制一份再换规模）")
	# 第一章的撤离点也有对话
	var rules: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	t.check(rules.events_by_type.has("extract") or rules.events_by_type.has(&"extract"), "标准节点规则给撤离点配了事件")
	t.not_null(c.events.get(&"extract_default", null), "extract_default 存在")


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
	var armed := false
	for inst in run.board.items():
		if (inst as ItemInstance).def.id == &"knife":
			armed = true
	t.check(armed, "开局包里有一把匕首")
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
	t.is_null(f.next_chapter(), "序章二之后没有下一张教学图：走结算 → 局外")
	f.finish_result()
	t.eq(f.screen, GameFlow.Screen.META, "→ 局外")
	avail = f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"chapter_01", "序章二收起，只剩第一章：%s" % str(avail.map(func(x: ChapterDef) -> String: return String(x.id))))
	_cleanup()
