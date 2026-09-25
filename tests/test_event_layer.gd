## 事件层（059 第 4 项，报告 063）：事件走管线；生成时定进节点、可覆盖；踩上去先停下等选；选项的条件与后果是构件；
## 搜索点的「要不要搜」是事件；接着放下一个事件；等着选的跟着存档；流程与导演。
## **没有事件定义 = 老路**（现有套件一条不改）。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const SAVE := "user://test_event_run.json"
const META := "user://test_event_meta.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var loadouts: Array[LoadoutDef]
	var buffs: Dictionary
	var events: Dictionary
	var rules: NodeRules


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.loadouts = GameFlow.load_loadouts()
	c.buffs = GameFlow.load_run_buffs()
	c.events = GameFlow.load_events()
	c.rules = load(ContentPaths.asset_file("node_rules", String(c.chapter.node_rules)))
	return c


static func _kit(c: Content) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == &"standard":
			return l
	return c.loadouts[0]


## 带事件层的一局
static func _start(c: Content, seed: int) -> RunState:
	var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, _kit(c).items, c.buffs, [] as Array[StringName])
	if s != null:
		s.player_baseline = CombatantBaseline.with_hp(10000.0)
		s.event_defs = c.events.duplicate()
	return s


static func _flow(c: Content) -> GameFlow:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.buff_defs = c.buffs
	f.event_defs = c.events
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.loadouts = c.loadouts
	f.save_path = SAVE
	f.meta_path = META
	f.player_baseline = CombatantBaseline.with_hp(10000.0)
	return f


## 出生点旁边就有某类型点的种子
static func _seed_with(c: Content, type: StringName) -> Dictionary:
	for seed in range(1, 80):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, _kit(c).items)
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == type:
					return {"seed": seed, "entry": entry, "next": nid}
	return {}


## 造一个只给测试用的事件：options 的每项是 [标签, 后果数组, 条件数组]
static func _event(id: StringName, options: Array) -> EventDef:
	var def := EventDef.new()
	def.id = id
	def.title = String(id)
	for o in options:
		var opt := EventOption.new()
		opt.label = String(o[0])
		if o.size() > 1:
			opt.outcomes = o[1]
		if o.size() > 2:
			opt.requires = o[2]
		def.options.append(opt)
	return def


## 一套测试用的事件定义（互相引用，所以一起注入）
static func _custom_defs() -> Dictionary:
	var give := GiveItem.new()
	give.item = &"medkit"
	give.count = 2
	var heal := RestoreVitality.new()
	heal.amount = 1
	var mark := GrantMapBuff.new()
	mark.buff = &"marked"
	var unmark := RemoveMapBuff.new()
	unmark.buff = &"marked"
	var need_mark := HasBuffTag.new()
	need_mark.tag = &"marked"
	var rich := CanAfford.new()
	rich.amount = 999999
	var pay := ChangeMoney.new()
	pay.amount = -10
	var afford := CanAfford.new()
	afford.amount = 10
	var chain := NextEvent.new()
	chain.event = &"t_give"
	var fight := StartBattle.new()
	return {
		&"t_give": _event(&"t_give", [["拿", [give, heal] as Array[EventOutcome]]]),
		&"t_mark": _event(&"t_mark", [["记住我", [mark] as Array[EventOutcome]]]),
		&"t_locked": _event(&"t_locked", [
			["认出", [unmark] as Array[EventOutcome], [need_mark] as Array[EventCondition]],
			["太贵", [] as Array[EventOutcome], [rich] as Array[EventCondition]],
			["付 10", [pay] as Array[EventOutcome], [afford] as Array[EventCondition]]]),
		&"t_chain": _event(&"t_chain", [["接着", [chain] as Array[EventOutcome]]]),
		&"t_fight": _event(&"t_fight", [["上", [fight] as Array[EventOutcome]]]),
	}


## 开一局、站到出生点、把某个测试事件放到旁边那个点上
static func _start_with_custom(c: Content, found: Dictionary, eid: StringName) -> RunState:
	var s := _start(c, int(found["seed"]))
	s.pick_spawn(int(found["entry"]))
	for id in _custom_defs():
		s.event_defs[id] = _custom_defs()[id]
	s.map.get_node(int(found["next"])).content["event"] = String(eid)
	return s


