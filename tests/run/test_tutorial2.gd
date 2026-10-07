## 序章二「岔路」（作者定，报告 085）：分岔的教程图、节点浮窗开着、两件护具装不下、四个针对性的敌人、毒药瓶 + 匕首合成涂毒匕首、
## 两场都输也死不了、章节收起与顶上（序章通关 → 直接开序章二 → 通关 → 第一章）。期望从数据推、克制关系用真的战斗模拟验。
extends RefCounted

## 与 Support.paths("t2") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_t2_run.json"
const META := "user://test_t2_meta.json"
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	var c := TestSupport.load_content("prologue_2", ["brutus", "events", "recipes"])
	# 预设图按种子 1 解析一份：要跑地图源，只这个套件要，所以不进共用装载
	c.graph = c.chapter.map_source.resolve(1) if c.chapter != null and c.chapter.map_source != null else null
	return c


## 布鲁图斯背着这些东西的战斗单位
static func _player(c: TestSupport.Content, ids: Array[StringName]) -> CombatantSpec:
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
	return BattleCompiler.compile_board(board, base)


## 五个种子：赢几场、平均剩多少血
static func _fight(c: TestSupport.Content, ids: Array[StringName], content: Dictionary) -> Dictionary:
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
	t.check(c.chapter.next_chapter == &"prologue_3", "通关直接进序章三（113；第一章要序章三通关）")
	t.check(c.chapter.hidden_by_unlock == c.chapter.grants_unlock and c.prologue.hidden_by_unlock == c.prologue.grants_unlock, "教程通关就收起")
	t.check(c.chapter.skip_setup and c.chapter.auto_spawn and c.chapter.intro_event == &"tut2_intro", "不走开局屏、开局在出生点、先过 intro")
	t.check(c.chapter.starting_keepsakes.has(&"spyglass"), "开局发望远镜：节点浮窗从这一张开（088，不再用章节开关）")
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
		t.eq(int(k2["wins"]), 5, "药师 vs 涂毒匕首 + %s：全赢（解毒包 2 秒才解 1 层，清不动涂毒匕首）" % armor)
		var k3 := _fight(c, [&"knife", &"poison_vial", armor, &"bag_long"], cure)
		t.eq(int(k3["wins"]), 0, "药师 vs 匕首 + 毒药瓶（没合成）+ %s：赢不了（毒药瓶太慢）" % armor)
	# 两场都输也死不了：体力 = 角色的 + 坚韧 + 章节加成，输一场扣 loss_cost.battle
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	t.not_null(s, "开得了局")
	if s != null:
		var cost := s.node_rules.loss_cost_of(&"battle")
		t.check(s.vitality.maximum > cost * 2, "体力 %d > 两场战败的 %d" % [s.vitality.maximum, cost * 2])
		t.eq(s.vitality.maximum, c.brutus.vitality_max + s.buff_context().vitality_max_bonus + c.chapter.vitality_bonus, "体力 = 角色 + 技能 + 章节加成")


static func _knife_on(s: RunState) -> ItemInstance:
	for inst in s.board.items():
		if (inst as ItemInstance).def.id == &"knife":
			return inst
	return null


