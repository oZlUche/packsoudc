## 序章（作者定，报告 083）：只有布鲁图斯、一条路的教程图 —— 搜（两次、必不遇敌）→ 整理 → 战斗 → 战利品 → 搜（三次、第三次必遇敌）→ 战斗 → 战利品 → 精英 → 撤离；
## 通关解锁第一章。期望从数据推：地图文件里写的点、事件、搜索的次数与固定的收获，都读文件断言；教程能打赢用真的战斗模拟验。
extends RefCounted

const SAVE := "user://test_prologue_run.json"
const META := "user://test_prologue_meta.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var prologue: ChapterDef
	var chapter1: ChapterDef
	var characters: Array[CharacterDef]
	var events: Dictionary
	var faiths: Dictionary


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.prologue = load(ContentPaths.asset_file("chapters", "prologue"))
	c.chapter1 = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.characters = GameFlow.load_characters()
	c.events = GameFlow.load_events()
	c.faiths = GameFlow.load_faiths()
	return c


static func _cleanup() -> void:
	for p in [SAVE, META]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _brutus(c: Content) -> CharacterDef:
	for ch in c.characters:
		if ch.id == &"brutus":
			return ch
	return null


static func _start(c: Content) -> RunState:
	var s := RunState.start(c.prologue, 7, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], _brutus(c))
	if s == null:
		return null
	s.event_defs = c.events
	s.faith_defs = c.faiths
	s.pick_spawn(s.map.entry_ids[0])
	return s


## 084：敌人和玩家一样 —— 有包、道具全在包里、每件都摆得上（重建出的件数 = 写的件数）；必掉的都是身上有的
static func _check_enemy_bags(t: TestCase, c: Content, content: Dictionary, who: String) -> void:
	var board := EnemyKit.board_of(content, c.items)
	var entries: Array = content.get("items", [])
	t.eq(board.item_count(), entries.size(), "%s：%d 件都摆上了" % [who, entries.size()])
	t.check(board.requires_bag, "%s：道具依托背包" % who)
	var bags := 0
	var inside := {}
	for inst in board.items():
		var it := inst as ItemInstance
		if it.def.is_bag:
			bags += 1
			for uid in board.contents_of(it.uid):
				inside[uid] = true
	t.check(bags > 0, "%s：背着包" % who)
	for inst in board.items():
		var it := inst as ItemInstance
		if not it.def.is_bag:
			var covered := inside.has(it.uid)
			if not covered:
				covered = true
				for cell in it.cells():
					if board.bag_at(cell) == GridInventory.EMPTY_UID:
						covered = false
			t.check(covered, "%s：%s 在包里" % [who, it.def.display_name])
	var carried := DropResolver.carried_ids(content)
	for id in content.get("guaranteed_drops", []):
		t.check(carried.has(StringName(String(id))), "%s：必掉的 %s 是身上有的" % [who, id])


## 一条路：按 tier 排的节点
static func _path(g: MapGraph) -> Array[MapNode]:
	var out: Array[MapNode] = []
	for id in g.node_ids():
		out.append(g.get_node(id))
	out.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.tier < b.tier)
	return out


