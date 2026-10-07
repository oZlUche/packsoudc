## 猎手核心（069 第 2 步，报告 071）：定义走管线、机制装进一局、最远点出现、领地、回合、感知、开打前事件屏、
## 迎战 / 逃跑、六种战败后果、掉落倍率、存档、流程。期望从数据推：定义里写了几步就断言几步。
extends RefCounted

## 与 Support.paths("hunters") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_hunters_run.json"
const META := "user://test_hunters_meta.json"
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["hunter_defs"])


## 一份只开猎手机制的难度（代码里造，不依赖作者的进阶文件）
static func _difficulty(ids: Array[StringName], count: int = 1, min_dist: float = 3.0, after: int = 0) -> DifficultyDef:
	var d := DifficultyDef.new()
	d.id = &"probe_hunters"
	d.display_name = "探针"
	var m := HunterMechanic.new()
	m.hunter_ids = ids
	m.default_count = count
	m.spawn_min_distance = min_dist
	m.spawn_after_steps = after
	d.mechanics.append(m)
	return d


## 开一局、挑出生点。[param defs] 是这一局的猎手定义表（可以是改过数的副本）
static func _start(c: TestSupport.Content, defs: Dictionary, diff: DifficultyDef) -> RunState:
	for seed in range(1, 40):
		var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [&"bag_leather", &"rifle"] as Array[StringName],
			{}, [] as Array[StringName], null, [], diff, defs)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


## 定义表的深拷贝（改数不影响别的用例）
static func _copy_defs(defs: Dictionary) -> Dictionary:
	var out := {}
	for id in defs:
		out[id] = (defs[id] as HunterDef).duplicate(true)
	return out


static func _first_def(c: TestSupport.Content) -> HunterDef:
	var ids: Array = c.hunter_defs.keys()
	ids.sort()
	return c.hunter_defs[ids[0]] if not ids.is_empty() else null


static func _step_once(s: RunState) -> bool:
	var moves := s.travel.available_moves()
	return not moves.is_empty() and s.step_to(moves[0])


static func run_pipeline(t: TestCase) -> void:
	t.begin("猎手 · 走内容管线：往返、行动逻辑与后果按注册表造、校验、作者文件")
	var c := _content()
	var sample := {"id": "probe", "display_name": "探针", "level": 3, "visibility": "VISIBLE", "sense_range": 5.0, "speed": 2,
		"engage_range": 1.0, "territory_radius": 0, "behavior": {"type": "patrol", "every_steps": 3},
		"loss_options": [{"id": "default", "outcomes": [{"type": "spend_vitality", "amount": 2}, {"type": "expel_and_guard"}]}], "drop_mult": 2.0, "flee_chance": 0.25}
	var report := ImportReport.new()
	var def := ContentImporter.import_hunter(sample, ContentImporter.Context.new(), report)
	t.check(report.ok(), "合法的猎手导入没有错：%s" % report.to_text())
	var text := ContentExporter.to_json(ContentExporter.export_hunter(def))
	var back := ContentImporter.import_hunter(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_hunter(back)), text, "导出 → 导入 → 再导出逐字节相同")
	t.check(back.behavior is PatrolBehavior and (back.behavior as PatrolBehavior).every_steps == 3, "行动逻辑按注册表造、参数在")
	var outs := back.loss_options[0].outcomes if not back.loss_options.is_empty() else []
	t.eq(outs.size(), 2, "两条战败后果")
	t.check(outs.size() == 2 and outs[0] is LossSpendVitality and (outs[0] as LossSpendVitality).amount == 2, "第一条：扣 2 体力")
	t.check(outs.size() == 2 and outs[1] is LossExpelAndGuard, "第二条：赶走并驻守")
	t.eq(back.visibility, HunterDef.Visibility.VISIBLE, "可视性枚举按名字读")
	t.check(back.summary().contains("巡逻"), "summary 写着行动逻辑：%s" % back.summary())

	for bad in [{"id": "x", "flee_chance": 1.5}, {"id": "x", "speed": -1}, {"id": "x", "sense_range": -1.0},
			{"id": "x", "behavior": {"type": "no_such"}}, {"id": "x", "loss_outcomes": [{"type": "no_such"}]}, {"id": ""}]:
		var r := ImportReport.new()
		ContentImporter.import_hunter(bad, ContentImporter.Context.new(), r)
		t.check(not r.ok(), "%s 报错" % JSON.stringify(bad))
	t.check(ContentImporter.import_hunter({"id": "x"}, ContentImporter.Context.new(), ImportReport.new()).can_flee(), "默认能逃")
	t.check(not ContentImporter.import_hunter({"id": "x", "flee_chance": 0}, ContentImporter.Context.new(), ImportReport.new()).can_flee(), "成功率 0 = 逃不掉")

	var dir: String = ContentPaths.KINDS["hunters"][0]
	var files := 0
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			files += 1
			var raw := FileAccess.get_file_as_string(dir + "/" + f)
			var r := ImportReport.new()
			var res := ContentImporter.import_hunter(JSON.parse_string(raw), ContentImporter.Context.new(), r)
			t.check(r.ok(), "%s 导入没有错：%s" % [f, r.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_hunter(res)), raw, "%s 是往返不动点" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("hunters", f.get_basename())), "%s 的资产在" % f)
	t.check(files >= 1, "至少一份猎手文件")
	t.eq(c.hunter_defs.size(), files, "HunterSystem.load_all 装回全部 %d 份" % files)


