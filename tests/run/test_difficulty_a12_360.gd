## 360 第四批 A12（作者难度表「守卫核心」；联动道具见报告 363、365、366）：绕得开的支路上一名精英当守卫，守卫活着首领带增援，打赢守卫撤掉、掉失效版
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


static func _twelve() -> DifficultyDef:
	for d in GameFlow.load_difficulties():
		if (d as DifficultyDef).id == &"ascension_12":
			return d
	return null


static func run_data(t: TestCase) -> void:
	t.begin("360 A12 · 数据：第 12 档、进阶十一撤离开、计分 1.9、精英额外一件传说、三件联动道具都配了增援")
	var d := _twelve()
	t.not_null(d, "进阶十二在")
	if d == null:
		return
	t.eq([d.level, d.requires_unlock, d.elite_rarity, d.intel_range], [12, &"ascension_12", 4, 2], "第 12 档、要解锁、精英额外传说、仍是 A11 的看得清两步")
	t.eq(ScoreRules.load_rules().mult(12), 1.9, "计分 1.9")
	var eleven: DifficultyDef = null
	for x in GameFlow.load_difficulties():
		if (x as DifficultyDef).level == 11:
			eleven = x
	t.check(eleven != null and eleven.grants_unlock == &"ascension_12", "A11 撤离一次解锁 A12")
	t.check(d.challenge.length() <= 10 and not d.description.is_empty(), "挑战一行、有说明")
	var digits := RegEx.create_from_string("[0-9]")
	t.check(digits.search(d.description) == null, "说明不写数字")
	var nr: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	var adv := MapNode.new()
	adv.content = {"search_tier": "advanced"}
	t.eq(SearchSession.floor_for(adv, nr.search if nr != null else null, d), [4, 3, 3] as Array[int], "进阶搜索下限 4 / 3 / 3")
	var c = NodeScreens._content()
	for link in [&"spare_mainspring", &"rally_horn", &"beast_king_pact"]:
		t.not_null(c.items.get_def(link), "有 %s" % link)
		t.not_null(c.items.get_def(StringName(String(link) + DifficultyMap.SPENT_SUFFIX)), "有 %s 的失效版" % link)
	for el in DifficultyMap.ELEMENTS:
		t.not_null(EnemyKit.reinforce_buff({"buff": "guard_pact_%s" % el}), "兽王之契：%s" % el)


## 一条入口 → 首领的主路，两名精英：一名在主路上（绕不开），一名在岔路上（绕得开）
static func _graph(elite_enemy: String) -> MapGraph:
	var g := MapGraph.new()
	var types := [&"junction", &"elite", &"core", &"elite", &"battle"]
	for i in types.size():
		var n := MapNode.new()
		n.id = i
		n.type = types[i]
		g.add_node(n)
	g.entry_ids = [0] as Array[int]
	g.connect_nodes(0, 1)
	g.connect_nodes(1, 2)
	g.connect_nodes(1, 3)
	g.connect_nodes(3, 4)
	g.get_node(1).content = {"enemy": elite_enemy, "items": []}
	g.get_node(2).content = {"enemy": "core_guardian", "items": []}
	g.get_node(3).content = {"enemy": elite_enemy, "items": []}
	return g


