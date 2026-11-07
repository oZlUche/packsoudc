## 保险箱（092 的规则；101 之后它是一局的模块 [SafeModule]）：放进去的东西视为已带出，战败也带得出。
## 287（作者 11-07 选 C）：图上不再单放保险箱点，并进免费撤离点叫「托付」—— 关上 / 走开只把新放的交出去（拿不回来），空格留着下回再托；
## 付费出口不接、免费出口关门了托付也关。老档图上的 `safe` 点照旧能开。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _plain_item(s: RunState) -> ItemDef:
	for inst in s.board.items():
		if not (inst as ItemInstance).def.is_bag:
			return (inst as ItemInstance).def
	return null


## 一局图上的撤离点：免费的（[param free] 真）或付费的；没有 null
static func extract_node(run: RunState, free: bool) -> MapNode:
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if NodeEvents.effective_type(n) == &"extract" and (PaidExtracts.fee_of(n) == 0) == free:
			return n
	return null


## 把人直接摆到 [param node] 上（测试用：不走路、不触发点上的事）
static func stand_on(run: RunState, node: MapNode) -> void:
	run.travel.current_id = node.id


static func run_no_safe_nodes(t: TestCase) -> void:
	t.begin("287 · 图上不再有保险箱点；托付格子照旧是一局一块（3×3）；老档的类型、样式、地图文字 K 还认得")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var seen := 0
	for seed_ in range(1, 9):
		var s := RunState.start(c.chapter, seed_, c.items, c.enemies, c.sets, kit.items)
		if s == null:
			continue
		seen += 1
		var safes := 0
		for id in s.map.node_ids():
			safes += 1 if s.map.get_node(id).type == &"safe" else 0
		t.eq(safes, 0, "种子 %d：没有保险箱点" % seed_)
		var sm := SafeModule.of(s)
		t.check(sm != null and sm.inventory != null and sm.inventory.size == Vector2i(3, 3), "种子 %d：托付格子 3×3" % seed_)
		t.not_null(extract_node(s, true), "种子 %d：有免费撤离点" % seed_)
	t.check(seen >= 4, "至少四个种子开得出局（%d）" % seen)
	t.check(MapNodeTypes.has(&"safe") and MapNodeStyle.of(&"safe")["label"] != "", "老档：类型表与样式还认得")
	t.eq(MapGridText.SYMBOL_TYPES.get("K", &""), &"safe", "地图文字里 K 照旧")


static func run_seal_rules(t: TestCase) -> void:
	t.begin("287 · 托付的锁：关上只把新放的交出去、格子不关；第二回还能放空格；存档往返带着交出去的；老档整块锁着的读进来 = 全交出去、格子能用")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var s := RunState.start(c.chapter, 1, c.items, c.enemies, c.sets, kit.items)
	var def := _plain_item(s) if s != null else null
	t.check(s != null and def != null, "开一局、有能放的东西")
	if s == null or def == null:
		return
	var sm := SafeModule.of(s)
	t.check(not sm.lock() and sm.is_open(), "空着关不算关")
	var a := ItemInstance.create(def)
	t.check(sm.inventory.try_add(a, true), "放第一件")
	t.check(sm.lock() and sm.is_sealed(a.uid), "关上：这件交出去了")
	t.check(sm.is_open() and not sm.locked, "格子没关（还能再托）")
	t.check(not sm.lock(), "没有新放的：再关不算")
	var b := ItemInstance.create(def)
	t.check(sm.inventory.try_add(b, true) and not sm.is_sealed(b.uid), "第二回放一件：还没交")
	var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	var back_sm := SafeModule.of(back) if back != null else null
	t.check(back_sm != null and back_sm.inventory.item_count() == 2 and back_sm.is_sealed(a.uid) and not back_sm.is_sealed(b.uid), "存档往返：交出去的、没交的都对")
	t.check(sm.lock() and sm.is_sealed(b.uid) and sm.sealed_count() == 2, "第二回关上：也交出去了")
	var old := s.to_dict()
	var mods: Dictionary = old.get("modules", {})
	var saved: Dictionary = mods.get(SafeModule.ID, {})
	saved["locked"] = true
	saved.erase("sealed")
	var aged := RunState.from_dict(old, c.chapter, c.items, c.enemies, c.sets)
	var aged_sm := SafeModule.of(aged) if aged != null else null
	t.check(aged_sm != null and aged_sm.is_open() and aged_sm.is_sealed(a.uid) and aged_sm.is_sealed(b.uid), "老档整块锁着：全算交出去、格子还能用")