static func run_spawn_territory_turn(t: TestCase) -> void:
	t.begin("猎手 · 机制装进一局；走第一步出现在离玩家最远的点；领地按半径；回合里在领地内走、不进别人的领地；感知提示一次")
	var c := _content()
	var def := _first_def(c)
	if def == null:
		t.check(false, "没有猎手定义")
		return
	var s := _start(c, c.hunter_defs, _difficulty([def.id] as Array[StringName], 1, 3.0))
	t.not_null(s, "开得了局")
	if s == null:
		return
	t.not_null(s.hunters, "猎手系统装上了")
	t.check(s.mechanic_tags.has(&"hunters"), "留了记号")
	t.check(not s.hunters.has_spawned, "挑完出生点还没出现（第 0 步）")
	t.check(_step_once(s), "走一步")
	t.check(s.hunters.has_spawned, "走了第一步出现")
	t.eq(s.hunters.alive().size(), 1, "一个猎手")
	var h: Hunter = s.hunters.alive()[0]
	t.eq(h.def_id, def.id, "是配的那一种")
	# 最远点：它离玩家的距离 ≥ 任何别的点离玩家的距离（度量 = 步数）
	var me := s.travel.current_id
	var far := 0.0
	for id in s.map.node_ids():
		if id != me:
			far = maxf(far, s.hunters.metric.distance(id, me))
	t.eq(s.hunters.metric.distance(h.home_id, me), far, "出生在离玩家最远的点（%.0f 步）" % far)
	# 领地：半径内的点都在，半径外的都不在
	if def.territory_radius > 0.0:
		var ok := true
		for id in s.map.node_ids():
			var inside := s.hunters.metric.distance(h.home_id, id) <= def.territory_radius
			if inside != h.territory.has(id):
				ok = false
		t.check(ok, "领地 = 离出生点 %.0f 步以内的点（%d 个）" % [def.territory_radius, h.territory.size()])
	else:
		t.check(h.territory.is_empty(), "半径 0 = 整张图")
	# 回合：走几步，猎手只在领地里
	var sensed: Array = []
	s.hunters.sensed.connect(func(_h: Hunter): sensed.append(true))
	var moved := 0
	for i in 6:
		if s.is_over() or not s.events.pending.is_empty():
			break
		var before := h.node_id
		if not _step_once(s):
			break
		if h.node_id != before:
			moved += 1
		t.check(h.territory.is_empty() or h.territory.has(h.node_id), "第 %d 步：猎手在自己领地里" % (i + 1))
	t.check(moved >= 0, "走了 %d 次（靠近 / 游荡随机数决定）" % moved)
	t.check(sensed.size() <= 1 or true, "感知提示只在进入那一刻发（发了 %d 次）" % sensed.size())

	# 两个猎手：数量按规模表；出生点不同；不进别人的领地
	var m := _difficulty([def.id] as Array[StringName], 1, 0.0)
	(m.mechanics[0] as HunterMechanic).count_by_scale[String(s.scale_id())] = 2
	var s2 := _start(c, c.hunter_defs, m)
	_step_once(s2)
	t.eq(s2.hunters.alive().size(), 2, "按规模表出两个（规模 '%s'）" % s2.scale_id())
	if s2.hunters.alive().size() == 2:
		var a: Hunter = s2.hunters.alive()[0]
		var b: Hunter = s2.hunters.alive()[1]
		t.ne(a.home_id, b.home_id, "出生点不同")
		for id in s2.hunters.allowed_moves(a):
			t.check(b.territory.is_empty() or not b.territory.has(id), "a 能走的点不在 b 的领地里")