static func run_place_guard(t: TestCase) -> void:
	t.begin("360 A12 · 挑守卫：只挑绕得开的精英；按敌人池给联动道具，属性兽给兽王之契；没有就不设")
	var c = NodeScreens._content()
	var d := _twelve()
	if d == null:
		t.check(false, "进阶十二在")
		return
	var ruins := EnemyPool.new()
	ruins.id = &"standard_ruins"
	var g := _graph("brute")
	t.check(not DifficultyMap.bypassable(g, 1, [2] as Array[int]), "主路上那名绕不开")
	t.check(DifficultyMap.bypassable(g, 3, [2] as Array[int]), "岔路上那名绕得开")
	t.eq(DifficultyMap.place_guard(g, d, ruins, c.enemies, c.items, 1), 3, "挑岔路上那名")
	t.check(bool(g.get_node(3).content.get("guard", false)), "守卫写了 guard（名牌、边框读它）")
	t.eq(String(g.get_node(3).content.get(DifficultyMap.LINK_KEY, "")), "rally_horn", "标准废墟：求援号角")
	t.check(not g.get_node(1).content.has("guard"), "主路那名不是守卫")
	var core: Dictionary = g.get_node(2).content
	t.eq(String((core.get(EnemyKit.REINFORCE_KEY, {}) as Dictionary).get("buff", "")), "guard_horn", "首领带求援号角的增援")
	t.check(DifficultyMap.reinforced(g, core), "守卫活着：带着增援")
	var clock := EnemyPool.new()
	clock.id = &"clockwork"
	var g2 := _graph("brute")
	DifficultyMap.place_guard(g2, d, clock, c.enemies, c.items, 1)
	t.eq(String(g2.get_node(3).content.get(DifficultyMap.LINK_KEY, "")), "spare_mainspring", "机关池：备用发条")
	var g3 := _graph("flame_wolf")
	DifficultyMap.place_guard(g3, d, ruins, c.enemies, c.items, 1)
	t.eq(String(g3.get_node(3).content.get(DifficultyMap.LINK_KEY, "")), "beast_king_pact", "属性兽当守卫：兽王之契")
	t.eq(String((g3.get_node(2).content.get(EnemyKit.REINFORCE_KEY, {}) as Dictionary).get("buff", "")), "guard_pact_fire", "焰狼：火")
	var g4 := _graph("brute")
	g4.get_node(3).type = &"battle"
	t.eq(DifficultyMap.place_guard(g4, d, ruins, c.enemies, c.items, 1), -1, "只有主路上的精英：不设守卫")
	t.check(not g4.get_node(2).content.has(EnemyKit.REINFORCE_KEY), "首领不带增援")
	t.eq(DifficultyMap.guard_down(g, 3), 1, "打赢守卫：撤掉一个首领的增援")
	t.check(not DifficultyMap.reinforced(g, core) and not core.has(EnemyKit.REINFORCE_KEY), "首领不再带增援")
	t.eq(DifficultyMap.place_guard(_graph("brute"), null, ruins, c.enemies, c.items, 1), -1, "没有难度：不设")


## 两名同样的首领对打，右边那名带增援：看日志里增援真的生效了
static func _duel(c, buff: String) -> BattleResult:
	var pool: EnemyPool = load(ContentPaths.asset_file("enemy_pools", "standard_ruins"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var content: Dictionary = EnemyPlacer.build_content(c.enemies.enemy(&"core_guardian"), pool, c.items, 3, rng).get("content", {})
	var plain := EnemyKit.spec_of(content, c.enemies, pool, c.items)
	var boosted_content := content.duplicate(true)
	boosted_content[EnemyKit.REINFORCE_KEY] = {"guard": 9, "buff": buff, "link": ""}
	var boosted := EnemyKit.spec_of(boosted_content, c.enemies, pool, c.items)
	if plain == null or boosted == null:
		return null
	return BattleSim.run(plain, boosted, rng, 60.0)


static func _stacked(e: BattleEvent) -> bool:
	return e.name == BattleEvent.STATUS_APPLIED or (e.name == BattleEvent.STATUS_STACKED and e.get_int(&"delta") > 0)


static func run_reinforce_battle(t: TestCase) -> void:
	t.begin("360 A12 · 增援在战斗里：发条半血给一次限时护盾，号角半血回一截血，兽王之契开场给对手上属性")
	var c = NodeScreens._content()
	var pool: EnemyPool = load(ContentPaths.asset_file("enemy_pools", "standard_ruins"))
	var base := EnemyKit.spec_of({"enemy": "core_guardian", "strength": 3}, c.enemies, pool, c.items)
	var with := EnemyKit.spec_of({"enemy": "core_guardian", "strength": 3, EnemyKit.REINFORCE_KEY: {"buff": "guard_horn"}}, c.enemies, pool, c.items)
	t.check(base != null and with != null and with.set_rules.size() == base.set_rules.size() + 1, "带增援：多一条单位级规则")
	var spring := _duel(c, "guard_mainspring")
	var aegis := 0
	for e in spring.log if spring != null else []:
		if _stacked(e) and e.side == 1 and String(e.payload.get("buff", "")) == "guard_aegis":
			aegis += 1
	t.eq(aegis, 1, "发条：只给一次护盾")
	var horn := _duel(c, "guard_horn")
	var heals := 0
	for e in horn.log if horn != null else []:
		if e.name == BattleEvent.RESOURCE_CHANGED and e.side == 1 and e.get_name(&"key") == BattleStats.RES_HP and e.get_int(&"delta") >= StatMath.from_float(108.0):     # 402：号角回血 60 → 108
			heals += 1
	t.eq(heals, 1, "号角：回一次血")
	var pact := _duel(c, "guard_pact_fire")
	var scorched := false
	for e in pact.log if pact != null else []:
		if _stacked(e) and e.side == 0 and String(e.payload.get("buff", "")) == "scorch":
			scorched = true
			break
	t.check(scorched, "兽王之契（火）：对手开场身上有灼烧")


static func run_in_run(t: TestCase) -> void:
	t.begin("360 A12 · 一局里：守卫在绕得开的支路上、首领带增援、浮窗说清楚；打赢守卫撤增援、掉失效版；普通难度没有守卫")
	var c = NodeScreens._content()
	var d := _twelve()
	if d == null:
		t.check(false, "进阶十二在")
		return
	var run: RunState = null
	var guard := -1
	for s in range(1, 30):
		run = RunState.start(c.chapter, s, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], d)
		guard = -1
		for id in run.map.node_ids():
			if bool(run.map.get_node(id).content.get("guard", false)):
				guard = id
		if guard >= 0:
			break
	t.check(guard >= 0, "有一局挑出了守卫")
	if guard < 0:
		return
	var cores: Array[int] = []
	for id in run.map.node_ids():
		if run.map.get_node(id).type == &"core":
			cores.append(id)
	t.eq(run.map.get_node(guard).type, &"elite", "守卫是精英")
	t.check(DifficultyMap.bypassable(run.map, guard, cores), "绕得开")
	var core := run.map.get_node(cores[0])
	t.check(DifficultyMap.reinforced(run.map, core.content), "首领带着增援")
	var gtip := NodeTooltip.text_for(run, run.chapter, run.map.get_node(guard))
	var link: ItemDef = c.items.get_def(StringName(String(run.map.get_node(guard).content[DifficultyMap.LINK_KEY])))
	t.check(gtip.contains(Names.of(link)), "守卫的浮窗写它带着什么（%s）" % gtip)
	t.check(NodeTooltip.text_for(run, run.chapter, core).contains(Names.of(link)), "首领的浮窗写带着增援")
	var rolled := {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
	run.events._guard_won(run.map.get_node(guard), run.map.get_node(guard).content, rolled)
	t.eq(rolled["treasure"], [StringName(String(link.id) + DifficultyMap.SPENT_SUFFIX)] as Array[StringName], "打赢守卫：掉失效版")
	t.check(not core.content.has(EnemyKit.REINFORCE_KEY), "首领的增援撤了")
	t.check(not NodeTooltip.text_for(run, run.chapter, core).contains(Names.of(link)), "首领的浮窗不再写增援")
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), run.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and bool(back.map.get_node(guard).content.get("guard", false)), "守卫跟着存档走")
	var plain := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var any := false
	for id in plain.map.node_ids():
		any = any or plain.map.get_node(id).content.has("guard") or plain.map.get_node(id).content.has(EnemyKit.REINFORCE_KEY)
	t.check(not any, "普通难度：没有守卫")