static func run_pipeline(t: TestCase) -> void:
	t.begin("事件 · 走管线：往返、校验、作者文件、资产、节点规则引用得到")

	var def := EventDef.new()
	def.id = &"t_ev"
	def.title = "测试"
	def.text = "两行\n文字"
	var opt := EventOption.new()
	opt.label = "拿"
	var cond := CanAfford.new()
	cond.amount = 5
	opt.requires = [cond] as Array[EventCondition]
	var give := GiveItem.new()
	give.item = &"pistol"
	var say := Say.new()
	say.text = "好"
	opt.outcomes = [give, say] as Array[EventOutcome]
	var opt2 := EventOption.new()
	opt2.label = "走"
	def.options = [opt, opt2] as Array[EventOption]
	var text := ContentExporter.to_json(ContentExporter.export_event(def))
	var report := ImportReport.new()
	var back := ContentImporter.import_event(JSON.parse_string(text), ContentImporter.Context.new(), report)
	t.check(report.ok(), "导得回来：%s" % report.to_text())
	t.eq(back.options.size(), 2, "两个选项")
	t.check(back.options[0].requires.size() == 1 and back.options[0].requires[0] is CanAfford, "条件按注册表造回来了")
	t.check(back.options[0].outcomes.size() == 2 and back.options[0].outcomes[0] is GiveItem and back.options[0].outcomes[1] is Say, "后果按注册表造回来了")
	t.eq((back.options[0].outcomes[0] as GiveItem).item, &"pistol", "字段原样")
	t.eq(ContentExporter.to_json(ContentExporter.export_event(back)), text, "再导出逐字节相同")

	var c := _content()
	var ctx := ContentImporter.Context.new()
	for id in c.items.ids():
		ctx.register_item(c.items.get_def(id))
	for id in c.buffs:
		ctx.register_run_buff(c.buffs[id])
	var bad := ImportReport.new()
	ContentImporter.import_event({"id": "x", "options": []}, ctx, bad)
	t.check(not bad.ok(), "没有选项不行")
	bad = ImportReport.new()
	ContentImporter.import_event({"id": "x", "options": [{"label": "付", "requires": [{"type": "can_afford", "amount": 5}]}, {"label": "认", "requires": [{"type": "has_buff_tag", "tag": "marked"}]}]}, ctx, bad)
	t.check(not bad.ok(), "所有选项都带条件不行（作者：至少一个无条件选项，否则玩家会被困在这一屏）")
	bad = ImportReport.new()
	ContentImporter.import_event({"id": "x", "options": [{"label": "付", "requires": [{"type": "can_afford", "amount": 5}]}, {"label": "走"}]}, ctx, bad)
	t.check(bad.ok(), "有一个无条件的就行")
	bad = ImportReport.new()
	ContentImporter.import_event({"id": "x", "options": [{"label": "拿", "outcomes": [{"type": "give_item", "item": "no_such"}]}]}, ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("no_such"), "给不存在的道具不行")
	bad = ImportReport.new()
	ContentImporter.import_event({"id": "x", "options": [{"label": "拿", "outcomes": [{"type": "grant_map_buff", "buff": "hardy"}]}]}, ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("局外"), "给局外 buff 不行")
	bad = ImportReport.new()
	ContentImporter.import_event({"id": "x", "options": [{"label": ""}]}, ctx, bad)
	t.check(not bad.ok(), "选项没字不行")

	var dir: String = ContentPaths.KINDS["events"][0]
	var d := DirAccess.open(dir)
	t.not_null(d, "有 %s" % dir)
	var files := 0
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			files += 1
			var raw := FileAccess.get_file_as_string(dir + "/" + f)
			var rep := ImportReport.new()
			var res := ContentImporter.import_event(JSON.parse_string(raw), ctx, rep)
			t.check(rep.ok(), "%s 导得进：%s" % [f, rep.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_event(res)), raw, "%s 是往返不动点" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("events", f.get_basename())), "%s 的资产在" % f)
	t.check(files >= 5, "至少五个事件（实际 %d）" % files)
	t.eq(c.events.size(), files, "load_all 装回全部")
	t.check(c.events.has(&"search_default"), "搜索点的默认事件在")
	for type in c.rules.events_by_type:
		for eid in c.rules.events_by_type[type]:
			t.check(c.events.has(StringName(String(eid))), "节点规则里 '%s' 的事件 '%s' 存在" % [type, eid])
	var nr_bad := ImportReport.new()
	var nctx := ContentImporter.Context.new()
	for id in c.events:
		nctx.register_event(c.events[id])
	ContentImporter.import_node_rules({"id": "x", "events_by_type": {"search": {"no_such_event": 1}}}, nctx, nr_bad)
	t.check(not nr_bad.ok() and nr_bad.to_text().contains("no_such_event"), "节点规则引用不存在的事件不行")


