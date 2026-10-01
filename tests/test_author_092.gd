## 作者第十六批（报告 092）：全局倒计时（每步 -1，归零 = 行动失败）、倒计时过半关闭一个撤离点（地图上标着）、
## 新节点类型「保险箱」（放进去的视为已带出，战败也带得出，结算屏单独一格，初始 3×3）、离开结算屏时一键出售暂存区
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_092_run.json"
const META := "user://test_092_meta.json"
const SETTINGS := "user://test_092_settings.json"
const NodeScreens := preload("res://tests/test_node_screens.gd")


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _flow(c, hp: float = 10000.0) -> GameFlow:
	var f: GameFlow = NodeScreens._flow(c, hp)
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	return f


static func _safe_node(run: RunState) -> MapNode:
	for id in run.map.node_ids():
		if run.map.get_node(id).type == &"safe":
			return run.map.get_node(id)
	return null


## 从当前点走到某个点（沿最短路），每一步把叠层看完；到不了 / 一局结束返回 false
static func _walk_to(f: GameFlow, target: int, stop_at_screen: int = -1) -> bool:
	var run := f.run
	var guard := 0
	while run.travel.current_id != target and guard < 40 and not run.is_over():
		guard += 1
		var dist := MapNavigator.distance_map(run.map, target)
		var best := -1
		for n in run.travel.available_moves():
			if dist.has(n) and (best < 0 or int(dist[n]) < int(dist[best])):
				best = n
		if best < 0 or not f.step_to(best):
			return false
		if run.travel.current_id == target and stop_at_screen >= 0:
			var g := 0
			while GameFlow.is_overlay(f.screen) and f.screen != stop_at_screen and g < 20:
				g += 1
				_settle_one(f)
			return true
		NodeScreens._settle(f)
	return run.travel.current_id == target


## 只把当前这一屏看完（不像 _settle 那样一路看到地图 —— 撤离点的事件选第 0 项就是「撤离」）
static func _settle_one(f: GameFlow) -> void:
	match f.screen:
		GameFlow.Screen.PREBATTLE:
			f.start_battle()
		GameFlow.Screen.LOOT:
			f.take_all_loot()
		GameFlow.Screen.SEARCH:
			f.run.events.current_search.leave()
		GameFlow.Screen.SHOP:
			f.run.events.current_shop.leave()
		GameFlow.Screen.EVENT:
			if f.run.events.pending_event() != null:
				f.choose_event(0)
			else:
				f.resume()
		_:
			f.resume()


