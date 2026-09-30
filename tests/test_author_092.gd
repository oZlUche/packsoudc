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
	t.begin("092 · 全局倒计时：第一章 36 行动点，每走一步 -1；过半关掉离出生点最近的免费撤离点（closes_at = 18）；归零 = 行动失败（time_out），保险箱里的照样带出；序章没有倒计时")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	t.eq(c.chapter.step_limit, 36, "第一章配了 36（占位）")
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, 7)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	t.check(run.has_countdown() and run.countdown_limit() == 36 and run.countdown_left() == 36, "开局倒计时 36")
	var closing := run.closing_extract_id()
	t.check(closing >= 0, "标了一个会关的撤离点（%d）" % closing)
	if closing >= 0:
		var node := run.map.get_node(closing)
		t.check(node.type == &"extract" and PaidExtracts.fee_of(node) == 0, "是免费撤离点")
		t.eq(PaidExtracts.closes_at(node), 18, "倒计时剩 18 时关")
		t.check(not run.extract_closed(node), "开局没关")
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
	t.eq(run.countdown_left(), 36 - run.travel.clock.total, "倒计时 = 上限 − 花掉的行动点")
	t.check(run.countdown_left() <= 35, "走一步至少 -1")
	if closing >= 0:
		run.travel.clock.total = 36 - 18
		t.check(run.extract_closed(run.map.get_node(closing)), "剩 18：关了")
		run.travel.clock.total = 36 - 19
		t.check(not run.extract_closed(run.map.get_node(closing)), "剩 19：还开着")
	# 放一件进保险箱，再让倒计时归零
	var board_item: ItemInstance = null
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			board_item = inst
			break
	if board_item != null:
		t.check(InventoryService.transfer_auto(run.board, board_item.uid, run.safe), "一件进了保险箱")
	run.travel.clock.total = 35
	var moves := run.travel.available_moves()
	t.check(not moves.is_empty() and f.step_to(moves[0]), "最后一步")
	t.check(run.is_over() and run.phase == RunState.Phase.DEFEATED and run.end_reason == &"time_out", "归零：行动失败（time_out）")
	t.eq(run.countdown_left(), 0, "剩 0")
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
	# 序章：没有倒计时、没有保险箱
	var p := RunState.start(c.prologue, 1, c.items, c.enemies, c.sets, [] as Array[StringName])
	if p != null:
		t.check(not p.has_countdown() and p.countdown_left() == -1 and p.closing_extract_id() == -1, "序章没有倒计时、不关撤离点")
		t.check(_safe_node(p) == null, "序章没有保险箱")
	_cleanup()


static func run_safe_placement(t: TestCase) -> void:
	t.begin("092 · 保险箱点：第一章每张图恰好一个、不挨着出生点、不是结构点、没有敌人；容器 3×3；存档往返带着里面的东西；地图文字符号 K")
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
		t.eq(s.safe.size, Vector2i(3, 3), "容器 3×3")
		t.check(MapNodeTypes.has(&"safe") and MapNodeStyle.of(&"safe")["label"] == "保险箱", "类型表与样式认得")
		if seed == 1:
			var def: ItemDef = null
			for inst in s.board.items():
				if not (inst as ItemInstance).def.is_bag:
					def = (inst as ItemInstance).def
					break
			if def != null:
				var extra := ItemInstance.create(def)
				t.check(s.safe.try_add(extra, true), "放一件进去")
				var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
				t.check(back != null and back.safe != null and back.safe.item_count() == 1 and back.safe.size == Vector2i(3, 3), "存档往返：保险箱里的还在")
				t.eq(NodeEvents.effective_type(back.map.get_node(node.id)), &"safe", "类型跟着图存")
	t.check(seen >= 4, "至少四个种子开得出局（%d）" % seen)
	t.eq(MapGridText.SYMBOL_TYPES.get("K", &""), &"safe", "地图文字里 K = 保险箱")
	t.check(SafePlacer.mark(null, 1).is_empty(), "没图不标")


static func frame_safe_screen(t: TestCase, root: Window) -> void:
	t.begin("092 · 保险箱屏：走到保险箱点就开；双击 / put_in 把棋盘上的放进去（包不收）、take_back 拿回；Esc 收起回地图、站着随时能再开；回头再踩又开")
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
		t.check(run.safe.has_item(item.uid) and not run.board.has_item(item.uid), "在保险箱里、不在棋盘上")
		t.check(screen.take_back(item.uid), "拿回来")
		t.check(run.board.has_item(item.uid) or run.storage.has_item(item.uid), "回到棋盘（或暂存区）")
		t.check(screen.put_in(item.uid), "再放进去")
	if bag != null:
		t.check(not screen.put_in(bag.uid) and not run.safe.has_item(bag.uid), "包放不进保险箱")
	t.check(game.escape(), "Esc 收起")
	t.eq(flow.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(flow.can_reopen(), "站着随时能再开")
	t.check(flow.reopen_node(), "再开")
	t.eq(flow.screen, GameFlow.Screen.SAFE, "→ 保险箱屏")
	flow.hide_overlay()
	# 走开再回来：又开
	var moves := run.travel.available_moves()
	if not moves.is_empty() and flow.step_to(moves[0]):
		NodeScreens._settle(flow)
		if not run.is_over() and run.travel.available_moves().has(safe_node.id) and flow.step_to(safe_node.id):
			var g := 0
			while GameFlow.is_overlay(flow.screen) and flow.screen != GameFlow.Screen.SAFE and g < 10:
				g += 1
				NodeScreens._settle(flow)
			t.eq(flow.screen, GameFlow.Screen.SAFE, "回头再踩：又开了")
			flow.hide_overlay()
	if item != null:
		t.check(run.safe.has_item(item.uid), "里面的东西一直在")
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
	t.check(InventoryService.transfer_auto(run.board, board_item.uid, run.safe), "一件进保险箱")
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
	var safe_n := run.safe.item_count()
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
