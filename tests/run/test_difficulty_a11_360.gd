## 360 第三批 A11（作者难度表「只能看到周围 N 个节点内的敌情；远处仍显示节点类型」，N = 2 是建议初值）
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


static func _eleven() -> DifficultyDef:
	for d in GameFlow.load_difficulties():
		if (d as DifficultyDef).id == &"ascension_11":
			return d
	return null


static func run_data(t: TestCase) -> void:
	t.begin("360 A11 · 数据：第 11 档、进阶十撤离开、可视距离 2、计分 1.8")
	var d := _eleven()
	t.not_null(d, "进阶十一在")
	if d == null:
		return
	t.eq([d.level, d.requires_unlock, d.intel_range], [11, &"ascension_11", 2], "第 11 档、要解锁、看得清两步")
	t.eq(ScoreRules.load_rules().mult(11), 1.8, "计分 1.8")
	t.check(d.description.contains("{intel_range}"), "说明写占位")
	t.check(d.challenge.length() <= 10, "挑战一行（%s）" % d.challenge)


static func run_in_run(t: TestCase) -> void:
	t.begin("360 A11 · 一局里：两步以内看得清，远处只说敌情不明；走近揭示后一直看得清；普通难度全看得清")
	var c = NodeScreens._content()
	var d := _eleven()
	if d == null:
		t.check(false, "进阶十一在")
		return
	var run := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], d)
	var plain := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	if run.travel.current_id < 0:
		run.pick_spawn(run.map.entry_ids[0])
	var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
	var near := -1
	var far := -1
	for id in run.map.node_ids():
		if not EnemyKit.has_enemy(run.map.get_node(id).content) or not dist.has(id):
			continue
		if int(dist[id]) <= 2 and near < 0:
			near = id
		if int(dist[id]) >= 5 and far < 0:
			far = id
	t.check(near >= 0 and far >= 0, "图上有近处和远处的敌人（%d / %d）" % [near, far])
	if near < 0 or far < 0:
		return
	t.check(run.intel_visible(near), "两步以内看得清")
	t.check(not run.intel_visible(far), "远处看不清")
	t.check(plain.intel_visible(far), "普通难度：都看得清")
	var tip := NodeTooltip.text_for(run, run.chapter, run.map.get_node(far))
	t.check(tip.contains(UiText.t("node.unknown_enemy")), "远处的浮窗写敌情不明（%s）" % tip)
	t.check(not NodeTooltip.shows_board(run.map.get_node(far), run), "远处不画对手的棋盘")
	var name := Names.of(c.enemies.enemy(StringName(String(run.map.get_node(far).content.get("enemy", "")))))
	t.check(name == "" or not tip.contains(name), "远处的浮窗不写敌人的名字")
	run.intel_seen[far] = true
	t.check(run.intel_visible(far), "揭示过的一直看得清")
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), run.chapter, c.items, c.enemies, c.sets)
	t.check(back != null and back.intel_seen.has(far), "揭示过的跟着存档走")
