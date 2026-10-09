## 节点事件（M4-4，架构文档 5.6 / 6.2 / 7.1）：踩到每种点发生什么，数值全来自规则。
##
## 图是合成的（出生点连着每种类型各一个点），敌人、规则、道具是仓库里的真数据。
extends RefCounted

const TYPES: Array[StringName] = [&"battle", &"elite", &"core", &"search", &"rest", &"shop", &"event", &"extract", &"random", &"junction"]


class World:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var chapter: ChapterDef
	var pool: EnemyPool
	var drop_rule: DropRule
	var rules: NodeRules
	var graph: MapGraph
	var travel: MapTravel
	var vitality: Vitality
	var events: NodeEvents
	var ids: Dictionary = {}   # type -> node id

	func exploration_of_events() -> Dictionary:
		return events.exploration()


static func _world(seed_base: int = 100, vitality_max: int = 5, strong: bool = true) -> World:
	var w := World.new()
	w.items = ItemDatabase.new()
	w.items.load_dir()
	w.enemies = EnemyDatabase.new()
	w.enemies.load_all()
	w.chapter = load(ContentPaths.asset_file("chapters", "free_mode"))
	w.pool = w.enemies.pool(w.chapter.enemy_pool)
	w.drop_rule = load(ContentPaths.asset_file("drop_rules", String(w.chapter.drop_rule)))
	w.rules = load(ContentPaths.asset_file("node_rules", String(w.chapter.node_rules)))

	w.graph = MapGraph.new()
	var spawn := MapNode.new()
	spawn.id = 0
	spawn.type = &"spawn"
	spawn.tier = 0
	w.graph.add_node(spawn)
	var i := 0
	for type in TYPES:
		i += 1
		var n := MapNode.new()
		n.id = i
		n.type = type
		n.tier = 3 if type == &"core" else 1
		n.content_seed = seed_base + i
		w.graph.add_node(n)
		w.graph.connect_nodes(0, i)
		w.ids[type] = i
	EnemyPlacer.fill(w.graph, w.pool, w.enemies, w.items, 0, &"")

	w.travel = MapTravel.new(w.graph, ActionClock.new())
	w.vitality = Vitality.new(vitality_max)
	w.travel.start_at(0)
	w.events = NodeEvents.new(w.graph)
	w.events.vitality = w.vitality
	w.events.rules = w.rules
	w.events.pool = w.pool
	w.events.enemies = w.enemies
	w.events.items = w.items
	w.events.drop_rule = w.drop_rule
	var spec := _strong(w.items) if strong else _weak()
	w.events.hooks.register(&"player_spec", func() -> CombatantSpec: return spec)
	w.events.bind(w.travel)
	return w


## 打得过任何占位敌人的玩家：一万血、两把枪
static func _strong(items: ItemDatabase) -> CombatantSpec:
	var board := GridInventory.new(Vector2i(8, 4), 0, false)
	for id in [&"sniper", &"rifle", &"pistol", &"armor"]:
		var d := items.get_def(id)
		if d != null:
			board.try_add(ItemInstance.create(d, 0), true)
	return BattleCompiler.compile_board(board, CombatantBaseline.with_hp(10000.0))


## 一血、空手：只要敌人有 DPS 就必输
static func _weak() -> CombatantSpec:
	return BattleCompiler.compile_board(null, CombatantBaseline.with_hp(1.0))


static func _node(w: World, type: StringName) -> MapNode:
	return w.graph.get_node(int(w.ids[type]))


