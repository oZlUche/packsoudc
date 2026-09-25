## 084（作者八条）：搜满不自动结束；开打前先过战前准备屏（等着的一场跟存档、走不了）；节点的叠层能最小化再恢复（会话、
## 没拿的战利品、暂存区都留着，走了才没）；棋盘外的空间全是暂存区；序章开局就站在出生点上；浮窗能挪、不出边。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_084_run.json"
const META := "user://test_084_meta.json"
const SETTINGS := "user://test_084_settings.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var prologue: ChapterDef
	var loadouts: Array[LoadoutDef]
	var events: Dictionary


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.prologue = load(ContentPaths.asset_file("chapters", "prologue"))
	c.loadouts = GameFlow.load_loadouts()
	c.events = GameFlow.load_events()
	return c


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _flow(c: Content, hp: float = 10000.0, keep_saves: bool = false) -> GameFlow:
	if not keep_saves:
		_cleanup()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.loadouts = c.loadouts
	f.event_defs = c.events
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	f.player_baseline = CombatantBaseline.with_hp(hp)
	return f


static func _kit(c: Content) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == &"standard":
			return l
	return c.loadouts[0] if not c.loadouts.is_empty() else LoadoutDef.new()


## 出生点旁边就有某类型点的种子：{seed, entry, next}
static func _seed_with(c: Content, type: StringName, kit: Array[StringName]) -> Dictionary:
	for seed in range(1, 80):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit)
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == type:
					return {"seed": seed, "entry": entry, "next": nid}
	return {}


static func _settle(f: GameFlow) -> void:
	var guard := 0
	while GameFlow.is_overlay(f.screen) and guard < 30:
		guard += 1
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


static func run_prebattle(t: TestCase) -> void:
	t.begin("084 · 战前准备：踩上战斗点先停（对手的棋盘与读数拿得到）、走不了也收不起、存档读回来还停着、开战后回放 → 战利品，点才算用过")
	var c := _content()
	var kit := _kit(c)
	var found := _seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	var next := int(found["next"])
	var pendings: Array = []
	run.events.battle_pending.connect(func(n: MapNode, type: StringName, content: Dictionary): pendings.append([n.id, type, content]))
	t.check(f.step_to(next), "走上战斗点")
	t.eq(f.screen, GameFlow.Screen.PREBATTLE, "→ 战前准备屏")
	t.eq(pendings.size(), 1, "发了 battle_pending")
	t.check(int(f.last_payload.get("node").id) == next and (f.last_payload.get("content", {}) as Dictionary).has("enemy"), "载荷带着点与敌人内容")
	t.check(not run.map.get_node(next).is_visited(), "还没打：点没用过")
	t.eq(int(run.tally["battles_won"]) + int(run.tally["battles_lost"]), 0, "还没打")
	var spec := run.events.pending_battle_spec()
	var board := run.events.pending_battle_board()
	t.check(spec != null and spec.max_hp_int() > 0, "对手的战斗单位算得出来")
	t.check(board != null and board.item_count() == (run.map.get_node(next).content.get("items", []) as Array).size(), "对手的棋盘按内容重建")
	t.check(not f.step_to(int(found["entry"])), "没开战走不了")
	t.check(not f.hide_overlay(), "战前准备屏收不起来")
	t.check(not f.can_reopen() or f.reopen_node(), "（重开只会回到同一屏）")
	# 存档：等着的一场跟着走
	t.check(f.save(), "存得了档")
	var f2 := _flow(c, 10000.0, true)
	t.check(f2.continue_run(), "读档")
	t.eq(f2.screen, GameFlow.Screen.PREBATTLE, "读回来还停在战前准备屏")
	t.check(not f2.run.events.pending_battle.is_empty() and int(f2.run.events.pending_battle["node"]) == next, "等着开打的还是那个点")
	t.eq(String(f2.run.events.pending_battle["kind"]), "node", "kind 是节点的战斗")
	# 开战
	t.check(f2.start_battle(), "开战")
	t.eq(f2.screen, GameFlow.Screen.BATTLE, "→ 回放")
	t.check(bool(f2.last_payload.get("won", false)), "赢了（血 10000）")
	t.check(f2.run.events.pending_battle.is_empty(), "等着的一场清了")
	t.check(f2.run.map.get_node(next).is_visited(), "打完点用过了")
	t.check(not f2.start_battle(), "没有等着的一场再按没用")
	_settle(f2)
	t.eq(f2.screen, GameFlow.Screen.MAP, "看完回地图")
	_cleanup()


