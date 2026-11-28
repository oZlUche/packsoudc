## 404（作者 11-28）：精英的额外奖励改成宝箱 —— 打赢精英点，那一件保底不再进战利品，原地留一个精英宝箱：
## 战利品屏之后接宝箱屏；不开就走，宝箱留在点上，回来还能开；开了是一次搜索（必出一件同档 + 随机 1～2 件、能出珍宝、不遭遇）；
## 开过的不能再开；存档往返宝箱还在。
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_rules(t: TestCase) -> void:
	t.begin("404 · 精英宝箱的小表在数据里：随机 1～2 件、能出珍宝；放宝箱、认精英宝箱、等着开")
	var nr := ContentPaths.load_asset("node_rules", "standard") as NodeRules
	t.check(nr != null and nr.chest != null, "标准节点规则写了宝箱规则")
	if nr != null and nr.chest != null:
		t.eq(nr.chest.elite_random_items, Vector2i(1, 2), "随机 1～2 件")
		t.check(nr.chest.elite_include_treasure, "能出珍宝")
		t.eq(nr.chest.items_by_rarity, ChestRules.new().items_by_rarity, "地图宝箱的表不动")
	var n := MapNode.new()
	n.type = &"elite"
	n.state = MapNode.State.VISITED
	t.check(not ChestPlacer.waiting(n), "没宝箱：不等")
	ChestPlacer.place_elite(n, 3, &"ruins", &"knife")
	t.check(ChestPlacer.is_elite(n) and ChestPlacer.rarity_of(n) == 3 and ChestPlacer.prize_of(n) == &"knife", "放下：档、必出的那一件")
	t.check(ChestPlacer.waiting(n), "点用过了也等着开")
	var back := MapNode.from_dict(n.to_dict())
	t.check(ChestPlacer.waiting(back) and ChestPlacer.prize_of(back) == &"knife", "节点存取往返")
	var plain := MapNode.new()
	plain.type = &"chest"
	plain.state = MapNode.State.VISITED
	t.check(not ChestPlacer.waiting(plain), "地图宝箱点用过了不等")


## 出生点旁边改一个精英点（敌人现造）
static func _elite_next_to_spawn(f: GameFlow, c, kit: LoadoutDef) -> MapNode:
	var found: Dictionary = NodeScreens._seed_with(c, &"elite", kit.items)
	var run := f.begin(c.chapter, kit, int(found.get("seed", 1)))
	if run == null:
		return null
	var entry := int(found.get("entry", run.map.entry_ids[0]))
	f.pick_spawn(entry)
	Support.settle(f)
	if found.has("next"):
		return run.map.get_node(int(found["next"]))
	for nid in run.map.neighbors(entry):
		var node := run.map.get_node(nid)
		if node.type in [&"battle", &"event", &"search"]:
			run.events.retype(node, &"elite")
			return node
	return null


## 一屏一屏往下看，停在宝箱屏（或回到地图）
static func _to_chest(f: GameFlow, seen: Array) -> void:
	var guard := 0
	while GameFlow.is_overlay(f.screen) and f.screen != GameFlow.Screen.CHEST and guard < 30:
		guard += 1
		seen.append(f.screen)
		if f.screen == GameFlow.Screen.LOOT:
			var loot := f.run.pending_loot
			if loot != null:
				for inst in loot.items():
					t_loot.append((inst as ItemInstance).def.id)
			f.discard_loot()
		else:
			Support.settle_one(f)


static var t_loot: Array = []