static func run_battle(t: TestCase) -> void:
	t.begin("节点事件 · 战斗：赢了掉落进尸体容器，输了扣规则里的体力，不论输赢点都用过")

	var w := _world()
	var fights: Array = []
	w.events.battle_finished.connect(func(n: MapNode, r: BattleResult, won: bool): fights.append([n.id, r, won]))
	var loots: Array = []
	w.events.loot_ready.connect(func(n: MapNode, corpse: GridInventory): loots.append([n.id, corpse]))
	var battle := _node(w, &"battle")
	t.check(EnemyKit.has_enemy(battle.content), "战斗点生成时就有敌人")
	var before := w.vitality.current
	t.check(w.travel.step_to(battle.id), "走上去")
	t.eq(fights.size(), 1, "打了一场")
	if fights.is_empty():
		return
	t.check(fights[0][2], "一万血两把枪：赢了")
	t.check(battle.is_visited(), "点用过了")
	t.eq(w.vitality.current, before, "赢了不扣体力")
	t.eq(loots.size(), 1, "有战利品")
	if not loots.is_empty():
		var corpse: GridInventory = loots[0][1]
		var carried := DropResolver.carried_ids(battle.content)
		for inst in corpse.items():
			t.check(carried.has((inst as ItemInstance).def.id), "尸体里的 '%s' 是敌人背的" % (inst as ItemInstance).def.id)
	# 再走上去：用过了，不再打
	t.check(w.travel.step_to(0) and w.travel.step_to(battle.id), "走回来再走上去")
	t.eq(fights.size(), 1, "用过的点不再打")

	# 输：弱玩家
	var lw := _world(200, 5, false)
	var lf: Array = []
	lw.events.battle_finished.connect(func(n: MapNode, r: BattleResult, won: bool): lf.append([n.id, r, won]))
	var lost: Array = []
	lw.events.defeated.connect(func(why: StringName): lost.append(why))
	var b2 := _node(lw, &"battle")
	var v0 := lw.vitality.current
	lw.travel.step_to(b2.id)
	t.eq(lf.size(), 1, "打了一场")
	if not lf.is_empty():
		t.check(not lf[0][2], "一血空手：输了")
	t.eq(lw.vitality.current, v0 - lw.rules.loss_cost_of(&"battle"), "扣了规则里 battle 的数（%d）" % lw.rules.loss_cost_of(&"battle"))
	t.check(b2.is_visited(), "输了点也变空白（7.1）")
	t.check(lost.is_empty(), "还有体力，没战败")
	lw.travel.step_to(0)
	var e2 := _node(lw, &"elite")
	v0 = lw.vitality.current
	lw.travel.step_to(e2.id)
	t.eq(lw.vitality.current, v0 - lw.rules.loss_cost_of(&"elite"), "精英输了扣 elite 的数（%d）" % lw.rules.loss_cost_of(&"elite"))

	# 核心输了：直接战败，不扣
	lw.travel.step_to(0)
	v0 = lw.vitality.current
	lw.travel.step_to(_node(lw, &"core").id)
	t.eq(lost, [&"boss_lost"] as Array[StringName], "BOSS 输了直接战败")
	t.eq(lw.vitality.current, v0, "战败不走 spend")

	# 体力归零：战败
	var dw := _world(300, 1, false)
	var dl: Array = []
	dw.events.defeated.connect(func(why: StringName): dl.append(why))
	dw.travel.step_to(_node(dw, &"battle").id)
	t.eq(dl, [&"vitality_depleted"] as Array[StringName], "只剩一格输一场：体力归零，战败")

	# 同种子同结果
	var a := _world(400)
	var b := _world(400)
	var ra: Array = []
	var rb: Array = []
	a.events.battle_finished.connect(func(_n: MapNode, r: BattleResult, _w: bool): ra.append(r))
	b.events.battle_finished.connect(func(_n: MapNode, r: BattleResult, _w: bool): rb.append(r))
	a.travel.step_to(_node(a, &"elite").id)
	b.travel.step_to(_node(b, &"elite").id)
	t.check(ra.size() == 1 and rb.size() == 1 and ra[0].winner == rb[0].winner and ra[0].duration == rb[0].duration,
		"同一局同一个点，打出来一样")


static func run_havens(t: TestCase) -> void:
	t.begin("节点事件 · 休息回规则里的数；商店、撤离只发信号；岔路口什么都不发生")

	var w := _world()
	w.vitality.spend(3, &"test")
	var rested: Array = []
	w.events.rested.connect(func(n: MapNode, got: int): rested.append([n.id, got]))
	var before := w.vitality.current
	w.travel.step_to(_node(w, &"rest").id)
	t.eq(rested.size(), 1, "休息了")
	if not rested.is_empty():
		t.eq(rested[0][1], mini(w.rules.rest_restore, w.vitality.maximum - before), "回了规则里的数（封顶）")
	t.eq(w.vitality.current, before + rested[0][1] if not rested.is_empty() else before, "体力涨了")
	t.check(_node(w, &"rest").is_visited(), "休息区用过了")

	w.travel.step_to(0)
	var shops: Array = []
	w.events.shop_opened.connect(func(n: MapNode, _s: ShopSession): shops.append(n.id))
	w.travel.step_to(_node(w, &"shop").id)
	t.eq(shops, [_node(w, &"shop").id], "商店：发信号（没有经济规则时店是空的，点直接用过）")
	t.check(_node(w, &"shop").is_visited(), "没有经济规则：商店点直接用过")

	w.travel.step_to(0)
	var ex: Array = []
	w.events.extract_reached.connect(func(n: MapNode, _fee: int): ex.append(n.id))
	w.travel.step_to(_node(w, &"extract").id)
	t.eq(ex, [_node(w, &"extract").id], "撤离点：发信号（撤离动作是 M6 的事）")

	w.travel.step_to(0)
	w.travel.step_to(_node(w, &"junction").id)
	t.check(_node(w, &"junction").is_visited(), "岔路口：只是用过了")