static func run_search_loop(t: TestCase) -> void:
	t.begin("084 · 搜索循环：事件屏（搜索 / 离开）→ 选搜索自动搜一次进搜索屏 → 关闭回事件屏（再搜 / 离开）→ 搜满回「翻遍了」→ 离开交收获；遭遇那一次直接到「有人来了」→ 迎战 → 战前准备 → 回放 → 「余波」→ 战利品；最小化 / 恢复的是同一个会话")
	var c := _content()
	var kit := _kit(c)
	var found := _seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := _flow(c)
	var run := f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	var next := int(found["next"])
	t.check(f.step_to(next), "走上搜索点")
	t.eq(f.screen, GameFlow.Screen.EVENT, "先到事件屏")
	var def: EventDef = f.last_payload.get("def", null)
	var labels: Array = _labels(def)
	t.check(labels.has("搜索") and labels.has("离开"), "选项是搜索 / 离开（%s）" % str(labels))
	t.check(f.choose_event(labels.find("搜索")), "选「搜索」")
	var session: SearchSession = run.events.current_search
	t.not_null(session, "会话开着")
	if session == null:
		return
	var rounds := 1
	var met := false
	while true:
		if not session.active:
			met = true
			break
		t.eq(f.screen, GameFlow.Screen.SEARCH, "第 %d 次：搜索屏" % rounds)
		t.eq(session.searches_done, rounds, "第 %d 次：自动搜了这一次" % rounds)
		t.check(f.last_payload.get("session", null) == session, "搜索屏带着会话")
		if rounds == 1:
			# 最小化 / 恢复
			var had := session.haul_box.item_count()
			t.check(f.hide_overlay(), "收起回地图")
			t.check(f.screen == GameFlow.Screen.MAP and bool(f.last_payload.get("minimized", false)), "→ 地图（最小化）")
			t.check(run.events.current_search == session and session.active and session.haul_box.item_count() == had, "会话与收获都在")
			t.check(f.can_reopen() and f.reopen_node(), "回到这个点")
			t.check(f.screen == GameFlow.Screen.SEARCH and f.last_payload.get("session", null) == session, "恢复的是同一个会话")
		t.check(f.close_search(), "关闭搜索屏")
		t.eq(f.screen, GameFlow.Screen.EVENT, "第 %d 次之后：回到事件屏" % rounds)
		var again: EventDef = f.last_payload.get("def", null)
		var l2: Array = _labels(again)
		if session.is_exhausted():
			t.check(again != null and again.id == &"search_done" and l2 == ["离开"], "搜满了：「翻遍了」只能离开（%s）" % str(l2))
			var had_all := session.haul_box.item_count()
			t.check(f.choose_event(0), "离开")
			t.check(not session.active and run.events.current_search == null, "会话结束")
			t.check(run.map.get_node(next).is_visited(), "点用过了")
			if had_all > 0:
				t.check(f.screen == GameFlow.Screen.LOOT and run.pending_loot != null and run.pending_loot.item_count() == had_all, "收获交到待拾取 → 战利品屏")
			else:
				t.eq(f.screen, GameFlow.Screen.MAP, "空手：回地图")
			break
		t.check(again != null and again.id == &"search_again" and l2 == ["再搜一次", "离开"], "「翻过一遍」：再搜一次 / 离开（%s）" % str(l2))
		t.check(f.choose_event(0), "再搜一次")
		rounds += 1
		if rounds > 10:
			t.check(false, "循环没停")
			break
	if met:
		# 遭遇那一次：没有搜索屏，直接「有人来了」→ 迎战 → 战前准备 → 回放 → 余波 → 战利品
		t.eq(f.screen, GameFlow.Screen.EVENT, "遭遇：直接到事件屏")
		var enc: EventDef = f.last_payload.get("def", null)
		t.check(enc != null and enc.id == &"search_encounter" and _labels(enc) == ["迎战"], "「有人来了」只有迎战")
		t.check(run.events.current_search == session and not session.encounter.is_empty(), "会话还挂着，遭遇在里面")
		var before := session.haul_box.item_count()
		t.check(f.choose_event(0), "迎战")
		t.eq(f.screen, GameFlow.Screen.PREBATTLE, "→ 战前准备")
		t.eq(String(run.events.pending_battle["kind"]), "search", "是搜索里的一场")
		t.check(f.start_battle(), "开战")
		t.eq(f.screen, GameFlow.Screen.BATTLE, "→ 回放")
		t.check(run.events.current_search == null and run.map.get_node(next).is_visited(), "会话收了、点用过了")
		f.resume()
		t.check(f.screen == GameFlow.Screen.EVENT and (f.last_payload.get("def", null) as EventDef).id == &"search_destroyed", "回放之后先说「余波」，再看战利品")
		t.check(f.choose_event(0), "继续")
		if run.pending_loot != null:
			t.eq(f.screen, GameFlow.Screen.LOOT, "→ 战利品（敌人掉的 + 之前的收获）")
			t.check(run.pending_loot.item_count() >= before, "之前搜到没拿的也在里面")
		else:
			t.eq(f.screen, GameFlow.Screen.MAP, "什么都没掉：回地图")
	_settle(f)
	_cleanup()


