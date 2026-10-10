## 117（作者定）：战斗的内部日志（BattleTrace，逐条、带时间、写文件）与回放存档（开发工具里翻）。
## 开着 trace 打出来的那场和关着逐条一样；日志里有 before_damage、规则出手 / 跳过、伤害管线、随机数、buff、快照；
## 回放存档 JSON 来回等价；只留最近 N 场；正式一局按设置写文件；回放浏览能读能播；replay_log 命令行打得出双方
extends RefCounted

const DIR := "user://test_117_logs"
const BROWSER := "res://ui/battle/replay_browser.tscn"


static func _cleanup() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(DIR.path_join(f))
	DirAccess.remove_absolute(DIR)


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 一场有毒（buff）、有暴击掷骰（默认暴击率）、耐力会见底（跳过）的仗
static func _pair(db: ItemDatabase) -> Array:
	var weak := CombatantBaseline.with_hp(400.0)
	weak.base_stats["max_stamina"] = 12.0
	weak.base_stats["regen_stamina"] = 1.0
	var me := BattleCompiler.compile_board(LootPacker.board_of([&"poisoned_knife", &"longsword", &"shortsword"] as Array[StringName], Vector2i(5, 5), db), weak)
	var foe := BattleCompiler.compile_board(LootPacker.board_of([&"knife", &"salve"] as Array[StringName], Vector2i(4, 4), db), CombatantBaseline.with_hp(160.0))
	return [me, foe]


static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 117
	return r