static func run_flow(t: TestCase) -> void:
	t.begin("404 · 打赢精英：战利品里没有那一件、接着是宝箱屏；不开就走宝箱留着，回来再开；开了必出那一件 + 随机 1～2 件，开过不能再开")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "elite404")
	var node := _elite_next_to_spawn(f, c, kit)
	t.check(node != null, "出生点旁边有精英点")
	if node == null:
		Support.cleanup("elite404")
		return
	var run := f.run
	var spawn := run.travel.current_id
	t_loot.clear()
	var seen: Array = []
	t.check(f.step_to(node.id), "走上精英点")
	_to_chest(f, seen)
	t.check(seen.has(GameFlow.Screen.LOOT), "先是战利品屏")
	t.eq(f.screen, GameFlow.Screen.CHEST, "战利品之后 → 宝箱屏")
	t.check(node.is_visited(), "精英点算用过")
	t.check(ChestPlacer.is_elite(node) and not ChestPlacer.is_opened(node), "点上留了没开的精英宝箱")
	var r := DropResolver.elite_rarity_of(run.drop_rule, run.events._loot_ctx())
	t.eq(ChestPlacer.rarity_of(node), r, "宝箱的档 = 难度的精英稀有度（%d）" % r)
	var prize := ChestPlacer.prize_of(node)
	t.check(prize != &"" and run.items.get_def(prize) != null, "必出的那一件定好了（%s）" % prize)

	t.check(f.leave_chest(), "不开就走")
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(ChestPlacer.waiting(node), "宝箱还等着")
	t.check(f.can_reopen() and f.reopen_node(), "站着能再开")
	t.eq(f.screen, GameFlow.Screen.CHEST, "→ 宝箱屏")
	t.check(f.leave_chest(), "又走")

	# 存档往返：宝箱还在
	var back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and ChestPlacer.waiting(back.map.get_node(node.id)), "读回：宝箱还等着开")

	# 走开再回来：再给看宝箱屏
	t.check(f.step_to(spawn), "走回出生点")
	Support.settle(f)
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(f.step_to(node.id), "回到精英点")
	t.eq(f.screen, GameFlow.Screen.CHEST, "回来 → 宝箱屏")
	t.eq(run.events.chest_hold_seconds(node), run.events.chest_rules().hold_time(r), "按住秒数按宝箱的档")

	t.check(f.open_chest(node), "锁开了")
	t.eq(f.screen, GameFlow.Screen.SEARCH, "→ 搜索屏")
	var session := run.events.current_search
	t.check(session != null and session.node == node, "开了这个点的会话")
	if session != null:
		t.check(session.encounter.is_empty() and not session.can_search(), "只搜一次、不遭遇")
		t.check(not session.rules.exclude_tags.has(&"treasure"), "能出珍宝")
		t.eq(session.search_floor, [] as Array[int], "随机的几件不设下限")
		var ids: Array = []
		for inst in session.haul().items():
			ids.append((inst as ItemInstance).def.id)
		t.check(ids.has(prize), "必出的那一件在里面（%s）" % str(ids))
		var span := run.events.chest_rules().elite_random_items
		t.check(ids.size() >= 1 + span.x and ids.size() <= 1 + span.y, "一共 %d 件（必出 1 + 随机 %d～%d）" % [ids.size(), span.x, span.y])
	t.check(ChestPlacer.is_opened(node) and not ChestPlacer.waiting(node), "记了开过")
	t.check(run.events.pause_search(), "关搜索屏 = 拿完走人")
	Support.settle(f)
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(not f.open_chest(node) and not f.can_reopen(), "开过的不能再开")
	Support.cleanup("elite404")


static func run_no_chest_without_rarity(t: TestCase) -> void:
	t.begin("404 · 没有精英稀有度（规则与难度都没写）：不留宝箱；普通战不留")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "elite404b")
	var node := _elite_next_to_spawn(f, c, kit)
	if node == null:
		t.check(false, "出生点旁边有精英点")
		Support.cleanup("elite404b")
		return
	var rule := f.run.drop_rule.duplicate() as DropRule
	rule.elite_rarity = -1
	f.run.events.drop_rule = rule
	t.check(f.step_to(node.id), "走上精英点")
	var seen: Array = []
	_to_chest(f, seen)
	t.check(f.screen != GameFlow.Screen.CHEST and ChestPlacer.chest_of(node).is_empty(), "不留宝箱")
	Support.cleanup("elite404b")