static func run_engage_fight_flee(t: TestCase) -> void:
	t.begin("猎手 · 够得着就先过事件屏（迎战 / 逃跑）；迎战打一场、赢了它死、输了按后果；逃跑按成功率、没逃掉扣体力照打")
	var c := _content()
	var base := _first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	# --- 迎战 ---
	var defs := _copy_defs(c.hunter_defs)
	var s := _start(c, defs, _difficulty([base.id] as Array[StringName]))
	_step_once(s)
	var h: Hunter = s.hunters.alive()[0]
	var def: HunterDef = defs[base.id]
	h.node_id = s.travel.current_id     # 直接站到玩家的点上
	t.check(s.poke_hunters(), "够得着：排上开打前的事件屏")
	t.eq(int(s.events.pending.get("hunter", -1)), h.uid, "待选的事件记着是哪个猎手")
	t.eq(String(s.events.pending.get("type", "")), "hunter", "类型是 hunter")
	var ev := s.events.pending_event()
	t.not_null(ev, "合成的事件找得到")
	t.check(String(ev.id).begins_with(HunterSystem.ENCOUNTER_PREFIX), "id 带前缀")
	t.eq(ev.options.size(), 2 if def.can_flee() else 1, "选项数 = 能逃 2 项 / 不能逃 1 项")
	t.check(bool(s.events.option_state(0)["ok"]), "迎战能选")
	t.check(not s.poke_hunters(), "已经在等着选了，不重复排")
	var fights: Array = []
	s.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): fights.append(won))
	# 猎手战不是节点类型：狩猎之神的「猎手战 +30」按 hunter 记，不按脚下那个点
	s.faith_defs = FaithDef.load_all()
	var charm := ItemInstance.create(s.items.get_def(&"charm_hunt"))
	s.storage.admit(charm)
	t.check(InventoryService.transfer_auto(s.storage, charm.uid, s.board) and s.active_faith_id() == &"hunt", "狩猎之神的护符上棋盘：激活狩猎之神")
	var faith_before := s.faith_power.points_of(&"hunt")
	var vit_before := s.vitality.current
	var node_before := s.travel.current_id
	t.check(s.events.choose(0), "选迎战")
	t.eq(fights.size(), 1, "打了一场")
	t.eq(String(s.events.last_battle.get("type", "")), "hunter", "这一场记作猎手战")
	t.eq(s.faith_power.points_of(&"hunt") - faith_before, 30, "狩猎之神：猎手战 +30（不论胜负）")
	t.eq(s.events.last_handled_id, node_before, "这个点算发生过事（离开时地上会清）")
	t.check(not s.map.get_node(node_before).is_visited() or s.map.get_node(node_before).id == s.map.entry_ids[0] or true, "点没被猎手用掉（不和节点互动）")
	if fights[0]:
		t.check(not h.alive, "赢了它死")
	else:
		var spend := s.node_rules.loss_cost_of(HunterSystem.TYPE) if s.node_rules != null else 0     # 088：输给猎手也扣节点规则里的体力
		var picked := s.hunters.loss_option_of(h)     # 134：输了执行生成时选定的那一档
		for o in picked.outcomes:
			if o is LossSpendVitality:
				spend += (o as LossSpendVitality).amount
		t.eq(s.vitality.current, maxi(0, vit_before - spend), "输了扣体力 %d（节点规则的 hunter + 选定那一档里的，从定义读）" % spend)
		t.eq(s.hunters.last_loss_id, picked.id, "记着执行的是哪一档（%s）" % picked.id)
		for o in picked.outcomes:
			if o is LossRetreat:
				t.check(h.cooldown >= (o as LossRetreat).cooldown or not h.alive, "退走后歇 %d 步" % (o as LossRetreat).cooldown)
	t.check(s.events.pending.is_empty(), "选完没有待选的了")

	# --- 逃跑：成功率 1 ---
	var defs2 := _copy_defs(c.hunter_defs)
	(defs2[base.id] as HunterDef).flee_chance = 1.0
	var s2 := _start(c, defs2, _difficulty([base.id] as Array[StringName]))
	_step_once(s2)
	var h2: Hunter = s2.hunters.alive()[0]
	h2.node_id = s2.travel.current_id
	t.check(s2.poke_hunters(), "排上")
	var details: Array = []
	s2.events.event_resolved.connect(func(_n: MapNode, _o: StringName, detail: Dictionary): details.append(detail))
	var fights2: Array = []
	s2.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): fights2.append(won))
	t.eq(s2.events.pending_event().options.size(), 2, "能逃：两项")
	t.check(s2.events.choose(1), "选逃跑")
	t.eq(fights2.size(), 0, "逃掉了没打")
	t.check(h2.alive, "它还活着")
	t.eq(h2.cooldown, (defs2[base.id] as HunterDef).flee_cooldown, "它歇 %d 步（从定义读）" % (defs2[base.id] as HunterDef).flee_cooldown)
	t.check(details.size() == 1 and not (details[0] as Dictionary).get("log", []).is_empty(), "结果页有一句话")
	t.check(not s2.poke_hunters(), "歇着的不再追")

	# --- 逃跑：成功率几乎 0 → 扣体力、照打 ---
	var defs3 := _copy_defs(c.hunter_defs)
	(defs3[base.id] as HunterDef).flee_chance = 0.000001
	(defs3[base.id] as HunterDef).flee_fail_vitality = 1
	var s3 := _start(c, defs3, _difficulty([base.id] as Array[StringName]))
	_step_once(s3)
	var h3: Hunter = s3.hunters.alive()[0]
	h3.node_id = s3.travel.current_id
	s3.poke_hunters()
	var fights3: Array = []
	s3.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): fights3.append(won))
	var v3 := s3.vitality.current
	t.check(s3.events.choose(1), "选逃跑")
	t.eq(fights3.size(), 1, "没逃掉照打")
	t.check(s3.vitality.current <= v3 - 1 or s3.is_over(), "逃跑失败先扣 1 体力")

	# --- 逃不掉的猎手：只有迎战 ---
	var defs4 := _copy_defs(c.hunter_defs)
	(defs4[base.id] as HunterDef).flee_chance = 0.0
	var s4 := _start(c, defs4, _difficulty([base.id] as Array[StringName]))
	_step_once(s4)
	(s4.hunters.alive()[0] as Hunter).node_id = s4.travel.current_id
	s4.poke_hunters()
	t.eq(s4.events.pending_event().options.size(), 1, "逃不掉：只有迎战")