static func run_event(t: TestCase) -> void:
	t.begin("节点事件 · 常规事件按权重出一种结果（占位）")

	var seen := {}
	for s in 12:
		var w := _world(500 + s * 10)
		w.vitality.spend(2, &"test")
		var got: Array = []
		w.events.event_resolved.connect(func(n: MapNode, outcome: StringName, detail: Dictionary): got.append([n.id, outcome, detail]))
		var before := w.vitality.current
		var node := _node(w, &"event")
		w.travel.step_to(node.id)
		t.eq(got.size(), 1, "种子 %d：事件发生了一次" % s)
		if got.is_empty():
			continue
		var outcome: StringName = got[0][1]
		var detail: Dictionary = got[0][2]
		seen[outcome] = true
		t.check(NodeRules.EVENT_OUTCOMES.has(outcome), "结果 '%s' 在清单里" % outcome)
		t.eq(String(node.content.get("outcome", "")), String(outcome), "结果记在内容里")
		t.check(node.is_visited(), "事件点用过了")
		match outcome:
			&"restore":
				t.eq(w.vitality.current - before, mini(w.rules.event_restore, w.vitality.maximum - before), "restore：回了 event_restore")
			&"item":
				t.check(detail.has("items") and (detail["items"] as Array).size() <= 1, "item：给了至多一件")
				for id in detail.get("items", []):
					t.check(w.items.get_def(id).rarity <= w.rules.event_item_rarity_cap, "事件给的道具稀有度不超上限")
			_:
				t.eq(w.vitality.current, before, "story：什么都不变")
	t.check(seen.size() >= 2, "十二个种子见到了 %d 种结果" % seen.size())


static func run_random(t: TestCase) -> void:
	t.begin("节点事件 · 随机点：踩上去才变成一种类型，变成什么按规则抽，是战斗就现造敌人")

	var seen := {}
	for s in 16:
		var w := _world(700 + s * 10)
		var node := _node(w, &"random")
		if s == 0:
			t.check(node.content.is_empty(), "随机点生成时内容是空的（5.10：唯一看不透的点）")
		var revealed: Array = []
		w.events.revealed.connect(func(n: MapNode, type: StringName): revealed.append([n.id, type]))
		var fights: Array = []
		w.events.battle_finished.connect(func(n: MapNode, _r: BattleResult, _won: bool): fights.append(n.id))
		var searches: Array = []
		w.events.search_opened.connect(func(n: MapNode, _s: SearchSession): searches.append(n.id))
		# 规则用同一个种子抽出来的，就是它会变成的
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:reveal" % node.content_seed)
		var expect := w.rules.random_pick(rng)
		w.travel.step_to(node.id)
		t.eq(revealed.size(), 1, "揭开了一次")
		if revealed.is_empty():
			continue
		var type: StringName = revealed[0][1]
		seen[type] = true
		t.eq(type, expect, "变成的就是规则按这个点的种子抽的")
		t.eq(NodeEvents.effective_type(node), type, "揭开之后这个点算这种类型")
		t.check(NodeRules.RANDOM_ALLOWED.has(type), "不会变成精英或 BOSS")
		match type:
			&"battle":
				t.check(EnemyKit.has_enemy(node.content), "变成战斗：现造了敌人")
				var view := MapNode.from_dict(node.to_dict())
				view.type = &"battle"
				t.eq(int(node.content["strength"]), EnemyPlacer.wanted_strength(w.pool, view, EnemyPlacer.depths_of(w.graph)[node.id],
					w.chapter.difficulty, &"", {"steps": w.travel.clock.total, "searches": 0}),
					"现造的敌人档位 = 规则按这个点 + 当时的探索度（走了 %d 步）算的" % w.travel.clock.total)
				t.eq(fights, [node.id], "而且打了")
				t.check(node.is_visited(), "打完用过了")
			&"search":
				t.eq(searches, [node.id], "变成搜索：开了会话")
				t.check(not node.is_visited(), "搜着的时候还没用过")
			_:
				t.check(node.is_visited(), "其他类型：处理完用过了")
		t.eq(w.events.reveal(node), type, "再揭一次还是它（记在内容里）")
	t.check(seen.size() >= 3, "十六个种子里变出了 %d 种（%s）" % [seen.size(), str(seen.keys())])


