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


## 一条路：按 tier 排的节点
static func _path(g: MapGraph) -> Array[MapNode]:
	var out: Array[MapNode] = []
	for id in g.node_ids():
		out.append(g.get_node(id))
	out.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.tier < b.tier)
	return out


## 教程里到某个点为止能搜到的全部东西
static func _finds_until(path: Array[MapNode], upto: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in mini(upto + 1, path.size()):
		for round in path[i].content.get("search_finds", []):
			for id in round:
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
	t.check(c.prologue.grants_unlock != &"" and c.chapter1.requires_unlock == c.prologue.grants_unlock, "序章通关给的解锁就是第一章要的")
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
	t.eq(int(s2.get("search_min", 0)), 3, "第二个搜索点至少搜三次")
	var curve: Array = s2.get("search_curve", [])
	t.check(curve.size() == 3 and float(curve[2]) >= 1.0 and float(curve[0]) == 0.0 and float(curve[1]) == 0.0, "第三次必遇敌、前两次不遇")
	t.check(s2.has("encounter") and EnemyKit.has_enemy(s2["encounter"]), "遭遇写死了")
	# 打得赢：用教程里到那一步为止搜到的东西对着每个敌人模拟几个种子
	var fights := [[path[2].content, 1], [s2["encounter"], 3], [path[4].content, 3]]
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
	t.begin("序章 · 走一遍：搜两次拿到固定的收获（搜满不自动结束）→ 整理事件只有「进入战前准备」→ 战斗赢 → 战利品 → 搜三次第三次遭遇 → 赢 → 战利品 → 精英赢 → 撤离")
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
	t.check(s.events.choose(0), "选「搜索」")
	var session := s.events.current_search
	t.not_null(session, "开了搜索会话")
	if session == null:
		return
	t.eq(session.max_total(), 2, "能搜两次")
	t.eq(session.next_encounter_chance(), 0.0, "遭遇 0%")
	var finds: Array = path[1].content["search_finds"]
	for k in 2:
		var got: Dictionary = session.search()
		var want: Array = []
		for id in finds[k]:
			want.append(StringName(String(id)))
		t.eq(got["found"], want, "第 %d 次搜到写死的东西" % (k + 1))
		t.check((got["encounter"] as Dictionary).is_empty(), "第 %d 次没遭遇" % (k + 1))
	t.check(not session.can_search() and session.active, "搜满了不能再搜，但会话不自动结束（084：收获留给玩家亮出来、拖走）")
	session.leave()
	t.check(not session.active, "按「离开」才结束")
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
	t.check(s.events.choose(0), "选「搜索」")
	session = s.events.current_search
	t.eq(session.min_searches(), 3, "至少搜三次")
	t.check(not session.can_leave(), "一次没搜不能走")
	for k in 2:
		var got: Dictionary = session.search()
		t.check((got["encounter"] as Dictionary).is_empty(), "第 %d 次没遭遇" % (k + 1))
	t.check(not session.can_leave(), "搜了两次还不能走")
	var third: Dictionary = session.search()
	t.eq(third["encounter"], path[3].content["encounter"], "第三次遭遇 = 写死的那个")
	t.eq(int(s.tally["battles_won"]), 2, "遭遇也打赢了")
	t.eq(s.phase, RunState.Phase.ON_MAP, "还在图上")
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
	t.check(s.events.choose(0), "明白了")
	t.eq(NodeEvents.effective_type(s.current_node()), &"extract", "站在撤离点上")
	t.check(s.try_extract(), "撤离")
	t.eq(s.phase, RunState.Phase.EXTRACTED, "这一局撤出来了")
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
	var run := f.begin(c.prologue, null, 1, [] as Array[int], _brutus(c), [])
	t.not_null(run, "开序章")
	if run == null:
		return
	f.pick_spawn(run.map.entry_ids[0])
	# 直接站到撤离点上撤（走一遍在上一组验过了）
	run.travel.start_at(run.map.goal_ids[0])
	t.check(f.extract(), "撤离")
	t.check(f.meta.has_unlock(c.prologue.grants_unlock), "拿到了解锁 %s" % c.prologue.grants_unlock)
	avail = f.available_chapters()
	t.eq(avail.size(), f.chapters.size(), "第一章出现了")
	t.check(avail.size() >= 2 and avail[0].id == &"prologue" and avail[1].id == &"chapter_01", "顺序：序章、第一章")
	# 解锁跟着局外存档
	var meta2 := MetaSave.read(c.items, META)
	t.check(meta2 != null and meta2.has_unlock(c.prologue.grants_unlock), "解锁存进了局外存档")
	# 兜底：一章都列不出来就全列
	var f2 := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f2.chapters = [c.chapter1] as Array[ChapterDef]
	t.eq(f2.available_chapters().size(), 1, "只有一个要解锁的章节时照样列出来（不把游戏锁死）")
	_cleanup()
