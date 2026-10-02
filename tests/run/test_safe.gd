## 保险箱（092 的规则；101 之后它是一局的模块 [SafeModule]）：放进去的东西视为已带出，战败也带得出；
## 关上（或走开）就送回基地、不能再改；空着关不算关。图上每张恰好一个保险箱点。
##
## 用例从 `test_author_092.gd` 搬过来（102 第 A-4 条：谁改到哪个模块就顺手把用例搬到模块文件），断言一条没改。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_safe_placement(t: TestCase) -> void:
	t.begin("保险箱 · 图上的点（092）：第一章每张图恰好一个，覆盖的是靠近中央（深度 ≥ 0.5）的战斗 / 事件点、不挨着出生点、没有敌人；容器 3×3；存档往返带着里面的东西与锁；地图文字符号 K")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var seen := 0
	for seed in range(1, 9):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items)
		if s == null:
			continue
		seen += 1
		var safes: Array[int] = []
		for id in s.map.node_ids():
			if s.map.get_node(id).type == &"safe":
				safes.append(id)
		t.eq(safes.size(), 1, "种子 %d：恰好一个保险箱" % seed)
		if safes.is_empty():
			continue
		var node := s.map.get_node(safes[0])
		var near := false
		for entry in s.map.entry_ids:
			if s.map.neighbors(entry).has(node.id) or entry == node.id:
				near = true
		t.check(not near and not s.map.goal_ids.has(node.id), "不挨着出生点、不是终点")
		t.check(not EnemyKit.has_enemy(node.content), "没有敌人")
		t.check(float(EnemyPlacer.depths_of(s.map).get(node.id, 0.0)) >= 0.5, "比较靠近中央（深度 %.2f）" % float(EnemyPlacer.depths_of(s.map).get(node.id, 0.0)))
		var sm := SafeModule.of(s)     # 101：保险箱是一局的模块（RunModule）
		t.check(sm != null and sm.inventory != null, "装了保险箱模块")
		t.eq(sm.inventory.size, Vector2i(3, 3), "容器 3×3")
		t.check(MapNodeTypes.has(&"safe") and MapNodeStyle.of(&"safe")["label"] == "保险箱", "类型表与样式认得")
		if seed == 1:
			var def: ItemDef = null
			for inst in s.board.items():
				if not (inst as ItemInstance).def.is_bag:
					def = (inst as ItemInstance).def
					break
			if def != null:
				var extra := ItemInstance.create(def)
				t.check(sm.inventory.try_add(extra, true), "放一件进去")
				t.check(sm.lock() and sm.locked and not sm.is_open(), "关上：锁了")
				t.check(not sm.lock(), "再关不重复")
				t.check(s.map.get_node(node.id).is_visited(), "锁了点就灰")
				var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
				var back_safe := SafeModule.of(back) if back != null else null
				t.check(back_safe != null and back_safe.inventory != null and back_safe.inventory.item_count() == 1 and back_safe.inventory.size == Vector2i(3, 3),
					"存档往返：保险箱里的还在（模块自己存自己读）")
				t.check(back_safe != null and back_safe.locked, "锁也跟着存")
				t.eq(NodeEvents.effective_type(back.map.get_node(node.id)), &"safe", "类型跟着图存")
	t.check(seen >= 4, "至少四个种子开得出局（%d）" % seen)
	t.eq(MapGridText.SYMBOL_TYPES.get("K", &""), &"safe", "地图文字里 K = 保险箱")
	t.check(SafePlacer.mark(null, 1).is_empty(), "没图不标")
	var empty := RunState.start(c.chapter, 2, c.items, c.enemies, c.sets, kit.items)
	if empty != null:
		var empty_safe := SafeModule.of(empty)
		t.check(empty_safe != null and not empty_safe.lock() and empty_safe.is_open(), "空着关不算关")