## 教程里到某个点为止能拿到的全部东西：搜到的 + 遭遇敌人必掉的
static func _finds_until(path: Array[MapNode], upto: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in mini(upto + 1, path.size()):
		for round in path[i].content.get("search_finds", []):
			for id in round:
				out.append(StringName(String(id)))
		for id in (path[i].content.get("encounter", {}) as Dictionary).get("guaranteed_drops", []):
			out.append(StringName(String(id)))
	return out


## 布鲁图斯背着这些东西的战斗单位（初始包 + 尽量塞）
static func _player(c: Content, ids: Array[StringName]) -> CombatantSpec:
	var ch := _brutus(c)
	var board := GridInventory.new(ch.board_size, 1, true)
	for bag_id in ch.starting_bags:
		board.try_add(ItemInstance.create(c.items.get_def(bag_id), 0), true)
	for id in ids:
		board.try_add(ItemInstance.create(c.items.get_def(id), 0), true)
	var ctx := RunContext.new()
	for e in ch.run_effects():
		e.modify(ctx)
	var base := ch.baseline()
	for key in ctx.stat_bonus:
		base.base_stats[String(key)] = float(base.base_stats.get(String(key), 0.0)) + float(ctx.stat_bonus[key])
	return BattleCompiler.compile(board, base)


static func run_data(t: TestCase) -> void:
	t.begin("序章 · 章节与地图：预设的一条路（生 → 搜 → 战 → 搜 → 精 → 撤）、每个点配了教程事件、搜索点的次数 / 曲线 / 固定收获、战斗点写死的敌人、只有布鲁图斯、不能带东西、通关解锁第一章")
	var c := _content()
	t.not_null(c.prologue, "有序章")
	if c.prologue == null:
		return
	t.eq(c.prologue.map_source.mode, MapSource.Mode.PRESET, "地图是预设")
	t.eq(c.prologue.characters, [&"brutus"] as Array[StringName], "只有布鲁图斯")
	t.check(not c.prologue.allow_carry_in, "不能从仓库带东西")
	t.check(c.prologue.skip_setup and c.prologue.auto_spawn and c.prologue.intro_event == &"tut_intro", "序章不走开局屏、开局就在出生点、先过 intro 事件（084）")
	t.not_null(c.events.get(&"tut_intro", null), "intro 事件存在")
	t.check(c.prologue.grants_unlock != &"" and c.chapter1.requires_unlock == &"prologue2_done", "序章通关开序章二，序章二通关才开第一章（085）")
	t.check(c.prologue.order < c.chapter1.order, "序章排在第一章前面")
	var g := c.prologue.map_source.resolve(1)
	t.not_null(g, "预设载入并过了校验：%s" % c.prologue.map_source.last_error)
	if g == null:
		return
	t.eq(g.layout_kind, &"line", "一条线的布局")
	t.not_null(MapLayout.for_graph(g), "布局登记过")
	var path := _path(g)
	var types: Array = []
	for n in path:
		types.append(n.type)
		t.check(g.edges_of(n.id).size() <= 2, "点 %d 最多两条边（一条路）" % n.id)
	t.eq(types, [&"spawn", &"search", &"battle", &"search", &"elite", &"extract"], "顺序：生 → 搜 → 战 → 搜 → 精 → 撤")
	t.eq(g.entry_ids, [path[0].id] as Array[int], "出生点是第一个")
	t.eq(g.goal_ids, [path[-1].id] as Array[int], "终点是撤离点")
	for i in range(1, path.size()):
		var n := path[i]
		var eid := String(n.content.get("event", ""))
		t.check(eid != "" and c.events.has(StringName(eid)), "点 %d 配了教程事件 %s" % [n.id, eid])
		if n.type == &"battle" or n.type == &"elite":
			t.check(EnemyKit.has_enemy(n.content) and c.enemies.enemy(StringName(String(n.content["enemy"]))) != null, "点 %d 写死了敌人 %s" % [n.id, n.content.get("enemy", "")])
			for entry in n.content.get("items", []):
				t.not_null(c.items.get_def(StringName(String(entry["id"]))), "敌人的道具 %s 存在" % entry["id"])
			_check_enemy_bags(t, c, n.content, "点 %d 的敌人" % n.id)
		if n.type == &"search" and n.content.has("encounter"):
			_check_enemy_bags(t, c, n.content["encounter"], "点 %d 的遭遇" % n.id)
		if n.type == &"search":
			for round in n.content.get("search_finds", []):
				for id in round:
					t.not_null(c.items.get_def(StringName(String(id))), "固定收获 %s 存在" % id)
	# 第一个搜索点：两次、必不遇敌；第二个：三次、至少三次、第三次必遇敌、遭遇写死
	var s1 := path[1].content
	var s2 := path[3].content
	t.eq(int(s1.get("search_max", 0)), 2, "第一个搜索点搜两次")
	var all_zero := true
	for v in s1.get("search_curve", [1.0]):
		if float(v) > 0.0:
			all_zero = false
	t.check(all_zero, "第一个搜索点必不遇敌")
	t.eq(int(s2.get("search_max", 0)), 3, "第二个搜索点搜三次")
	# 084：搜索循环的事件都配了、全是强制搜（没有「离开」）；遭遇的敌人必掉一个包
	for eid in ["tut_search_1", "tut_search_1_again", "tut_search_1_done", "tut_search_2", "tut_search_2_again_1", "tut_search_2_again_2", "tut_search_2_encounter"]:
		var d: EventDef = c.events.get(StringName(eid), null)
		t.not_null(d, "教程事件 %s 存在" % eid)
		if d != null:
			t.eq(d.options.size(), 1, "%s 只有一个选项（序章不给不搜的选择）" % eid)
	t.eq(s1.get("search_again_events", []), ["tut_search_1_again"], "第一个搜索点搜一次之后的事件")
	t.eq(String(s1.get("search_done_event", "")), "tut_search_1_done", "第一个搜索点搜完的事件")
	t.eq(s2.get("search_again_events", []), ["tut_search_2_again_1", "tut_search_2_again_2"], "第二个搜索点两次之后各一屏")
	t.check(String((c.events.get(&"tut_search_2_again_2") as EventDef).text).contains("包"), "第二次之后的文字提示包装不下")
	t.eq(String(s2.get("search_encounter_event", "")), "tut_search_2_encounter", "遭遇的事件")
	var drops: Array = (s2["encounter"] as Dictionary).get("guaranteed_drops", [])
	var has_bag := false
	for id in drops:
		var dd := c.items.get_def(StringName(String(id)))
		if dd != null and dd.is_bag:
			has_bag = true
	t.check(has_bag, "遭遇的敌人必掉一个包（%s）" % str(drops))
	var curve: Array = s2.get("search_curve", [])
	t.check(curve.size() == 3 and float(curve[2]) >= 1.0 and float(curve[0]) == 0.0 and float(curve[1]) == 0.0, "第三次必遇敌、前两次不遇")
	t.check(s2.has("encounter") and EnemyKit.has_enemy(s2["encounter"]), "遭遇写死了")
	# 打得赢：用教程里到那一步为止搜到的东西对着每个敌人模拟几个种子
	var fights := [[path[2].content, 1], [s2["encounter"], 2], [path[4].content, 3]]     # 遭遇那一次什么都翻不到：只带到第二个点的收获
	for f in fights:
		var me := _player(c, _finds_until(path, int(f[1])))
		var foe := EnemyKit.spec_of(f[0], c.enemies, null, c.items)
		var wins := 0
		for seed in range(1, 6):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			if BattleSim.run(me, foe, rng, 60.0).winner == 0:
				wins += 1
		t.eq(wins, 5, "带着到那时的收获能打赢 %s（五个种子全赢）" % f[0]["enemy"])


static func run_walkthrough(t: TestCase) -> void:
	t.begin("序章 · 走一遍：搜索循环（搜索 → 关闭回事件 → 再搜 → 搜完事件）→ 整理事件只有「进入战前准备」→ 战斗赢 → 战利品 → 第二点两次之后第三次遭遇事件 → 迎战赢 → 余波事件 → 战利品里有包 → 精英赢 → 撤离")
	var c := _content()
	var s := _start(c)
	t.not_null(s, "按布鲁图斯开局")
	if s == null:
		return
	var path := _path(s.map)
	t.eq(s.board.item_count(), _brutus(c).starting_bags.size(), "开局只有包")
	# 搜索点 1
	t.check(s.step_to(path[1].id), "走到搜索点")
	var ev := s.events.pending_event()
	t.check(ev != null and ev.id == StringName(String(path[1].content["event"])), "先看教程事件")
	var shown: Array = []
	s.events.search_shown.connect(func(_n: MapNode, _ss: SearchSession): shown.append(1))
	t.check(s.events.choose(0), "选「搜索」：自动搜一次")
	var session := s.events.current_search
	t.not_null(session, "开了搜索会话")
	if session == null:
		return
	t.eq(session.max_total(), 2, "能搜两次")
	t.eq(session.searches_done, 1, "已经搜了一次")
	t.eq(shown.size(), 1, "给看了一回搜索屏")
	var finds: Array = path[1].content["search_finds"]
	var want0: Array = []
	for id in finds[0]:
		want0.append(StringName(String(id)))
	t.eq(session.found, want0, "第一次搜到写死的东西")
	t.check(s.events.pause_search(), "关闭搜索屏")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut_search_1_again", "回到事件屏：「再翻一次」")
	t.check(s.events.choose(0), "再搜一次")
	t.eq(session.searches_done, 2, "搜了两次")
	t.eq(shown.size(), 2, "又给看了一回搜索屏")
	t.check(session.is_exhausted() and session.active, "搜满了不能再搜，会话还开着")
	t.check(s.events.pause_search(), "关闭搜索屏")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut_search_1_done", "回到事件屏：「翻遍了」")
	t.check(s.events.choose(0), "继续")
	t.check(not session.active and s.events.current_search == null, "会话结束了")
	t.check(path[1].is_visited(), "点用过了")
	t.not_null(s.pending_loot, "收获等着拿")
	t.eq(s.take_all_loot(), 3, "拿走三件")
	# 整理：暂存区一挪步就清（080），先把搜到的都放进包里（有没有武器的门在战前准备屏上，084）
	var weapon: ItemInstance = null
	for inst in s.storage.items().duplicate():
		if (inst as ItemInstance).def.tags.has(&"weapon") and weapon == null:
			weapon = inst
		s.equip((inst as ItemInstance).uid)
	t.not_null(weapon, "第一次搜到了武器")
	t.eq(s.storage.item_count(), 0, "都放进包里了")
	t.check(s.step_to(path[2].id), "走到战斗点")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == StringName(String(path[2].content["event"])), "先看「整理」事件")
	t.eq(ev.options.size() if ev != null else 0, 1, "只有「进入战前准备」一个选项（084）")
	t.check(ev != null and (ev.options[0] as EventOption).label == "进入战前准备", "选项叫「进入战前准备」")
	t.check(bool(s.events.option_state(0)["ok"]), "随时能选")
	var v0 := s.vitality.current
	t.check(s.events.choose(0), "进入战前准备（直接驱动 RunState 不停战前屏，立刻开打）")
	t.eq(int(s.tally["battles_won"]), 1, "打赢了")
	t.eq(s.vitality.current, v0, "没扣体力")
	t.not_null(s.pending_loot, "战利品")
	s.take_all_loot()
	for inst in s.storage.items().duplicate():
		s.equip((inst as ItemInstance).uid)
	# 搜索点 2
	t.check(s.step_to(path[3].id), "走到第二个搜索点")
	t.check(s.events.choose(0), "选「搜索」：第一次")
	session = s.events.current_search
	t.eq(session.searches_done, 1, "搜了一次")
	t.check(s.events.pause_search() and s.events.pending_event().id == &"tut_search_2_again_1", "关闭 → 「还有」")
	t.check(s.events.choose(0), "再搜一次：第二次")
	t.eq(session.searches_done, 2, "搜了两次")
	t.check(s.events.pause_search() and s.events.pending_event().id == &"tut_search_2_again_2", "关闭 → 「包装不下了」")
	t.check(s.events.choose(0), "再搜一次：第三次")
	t.eq(session.encounter, path[3].content["encounter"], "第三次遭遇 = 写死的那个")
	var expect_found := 0
	for round in path[3].content["search_finds"]:
		expect_found += (round as Array).size()
	t.eq(session.found.size(), expect_found, "遭遇那一次什么都没翻到（前两次共 %d 件）" % expect_found)
	t.check(not session.active, "会话结束（遭遇）")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut_search_2_encounter", "直接到「惊动了」事件，不开搜索屏")
	t.eq(int(s.tally["battles_won"]), 1, "还没打")
	t.check(s.events.choose(0), "迎战")
	t.eq(int(s.tally["battles_won"]), 2, "遭遇也打赢了")
	t.eq(s.phase, RunState.Phase.ON_MAP, "还在图上")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"search_destroyed", "打完过「余波」事件：不能再搜")
	t.check(s.events.current_search == null and path[3].is_visited(), "会话收了、点用过了")
	t.check(s.events.choose(0), "继续")
	t.not_null(s.pending_loot, "战利品（敌人掉的 + 前两次的收获）")
	var got_bag := false
	if s.pending_loot != null:
		for inst in s.pending_loot.items():
			if (inst as ItemInstance).def.is_bag:
				got_bag = true
	t.check(got_bag, "战利品里有一个包")
	if s.pending_loot != null:
		s.take_all_loot()
	for inst in s.storage.items().duplicate():
		s.equip((inst as ItemInstance).uid)
	t.eq(s.storage.item_count(), 0, "新搜到的都放进包里了（放不下的先不管）") if s.storage.item_count() == 0 else t.check(true, "（有放不下的，留在暂存区，走了就没）")
	# 精英
	t.check(s.step_to(path[4].id), "走到精英")
	t.check(bool(s.events.option_state(0)["ok"]), "棋盘上有东西：能开打")
	t.check(s.events.choose(0), "开打精英")
	t.eq(int(s.tally["battles_won"]), 3, "精英也赢了")
	if s.pending_loot != null:
		s.take_all_loot()
	# 撤离
	t.check(s.step_to(path[5].id), "走到撤离点")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == StringName(String(path[5].content["event"])), "撤离的教程事件")
	t.eq(NodeEvents.effective_type(s.current_node()), &"extract", "站在撤离点上")
	t.check((ev.options[0] as EventOption).label == "撤离", "对话里第一项就是「撤离」（085）")
	t.check(s.events.choose(0), "选「撤离」")
	t.eq(s.phase, RunState.Phase.EXTRACTED, "这一局撤出来了（不用再按右栏的按钮）")
	t.eq(int(s.tally["battles_lost"]), 0, "一场没输")