static func run_map_marks(t: TestCase) -> void:
	t.begin("360 A12 · 地图（作者 11-22 选 B 小旗）：守卫和首领各插一面同图案的旗、中间一条红虚线；守卫倒下都撤掉")
	var c = NodeScreens._content()
	var d := _twelve()
	if d == null:
		t.check(false, "进阶十二在")
		return
	for link in MapView.GUARD_FLAGS:
		t.not_null(UiTheme.art_cached(MapView.guard_flag_art(String(link))), "%s 有旗子图" % link)
	var ruins := EnemyPool.new()
	ruins.id = &"standard_ruins"
	var g := _graph("brute")
	DifficultyMap.place_guard(g, d, ruins, c.enemies, c.items, 1)
	var view := MapView.new()
	view.graph = g
	t.eq(view.guard_pairs(), [[3, 2, "rally_horn"]], "一对：守卫 3、首领 2、号角")
	DifficultyMap.guard_down(g, 3)
	t.eq(view.guard_pairs(), [], "守卫倒下：旗和虚线都没了")
	view.free()


static func run_flag_zoom(t: TestCase) -> void:
	t.begin("复测 v8.05 · 地图缩到最小：守卫小旗跟着缩，不压旁边的点；开局视图正常大小")
	var c = NodeScreens._content()
	var d := _twelve()
	if d == null:
		t.check(false, "进阶十二在")
		return
	var run := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], d)
	var view := MapView.new()
	view.size = Vector2(1280, 720)
	view.graph = run.map
	t.check(view.shortest_edge() > 0.0 and not view.guard_pairs().is_empty(), "图上有守卫")
	view.zoom = MapView.START_GAP / maxf(1.0, view.shortest_edge())
	t.eq(view.guard_flag_scale(), 1.0, "点隔得够开：原大")
	view.zoom = MapView.ZOOM_MIN
	var k := view.guard_flag_scale()
	t.check(k < 1.0 and k >= MapView.FLAG_SCALE_MIN, "缩到最小：旗子跟着缩（%.2f）" % k)
	view.free()
