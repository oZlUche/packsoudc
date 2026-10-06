## 134：猎手的战败结果分档、生成时选定；猎手战插在进点的事件队列前面（驱逐 = 视为没进这个点）。
## 期望从数据推：档名、档数、后果都从定义里读
extends RefCounted

const H := preload("res://tests/run/test_hunters.gd")


## hunter_1 的副本：不动（速度 0），够得着才打（同一个点）
static func _still_defs(c: H.Content, id: StringName) -> Dictionary:
	var defs := H._copy_defs(c.hunter_defs)
	var def: HunterDef = defs[id]
	def.speed = 0
	def.engage_range = 0.0
	return defs


## 开局走一步（猎手出现），清掉脚下等着选的事；返回 [run, 猎手]
static func _ready_run(c: H.Content, defs: Dictionary, id: StringName) -> Array:
	var s := H._start(c, defs, H._difficulty([id] as Array[StringName]))
	if s == null or not H._step_once(s) or s.hunters.alive().is_empty():
		return []
	s.events.pending = {}
	return [s, s.hunters.alive()[0]]


## 相邻、还没走过的一个点；没有返回 -1
static func _fresh_neighbor(s: RunState) -> int:
	for id in s.travel.available_moves():
		if not s.map.get_node(id).is_visited():
			return id
	return -1


static func run_pick_on_spawn(t: TestCase) -> void:
	t.begin("134 · 战败结果档：生成时按选法定一档、跟着存档；随机按权重；固定给定档；旧定义与旧存档按第一档")
	var c := H._content()
	var base := H._first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	t.check(base.loss_options.size() >= 2, "作者的猎手配了至少两档（%d）" % base.loss_options.size())
	var ids: Array = []
	for o in base.options():
		ids.append(String((o as HunterLossOption).id))
	t.check(ids.has("repel") and ids.has("expel"), "有击退与驱逐两档：%s" % str(ids))
	var r := ContentImporter.import_hunter({"id": "x"}, ContentImporter.Context.new(), ImportReport.new())
	t.is_null(r.loss_pick, "不写选法 = null（按权重随机）")

	var s := H._start(c, c.hunter_defs, H._difficulty([base.id] as Array[StringName]))
	H._step_once(s)
	var h: Hunter = s.hunters.alive()[0]
	t.check(ids.has(String(h.loss_id)), "生成时选了一档（%s）" % h.loss_id)
	t.eq(s.hunters.loss_option_of(h).id, h.loss_id, "按档名找得回那一档")
	var back := Hunter.from_dict(h.to_dict())
	t.eq(back.loss_id, h.loss_id, "档名跟着存档")
	var old := h.to_dict()
	old.erase("loss")
	t.eq(s.hunters.loss_option_of(Hunter.from_dict(old)), base.options()[0], "旧存档没有档名：按第一档")

	# 随机按权重：一档权重 0 永远不中；两档都 1 两档都会出
	var sys := s.hunters
	var opts: Array[HunterLossOption] = []
	for i in 2:
		var o := HunterLossOption.new()
		o.id = StringName("o%d" % i)
		opts.append(o)
	var rnd := LossPickRandom.new()
	opts[0].weight = 0.0
	var all_second := true
	for i in 50:
		if rnd.pick(opts, sys) != 1:
			all_second = false
	t.check(all_second, "权重 0 的那档 50 次都没中")
	opts[0].weight = 1.0
	var seen := {}
	for i in 200:
		seen[rnd.pick(opts, sys)] = true
	t.eq(seen.size(), 2, "两档权重相同：200 次两档都出过")
	var fixed := LossPickFixed.new()
	fixed.index = 1
	t.eq(fixed.pick(opts, sys), 1, "固定第 2 档")
	fixed.index = 9
	t.eq(fixed.pick(opts, sys), 1, "超出按最后一档")

	# 定义里的固定选法：生成出来就是那一档
	var defs := H._copy_defs(c.hunter_defs)
	var fdef: HunterDef = defs[base.id]
	var pick := LossPickFixed.new()
	pick.index = fdef.options().size() - 1
	fdef.loss_pick = pick
	var s2 := H._start(c, defs, H._difficulty([base.id] as Array[StringName]))
	H._step_once(s2)
	t.eq(s2.hunters.alive()[0].loss_id, fdef.options()[pick.index].id, "固定选法：生成的就是第 %d 档" % (pick.index + 1))

	# 旧定义：只写了 loss_outcomes —— 当作只有一档
	var legacy := ContentImporter.import_hunter({"id": "legacy", "loss_outcomes": [{"type": "spend_vitality"}, {"type": "retreat"}]},
		ContentImporter.Context.new(), ImportReport.new())
	t.eq(legacy.options().size(), 1, "旧定义：一档")
	t.eq(legacy.options()[0].outcomes.size(), 2, "那一档就是原来的两条后果")
	t.eq(legacy.option_by_id(&"whatever"), legacy.options()[0], "找不到的档名按第一档")