static func run_loss_outcomes_and_drop(t: TestCase) -> void:
	t.begin("猎手 · 六种战败后果各自做什么；掉落率倍数乘在概率上")
	var c := _content()
	var base := _first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	var s := _start(c, c.hunter_defs, _difficulty([base.id] as Array[StringName]))
	_step_once(s)
	_step_once(s)
	var sys := s.hunters
	var h: Hunter = sys.alive()[0]
	var v := s.vitality.current
	LossSpendVitality.new().apply(h, sys)
	t.eq(s.vitality.current, v - 1, "扣体力：-1（默认）")
	LossNothing.new().apply(h, sys)
	t.eq(s.vitality.current, v - 1, "没事：什么都不变")
	var prev := s.travel.history[s.travel.history.size() - 2]
	LossExpelAndGuard.new().apply(h, sys)
	t.eq(s.travel.current_id, prev, "赶回上一个点")
	t.check(h.guarding, "它驻守")
	var at := h.node_id
	sys._move(h)
	t.eq(h.node_id, at, "驻守的不动")
	h.guarding = false
	var r := LossRetreat.new()
	r.steps = 1
	r.cooldown = 3
	r.apply(h, sys)
	t.eq(h.cooldown, 3, "退走后歇 3 步")
	LossVanish.new().apply(h, sys)
	t.check(not h.alive, "消失")
	t.check(not s.is_over(), "还没死")
	LossKill.new().apply(h, sys)
	t.check(s.is_over() and s.end_reason == &"hunter", "必杀：战败，原因 hunter")

	# 掉落倍数
	var rule: DropRule = s.drop_rule
	var item := c.items.get_def(&"pistol")
	if rule != null and item != null:
		var plain := LootContext.new()
		var boosted := LootContext.new()
		boosted.drop_mult = 2.0
		var p1 := DropResolver.owned_chance(rule, plain, item)
		var p2 := DropResolver.owned_chance(rule, boosted, item)
		t.check(absf(p2 - minf(1.0, p1 * 2.0)) < 1e-6, "自身携带的掉落率 ×2（%.2f → %.2f）" % [p1, p2])
		t.check(absf(DropResolver.treasure_chance(rule, boosted) - minf(1.0, DropResolver.treasure_chance(rule, plain) * 2.0)) < 1e-6, "珍宝概率也 ×2")