static func frame_safe_screen(t: TestCase, root: Window) -> void:
	t.begin("保险箱 · 屏（092）：走到保险箱点就开；put_in 放进去（包不收）、take_back 拿回；空着 Esc 只是收起、站着能再开；里面有东西关上就锁：屏关掉、点灰、不能再开、再踩不开")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("safe")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("safe")["run"])
	game.meta_path = String(Support.paths("safe")["meta"])
	game.settings_path = String(Support.paths("safe")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	var reached := false
	for seed in range(1, 12):
		var run := flow.begin(c.chapter, kit, seed)
		if run == null:
			continue
		var safe := Support.safe_node(run)
		if safe == null:
			flow.to_main_menu()
			continue
		# 出生点挑离保险箱最近的
		var dist := MapNavigator.distance_map(run.map, safe.id)
		var entry := run.map.entry_ids[0]
		for e in run.map.entry_ids:
			if dist.has(e) and (not dist.has(entry) or int(dist[e]) < int(dist[entry])):
				entry = e
		flow.pick_spawn(entry)
		if Support.walk_to(flow, safe.id, GameFlow.Screen.SAFE) and flow.screen == GameFlow.Screen.SAFE:
			reached = true
			break
		flow.to_main_menu()
	t.check(reached, "走到了保险箱点、开了保险箱屏")
	if not reached:
		game.queue_free()
		Support.cleanup("safe")
		return
	var run: RunState = flow.run
	var safe_node := Support.safe_node(run)
	var screen = game.overlay()
	t.check(screen != null and screen.has_method("put_in"), "叠层是保险箱屏")
	t.check(not safe_node.is_visited(), "保险箱点不算用过")
	var item: ItemInstance = null
	var bag: ItemInstance = null
	for inst in run.board.items():
		if (inst as ItemInstance).def.is_bag:
			bag = inst
		elif item == null:
			item = inst
	t.check(item != null, "棋盘上有能放的东西")
	if item != null:
		t.check(screen.put_in(item.uid), "放进保险箱")
		t.check(SafeModule.of(run).inventory.has_item(item.uid) and not run.board.has_item(item.uid), "在保险箱里、不在棋盘上")
		t.check(screen.take_back(item.uid), "拿回来")
		t.check(run.board.has_item(item.uid) or run.storage.has_item(item.uid), "回到棋盘（或暂存区）")
		t.check(screen.put_in(item.uid), "再放进去")
	if bag != null:
		t.check(not screen.put_in(bag.uid) and not SafeModule.of(run).inventory.has_item(bag.uid), "包放不进保险箱")
	# 空着关：只是收起
	if item != null:
		t.check(screen.take_back(item.uid), "先拿出来，空着")
	t.check(game.escape(), "Esc（空着）")
	t.check(flow.screen == GameFlow.Screen.MAP and not SafeModule.of(run).locked, "→ 地图，没锁")
	t.check(flow.can_reopen(), "站着能再开")
	t.check(flow.reopen_node(), "再开")
	t.eq(flow.screen, GameFlow.Screen.SAFE, "→ 保险箱屏")
	screen = game.overlay()
	# 放进去再关：锁
	if item != null and screen != null:
		t.check(screen.put_in(item.uid), "放进去")
		t.check(game.escape(), "Esc（里面有东西）")
		t.check(flow.screen == GameFlow.Screen.MAP and SafeModule.of(run).locked and not SafeModule.of(run).is_open(), "→ 地图，锁上了")
		t.check(game.overlay() == null and game.minimized() == null, "屏关掉了，不是收起")
		t.check(not flow.can_reopen(), "不能再开")
		t.check(safe_node.is_visited(), "点灰了")
		t.check(SafeModule.of(run).inventory.has_item(item.uid), "里面的东西留着（结算进局外）")
	# 走开再回来：不开
	var moves := run.travel.available_moves()
	if not moves.is_empty() and flow.step_to(moves[0]):
		NodeScreens._settle(flow)
		if not run.is_over() and run.travel.available_moves().has(safe_node.id) and flow.step_to(safe_node.id):
			NodeScreens._settle(flow)
			t.check(flow.screen != GameFlow.Screen.SAFE, "回头再踩：锁着的不开")
	if item != null:
		t.check(SafeModule.of(run).inventory.has_item(item.uid), "里面的东西一直在")
	game.queue_free()
	Support.cleanup("safe")