static func run_import_checks(t: TestCase) -> void:
	t.begin("134 · 导入：档名不空不重、权重不为负、固定选法不越界；两样都写提醒；往返不动")
	var sample := {"id": "probe", "loss_options": [
		{"id": "repel", "display_name": "击退", "weight": 2.0, "outcomes": [{"type": "retreat"}]},
		{"id": "expel", "display_name": "驱逐", "outcomes": [{"type": "expel"}]}],
		"loss_pick": {"type": "fixed", "index": 1}}
	var report := ImportReport.new()
	var def := ContentImporter.import_hunter(sample, ContentImporter.Context.new(), report)
	t.check(report.ok(), "合法：%s" % report.to_text())
	t.check(def.loss_pick is LossPickFixed and (def.loss_pick as LossPickFixed).index == 1, "选法按注册表造")
	t.check(def.loss_options[1].outcomes[0] is LossExpel, "驱逐构件按注册表造")
	var text := ContentExporter.to_json(ContentExporter.export_hunter(def))
	var back := ContentImporter.import_hunter(JSON.parse_string(text), ContentImporter.Context.new(), ImportReport.new())
	t.eq(ContentExporter.to_json(ContentExporter.export_hunter(back)), text, "导出 → 导入 → 再导出逐字节相同")
	t.check(def.summary().contains("击退") and def.summary().contains("驱逐"), "summary 列出两档：%s" % def.summary())
	for bad in [
			{"id": "x", "loss_options": [{"display_name": "没名字"}]},
			{"id": "x", "loss_options": [{"id": "a"}, {"id": "a"}]},
			{"id": "x", "loss_options": [{"id": "a", "weight": -1.0}]},
			{"id": "x", "loss_options": [{"id": "a"}], "loss_pick": {"type": "fixed", "index": 3}},
			{"id": "x", "loss_pick": {"type": "no_such"}}]:
		var r := ImportReport.new()
		ContentImporter.import_hunter(bad, ContentImporter.Context.new(), r)
		t.check(not r.ok(), "%s 报错" % JSON.stringify(bad))
	var both := ImportReport.new()
	ContentImporter.import_hunter({"id": "x", "loss_outcomes": [{"type": "retreat"}], "loss_options": [{"id": "a"}]}, ContentImporter.Context.new(), both)
	t.check(both.ok() and both.to_text().contains("loss_outcomes"), "两样都写：提醒、不报错")