static func run_crafting_drop(t: TestCase) -> void:
	t.begin("114 · 合成是拖到上面立刻合（作者定）：CraftingModule.craft —— 产物落在被压那件的位置、发一次 done；挨着放走一步不会自动合；装不下到地上并提醒；没配方不合")
	var c := _content()
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	t.not_null(s, "开得了局")
	if s == null:
		return
	var cm := CraftingModule.of(s)     # 101：合成是一局的模块
	t.not_null(cm, "默认清单里有合成")
	cm.recipes = c.recipes
	s.event_defs = c.events
	var knife := _knife_on(s)
	t.not_null(knife, "开局包里有匕首")
	if knife == null:
		return
	var home := knife.origin
	var done: Array = []
	cm.done.connect(func(detail: Dictionary): done.append(detail))
	# 挨着放：不再自动合（相邻是增益槽 / 受益槽的事）
	var vial := ItemInstance.create(c.items.get_def(&"poison_vial"))
	var placed := s.board.place(vial, home + Vector2i(1, 0), 0) or s.board.place(vial, home + Vector2i(0, 1), 0) or s.board.place(vial, home + Vector2i(-1, 0), 0) or s.board.place(vial, home + Vector2i(0, -1), 0)
	t.check(placed, "毒药瓶放到匕首旁边")
	t.check(s.step_to(s.travel.available_moves()[0]), "走到下一个点")
	t.check(done.is_empty() and s.board.has_item(knife.uid) and s.board.has_item(vial.uid), "挨着、走一步：没合成，两件都还在")
	# 拖到上面：立刻合
	s.board.remove(vial.uid)     # 拿在手上
	var r := cm.craft(vial, knife.uid)
	t.check(bool(r["ok"]), "压到匕首上：合成了")
	t.eq(done.size(), 1, "发了一次 done")
	t.eq(String(r["output"]), "poisoned_knife", "产物是涂毒匕首")
	t.eq(String(r["where"]), "board", "落在棋盘上")
	t.check(String((r["log"] as Array)[0]).contains("合成了"), "提示文字")
	var made: ItemInstance = null
	for inst in s.board.items():
		if (inst as ItemInstance).def.id == &"poisoned_knife":
			made = inst
	t.check(made != null and made.origin == home, "涂毒匕首落在匕首（被压那件）原来的位置")
	t.check(not s.board.has_item(knife.uid) and not s.board.has_item(vial.uid), "两件原料没了")
	# 没配方：不合、棋盘不动
	var salve := ItemInstance.create(c.items.get_def(&"salve"))
	var before := s.board.item_count()
	t.check(not bool(cm.craft(salve, made.uid)["ok"]) and s.board.item_count() == before and done.size() == 1, "没配方：不合、棋盘不动、不发 done")
	# 存档往返不需要记什么
	var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and not back.to_dict().has("pending_crafts"), "存档里没有配对表")
	# 产物放不下：用一个临时配方（1 格 + 1 格 → 板甲），包里塞满
	var s3 := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	var big := RecipeDef.new()
	big.id = &"t_big"
	big.inputs = [&"knife", &"poison_vial"] as Array[StringName]
	big.output = &"plate_cuirass"
	var cm3 := CraftingModule.of(s3)
	cm3.recipes = [big] as Array[RecipeDef]
	var knife3 := _knife_on(s3)
	while s3.board.try_add(ItemInstance.create(c.items.get_def(&"salve")), true):
		pass     # 塞满
	var r3 := cm3.craft(ItemInstance.create(c.items.get_def(&"poison_vial")), knife3.uid)
	t.check(bool(r3["ok"]) and String(r3["where"]) == "storage", "产物装不下：到地上")
	t.check((r3["log"] as Array).size() == 2 and String((r3["log"] as Array)[1]).contains("装不下"), "提醒玩家装不下")
	var in_storage := false
	for inst in s3.storage.items():
		if (inst as ItemInstance).def.id == &"plate_cuirass":
			in_storage = true
	t.check(in_storage, "产物在地上")