static func _same_log(a: Array[BattleEvent], b: Array[BattleEvent]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x := a[i]
		var y := b[i]
		if x.name != y.name or x.time != y.time or x.side != y.side or x.payload != y.payload:
			return false
	return true


static func _has_event(trace: BattleTrace, name: String) -> bool:
	for e in trace.of_kind(BattleTrace.EVENT):
		if String(e["data"]["name"]) == name:
			return true
	return false


static func run_trace_contents(t: TestCase) -> void:
	t.begin("117 · 内部日志：开着 trace 打的那场和关着逐条一样；日志里有 before_damage、出手 / 跳过（带原因）、伤害管线、随机数、buff、快照与时间轮")
	var db := _items()
	var pair := _pair(db)
	var plain := BattleSim.run(pair[0], pair[1], _rng(), 60.0)
	var trace := BattleTrace.new()
	var traced := BattleSim.run(pair[0], pair[1], _rng(), 60.0, null, trace)
	t.check(_same_log(plain.log, traced.log), "回放日志逐条相同（%d 条）" % plain.log.size())
	t.eq(traced.winner, plain.winner, "胜负一样")
	t.eq(traced.duration, plain.duration, "时长一样")
	t.check(trace.of_kind(BattleTrace.EVENT).size() >= plain.log.size(), "内部日志的事件不少于回放日志（%d ≥ %d）" % [trace.of_kind(BattleTrace.EVENT).size(), plain.log.size()])
	t.check(_has_event(trace, "before_damage"), "同步派发的 before_damage 也记了")
	t.check(not trace.of_kind(BattleTrace.RULE_FIRE).is_empty(), "有规则出手")
	var cost_skip := false
	for e in trace.of_kind(BattleTrace.RULE_SKIP):
		if String(e["data"].get("reason", "")) == "cost" and (e["data"]["cost"] as Dictionary).has("resource"):
			cost_skip = true
	t.check(cost_skip, "有因资源不够跳过的出手（写了哪种资源、要多少、有多少）")
	var dmg := trace.of_kind(BattleTrace.DAMAGE)
	t.check(not dmg.is_empty(), "有伤害管线")
	var first: Dictionary = dmg[0]["data"] if not dmg.is_empty() else {}
	for key in ["raw_in", "raw", "absorbed", "block", "taken", "final", "hp_before", "hp_after"]:
		t.check(first.has(key), "管线一条带「%s」" % key)
	t.check(not trace.of_kind(BattleTrace.RNG).is_empty(), "有随机数（暴击掷骰）")
	t.check(not trace.of_kind(BattleTrace.BUFF).is_empty(), "有 buff 叠层")
	var snaps := trace.of_kind(BattleTrace.SNAPSHOT)
	t.check(snaps.size() >= 3, "快照：开战、节拍、结束（%d 张）" % snaps.size())
	t.eq(String(snaps[0]["data"]["label"]), "开战", "第一张是开战")
	t.eq(String(snaps[-1]["data"]["label"]), "结束", "最后一张是结束")
	t.check(not trace.of_kind(BattleTrace.SCHEDULE).is_empty(), "有时间轮的节拍")
	var ordered := true
	for i in range(1, trace.entries.size()):
		if int(trace.entries[i]["seq"]) != i:
			ordered = false
	t.check(ordered, "seq 连续")
	# 掩码不变式照旧：trace 开着时掩码开关两条路径的回放日志仍然逐条相同
	var ctx_on := BattleContext.create(CombatantRuntime.from_spec(pair[0], 0), CombatantRuntime.from_spec(pair[1], 1), _rng())
	ctx_on.trace = BattleTrace.new()
	var ctx_off := BattleContext.create(CombatantRuntime.from_spec(pair[0], 0), CombatantRuntime.from_spec(pair[1], 1), _rng())
	ctx_off.trace = BattleTrace.new()
	ctx_off.mask_enabled = false
	t.check(_same_log(BattleSim.run_context(ctx_on, 60.0).log, BattleSim.run_context(ctx_off, 60.0).log), "trace 开着，掩码开 / 关逐条相同")
	# 排版：一行一条、双方都在
	trace.header = {"when": "test", "names": [{1: "甲"}, {1: "乙"}]}
	var text := trace.to_text()
	t.check(text.contains("] S0 ") and text.contains("] S1 "), "人读版有 S0 与 S1 两方")
	t.check(text.contains("damage") and text.contains("fire") and text.contains("skip"), "人读版有伤害 / 出手 / 跳过")
	var back := BattleTrace.parse_jsonl(trace.to_jsonl())
	t.eq((back["entries"] as Array).size(), trace.entries.size(), "jsonl 读回来条数一样")
	t.eq(int(back["bad"]), 0, "没有坏行")


static func run_result_roundtrip(t: TestCase) -> void:
	t.begin("117 · 回放存档：BattleResult 经 JSON 来回等价（日志逐条 name / time / side / payload、胜负、时长、开战快照）；buff 按 id 回查")
	var db := _items()
	var pair := _pair(db)
	var r := BattleSim.run(pair[0], pair[1], _rng(), 60.0)
	var text := JSON.stringify(JSON.from_native(r.to_dict()))
	var back := BattleResult.from_dict(JSON.to_native(JSON.parse_string(text)), r.buffs)
	t.check(_same_log(r.log, back.log), "日志逐条相同（%d 条）" % r.log.size())
	t.eq(back.winner, r.winner, "胜负")
	t.eq(back.duration, r.duration, "时长")
	t.check(back.initial == r.initial, "开战快照相同（int 键的冷却表也还原了）")
	t.eq(back.buffs.size(), r.buffs.size(), "buff 都按 id 找回来了")
	t.check(BattleResult.from_dict(r.to_dict()).buffs.is_empty(), "查不到的 buff 跳过")


static func run_writer_and_prune(t: TestCase) -> void:
	t.begin("117 · 写文件：一场三份（.jsonl / .txt / .replay.json）；只留最近 N 场，多的三份一起删；列表新的在前；坏文件跳过")
	_cleanup()
	var db := _items()
	var pair := _pair(db)
	var info := {"run_seed": 5, "chapter": "free_mode", "node": 3, "enemy": "raider", "names": [{1: "甲"}, {1: "乙"}], "boards": [{}, {}]}
	var bases: Array[String] = []
	for i in 3:
		var trace := BattleTrace.new()
		var r := BattleSim.run(pair[0], pair[1], _rng(), 60.0, null, trace)
		info["node"] = i
		bases.append(BattleTraceWriter.write(trace, r, info, DIR, 2))
	for ext in [BattleArchive.TRACE_EXT, BattleArchive.TEXT_EXT, BattleArchive.REPLAY_EXT]:
		t.check(FileAccess.file_exists(bases[2] + String(ext)), "最新一场有 %s" % ext)
		t.check(not FileAccess.file_exists(bases[0] + String(ext)), "最旧一场的 %s 删了" % ext)
	t.eq(BattleArchive.stems(DIR).size(), 2, "只留 2 场")
	var listed := BattleArchive.list(DIR)
	t.eq(listed.size(), 2, "列出 2 场")
	t.eq(int(listed[0]["node"]), 2, "新的在前")
	var replay := BattleArchive.load_replay(String(listed[0]["path"]))
	t.eq(String(replay.get("chapter", "")), "free_mode", "元数据照原样")
	t.eq(String((replay["names"] as Array)[0][1]), "甲", "名字表还原成 int 键")
	t.not_null(BattleArchive.result_of(replay), "能还原成 BattleResult")
	var head: Dictionary = BattleTrace.parse_jsonl(FileAccess.get_file_as_string(bases[2] + BattleArchive.TRACE_EXT))["header"]
	t.check(head.has("when") and head.has("initial") and head.has("run_seed"), "日志文件头有现实时间、开战快照、种子")
	var bad := FileAccess.open(DIR.path_join("99999999-999999_bad" + BattleArchive.REPLAY_EXT), FileAccess.WRITE)
	bad.store_string("{不是 json")
	bad.close()
	t.eq(BattleArchive.list(DIR).size(), 2, "坏文件跳过")
	_cleanup()


static func run_settings(t: TestCase) -> void:
	t.begin("117 · 设置：战斗日志默认按包的类型（非导出包开），存档来回；正式一局按设置给 NodeEvents 填好 / 清掉")
	t.eq(GameSettings.new().battle_trace, BattleArchive.default_on(), "默认值按包的类型")
	var s := GameSettings.new()
	s.battle_trace = not BattleArchive.default_on()
	t.eq(GameSettings.from_dict(s.to_dict()).battle_trace, s.battle_trace, "存档来回")
	t.eq(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION}).battle_trace, BattleArchive.default_on(), "旧文件没有这一项：按默认")