static func run_placer(t: TestCase) -> void:
	t.begin("事件 · 生成时按类型定进节点、同种子同结果、已有的不覆盖、随机点揭开后再配")

	var c := _content()
	var s := _start(c, 3)
	var s2 := _start(c, 3)
	var searches := 0
	var events := 0
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		var eid := String(n.content.get("event", ""))
		match n.type:
			&"search":
				searches += 1
				t.eq(eid, "search_default", "搜索点 %d 配了搜索事件" % id)
			&"event":
				events += 1
				t.check((c.rules.events_by_type["event"] as Dictionary).has(eid), "事件点 %d 配的 '%s' 在表里" % [id, eid])
			_:
				# 别的类型：规则表里挂了就得是表里的（8-3 给休息 / 商店挂了默认事件），没挂就不配（转场）
				var table: Dictionary = c.rules.events_by_type.get(n.type, {})
				if table.is_empty():
					t.eq(eid, "", "%s 点 %d 没配事件（规则表没挂 → 转场）" % [n.type, id])
				else:
					t.check(table.has(eid), "%s 点 %d 配的 '%s' 在表里" % [n.type, id, eid])
		t.eq(eid, String(s2.map.get_node(id).content.get("event", "")), "点 %d 同种子同事件" % id)
	t.check(searches > 0 and events > 0, "图上有搜索点 %d 个、事件点 %d 个" % [searches, events])

	# 已有的不覆盖：手动改掉一个再铺一遍
	var some := -1
	for id in s.map.node_ids():
		if s.map.get_node(id).type == &"event":
			some = id
			break
	s.map.get_node(some).content["event"] = "event_rest_spot"
	EventPlacer.fill(s.map, c.rules)
	t.eq(String(s.map.get_node(some).content["event"]), "event_rest_spot", "替换过的不被铺回去（作者：可覆盖、可替换）")

	# 随机点：揭开成有表的类型才配事件
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if n.type != &"random":
			continue
		var type := s.events.reveal(n)
		var expect := EventPlacer.pick_for(n, type, c.rules)
		t.eq(String(n.content.get("event", "")), String(expect), "随机点 %d 揭成 %s 之后配的事件按那种类型抽" % [id, type])
		break