static func run_crafting_drag(t: TestCase) -> void:
	t.begin("114 · 拖拽层：拿起一件时能和它合成的亮一圈；压到有配方的那件上 = 合成（绿预览，不是顶替）；压到没配方的 = 顶替；没配 craft_drop 的地方照常顶替")
	var c := _content()
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	t.not_null(s, "开得了局")
	if s == null:
		return
	var cm := CraftingModule.of(s)
	cm.recipes = c.recipes
	var board := s.board
	var stash := s.storage
	var knife := _knife_on(s)
	var home := knife.origin
	var vial := ItemInstance.create(c.items.get_def(&"poison_vial"))
	stash.admit(vial)
	var other := ItemInstance.create(c.items.get_def(&"salve"))
	stash.admit(other)
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	var sview := GroundLayer.new()     # 128：一块地
	sview.stash = stash
	sview.position = Vector2(board.size.x * InventoryView.CELL + 40, 0)
	sview.size = Vector2(400, 300)
	var drag := DragLayer.new()
	drag.register_view(view)
	drag.register_view(sview)
	drag.stash = stash
	drag.craft = func(a: ItemInstance, b: ItemInstance) -> ItemDef:
		return cm.output_of(a.def, b.def)
	drag.craft_grid = board
	drag.craft_drop = func(a: ItemInstance, b_uid: int) -> bool:
		return bool(cm.craft(a, b_uid)["ok"])
	sview.grab_requested.emit(sview, vial.uid, Vector2(10, 10))
	t.check(drag.is_dragging(), "抓起毒药瓶")
	t.check(view.highlights.has(knife.uid), "拿起毒药瓶：棋盘上的匕首亮了")
	t.check(not sview.highlights.has(other.uid), "伤药没亮")
	var at := (Vector2(home) + Vector2(0.5, 0.5)) * InventoryView.CELL
	drag.craft_note = func(a: ItemInstance, b: ItemInstance) -> String: return cm.note_of(a.def, b.def)
	drag.update_preview(at)
	t.check(view._preview_valid and view._preview_victims.is_empty(), "压到匕首上：预览是绿的、不画顶替")
	# 140：绿预览旁边一行小字 = 产物 + 作者写的配方说明
	var recipe := RecipeDef.find(c.recipes, &"knife", &"poison_vial")
	t.check(drag.craft_hint.begins_with("合成 → " + Names.of(c.items.get_def(&"poisoned_knife"))), "提示写产物：%s" % drag.craft_hint)
	t.check(recipe != null and recipe.note != "" and drag.craft_hint.ends_with("：" + recipe.note), "提示带配方的 note")
	# 审查 A1：craft_filter 不许的那件（商店里没付钱的商品）压上去不是合成
	drag.craft_filter = func(_i: ItemInstance) -> bool: return false
	t.is_null(drag._craft_target(board, home), "craft_filter 不许：不算合成")
	drag.craft_filter = Callable()
	t.check(drag.drop_at(at), "放到匕首上：合成（算放下了）")
	t.check(not drag.is_dragging(), "手上空了（不是顶替）")
	t.eq(drag.craft_hint, "", "放下之后提示没了")
	var made: ItemInstance = null
	for inst in board.items():
		if (inst as ItemInstance).def.id == &"poisoned_knife":
			made = inst
	t.check(made != null and made.origin == home, "涂毒匕首落在匕首的位置")
	t.check(not board.has_item(knife.uid) and not stash.has_item(vial.uid), "两件原料没了")
	t.check(view.highlights.is_empty() and sview.highlights.is_empty(), "放下之后高光熄了")
	# 没配方的：照常顶替
	sview.grab_requested.emit(sview, other.uid, Vector2(10, 10))
	var at2 := (Vector2(made.origin) + Vector2(0.5, 0.5)) * InventoryView.CELL
	t.check(drag.drop_at(at2), "伤药压到涂毒匕首上：顶替")
	t.check(board.has_item(other.uid) and drag.is_dragging(), "涂毒匕首被顶出来拿在手上")
	drag.cancel()
	# 没配 craft_drop（沙盒 / 开局屏）：压上去是顶替
	var drag2 := DragLayer.new()
	drag2.register_view(view)
	drag2.register_view(sview)
	drag2.stash = stash
	drag2.craft = drag.craft
	var vial2 := ItemInstance.create(c.items.get_def(&"poison_vial"))
	var knife2 := ItemInstance.create(c.items.get_def(&"knife"))
	t.check(board.try_add(knife2, true) and stash.admit(vial2), "再来一把匕首和一瓶毒")
	drag.unregister_view(view)
	drag.unregister_view(sview)
	sview.grab_requested.emit(sview, vial2.uid, Vector2(10, 10))
	var at3 := (Vector2(knife2.origin) + Vector2(0.5, 0.5)) * InventoryView.CELL
	t.check(drag2.drop_at(at3) and drag2.is_dragging() and board.has_item(vial2.uid), "没有 craft_drop：普通顶替，匕首拿在手上")
	drag2.cancel()
	t.check(cm.output_of(c.items.get_def(&"knife"), c.items.get_def(&"poison_vial")) == c.items.get_def(&"poisoned_knife"), "CraftingModule.output_of 查得到")
	t.is_null(cm.output_of(c.items.get_def(&"knife"), c.items.get_def(&"salve")), "没有的是 null")


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
	Support.cleanup("t2")
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = GameFlow.load_chapters()
	f.characters = GameFlow.load_characters()
	f.event_defs = c.events
	f.recipes = c.recipes
	f.save_path = SAVE
	f.meta_path = META
	var first_target := f.new_run_target()
	t.check(first_target != null and first_target.id == &"prologue", "一张白纸：「新的一局」直接开序章一")
	t.is_null(f.continue_target(), "一张白纸：没有「继续」")
	t.check(not f.continue_run(), "没存档、没进度：继续不了")
	f.meta.grant_unlock(c.prologue.grants_unlock)
	var avail := f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"prologue_2", "序章通关之后只列序章二（序章收起）：%s" % str(avail.map(func(x: ChapterDef) -> String: return String(x.id))))
	var target := f.new_run_target()
	t.check(target != null and target.id == &"prologue", "序章通关后「新的一局」仍从序章一开始（新的一局 = 从头）")
	var cont := f.continue_target()
	t.check(cont != null and cont.id == &"prologue_2", "「继续」指向序章二（和新的一局并列）")
	t.check(not f.tutorials_done(), "教程还没全通")
	# 新的一局：真的开序章一
	f.new_run()
	t.check(f.run != null and f.run.chapter == c.prologue, "新的一局开的是序章一")
	t.eq(f.screen, GameFlow.Screen.EVENT, "先过序章一的 intro")
	f.to_main_menu()
	RunSave.remove(SAVE)
	# 有局内存档时「继续」是读档：开序章一走到地图、存盘、回菜单再继续
	f.new_run()
	f.choose_event(0)
	t.check(f.save(), "存盘")
	f.to_main_menu()
	t.check(f.has_save() and f.continue_target() == null, "有存档：继续 = 读档，不指向章")
	t.check(f.continue_run() and f.run != null and f.run.chapter == c.prologue, "读档回到序章一")
	f.to_main_menu()
	RunSave.remove(SAVE)
	# 继续：开序章二
	t.check(f.continue_run(), "继续开得了")
	var run := f.run
	t.not_null(run, "「继续」直接开了序章二")
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
	t.check(not CraftingModule.of(run).recipes.is_empty(), "配方进了这一局")
	t.check(f.choose_event(0), "出发")
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.eq(run.travel.available_moves().size(), 1, "出生点只通向搜索点")
	# 直接站到撤离点撤（走一遍的克制在上一组验过了）
	run.travel.start_at(run.map.goal_ids[0])
	t.check(f.extract(), "撤离")
	t.check(f.meta.has_unlock(c.chapter.grants_unlock), "拿到序章二的解锁")
	var nxt := f.next_chapter()
	t.check(nxt != null and nxt.id == &"prologue_3", "序章二之后直接进序章三（113）")
	f.finish_result()
	avail = f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"prologue_3", "序章二收起，只剩序章三：%s" % str(avail.map(func(x: ChapterDef) -> String: return String(x.id))))
	Support.cleanup("t2")