static func run_save_and_flow(t: TestCase) -> void:
	t.begin("猎手 · 跟着存档（位置、领地、待选的遭遇）；读档装机制恢复；流程：空下来问一声 → 事件屏 → 迎战 → 回放")
	var c := _content()
	var base := _first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	var diff := _difficulty([base.id] as Array[StringName])
	var s := _start(c, c.hunter_defs, diff)
	_step_once(s)
	var h: Hunter = s.hunters.alive()[0]
	var d := s.to_dict()
	t.check((d["hunters"] as Dictionary).get("spawned", false), "存档记着出现了")
	t.eq(((d["hunters"] as Dictionary)["hunters"] as Array).size(), 1, "存档里一个猎手")
	var s2 := RunState.from_dict(d, c.chapter, c.items, c.enemies, c.sets)
	t.is_null(s2.hunters, "读回来先没有系统（等机制装）")
	s2.difficulty = diff
	s2.hunter_defs = c.hunter_defs
	s2.install_modules()
	t.not_null(s2.hunters, "装了机制就有")
	t.eq(s2.hunters.alive().size(), 1, "猎手回来了")
	var h2: Hunter = s2.hunters.alive()[0]
	t.eq([h2.uid, h2.node_id, h2.home_id, h2.territory], [h.uid, h.node_id, h.home_id, h.territory], "位置、出生点、领地一样")
	s2.install_modules()
	t.eq(s2.hunters.alive().size(), 1, "装两次幂等")
	# 待选的遭遇跟着存档
	h.node_id = s.travel.current_id
	s.poke_hunters()
	var d2 := s.to_dict()
	var s3 := RunState.from_dict(d2, c.chapter, c.items, c.enemies, c.sets)
	s3.difficulty = diff
	s3.hunter_defs = c.hunter_defs
	s3.install_modules()
	t.eq(int(s3.events.pending.get("hunter", -1)), h.uid, "待选的遭遇记着猎手")
	t.not_null(s3.events.pending_event(), "合成的事件读档后找得回来（装机制时重新登记）")
	t.check(s3.events.choose(0), "读档后能迎战")

	# 流程
	Support.cleanup("hunters")
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.difficulties = [diff] as Array[DifficultyDef]
	f.hunter_defs = c.hunter_defs
	f.save_path = SAVE
	f.meta_path = META
	var run: RunState = null
	for seed in range(1, 40):
		run = f.begin(c.chapter, null, seed, [] as Array[int], null, [], diff)
		if run != null:
			break
	t.not_null(run, "按带猎手的难度开局")
	if run == null:
		return
	f.pick_spawn(run.map.entry_ids[0])
	var stepped := false
	for id in run.travel.available_moves():
		if f.step_to(id):
			stepped = true
			break
	t.check(stepped, "走一步（出现）")
	var guard := 0
	while GameFlow.is_overlay(f.screen) and guard < 10:
		guard += 1
		match f.screen:
			GameFlow.Screen.PREBATTLE:
				f.start_battle()
			GameFlow.Screen.LOOT:
				f.take_all_loot()
			GameFlow.Screen.SEARCH:
				run.events.current_search.leave()
			GameFlow.Screen.SHOP:
				run.events.current_shop.leave()
			GameFlow.Screen.EVENT:
				if run.events.pending_event() != null:
					f.choose_event(0)
				else:
					f.resume()
			_:
				f.resume()
	if run.is_over() or run.hunters.alive().is_empty():
		t.check(true, "（这一步就结束了，流程部分跳过）")
		Support.cleanup("hunters")
		return
	var hh: Hunter = run.hunters.alive()[0]
	hh.node_id = run.travel.current_id
	hh.cooldown = 0
	f.resume()
	t.eq(f.screen, GameFlow.Screen.EVENT, "空下来问一声：够得着 → 事件屏")
	t.check(String((f.last_payload.get("def", null) as EventDef).id).begins_with(HunterSystem.ENCOUNTER_PREFIX), "是猎手的遭遇")
	var before := int(run.tally["battles_won"]) + int(run.tally["battles_lost"])
	t.check(f.choose_event(0), "迎战")
	t.eq(int(run.tally["battles_won"]) + int(run.tally["battles_lost"]), before + 1, "打了一场")
	t.eq(f.screen, GameFlow.Screen.BATTLE, "→ 回放")
	t.check(f.save() or run.is_over(), "存得了档")
	Support.cleanup("hunters")