static func run_entrust_gate(t: TestCase) -> void:
	t.begin("287 · 托付只在免费撤离点：人站在上面、出口没关；付费出口不接；免费出口过半关门托付也关")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "safe287")
	var run := f.begin(c.chapter, kit, 1)
	t.not_null(run, "开局")
	if run == null:
		Support.cleanup("safe287")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var free := extract_node(run, true)
	var paid := extract_node(run, false)
	t.check(free != null, "有免费撤离点")
	if free == null:
		Support.cleanup("safe287")
		return
	t.check(not f.entrust_open(free), "人不在上面：不能托")
	stand_on(run, free)
	t.check(f.entrust_open(free) and f.open_safe(free), "站在免费出口上：能托、开托付屏")
	t.eq(f.screen, GameFlow.Screen.SAFE, "→ 托付屏")
	f.close_safe()
	if paid != null:
		stand_on(run, paid)
		t.check(not f.entrust_open(paid) and not f.open_safe(paid), "付费出口：不接托付")
	var cd := CountdownModule.of(run)
	var closing := cd.closing_extract_id() if cd != null else -1
	if closing >= 0:
		var node := run.map.get_node(closing)
		stand_on(run, node)
		t.check(f.entrust_open(node), "会关的那个，开局还能托")
		run.travel.clock.total = cd.limit() - PaidExtracts.closes_at(node)
		t.check(cd.extract_closed(node) and not f.entrust_open(node), "关门了：托付也关")
	var spot := _first_of(run, &"battle")
	if spot != null:
		stand_on(run, spot)
		t.check(not f.entrust_open(spot), "不是撤离点：不能托")
	Support.cleanup("safe287")


static func _first_of(run: RunState, type: StringName) -> MapNode:
	for id in run.map.node_ids():
		if run.map.get_node(id).type == type:
			return run.map.get_node(id)
	return null


static func frame_safe_screen(t: TestCase, root: Window) -> void:
	t.begin("287 · 托付屏：撤离确认框里有【托付】；put_in 放进去（包不收）、没交前 take_back 拿得回；空着 Esc 只是收起；放了再关：交出去、压灰、拿不回，空格还能放；付费出口的确认框没有【托付】")
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
	var run := flow.begin(c.chapter, kit, 1)
	if run == null:
		t.check(false, "开局")
		game.queue_free()
		Support.cleanup("safe")
		return
	flow.pick_spawn(run.map.entry_ids[0])
	var free := extract_node(run, true)
	var map_screen = game.base()
	if free == null or map_screen == null or not map_screen.has_method("entrust_here"):
		t.check(false, "有免费撤离点、地图屏")
		game.queue_free()
		Support.cleanup("safe")
		return
	stand_on(run, free)
	t.check(map_screen.extract() and map_screen.confirm_open(), "按撤离：弹确认框")
	var labels: Array[String] = []
	for b in (map_screen as Node).find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	t.check(labels.has(UiText.t("map.entrust")), "确认框里有【托付】（%s）" % str(labels))
	t.check(map_screen.entrust_here(), "按【托付】")
	t.eq(flow.screen, GameFlow.Screen.SAFE, "→ 托付屏")
	var screen = game.overlay()
	t.check(screen != null and screen.has_method("put_in"), "叠层是托付屏")
	var item: ItemInstance = null
	var item2: ItemInstance = null
	var bag: ItemInstance = null
	for inst in run.board.items():
		if (inst as ItemInstance).def.is_bag:
			bag = inst
		elif item == null:
			item = inst
		elif item2 == null:
			item2 = inst
	t.check(item != null, "棋盘上有能放的东西")
	if screen == null or item == null:
		game.queue_free()
		Support.cleanup("safe")
		return
	t.check(screen.put_in(item.uid), "放进去")
	t.check(SafeModule.of(run).inventory.has_item(item.uid) and not run.board.has_item(item.uid), "在格子里、不在棋盘上")
	t.check(screen.take_back(item.uid), "没交出去：拿得回来")
	if bag != null:
		t.check(not screen.put_in(bag.uid) and not SafeModule.of(run).inventory.has_item(bag.uid), "包托付不了")
	t.check(game.escape(), "Esc（空着）")
	t.check(flow.screen == GameFlow.Screen.MAP and SafeModule.of(run).sealed_count() == 0, "→ 地图，什么也没交")
	t.check(flow.open_safe(free), "再开")
	screen = game.overlay()
	t.check(screen.put_in(item.uid), "放进去")
	t.check(game.escape(), "Esc（里面有东西）")
	t.check(flow.screen == GameFlow.Screen.MAP and SafeModule.of(run).is_sealed(item.uid), "→ 地图，交出去了")
	t.check(SafeModule.of(run).is_open() and flow.entrust_open(free), "格子没关：还能托")
	t.check(flow.open_safe(free), "回来再开")
	screen = game.overlay()
	t.check(not screen.take_back(item.uid) and SafeModule.of(run).inventory.has_item(item.uid), "交出去的拿不回来")
	var view: InventoryView = screen.safe_view()
	t.check(view.dim_filter.is_valid() and not bool(view.dim_filter.call(item)), "交出去的压灰")
	if item2 != null:
		t.check(screen.put_in(item2.uid), "空格还能放第二件")
	screen.to_map()
	map_screen = game.base()
	var paid := extract_node(run, false)
	if paid != null and map_screen != null and map_screen.has_method("extract"):
		stand_on(run, paid)
		map_screen.extract()
		var paid_labels: Array[String] = []
		var box: Node = map_screen._confirm
		for b in (box.find_children("*", "Button", true, false) if box != null else []):
			paid_labels.append((b as Button).text)
		t.check(not paid_labels.has(UiText.t("map.entrust")), "付费出口的确认框：没有【托付】")
		map_screen.cancel_extract()
	game.queue_free()
	Support.cleanup("safe")