static func run_real_run_writes(t: TestCase) -> void:
	t.begin("117 · 正式一局：NodeEvents 开着日志打一场 → user 目录里多一场（种子、章节、点、对手都在），回放存档的胜负和这场一样")
	_cleanup()
	var db := _items()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var s: RunState = null
	for seed in range(1, 60):
		s = RunState.start(chapter, seed, db, enemies, sets)
		if s != null:
			s.pick_spawn(s.map.entry_ids[0])
			break
	if s == null:
		t.check(false, "开不了局")
		return
	var node: MapNode = null
	for id in s.map.node_ids():
		var n := s.map.get_node(id)
		if n.type == &"battle" and EnemyKit.has_enemy(n.content):
			node = n
			break
	t.not_null(node, "图上有带敌人的点")
	if node == null:
		return
	BattleArchive.enabled = true
	s.events.trace_info = {"dir": DIR, "run_seed": s.run_seed, "chapter": String(chapter.id)}
	var won := s.events.fight_content(node, &"battle", node.content, null, 0)
	BattleArchive.enabled = false
	var listed := BattleArchive.list(DIR)
	t.eq(listed.size(), 1, "多了一场")
	if listed.is_empty():
		return
	var e: Dictionary = listed[0]
	t.eq(e["node"], node.id, "点 id")
	t.eq(String(e["chapter"]), "free_mode", "章节")
	t.eq(String(e["enemy"]), String(node.content.get("enemy", "")), "对手")
	t.eq(int(e["winner"]) == 0, won, "胜负和这场一样")
	t.check(String(e["stem"]).contains("_%d_" % s.run_seed), "文件名带种子")
	var replay := BattleArchive.load_replay(String(e["path"]))
	t.check(not ((replay["names"] as Array)[1] as Dictionary).is_empty(), "敌方道具名表有东西")
	t.check(not ((replay["boards"] as Array)[0] as Dictionary).is_empty(), "我方棋盘存了")
	s.events.trace_info = {}
	s.events.fight_content(node, &"battle", node.content, null, 0)
	t.eq(BattleArchive.list(DIR).size(), 1, "trace_info 空：不写")