static func run_hunter_before_node(t: TestCase) -> void:
	t.begin("134 · 猎手战排在进点的事前面：够得着就先上猎手的事件屏、这个点挂起；逃掉 / 击退之后这个点的事才发生")
	var c := H._content()
	var base := H._first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	# --- 逃掉：接着进点 ---
	var defs := _still_defs(c, base.id)
	(defs[base.id] as HunterDef).flee_chance = 1.0
	var got := _ready_run(c, defs, base.id)
	if got.is_empty():
		t.check(false, "开得了局")
		return
	var s: RunState = got[0]
	var h: Hunter = got[1]
	var to := _fresh_neighbor(s)
	if to < 0:
		t.check(true, "（没有没走过的相邻点，跳过）")
		return
	h.node_id = to
	h.cooldown = 0
	var arrived: Array = []
	s.arrived.connect(func(id: int, first: bool): arrived.append([id, first]))
	var moved: Array = []
	s.travel.moved.connect(func(i: MoveIntent, first: bool): moved.append([i.to_id, first]))
	t.check(s.step_to(to), "走过去")
	t.eq(s.travel.current_id, to, "人到了点上")
	t.eq(int(s.events.pending.get("hunter", -1)), h.uid, "先上猎手的事件屏")
	t.check(s.has_pending_arrival(), "这个点挂起了")
	t.check(not s.map.get_node(to).is_visited(), "还没标走过")
	t.check(not arrived.has([to, true]), "这个点的事还没发生")
	t.check(not moved.has([to, true]), "首访还没记")
	t.check(not s.resume_arrival(), "猎手的事件屏还等着：不接着进")
	t.check(s.events.choose(1), "逃跑")
	t.check(h.cooldown > 0, "逃掉了")
	t.check(s.has_pending_arrival(), "选完还挂着（等玩家空下来）")
	t.check(s.poke_hunters(), "空下来问一声：接着进点")
	t.check(not s.has_pending_arrival(), "不再挂着")
	t.check(arrived.has([to, true]), "这个点的事现在发生了（头一回到）")
	t.check(moved.has([to, true]), "首访现在才记")

	# --- 击退：输了留在点上，这个点的事照常发生 ---
	var defs2 := _still_defs(c, base.id)
	(defs2[base.id] as HunterDef).flee_chance = 0.0
	var got2 := _ready_run(c, defs2, base.id)
	var s2: RunState = got2[0]
	var h2: Hunter = got2[1]
	var to2 := _fresh_neighbor(s2)
	h2.node_id = to2
	h2.cooldown = 0
	h2.loss_id = &"repel"
	s2.board.clear()     # 空手必输
	var arrived2: Array = []
	s2.arrived.connect(func(id: int, first: bool): arrived2.append([id, first]))
	t.check(s2.step_to(to2), "走过去")
	t.check(s2.has_pending_arrival(), "挂起")
	var lost: Array = []
	s2.events.battle_finished.connect(func(_n: MapNode, _r: BattleResult, won: bool): lost.append(not won))
	t.check(s2.events.choose(0), "迎战")
	t.check(lost.size() == 1 and lost[0], "空手输了")
	if s2.is_over():
		t.check(true, "（体力耗光，后面跳过）")
		return
	t.eq(s2.hunters.last_loss_id, &"repel", "执行的是击退档")
	t.eq(s2.travel.current_id, to2, "击退：人留在点上")
	t.check(h2.cooldown > 0, "猎手退走、歇着")
	t.check(s2.poke_hunters(), "接着进点")
	t.check(arrived2.has([to2, true]), "击退档：这个点的事照常发生")