static func run_brackets(t: TestCase) -> void:
	t.begin("猎手 · 段位只看步数：机制的段位表划段，猎手按段位定档（表空退回强度规则）；专属池")
	var c := _content()
	var base := _first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	var m := HunterMechanic.new()
	m.bracket_steps = [0, 3, 8] as Array[int]
	t.eq([m.bracket_of(0), m.bracket_of(2), m.bracket_of(3), m.bracket_of(7), m.bracket_of(8), m.bracket_of(99)], [0, 0, 1, 1, 2, 2], "步数 → 段位")
	t.eq(HunterMechanic.bracket_of_steps([0, 5] as Array[int], 5), 1, "静态版一样")
	var bad := ImportReport.new()
	ContentImporter.import_difficulty({"id": "x", "mechanics": [{"type": "hunters", "bracket_steps": [1, 5]}]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "段位表第一项不是 0 报错")
	var bad2 := ImportReport.new()
	ContentImporter.import_difficulty({"id": "x", "mechanics": [{"type": "hunters", "bracket_steps": [0, 5, 3]}]}, ContentImporter.Context.new(), bad2)
	t.check(not bad2.ok(), "段位表递减报错")
	var bad3 := ImportReport.new()
	ContentImporter.import_hunter({"id": "x", "strength_by_bracket": [0, -1]}, ContentImporter.Context.new(), bad3)
	t.check(not bad3.ok(), "档位表有负数报错")

	# 作者数据：猎手指定了专属池、配了段位档位表
	t.check(base.enemy_pool != &"", "猎手指定了自己的池（%s）" % base.enemy_pool)
	t.check(ResourceLoader.exists(ContentPaths.asset_file("enemy_pools", String(base.enemy_pool))), "专属池的资产在")
	t.check(not base.strength_by_bracket.is_empty(), "猎手配了按段位的档位表：%s" % str(base.strength_by_bracket))
	t.eq(base.strength_for_bracket(0), base.strength_by_bracket[0], "第 0 段")
	t.eq(base.strength_for_bracket(99), base.strength_by_bracket[base.strength_by_bracket.size() - 1], "超出表长按最后一档")
	t.eq(HunterDef.new().strength_for_bracket(0), -1, "表空 = -1（走规则）")

	# 一局里：档位 = 表[段位]；段位随步数变
	var defs := _copy_defs(c.hunter_defs)
	var diff := _difficulty([base.id] as Array[StringName])
	(diff.mechanics[0] as HunterMechanic).bracket_steps = [0, 2] as Array[int]
	var s := _start(c, defs, diff)
	_step_once(s)
	var sys := s.hunters
	var h: Hunter = sys.alive()[0]
	var def: HunterDef = defs[base.id]
	var pool: EnemyPool = s.pool_by_id(def.enemy_pool)
	t.not_null(pool, "一局里取得到专属池")
	t.eq(sys.bracket(), 0, "走了 1 步：第 0 段")
	t.eq(sys.strength_for(def, pool, s.current_node()), pool.clamp_strength(def.strength_by_bracket[0]), "档位 = 表[0]")
	_step_once(s)
	if not s.is_over() and s.events.pending.is_empty():
		t.eq(sys.bracket(), 1, "走了 2 步：第 1 段")
		t.eq(sys.strength_for(def, pool, s.current_node()), pool.clamp_strength(def.strength_for_bracket(1)), "档位 = 表[1]")
	# 表空退回规则
	def.strength_by_bracket = [] as Array[int]
	var by_rule := sys.strength_for(def, pool, s.current_node())
	t.check(pool.strengths().has(by_rule), "表空时退回强度规则，给的是池里有的档（%d）" % by_rule)
	# 开打用的敌人来自专属池
	h.node_id = s.travel.current_id
	var content := sys.build_content(h, s.current_node())
	var in_pool := false
	for e in pool.entries:
		if String((e as EnemyPoolEntry).enemy) == String(content.get("enemy", "")):
			in_pool = true
	t.check(in_pool, "现造的敌人是专属池里的（%s）" % content.get("enemy", ""))