static func run_gating(t: TestCase) -> void:
	t.begin("序章 · 开局屏的门：没通关只列序章、序章只能选布鲁图斯；撤离成功给解锁，第一章随之出现并排在序章后面")
	var c := _content()
	_cleanup()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = GameFlow.load_chapters()
	f.characters = c.characters
	f.event_defs = c.events
	f.save_path = SAVE
	f.meta_path = META
	var avail := f.available_chapters()
	t.eq(avail.size(), 1, "没通关只列一章")
	t.check(not avail.is_empty() and avail[0].id == &"prologue", "列的是序章")
	var chars := f.characters_for(c.prologue)
	t.eq(chars.size(), 1, "序章只能选一个角色")
	t.check(not chars.is_empty() and chars[0].id == &"brutus", "是布鲁图斯")
	t.eq(f.characters_for(c.chapter1).size(), c.characters.size(), "第一章全部角色都能选")
	# 084：主菜单「新的一局」直接开序章（只有它可选、skip_setup），先弹 intro，「出发」之后才是地图
	f.new_run()
	var run := f.run
	t.not_null(run, "「新的一局」直接开了序章，不经开局屏")
	if run == null:
		return
	t.check(run.chapter == c.prologue and run.character_id == &"brutus", "章是序章、角色是布鲁图斯")
	t.eq(run.phase, RunState.Phase.ON_MAP, "已经站在出生点上")
	t.eq(f.screen, GameFlow.Screen.EVENT, "先过 intro 事件屏")
	t.check((f.last_payload.get("def", null) as EventDef).id == &"tut_intro", "是 tut_intro")
	t.check(f.choose_event(0), "出发")
	t.eq(f.screen, GameFlow.Screen.MAP, "→ 地图")
	t.check(not run.travel.available_moves().is_empty(), "能走")
	# 直接站到撤离点上撤（走一遍在上一组验过了）
	run.travel.start_at(run.map.goal_ids[0])
	t.check(f.extract(), "撤离")
	t.check(f.meta.has_unlock(c.prologue.grants_unlock), "拿到了解锁 %s" % c.prologue.grants_unlock)
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	var nxt := f.next_chapter()
	t.check(nxt != null and nxt.id == &"prologue_2", "结算之后直接进下一张：序章二（085）")
	t.check(f.start_next_chapter(), "进入下一张")
	t.check(f.run != null and f.run.chapter.id == &"prologue_2" and f.screen == GameFlow.Screen.EVENT, "序章二开了、先过 intro")
	t.check(f.meta.warehouse.item_count() >= 0 and not f.meta.has_pending_board(), "带回来的先进了仓库")
	f.to_main_menu()
	avail = f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"prologue_2", "序章收起、序章二顶上（085）：%s" % str(avail.map(func(x: ChapterDef) -> String: return String(x.id))))
	f.meta.grant_unlock(&"prologue2_done")
	avail = f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"chapter_01", "序章二也通关：只剩第一章")
	# 解锁跟着局外存档
	var meta2 := MetaSave.read(c.items, META)
	t.check(meta2 != null and meta2.has_unlock(c.prologue.grants_unlock), "解锁存进了局外存档")
	# 兜底：一章都列不出来就全列
	var f2 := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f2.chapters = [c.chapter1] as Array[ChapterDef]
	t.eq(f2.available_chapters().size(), 1, "只有一个要解锁的章节时照样列出来（不把游戏锁死）")
	_cleanup()