static func run_search(t: TestCase) -> void:
	t.begin("节点事件 · 搜索点：开会话、搜几次自己定、遭遇就地打、走了才算用过")

	var w := _world(900)
	var opened: Array = []
	w.events.search_opened.connect(func(n: MapNode, s: SearchSession): opened.append([n.id, s]))
	var closed: Array = []
	w.events.search_closed.connect(func(n: MapNode, haul: GridInventory, why: StringName): closed.append([n.id, haul, why]))
	var fights: Array = []
	w.events.battle_finished.connect(func(n: MapNode, _r: BattleResult, won: bool): fights.append([n.id, won]))
	var node := _node(w, &"search")
	w.travel.step_to(node.id)
	t.eq(opened.size(), 1, "开了会话")
	if opened.is_empty():
		return
	var s: SearchSession = opened[0][1]
	t.check(w.events.current_search == s, "当前会话就是它")
	t.check(not node.is_visited(), "还在搜：点没用过")
	t.eq(s.next_encounter_chance(), w.rules.search.encounter_chance(0), "遭遇概率按曲线第 0 档")
	while s.can_search():
		s.search()
	if s.active:
		s.leave()     # 084：搜满不自动结束，玩家按「离开」
	t.eq(closed.size(), 1, "会话结束了")
	if closed.is_empty():
		return
	var why: StringName = closed[0][2]
	var haul: GridInventory = closed[0][1]
	t.check(why == &"exhausted" or why == &"encounter", "结束原因是搜满或遭遇（%s）" % why)
	t.eq(haul.item_count(), s.found.size(), "收获都在容器里")
	if why == &"encounter":
		t.eq(fights.size(), 1, "遭遇了就地打了一场")
		t.check(EnemyKit.has_enemy(s.encounter), "遭遇的是敌人池出的人")
		t.check(TestSupport.pool_entry(w.pool, StringName(String(s.encounter["enemy"]))).fits(_search_view(node)), "那个敌人允许在搜索点出现")
	else:
		# 091（作者定）：遭遇打赢了会话接着开、能搜到底 —— 所以搜满 / 走了之前可能已经打过，但都得是赢的
		var all_won := true
		for f in fights:
			all_won = all_won and bool(f[1])
		t.check(fights.size() == 0 or all_won, "没遭遇就没打；打过的都是赢了才搜下去的（%d 场）" % fights.size())
	t.check(node.is_visited(), "结束之后点用过了")
	t.check(w.events.current_search == null, "当前会话清了")

	# 随时走
	var w2 := _world(950)
	var c2: Array = []
	w2.events.search_closed.connect(func(n: MapNode, _h: GridInventory, why2: StringName): c2.append(why2))
	w2.travel.step_to(_node(w2, &"search").id)
	w2.events.current_search.search()
	w2.events.current_search.leave()
	t.eq(c2, [&"left"] as Array[StringName], "自己走：closed(left)")
	t.check(_node(w2, &"search").is_visited(), "走了就用过了")

	# 遭遇一定出现：把曲线拉满
	var w3 := _world(960)
	w3.rules = w3.rules.duplicate(true) as NodeRules
	w3.rules.search.encounter_curve = [1.0] as Array[float]
	w3.events.rules = w3.rules
	var f3: Array = []
	w3.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): f3.append(won))
	var l3: Array = []
	w3.events.loot_ready.connect(func(_n: MapNode, corpse: GridInventory): l3.append(corpse))
	w3.travel.step_to(_node(w3, &"search").id)
	w3.events.current_search.search()
	t.eq(f3.size(), 1, "曲线拉满：第一次就遭遇并打了")
	if not f3.is_empty() and f3[0]:
		t.eq(l3.size(), 1, "赢了有战利品")