static func run_countdown(t: TestCase) -> void:
	t.begin("092 · 全局倒计时：按地图规模（小 36 / 中 60 / 大 90），每走一步 -1；过半关掉离出生点最近的免费撤离点；归零 = 行动失败（time_out），保险箱里的照样带出；序章没有倒计时")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	t.eq(c.chapter.step_limit, 36, "第一章兜底 36（占位）；小图 36、中图 60、大图 90 写在规模档里")
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, 7)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var cd := CountdownModule.of(run)     # 101：倒计时是一局的模块
	t.not_null(cd, "默认清单里有倒计时")
	var limit := cd.limit()
	t.check(cd.has_countdown() and [36, 60, 90].has(limit) and cd.left() == limit, "开局倒计时 = 这个规模档的数（%d）" % limit)
	var closing := cd.closing_extract_id()
	t.check(closing >= 0, "标了一个会关的撤离点（%d）" % closing)
	if closing >= 0:
		var node := run.map.get_node(closing)
		t.check(node.type == &"extract" and PaidExtracts.fee_of(node) == 0, "是免费撤离点")
		t.eq(PaidExtracts.closes_at(node), limit / 2, "倒计时剩一半时关")
		t.check(not cd.extract_closed(node), "开局没关")
		# 离出生点最近：没有别的免费撤离点比它更近
		var best := 1 << 30
		var mine := 1 << 30
		for entry in run.map.entry_ids:
			var dist := MapNavigator.distance_map(run.map, entry)
			for id in run.map.node_ids():
				var n := run.map.get_node(id)
				if n.type == &"extract" and PaidExtracts.fee_of(n) == 0 and dist.has(id):
					best = mini(best, int(dist[id]))
					if id == closing:
						mine = mini(mine, int(dist[id]))
		t.eq(mine, best, "是离出生点最近的那个")
	var first := run.travel.available_moves()[0]
	t.check(f.step_to(first), "走一步")
	NodeScreens._settle(f)
	t.eq(cd.left(), limit - run.travel.clock.total, "倒计时 = 上限 − 花掉的行动点")
	t.check(cd.left() <= limit - 1, "走一步至少 -1")
	if closing >= 0:
		run.travel.clock.total = limit - limit / 2
		t.check(cd.extract_closed(run.map.get_node(closing)), "剩一半：关了")
		run.travel.clock.total = limit - limit / 2 - 1
		t.check(not cd.extract_closed(run.map.get_node(closing)), "剩一半 + 1：还开着")
	# 放一件进保险箱，再让倒计时归零
	var board_item: ItemInstance = null
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			board_item = inst
			break
	if board_item != null:
		t.check(InventoryService.transfer_auto(run.board, board_item.uid, SafeModule.of(run).inventory), "一件进了保险箱")
	run.travel.clock.total = limit - 1
	var moves := run.travel.available_moves()
	t.check(not moves.is_empty() and f.step_to(moves[0]), "最后一步")
	t.check(run.is_over() and run.phase == RunState.Phase.DEFEATED and run.end_reason == &"time_out", "归零：行动失败（time_out）")
	t.eq(cd.left(), 0, "剩 0")
	var g := 0
	while GameFlow.is_overlay(f.screen) and g < 10:
		g += 1
		f.resume()
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	var r: RunResult = f.result
	t.check(r != null and not r.is_extracted() and r.reason == &"time_out", "结算：战败、原因 time_out")
	if board_item != null:
		t.check(r != null and r.safe_items.size() == 1 and r.safe_layout.size() == 1, "保险箱里那件在账上")
		t.eq(int(f.last_absorbed.get("safe", 0)), 1, "进了局外（safe 计 1）")
		t.check(f.meta.board != null and f.meta.board.item_count() == 1, "战败也有带回来的棋盘：就是保险箱那件")
		t.check(int(f.meta.codex.get(String(board_item.def.id), 0)) >= 1, "图鉴记了")
	t.eq(f.meta.deaths, 1, "记一败")
	# 倒计时和地图规模正相关：小图 36、中图 60（过半 30）
	var small := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"small")
	if small != null:
		t.eq(CountdownModule.of(small).limit(), 36, "小型图倒计时 36")
	var mid := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"medium")
	if mid != null:
		t.eq(CountdownModule.of(mid).limit(), 60, "中型图倒计时 60")
		var mc := CountdownModule.of(mid).closing_extract_id()
		t.check(mc >= 0 and PaidExtracts.closes_at(mid.map.get_node(mc)) == 30, "中型图的撤离点剩 30 时关")
	else:
		t.check(true, "（中型图这个种子生成不出，跳过）")
	# 序章：没有倒计时、没有保险箱
	var p := RunState.start(c.prologue, 1, c.items, c.enemies, c.sets, [] as Array[StringName])
	if p != null:
		var pcd := CountdownModule.of(p)
		t.check(not pcd.has_countdown() and pcd.left() == -1 and pcd.closing_extract_id() == -1, "序章装了倒计时模块但这一章没有倒计时：不关撤离点")
		t.check(_safe_node(p) == null, "序章没有保险箱")
	_cleanup()


static func run_safe_placement(t: TestCase) -> void:
	t.begin("092 · 保险箱点：第一章每张图恰好一个，覆盖的是靠近中央（深度 ≥ 0.5）的战斗 / 事件点、不挨着出生点、没有敌人；容器 3×3；存档往返带着里面的东西与锁；地图文字符号 K")
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
	t.begin("092 · 保险箱屏：走到保险箱点就开；put_in 放进去（包不收）、take_back 拿回；空着 Esc 只是收起、站着能再开；里面有东西关上就锁：屏关掉、点灰、不能再开、再踩不开")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	_cleanup()
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	var reached := false
	for seed in range(1, 12):
		var run := flow.begin(c.chapter, kit, seed)
		if run == null:
			continue
		var safe := _safe_node(run)
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
		if _walk_to(flow, safe.id, GameFlow.Screen.SAFE) and flow.screen == GameFlow.Screen.SAFE:
			reached = true
			break
		flow.to_main_menu()
	t.check(reached, "走到了保险箱点、开了保险箱屏")
	if not reached:
		game.queue_free()
		_cleanup()
		return
	var run: RunState = flow.run
	var safe_node := _safe_node(run)
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
	_cleanup()