static func run_expel_cancels_arrival(t: TestCase) -> void:
	t.begin("134 · 驱逐档：输了退回上一步，这个点不标走过、事不发生、不记首访；步数照算；再走过去照常发生；正忙时被追上只退位置")
	var c := H._content()
	var base := H._first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	var defs := _still_defs(c, base.id)
	(defs[base.id] as HunterDef).flee_chance = 0.0
	var got := _ready_run(c, defs, base.id)
	var s: RunState = got[0]
	var h: Hunter = got[1]
	var from := s.travel.current_id
	var to := _fresh_neighbor(s)
	if to < 0:
		t.check(true, "（没有没走过的相邻点，跳过）")
		return
	h.node_id = to
	h.cooldown = 0
	h.loss_id = &"expel"
	s.board.clear()
	var arrived: Array = []
	s.arrived.connect(func(id: int, first: bool): arrived.append([id, first]))
	var moved: Array = []
	s.travel.moved.connect(func(i: MoveIntent, first: bool): moved.append([i.to_id, first]))
	var steps_before := s.travel.clock.total
	t.check(s.step_to(to), "走过去")
	t.check(s.has_pending_arrival(), "挂起")
	t.check(s.events.choose(0), "迎战")
	if s.is_over():
		t.check(true, "（体力耗光，后面跳过）")
		return
	t.eq(s.hunters.last_loss_id, &"expel", "执行的是驱逐档")
	t.eq(s.travel.current_id, from, "退回上一步（%d）" % from)
	t.check(not s.has_pending_arrival(), "挂起的进点取消了")
	t.check(not s.map.get_node(to).is_visited(), "那个点没标走过")
	t.check(not arrived.has([to, true]), "那个点的事没发生")
	t.check(not moved.has([to, true]) and not moved.has([to, false]), "没记进点（首访不算）")
	t.check(s.travel.clock.total > steps_before, "步数照算（%d → %d）" % [steps_before, s.travel.clock.total])
	t.check(not s.poke_hunters() or s.events.pending.has("hunter"), "没有挂起的可接")
	# 再走过去：这次没猎手挡（歇着），这个点的事照常发生
	h.cooldown = 99
	s.events.pending = {}
	t.check(s.step_to(to), "再走过去")
	t.check(not s.has_pending_arrival(), "没挂起")
	t.check(arrived.has([to, true]), "这次这个点的事发生了（还算头一回到）")
	t.check(moved.has([to, true]), "首访这次才记")

	# 正忙时被追上（已经进过了）：驱逐只退位置，那个点还是走过的
	var here := s.travel.current_id
	var back := s.travel.history[s.travel.history.size() - 2]
	s.events.pending = {}
	LossExpel.new().apply(h, s.hunters)
	t.eq(s.travel.current_id, back, "只退位置")
	t.check(arrived.has([here, true]), "那个点的事早就发生了，不撤销")


static func run_held_arrival_save(t: TestCase) -> void:
	t.begin("134 · 挂起的进点跟着存档：读档回来接着是猎手的事件屏，了结之后接着进点")
	var c := H._content()
	var base := H._first_def(c)
	if base == null:
		t.check(false, "没有猎手定义")
		return
	var defs := _still_defs(c, base.id)
	(defs[base.id] as HunterDef).flee_chance = 1.0
	var diff := H._difficulty([base.id] as Array[StringName])
	var s := H._start(c, defs, diff)
	H._step_once(s)
	s.events.pending = {}
	var h: Hunter = s.hunters.alive()[0]
	var to := _fresh_neighbor(s)
	if to < 0:
		t.check(true, "（没有没走过的相邻点，跳过）")
		return
	h.node_id = to
	h.cooldown = 0
	s.step_to(to)
	t.check(s.has_pending_arrival(), "挂起")
	var d := s.to_dict()
	t.check((d["travel"] as Dictionary).has("held"), "存档里记着挂起的进点")
	var s2 := RunState.from_dict(JSON.parse_string(JSON.stringify(d)), c.chapter, c.items, c.enemies, c.sets)
	s2.difficulty = diff
	s2.hunter_defs = defs
	s2.install_modules()
	t.check(s2.has_pending_arrival(), "读回来还挂着")
	t.eq((s2.travel.held["intent"] as MoveIntent).to_id, to, "挂的是那个点")
	t.check(not s2.map.get_node(to).is_visited(), "那个点还没走过")
	t.eq(int(s2.events.pending.get("hunter", -1)), h.uid, "猎手的事件屏还等着")
	var arrived: Array = []
	s2.arrived.connect(func(id: int, first: bool): arrived.append([id, first]))
	t.check(s2.events.choose(1), "逃跑")
	t.check(s2.poke_hunters(), "接着进点")
	t.check(arrived.has([to, true]), "那个点的事发生了")
	t.check(not s2.to_dict()["travel"].has("held"), "存档里不再有挂起")