static func run_exploration(t: TestCase) -> void:
	t.begin("节点事件 · 踩上去才造的敌人跟探索度挂钩：走得多、搜得多，随机点与搜索遭遇的敌人更强")

	var w := _world(1200)
	var rule: StrengthRule = w.pool.strength_rule
	t.check(rule.steps_per_tier > 0 and rule.searches_per_tier > 0, "第一章的池配了探索度（步数每 %d 步、搜索每 %d 次一档）" % [rule.steps_per_tier, rule.searches_per_tier])
	# 在出生点和岔路口之间来回走，把步数走上去
	var junction := _node(w, &"junction")
	while w.travel.clock.total < rule.steps_per_tier * rule.steps_max_bonus + 2:
		w.travel.step_to(junction.id)
		w.travel.step_to(0)
	var steps := w.travel.clock.total
	t.eq(w.exploration_of_events(), {"steps": steps, "searches": 0}, "探索度：步数 = 行动点总数，还没搜过")

	# 随机点强制变成战斗
	w.rules = w.rules.duplicate(true) as NodeRules
	w.rules.random_weights = {"battle": 1}
	w.events.rules = w.rules
	var node := _node(w, &"random")
	var depth: float = EnemyPlacer.depths_of(w.graph)[node.id]
	w.travel.step_to(node.id)
	var view := MapNode.from_dict(node.to_dict())
	view.type = &"battle"
	var steps_then := w.travel.clock.total
	var plain := EnemyPlacer.wanted_strength(w.pool, view, depth, w.chapter.difficulty, &"")
	var explored := EnemyPlacer.wanted_strength(w.pool, view, depth, w.chapter.difficulty, &"", {"steps": steps_then, "searches": 0})
	t.eq(int(node.content["strength"]), explored, "随机点的敌人档位 = 规则 + 探索度")
	t.check(explored >= plain, "不低于不算探索度的档位")
	t.check(explored > plain or plain >= w.pool.strengths()[w.pool.strengths().size() - 1],
		"步数够了就更高（%d → %d），除非本来就到顶了" % [plain, explored])

	# 搜索遭遇：曲线拉满，第一次就遭遇；遭遇的敌人按「含这一次」的搜索次数算
	w.rules.search.encounter_curve = [1.0] as Array[float]
	var met: Array = []
	w.events.search_opened.connect(func(_n: MapNode, s: SearchSession):
		s.searched.connect(func(_f: Array[StringName], e: Dictionary): met.append(e)))
	w.travel.step_to(0)
	var snode := _node(w, &"search")
	w.travel.step_to(snode.id)
	var steps_search := w.travel.clock.total
	w.events.current_search.search()
	t.eq(met.size(), 1, "遭遇了")
	if met.is_empty():
		return
	var sview := MapNode.from_dict(snode.to_dict())
	sview.type = &"search"
	var sdepth: float = EnemyPlacer.depths_of(w.graph)[snode.id]
	t.eq(int(met[0]["strength"]),
		EnemyPlacer.wanted_strength(w.pool, sview, sdepth, w.chapter.difficulty, &"", {"steps": steps_search, "searches": 1}),
		"遭遇的敌人档位 = 规则 + 探索度（这是第 1 次搜索）")
	t.eq(w.events.searches_total(), 1, "会话结束后累计搜索次数记下来了")

	# 地图上看得见的敌人不随探索变：生成时定好的档位 = 不带探索度的规则值
	var battle := _node(w, &"battle")
	var bdepth: float = EnemyPlacer.depths_of(w.graph)[battle.id]
	t.eq(int(battle.content["strength"]), EnemyPlacer.wanted_strength(w.pool, battle, bdepth, w.chapter.difficulty, &""),
		"生成时放好的敌人不吃探索度 —— 地图上看到的就是打到的")


static func _search_view(node: MapNode) -> MapNode:
	var v := MapNode.from_dict(node.to_dict())
	v.type = &"search"
	return v


static func run_without_content(t: TestCase) -> void:
	t.begin("节点事件 · 没有敌人池 / 没有玩家：战斗点只是走过")

	var w := _world(990)
	w.events.hooks.register(&"player_spec", Callable())     # 101 第 3 刀：接上一个无效的 Callable = 这一条没人接
	var fights: Array = []
	w.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, _w: bool): fights.append(1))
	var node := _node(w, &"battle")
	w.travel.step_to(node.id)
	t.eq(fights.size(), 0, "没有玩家：不打")
	t.check(node.is_visited(), "但点用过了")

	var w2 := _world(995)
	var n2 := _node(w2, &"elite")
	n2.content = {}
	var f2: Array = []
	w2.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, _w: bool): f2.append(1))
	w2.travel.step_to(n2.id)
	t.eq(f2.size(), 0, "点里没敌人：不打")
	t.check(n2.is_visited(), "点用过了")