static func run_replay_log_tool(t: TestCase) -> void:
	t.begin("117 · replay_log 命令行：读 .jsonl 按人读格式打出来（含 S0 / S1）；--summary 打双方伤害与出手次数；没有文件退出码 1")
	_cleanup()
	var db := _items()
	var pair := _pair(db)
	var trace := BattleTrace.new()
	var r := BattleSim.run(pair[0], pair[1], _rng(), 60.0, null, trace)
	var base := BattleTraceWriter.write(trace, r, {"run_seed": 1, "chapter": "t", "node": 1, "enemy": "e", "names": [{}, {}], "boards": [{}, {}]}, DIR)
	var exe := OS.get_executable_path()
	var root := ProjectSettings.globalize_path("res://")
	var out: Array = []
	var code := OS.execute(exe, ["--headless", "--path", root, "--script", "res://tools/replay_log.gd", "--", ProjectSettings.globalize_path(base + BattleArchive.TRACE_EXT)], out, true)
	var text := "\n".join(out)
	t.eq(code, 0, "退出码 0")
	t.check(text.contains("] S0 ") and text.contains("] S1 "), "输出含 S0 与 S1")
	out = []
	code = OS.execute(exe, ["--headless", "--path", root, "--script", "res://tools/replay_log.gd", "--", ProjectSettings.globalize_path(base + BattleArchive.TRACE_EXT), "--summary"], out, true)
	text = "\n".join(out)
	t.eq(code, 0, "--summary 退出码 0")
	t.check(text.contains("S0　造成伤害") and text.contains("S1　造成伤害") and text.contains("出手"), "摘要有双方伤害与出手次数")
	out = []
	code = OS.execute(exe, ["--headless", "--path", root, "--script", "res://tools/replay_log.gd", "--", "/no/such/file.jsonl"], out, true)
	t.eq(code, 1, "没有文件：退出码 1")
	_cleanup()


static func frame_replay_browser(t: TestCase, root: Window) -> void:
	t.begin("117 · 开发工具的「战斗回放」：列出存档（新的在上），点一场交给 BattleView 从头播、双方名字与棋盘接上，跳过后游标在末尾；启动选择器里有入口")
	_cleanup()
	var db := _items()
	var pair := _pair(db)
	var names := [{}, {}]
	for side in 2:
		for item in (pair[side] as CombatantSpec).items:
			names[side][item.source_uid] = String(item.def_id)
	for i in 2:
		var trace := BattleTrace.new()
		var r := BattleSim.run(pair[0], pair[1], _rng(), 60.0, null, trace)
		BattleTraceWriter.write(trace, r, {"run_seed": 9, "chapter": "free_mode", "node": i, "enemy": "raider", "names": names,
			"boards": [(pair[0] as CombatantSpec).board.to_dict(), (pair[1] as CombatantSpec).board.to_dict()]}, DIR)
	var browser = (load(BROWSER) as PackedScene).instantiate()
	browser.dir = DIR
	root.add_child(browser)
	t.eq(browser.entries().size(), 2, "列出两场")
	t.eq(int(browser.entries()[0]["node"]), 1, "新的在上")
	t.check(not browser.open_entry(5), "不存在的一场：false")
	t.check(browser.open_entry(0), "打开第一场")
	var view: BattleView = browser.view
	t.not_null(view._result, "回放拿到结果")
	t.eq(view._cursor, 0, "从头播")
	t.not_null(view.board_view(0).inventory, "我方棋盘接上了")
	view.skip_to_end()
	t.eq(view._cursor, view._result.log.size(), "跳过：游标走到末尾")
	var has_entry := false
	for e in load("res://ui/launcher.gd").ENTRIES:
		if String(e["scene"]) == BROWSER:
			has_entry = true
	t.check(has_entry, "启动选择器里有「战斗回放」")
	browser.queue_free()
	_cleanup()