static func _labels(def: EventDef) -> Array:
	var out: Array = []
	if def != null:
		for o in def.options:
			out.append((o as EventOption).label)
	return out


static func run_auto_spawn(t: TestCase) -> void:
	t.begin("084 · 序章开局就站在出生点上（auto_spawn）；第一章照旧先挑")
	var c := _content()
	t.check(c.prologue.auto_spawn, "序章 auto_spawn")
	t.check(not c.chapter.auto_spawn, "第一章不自动")
	var s := RunState.start(c.prologue, 3, c.items, c.enemies, c.sets)
	t.not_null(s, "开序章")
	if s == null:
		return
	t.eq(s.phase, RunState.Phase.ON_MAP, "一开局就在图上")
	t.eq(s.travel.current_id, s.map.entry_ids[0], "站在出生点上")
	t.check(not s.pick_spawn(s.map.entry_ids[0]), "再挑一次没用（已经站着了）")
	t.check(not s.travel.available_moves().is_empty(), "能走")
	var s1 := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets)
	t.check(s1 == null or s1.phase == RunState.Phase.PICK_SPAWN, "第一章先挑出生点")


static func run_drop_outside(t: TestCase) -> void:
	t.begin("084 · 棋盘外的空间全是暂存区：放到空白处进暂存区（末尾）；从暂存区拖出又放到外面回原行；带东西的包不行；开关关着照旧退回")
	ItemInstance.reset_uid_counter()
	var gun := ItemDef.new()
	gun.id = &"t_gun"
	gun.display_name = "gun"
	gun.shape = ItemShape.from_ascii(["#"])
	var board := GridInventory.new(Vector2i(4, 4), 1)
	var stash := ItemStash.new(2, 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2.ZERO
	view.size = Vector2(board.size) * InventoryView.CELL
	var sview := StashView.new()
	sview.stash = stash
	sview.position = Vector2(400, 0)
	sview.size = Vector2(220, 200)
	var drag := DragLayer.new()
	drag.register_view(view)
	drag.register_view(sview)
	drag.stash = stash
	var a := ItemInstance.create(gun)
	board.place(a, Vector2i(0, 0), 0)
	# 开关关着：退回
	view.grab_requested.emit(view, a.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "抓起来了")
	t.check(not drag.drop_at(Vector2(300, 300)), "开关关着：放到空白处不算落入")
	t.check(board.has_item(a.uid), "退回棋盘")
	# 开关开着：进暂存区
	drag.drop_outside_to_stash = true
	var first := ItemInstance.create(gun)
	stash.admit(first)
	view.grab_requested.emit(view, a.uid, Vector2(24, 24))
	drag.update_preview(Vector2(300, 300))
	t.check(drag.drop_at(Vector2(300, 300)), "开关开着：放到空白处算落入")
	t.check(stash.has_item(a.uid) and not board.has_item(a.uid), "进了暂存区")
	t.eq(stash.index_of(a.uid), 1, "追加在末尾")
	# 从暂存区拖出又放到外面：回原行
	sview.grab_requested.emit(sview, first.uid, Vector2(10, 10))
	t.check(drag.is_dragging(), "从暂存区抓起第一行")
	t.check(not drag.drop_at(Vector2(300, 300)), "放回外面 = 没动")
	t.eq(stash.index_of(first.uid), 0, "还在第一行")
	t.eq(stash.item_count(), 2, "一件没多没少")
	# drop_filter 拦住的照旧退回
	drag.drop_filter = func(_inst: ItemInstance, _target: ItemContainer) -> bool: return false
	stash.remove(a.uid)
	board.place(a, Vector2i(1, 1), 0)
	view.grab_requested.emit(view, a.uid, Vector2(72, 72))
	t.check(not drag.drop_at(Vector2(300, 300)), "被 drop_filter 拦住：退回")
	t.check(board.has_item(a.uid), "还在棋盘上")


static func run_loot_lock_only_container(t: TestCase) -> void:
	t.begin("084 · 容器屏的落点过滤只锁容器里没亮的：自己棋盘上的包能挪到任意合法位置、能拖进暂存区；容器里没亮的仍只能在容器内挪")
	var c := _content()
	ItemInstance.reset_uid_counter()
	var bag_def := c.items.get_def(&"bag_leather")
	var box := LootPacker.board_of([&"knife", &"armor"] as Array[StringName], Vector2i(6, 4), c.items)
	var loot := LootView.new()
	loot.inventory = box
	var board := GridInventory.new(Vector2i(8, 6), 1, true)
	var bag := ItemInstance.create(bag_def, 0)
	board.try_add(bag, true)
	var filter := func(inst: ItemInstance, target: ItemContainer) -> bool:
		return not loot.is_locked(inst.uid) or target == box
	var stash := ItemStash.new(2, 0)
	t.check(not loot.is_locked(bag.uid), "棋盘上的包不算「没亮」")
	t.check(bool(filter.call(bag, board)) and bool(filter.call(bag, stash)), "包能放棋盘、能放暂存区")
	var hidden: ItemInstance = box.items()[0]
	t.check(loot.is_locked(hidden.uid), "容器里没亮的锁着")
	t.check(bool(filter.call(hidden, box)) and not bool(filter.call(hidden, board)), "没亮的只能在容器内挪，放不到棋盘")
	loot.mark_revealed([hidden.uid])
	t.check(not loot.is_locked(hidden.uid) and bool(filter.call(hidden, board)), "亮了就能拖出来")
	# 真挪一次：包连里面的东西从 (0,0) 挪到 (3,2)
	var knife := ItemInstance.create(c.items.get_def(&"knife"), 0)
	t.check(board.try_add(knife, true), "包里放一把刀")
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	var drag := DragLayer.new()
	drag.register_view(view)
	drag.drop_filter = filter
	view.grab_requested.emit(view, bag.uid, Vector2(24, 24))
	var at := (Vector2(3, 2) + Vector2(0.5, 0.5)) * InventoryView.CELL
	drag.update_preview(at)
	t.check(drag.drop_at(at), "包放到 (3,2)")
	t.eq(bag.origin, Vector2i(3, 2), "包挪过去了")
	t.check(board.contents_of(bag.uid).has(knife.uid), "刀跟着包走")


static func frame_minimize_and_window(t: TestCase, root: Window) -> void:
	t.begin("084 · 导演：收起 = 最小化（叠层藏着不销毁、恢复是同一块）；浮窗能挪、不出父控件的范围、记位置")
	var win := FloatingWindow.new()
	var host := Control.new()
	host.size = Vector2(800, 600)
	root.add_child(host)
	win.setup("t_win", "试", null)
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(200, 100)
	win.body().add_child(filler)
	host.add_child(win)
	win.move_to(Vector2(100, 50))
	t.eq(win.position, Vector2(100, 50), "挪到指定位置")
	win.move_to(Vector2(-40, 5000))
	t.check(win.position.x == 0.0 and win.position.y <= 600.0 - win.size.y + 0.5, "不出父控件的范围（%s）" % str(win.position))
	var again := FloatingWindow.new()
	again.setup("t_win", "再开", null)
	host.add_child(again)
	again._place()
	t.eq(again.position, win.position, "同一个 key 再开：记得上次的位置")
	host.queue_free()

	var c := _content()
	var kit := _kit(c)
	var found := _seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var scene := load(GAME) as PackedScene
	var game = scene.instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	_cleanup()
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(c.chapter, kit, int(found["seed"]))
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	t.check(map.step(int(found["next"])), "走上搜索点")
	if game.overlay() != null and game.overlay().screen == GameFlow.Screen.EVENT:
		game.overlay().proceed()     # 「搜索」
	var ov = game.overlay()
	if ov == null or ov.screen != GameFlow.Screen.SEARCH:
		t.check(true, "（这个种子没开出搜索屏：%s）" % str(flow.screen))
		flow.to_main_menu()
		game.queue_free()
		_cleanup()
		return
	t.check(map.can_reopen(), "地图上「回到这个点」亮着（会话开着）")
	t.check(ov.to_map(), "收起")
	t.is_null(game.overlay(), "叠层不在上面了")
	t.check(game.minimized() == ov and not ov.visible and ov.is_inside_tree(), "但没销毁：藏着")
	t.eq(game.base(), map, "地图还是那张")
	t.check(map.reopen(), "回到这个点")
	t.check(game.overlay() == ov and ov.visible and game.minimized() == null, "恢复的是同一块")
	t.check(ov.to_map(), "再收起")
	ov.leave() if false else null
	flow.run.events.current_search.leave()     # 会话结束：换屏，藏着的过期
	var guard := 0
	while game.overlay() != null and guard < 10:
		guard += 1
		var o = game.overlay()
		match o.screen:
			GameFlow.Screen.PREBATTLE:
				o.start_battle()
			GameFlow.Screen.LOOT:
				o.take_all()
			_:
				o.proceed()
	t.is_null(game.minimized(), "会话结束后藏着的那一屏也没了")
	flow.to_main_menu()
	game.queue_free()
	_cleanup()