static func run_two_phase(t: TestCase) -> void:
	t.begin("事件 · 踩上去先停下等选；搜索点「搜 / 离开」；后果：给东西、体力、钱、标记、锁住的选项、接下一个、开战；等着选的跟着存档")

	var c := _content()
	var found := _seed_with(c, &"search")
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var next := int(found["next"])
	# 离开
	var s := _start(c, int(found["seed"]))
	s.pick_spawn(int(found["entry"]))
	var pend: Array = []
	s.events.event_pending.connect(func(n: MapNode, def: EventDef): pend.append([n.id, String(def.id)]))
	var resolved: Array = []
	s.events.event_resolved.connect(func(n: MapNode, outcome: StringName, detail: Dictionary): resolved.append([n.id, outcome, detail]))
	t.check(s.step_to(next), "走上搜索点")
	t.eq(pend, [[next, "search_default"]], "先发了 event_pending")
	t.check(s.events.pending_event() != null and s.events.pending_node().id == next, "等着选")
	t.check(not s.map.get_node(next).is_visited() and s.events.current_search == null, "还没搜、还没用过")
	t.check(bool(s.events.option_state(0)["ok"]) and bool(s.events.option_state(1)["ok"]), "两个选项都能选")
	t.check(not s.events.choose(5), "没有的选项选不了")
	t.check(s.events.choose(1), "离开")
	t.check(s.events.pending_event() == null, "不再等着")
	t.check(s.map.get_node(next).is_visited() and s.events.current_search == null, "离开：点用过了、没开会话")
	t.eq(resolved.size(), 1, "发了 event_resolved")
	t.check((resolved[0][2] as Dictionary).is_empty(), "什么都没发生：detail 空")
	t.check(not s.events.choose(0), "选过了再选不了")
	# 搜索
	var s2 := _start(c, int(found["seed"]))
	s2.pick_spawn(int(found["entry"]))
	s2.step_to(next)
	t.check(s2.events.choose(0), "搜索")
	t.check(s2.events.current_search != null and not s2.map.get_node(next).is_visited(), "开了会话、还没用过")
	s2.events.current_search.leave()
	t.check(s2.map.get_node(next).is_visited(), "走了用过了")

	# 自定义的事件，每个一局：给东西与体力
	var g := _start_with_custom(c, found, &"t_give")
	g.vitality.spend(1, &"test")
	var vit := g.vitality.current
	t.check(g.step_to(next), "走上放了 t_give 的点")
	t.eq(String(g.events.pending_event().id), "t_give", "等着选的是它")
	t.check(g.events.choose(0), "拿")
	var medkits := 0
	for inst in g.storage.items():
		if (inst as ItemInstance).def.id == &"medkit":
			medkits += 1
	t.eq(medkits, 2, "给了两个医疗包，进了暂存区")
	t.eq(g.vitality.current, vit + 1, "体力 +1")
	t.check(g.map.get_node(next).is_visited(), "点用过了")

	# 标记，与锁住的选项
	var m := _start_with_custom(c, found, &"t_mark")
	m.step_to(next)
	m.events.choose(0)
	t.check(m.has_buff_tag(&"marked"), "有标记了")
	var l := _start_with_custom(c, found, &"t_locked")
	l.step_to(next)
	t.check(not bool(l.events.option_state(0)["ok"]) and String(l.events.option_state(0)["why"]).contains("marked"), "没标记：「认出」锁住并说原因")
	t.check(not bool(l.events.option_state(1)["ok"]) and String(l.events.option_state(1)["why"]).contains("999999"), "太贵：锁住并说原因")
	t.check(not l.events.choose(0), "锁住的选不了")
	var can_pay := l.wallet.balance >= 10
	t.eq(bool(l.events.option_state(2)["ok"]), can_pay, "「付 10」按钱够不够")
	if can_pay:
		var before := l.wallet.balance
		t.check(l.events.choose(2), "付 10")
		t.eq(l.wallet.balance, before - 10, "钱少了 10")
	var l2 := _start_with_custom(c, found, &"t_locked")
	l2.grant_map_buff(&"marked")
	l2.step_to(next)
	t.check(bool(l2.events.option_state(0)["ok"]), "有标记：「认出」能选")
	t.check(l2.events.choose(0), "认出")
	t.check(not l2.has_buff_tag(&"marked"), "标记用掉了")

	# 接着放下一个
	var ch := _start_with_custom(c, found, &"t_chain")
	var pends: Array = []
	ch.events.event_pending.connect(func(_n: MapNode, def: EventDef): pends.append(String(def.id)))
	ch.step_to(next)
	ch.events.choose(0)
	t.eq(String(ch.events.pending_event().id), "t_give", "接着放下一个事件")
	t.eq(int(ch.events.pending["node"]), next, "还是这个点")
	t.eq(pends, ["t_chain", "t_give"], "两次 event_pending")
	t.check(not ch.map.get_node(next).is_visited(), "第二个没选完，点还没用过")
	ch.events.choose(0)
	t.check(ch.events.pending_event() == null and ch.map.get_node(next).is_visited(), "第二个也选完了，点用过了")

	# 开战
	var fi := _start_with_custom(c, found, &"t_fight")
	var fights: Array = []
	fi.events.battle_finished.connect(func(n: MapNode, _r: BattleResult, _w: bool): fights.append(n.id))
	fi.step_to(next)
	fi.events.choose(0)
	t.eq(fights, [next], "开战：打了一场")
	t.check(fi.map.get_node(next).is_visited(), "打完用过了")

	# 存档带着等着选的事件
	var s4 := _start(c, int(found["seed"]))
	s4.pick_spawn(int(found["entry"]))
	s4.step_to(next)
	t.check(s4.events.pending_event() != null, "等着选")
	var back := RunState.from_dict(s4.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	back.event_defs = c.events
	t.check(back.events.pending_event() != null and String(back.events.pending_event().id) == "search_default", "读回来还在等这个事件")
	t.eq(back.events.pending_node().id, next, "点也对")
	t.check(back.events.choose(1), "读回来能选")
	t.check(back.map.get_node(next).is_visited(), "选了离开，点用过了")


static func run_flow(t: TestCase) -> void:
	t.begin("场景流 · 事件屏：踩上去先到事件屏；选了没发生什么直接回地图；发生了先看结果页；「搜索」进容器屏；读档回来还在事件屏")

	var c := _content()
	var found := _seed_with(c, &"search")
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	var f := _flow(c)
	f.begin(c.chapter, _kit(c), int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	var next := int(found["next"])
	t.check(f.step_to(next), "走上搜索点")
	t.eq(f.screen, GameFlow.Screen.EVENT, "→ 事件屏")
	t.check(f.last_payload.get("def", null) is EventDef, "带着事件")
	t.check(not f.choose_event(9), "没有的选项选不了")
	t.check(f.choose_event(1), "离开")
	t.eq(f.screen, GameFlow.Screen.MAP, "什么都没发生：直接回地图")

	# 「搜索」进容器屏
	var f2 := _flow(c)
	f2.begin(c.chapter, _kit(c), int(found["seed"]))
	f2.pick_spawn(int(found["entry"]))
	f2.step_to(next)
	t.check(f2.choose_event(0), "搜索")
	t.eq(f2.screen, GameFlow.Screen.SEARCH, "→ 容器屏（搜索会话）")
	t.check(f2.last_payload.get("session", null) is SearchSession, "带着会话")
	f2.run.events.current_search.leave()
	var guard := 0
	while GameFlow.is_overlay(f2.screen) and guard < 10:
		guard += 1
		if f2.screen == GameFlow.Screen.LOOT:
			f2.take_all_loot()
		else:
			f2.resume()
	t.eq(f2.screen, GameFlow.Screen.MAP, "离开后回地图")

	# 发生了什么：先看结果页
	var f3 := _flow(c)
	var run3 := f3.begin(c.chapter, _kit(c), int(found["seed"]))
	f3.pick_spawn(int(found["entry"]))
	var heal := RestoreVitality.new()
	heal.amount = 1
	var say := Say.new()
	say.text = "歇了一会儿"
	run3.event_defs = c.events.duplicate()
	run3.event_defs[&"t_rest"] = _event(&"t_rest", [["歇", [heal, say] as Array[EventOutcome]]])
	run3.map.get_node(next).content["event"] = "t_rest"
	run3.vitality.spend(1, &"test")
	f3.step_to(next)
	t.eq(f3.screen, GameFlow.Screen.EVENT, "→ 事件屏")
	t.check(f3.choose_event(0), "歇")
	t.eq(f3.screen, GameFlow.Screen.EVENT, "→ 结果页")
	var detail: Dictionary = f3.last_payload.get("detail", {})
	t.check(int(detail.get("restored", 0)) == 1 and (detail.get("log", []) as Array).size() == 1, "结果页带着回了 1 点体力和那句话")
	f3.resume()
	t.eq(f3.screen, GameFlow.Screen.MAP, "继续 → 地图")

	# 读档回来还在事件屏
	var f4 := _flow(c)
	f4.begin(c.chapter, _kit(c), int(found["seed"]))
	f4.pick_spawn(int(found["entry"]))
	f4.step_to(next)
	t.check(f4.save(), "在事件屏上存档")
	f4.to_main_menu()
	t.check(f4.continue_run(), "继续")
	t.eq(f4.screen, GameFlow.Screen.EVENT, "读档回来还在事件屏")
	t.check(f4.last_payload.get("def", null) is EventDef and String((f4.last_payload["def"] as EventDef).id) == "search_default", "还是那个事件")
	t.check(f4.choose_event(1), "选得了")
	t.eq(f4.screen, GameFlow.Screen.MAP, "→ 地图")
	RunSave.remove(SAVE)
	MetaSave.remove(META)


static func frame_director(t: TestCase, root: Window) -> void:
	t.begin("导演 · 事件屏叠在地图上；「搜索」进容器屏；proceed 选第一个能选的")

	var c := _content()
	var found := _seed_with(c, &"search")
	if found.is_empty():
		t.check(false, "找不到种子")
		return
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	var game = load(GAME).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	root.add_child(game)
	var flow: GameFlow = game.flow
	t.check(not flow.event_defs.is_empty(), "导演装了事件定义")
	# 083：这些测试要的是第一章（环形图）；序章通关才列它 —— 先把章节许诺的解锁都给上，再挑第一章
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"chapter_01":
			setup.choose_chapter(gi)
	# 067：开局屏按角色开；把第一套（发进仓库的）全带上，和从前按 standard 开差不多
	for inst in flow.meta.warehouse.items().duplicate():
		setup.carry_in((inst as ItemInstance).uid)
	setup.set_run_seed(int(found["seed"]))
	t.check(setup.depart(), "出发")
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	t.check(map.step(int(found["next"])), "走上搜索点")
	t.check(game.overlay() != null and game.overlay().screen == GameFlow.Screen.EVENT and game.overlay().is_options_page(), "事件屏叠上来了（选项页）")
	t.eq(game.base(), map, "地图还在底下")
	game.overlay().proceed()
	t.check(game.overlay() != null and game.overlay().screen == GameFlow.Screen.SEARCH and game.overlay().is_search(), "proceed 选了「搜索」→ 容器屏（搜索会话）")
	game.overlay().leave()
	var guard := 0
	while game.overlay() != null and guard < 10:
		guard += 1
		var ov = game.overlay()
		match ov.screen:
			GameFlow.Screen.LOOT:
				ov.take_all()
			_:
				ov.proceed()
	t.is_null(game.overlay(), "看完了回地图")
	flow.to_main_menu()
	game.queue_free()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
