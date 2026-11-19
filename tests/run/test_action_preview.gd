## 局内界面布局方案 §4.2：地图行动代价预览（[ActionPreview]）—— 预测和真走一步的结果一样；不泄露看不见的猎手
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Asc := preload("res://tests/run/test_ten_ascensions_320.gd")


static func _run(c, s: int, id: StringName = &"ascension_9") -> RunState:
	var d := Asc._by_id(id)
	return RunState.start(c.chapter, s, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], d) if d != null else null


static func run_matches_real_step(t: TestCase) -> void:
	t.begin("§4.2 · 预览的倒计时、体力、金币和真走一步一样（进阶多扣按累计取整；全图侵蚀时也对）")
	var c = NodeScreens._content()
	var checked := 0
	for s in [3, 7, 11, 19]:
		for eroded in [false, true]:
			var run := _run(c, s)
			if run == null:
				t.check(false, "进阶九开局")
				return
			if run.phase == RunState.Phase.PICK_SPAWN:
				for id in run.map.node_ids():
					if run.map.get_node(id).type == &"spawn" and run.pick_spawn(id):
						break
			run.travel.clock.total = 9     # 10% 多扣：9 → 10 点时一步扣 2
			if eroded and run.travel.erosion != null:
				run.travel.erosion.eroded_bands = run.travel.erosion.max_band
			if run.wallet != null:
				run.wallet.earn(50, &"test")
			var moves := run.travel.available_moves()
			if moves.is_empty():
				continue
			var to: int = moves[0]
			var p := ActionPreview.of(run, [to] as Array[int])
			var cd := CountdownModule.of(run)
			var spent0 := cd.spent() if cd != null and cd.has_countdown() else 0
			var eroded_vit := [0]     # 只数侵蚀扣的（进点之后的事 —— 打输、休息 —— 不是这一步的代价）
			run.vitality.changed.connect(func(_c: int, _m: int, delta: int, why: StringName) -> void:
				if why == &"erosion": eroded_vit[0] -= delta)
			var coins0 := run.wallet.balance if run.wallet != null else 0
			t.check(run.step_to(to), "种子 %d 能走到 %d" % [s, to])
			if cd != null and cd.has_countdown():
				t.eq(int(p[ActionPreview.COUNTDOWN]), cd.spent() - spent0, "种子 %d%s：倒计时扣 %d" % [s, "（全图侵蚀）" if eroded else "", cd.spent() - spent0])
			if int(p[ActionPreview.VITALITY_MAYBE]) == 0:
				t.eq(int(p[ActionPreview.VITALITY]), int(eroded_vit[0]), "种子 %d：侵蚀扣的体力一样（%d）" % [s, eroded_vit[0]])
			if int(p[ActionPreview.MONEY_MAYBE]) == 0 and run.wallet != null:
				t.eq(int(p[ActionPreview.MONEY]), coins0 - run.wallet.balance, "种子 %d：金币扣的一样" % s)
			checked += 1
	t.check(checked >= 4, "比对了 %d 次" % checked)


static func run_rounding_and_free_step(t: TestCase) -> void:
	t.begin("§4.2 · 显示真实取整后的数：9 点时走一步扣 2、10 点时扣 1；熟门熟路的那一步扣 0；负重翻倍照乘")
	var c = NodeScreens._content()
	var run := _run(c, 5, &"ascension_7")
	if run == null or CountdownModule.of(run) == null or not CountdownModule.of(run).has_countdown():
		t.check(false, "进阶七开局、有倒计时")
		return
	if run.phase == RunState.Phase.PICK_SPAWN:
		for id in run.map.node_ids():
			if run.map.get_node(id).type == &"spawn" and run.pick_spawn(id):
				break
	var to: int = run.travel.available_moves()[0]
	var one := MapNavigator.resolve_step(run.map, run.travel.current_id, to).action_cost
	if one != 1:
		t.check(true, "这条路不是 1 点，跳过取整检查")
		return
	run.travel.clock.total = 9
	t.eq(int(ActionPreview.of(run, [to] as Array[int])[ActionPreview.COUNTDOWN]), 2, "9 → 10：扣 2（9 → 11）")
	run.travel.clock.total = 10
	t.eq(int(ActionPreview.of(run, [to] as Array[int])[ActionPreview.COUNTDOWN]), 1, "10 → 11：扣 1（11 → 12）")
	run.travel.free_step_every = 2
	run.travel.paid_steps = 2
	t.eq(int(ActionPreview.of(run, [to] as Array[int])[ActionPreview.COUNTDOWN]), 0, "熟门熟路：这一步不扣")
	run.travel.free_step_every = 0
	run.travel.action_cost_mult = 2
	var p := ActionPreview.of(run, [to] as Array[int])
	t.eq([int(p[ActionPreview.ACTIONS]), int(p[ActionPreview.LOAD_MULT])], [2, 2], "负重三级：行动点 ×2，并说出来")
	t.check(ActionPreview.lines(p).contains(UiText.t("preview.load") % 2), "浮窗写负重倍数")
	t.check(ActionPreview.lines(p).contains(UiText.t("preview.countdown") % int(p[ActionPreview.COUNTDOWN])), "浮窗写实际扣的数")


static func run_no_hidden_hunters(t: TestCase) -> void:
	t.begin("§4.2 · 只说看得见的猎手；走不通、脚下不给预览")
	var c = NodeScreens._content()
	var run := _run(c, 9, &"ascension_3")
	if run == null:
		t.check(false, "进阶三开局")
		return
	if run.phase == RunState.Phase.PICK_SPAWN:
		for id in run.map.node_ids():
			if run.map.get_node(id).type == &"spawn" and run.pick_spawn(id):
				break
	t.check(ActionPreview.of(run, [] as Array[int]).is_empty(), "空路线：没有预览")
	t.check(ActionPreview.of(run, [run.travel.current_id] as Array[int]).is_empty(), "原地：走不通，没有预览")
	if run.hunters != null and not run.hunters.has_spawned:
		run.hunters.spawn()
	var visible: Array[String] = []
	if run.hunters != null:
		for h in run.hunters.visible_hunters():
			visible.append(Names.of(run.hunters.def_of(h)))
	for to in run.travel.available_moves():
		var named: Array = ActionPreview.of(run, [to] as Array[int])[ActionPreview.HUNTERS]
		for n in named:
			t.check(visible.has(n), "点 %d：说到的 %s 是看得见的" % [to, n])
	if run.hunters != null:
		for h in run.hunters.alive():
			h.node_id = run.travel.available_moves()[0]     # 贴到隔壁
		var near: Array = ActionPreview.of(run, [run.travel.available_moves()[0]] as Array[int])[ActionPreview.HUNTERS]
		var seen := run.hunters.visible_hunters()
		t.eq(near.size() > 0, not seen.is_empty(), "贴到隔壁：看得见就说「可能遭遇」，看不见就不说")