static func frame_stash_sale_and_result(t: TestCase, root: Window) -> void:
	t.begin("092 · 撤离结算：暂存区里没背出来的在结算屏上说清楚、离开时一键出售进局外、局外屏提示；保险箱那格画在结算屏上；只卖一次")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, 5)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var def: ItemDef = null
	var board_item: ItemInstance = null
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			def = (inst as ItemInstance).def
			board_item = inst
			break
	t.check(def != null, "棋盘上有非包道具")
	if def == null:
		_cleanup()
		return
	t.check(InventoryService.transfer_auto(run.board, board_item.uid, SafeModule.of(run).inventory), "一件进保险箱")
	# 走到最近的撤离点（出生点旁没有撤离点：环形图的撤离点在外面几环）
	var near := MapNavigator.nearest_of_type(run.map, run.travel.current_id, &"extract")
	t.check(int(near["id"]) >= 0 and _walk_to(f, int(near["id"]), GameFlow.Screen.EVENT), "走到了最近的撤离点（%d 步；停在它的对话上）" % int(near["steps"]))
	if run.is_over() or run.travel.current_id != int(near["id"]):
		t.check(false, "没走到就结束了")
		_cleanup()
		return
	# 到了再往暂存区塞两件（路上事件给的也算，账按当时的暂存区数）
	run.storage.admit(ItemInstance.create(def))
	run.storage.admit(ItemInstance.create(def))
	var stash_n := run.storage.item_count()
	var stash_funds := 0
	for inst in run.storage.items():
		stash_funds += MetaState.sell_price((inst as ItemInstance).def, f.sell_ratio())
	var safe_n := SafeModule.of(run).inventory.item_count()
	t.check(f.extract(), "撤离")
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	var r: RunResult = f.result
	t.check(r != null and r.is_extracted() and r.left_behind == stash_n and r.left_items.size() == stash_n, "暂存区 %d 件记在账上" % stash_n)
	t.check(r != null and r.safe_items.size() == safe_n and safe_n >= 1, "保险箱 %d 件记在账上" % safe_n)
	var price := stash_funds
	var pre := f.stash_sale_preview()
	t.eq([int(pre["count"]), int(pre["funds"])], [stash_n, stash_funds], "预览：件数与卖价之和")
	var funds0 := f.meta.funds
	# 结算屏
	var screen = load("res://ui/game/result_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.RESULT
	root.add_child(screen)
	screen.open({"result": r})
	t.check(screen._stash_line != null and screen._stash_line.text.contains("一键出售") and screen._stash_line.text.contains("得 %d 币" % price), "结算屏说了离开时一键出售、得多少（%s）" % (screen._stash_line.text if screen._stash_line != null else "无"))
	t.check(screen.safe_view() != null and screen.safe_view().inventory.item_count() == safe_n and screen.safe_view().inventory.size == Vector2i(3, 3), "保险箱那格画出来了：%d 件、3×3" % safe_n)
	t.check(f.meta.board != null and f.meta.board.item_count() >= safe_n, "带回来的棋盘里有保险箱那件")
	screen.proceed()
	t.eq(f.screen, GameFlow.Screen.META, "→ 局外")
	t.eq(f.meta.funds, funds0 + price, "暂存区里的卖了，钱进局外")
	t.eq(int((f.last_absorbed.get("stash_sold", {}) as Dictionary).get("count", 0)), stash_n, "记了卖掉几件")
	t.check(r.left_items.is_empty(), "清单清掉：只卖一次")
	f.finish_result()
	t.eq(f.meta.funds, funds0 + price, "再离开一次不重复卖")
	t.check(MetaSave.exists(META), "存了局外")
	# 局外屏的提示
	var meta_screen = load("res://ui/game/meta_screen.gd").new()
	meta_screen.flow = f
	meta_screen.font = UiPalette.cjk_font()
	meta_screen.screen = GameFlow.Screen.META
	root.add_child(meta_screen)
	meta_screen.open({"result": r, "stash_sold": {"count": stash_n, "funds": price}})
	var texts: Array[String] = []
	var walker := func(node: Node, fn: Callable) -> void:
		for ch in node.get_children():
			if ch is Label:
				texts.append((ch as Label).text)
			fn.call(ch, fn)
	walker.call(meta_screen, walker)
	var said := false
	for s in texts:
		if s.contains("已一键出售") and s.contains("%d 件" % stash_n):
			said = true
	t.check(said, "局外屏提示：暂存区 %d 件已一键出售" % stash_n)
	meta_screen.queue_free()
	screen.queue_free()
	_cleanup()
