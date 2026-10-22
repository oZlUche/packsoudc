## 242 平衡方法第一批：流派木桩（五路 × 四段都摆得进开局棋盘、编得过、有武器）；扫表（一格 10 场跑通、四张表都在）；
## 对局记录（一局一行、带版本号，快照也带）；导出 zip（两个目录都在）；战斗日志滚动删到 200
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const SNAPS := "user://test_242_snapshots.jsonl"
const RUNS := "user://test_242_runs.jsonl"
const CAL_DIR := "user://test_242_calibration"
const LOG_DIR := "user://test_242_battle_logs"
const ZIP := "user://test_242_export.zip"


static func _items() -> ItemDatabase:
	var items := ItemDatabase.new()
	items.load_dir()
	return items


static func _pool() -> EnemyPool:
	return ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool


static func _marcus() -> CharacterDef:
	return ContentPaths.load_asset("characters", String(ArchetypeBuilder.CHARACTER)) as CharacterDef


static func _wipe_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_wipe_dir(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


static func _cleanup() -> void:
	for p in [SNAPS, RUNS, ZIP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_wipe_dir(CAL_DIR)
	_wipe_dir(LOG_DIR)


static func run_archetypes(t: TestCase) -> void:
	t.begin("242 ① 流派木桩：五路 × 四段都摆进开局棋盘（8 × 6、要包）、编得过、带武器；件数在同号档的范围里；同种子可复现")
	var items := _items()
	var pool := _pool()
	var brackets := BalanceMatrix.brackets_of("ascension_3")
	t.eq(brackets, [0, 5, 10, 20] as Array[int], "段位表取难度Ⅲ的猎手段位")
	var dummies := ArchetypeBuilder.build(pool, items, brackets, _marcus(), 1)
	t.eq(dummies.size(), ArchetypeBuilder.ARCHETYPES.size() * brackets.size(), "五路 × 四段，一个种子各一份")
	for a in ArchetypeBuilder.ARCHETYPES:
		for k in brackets.size():
			var d: Dictionary = dummies.get(ArchetypeBuilder.key_of(a, k, 0), {})
			var tag := "%s 段 %d" % [a, k]
			t.check(not d.is_empty(), tag + "：有")
			if d.is_empty():
				continue
			t.eq(d["board_size"], [RunState.BOARD_SIZE.x, RunState.BOARD_SIZE.y], tag + "：开局棋盘的尺寸")
			t.check(bool(d["requires_bag"]), tag + "：要包的棋盘（和玩家一样）")
			var tier := pool.tier_of(pool.clamp_strength(k))
			var picked: Array = d["picked"]
			t.check(picked.size() >= tier.item_count.x, tag + "：件数不少于第 %d 档的下限（%d 件）" % [k, picked.size()])
			var board := CalibrationRecorder.board_of(d, items)
			t.eq(board.item_count(), (d["layout"] as Array).size(), tag + "：按记录原样摆得回去")
			var armed := false
			for inst in board.items():
				armed = armed or (inst as ItemInstance).def.tags.has(&"weapon")
			t.check(armed, tag + "：棋盘上有一件武器（防御两路也补了）")
			var spec := DummyBuilder.compile(d, items)
			t.check(spec != null and spec.items.size() > 0, tag + "：编得过，有战斗道具")
			if k >= brackets.size() - 2:
				t.check((d["bags"] as Array).size() > _marcus().starting_bags.size(), tag + "：后两段多背一个包")
	var again := ArchetypeBuilder.build(pool, items, brackets, _marcus(), 1)
	t.eq(JSON.stringify(again), JSON.stringify(dummies), "同种子逐字相同")
	t.eq(DummyBuilder.save(dummies, SNAPS), OK, "存成木桩文件（073 格式）")
	t.eq(DummyBuilder.load_file(SNAPS).size(), dummies.size(), "读回来份数一样")
	_cleanup()


static func run_matrix(t: TestCase) -> void:
	t.begin("242 第 2 项 扫表：一格 10 场跑通，胜率 0～1，四张表 + 单调性检查都在，表头带参数")
	var items := _items()
	var pool := _pool()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var brackets: Array[int] = [0, 5]
	var two: Array[StringName] = [&"burst", &"shield"]
	var dummies := ArchetypeBuilder.build(pool, items, brackets, _marcus(), 1, two)
	var result := BalanceMatrix.run(dummies, pool, enemies, items, 10, 3)
	t.eq(result["archetypes"], ["burst", "shield"] as Array[String], "两路")
	t.eq(result["brackets"], [0, 1] as Array[int], "两段")
	t.eq(result["tiers"], pool.strengths(), "池里每一档都扫")
	var cells: Dictionary = result["cells"]
	t.eq(cells.size(), 4, "两路 × 两段 = 四行")
	for g in cells:
		for tier in pool.strengths():
			var c: Dictionary = (cells[g] as Dictionary)[tier]
			t.eq(int(c["fights"]), 10, "%s 档 %d：打了 10 场" % [g, tier])
			t.check(float(c["rate"]) >= 0.0 and float(c["rate"]) <= 1.0, "%s 档 %d：胜率在 0～1" % [g, tier])
			t.check(float(c["duration"]) > 0.0, "%s 档 %d：有时长" % [g, tier])
			t.check(float(c["hp_left"]) >= 0.0 and float(c["hp_left"]) <= 1.0, "%s 档 %d：余血比例在 0～1" % [g, tier])
	var again := BalanceMatrix.run(dummies, pool, enemies, items, 10, 3)
	t.eq(JSON.stringify(again), JSON.stringify(result), "同种子结果逐字相同")
	var md := BalanceMatrix.markdown(result, "测试", ["参数一行", "git abc123"] as Array[String])
	for head in ["## 一 胜率", "## 二 平均时长", "## 三 赢时余血", "## 四 同段五路极差", "## 单调性检查"]:
		t.check(md.contains(head), "有「%s」" % head.trim_prefix("## "))
	t.check(md.contains("- git abc123"), "表头印了参数")
	t.check(md.contains("★"), "同段同档那格打了星")


static func run_runs_jsonl(t: TestCase) -> void:
	t.begin("242 ③④ 对局记录：一局结束 runs.jsonl 记一行（对局结果 + 版本号 + 角色 + 难度），再结算一次不重记；快照也带版本号")
	_cleanup()
	t.eq(CalibrationRecorder.version(), "0.1.0", "版本号 = project.godot 的 0.1.0")
	var c := TestSupport.load_content("free_mode", ["loadouts", "characters", "difficulties"])
	var f := Support.flow(c, "t242")
	f.recorder = CalibrationRecorder.new(SNAPS, RUNS)
	var run: RunState = null
	for seed in range(1, 20):
		run = f.begin(c.chapter, c.loadouts[0], seed)
		if run != null:
			break
	t.not_null(run, "开局")
	if run == null:
		return
	f.pick_spawn(run.map.entry_ids[0])
	t.check(f.step_to(run.travel.available_moves()[0]), "走一步")
	var snaps := CalibrationRecorder.read_all(SNAPS)
	t.eq(snaps.size(), 1, "走一步记一份快照")
	t.eq(String(snaps[0].get("version", "")), "0.1.0", "快照带版本号")
	t.check(run.force_extract(), "撤离")
	f._show_result()
	f._settle_run()     # 再结算一次：只记一次
	var rows := CalibrationRecorder.read_all(RUNS)
	t.eq(rows.size(), 1, "一局一行")
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		t.eq(String(row["version"]), "0.1.0", "带版本号")
		t.eq(String(row["outcome"]), String(f.result.outcome), "对局结果照 RunResult.to_dict")
		t.eq(int(row["seed"]), run.run_seed, "种子")
		t.eq(String(row["character"]), String(run.character_id), "角色")
		t.eq(String(row["difficulty"]), String(run.difficulty_id), "难度")
	Support.cleanup("t242")
	_cleanup()


static func run_export_zip(t: TestCase) -> void:
	t.begin("242 第 5 项 导出平衡数据：zip 里两个目录都在（空的也留目录项），文件按目录名放、子目录也进；文件名带日期")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(CAL_DIR)
	DirAccess.make_dir_recursive_absolute(LOG_DIR.path_join("old"))
	var f := FileAccess.open(CAL_DIR.path_join("runs.jsonl"), FileAccess.WRITE)
	f.store_line("{\"version\":\"0.1.0\"}")
	f.close()
	f = FileAccess.open(LOG_DIR.path_join("old").path_join("a.txt"), FileAccess.WRITE)
	f.store_string("日志")
	f.close()
	var n := DataExport.pack(ZIP, [CAL_DIR, LOG_DIR] as Array[String])
	t.eq(n, 2, "装了两个文件")
	var zip := ZIPReader.new()
	t.eq(zip.open(ZIP), OK, "zip 打得开")
	var names := zip.get_files()
	for want in ["test_242_calibration/", "test_242_battle_logs/", "test_242_calibration/runs.jsonl", "test_242_battle_logs/old/a.txt"]:
		t.check(names.has(want), "zip 里有 %s" % want)
	t.eq(zip.read_file("test_242_calibration/runs.jsonl").get_string_from_utf8().strip_edges(), "{\"version\":\"0.1.0\"}", "内容原样")
	zip.close()
	_wipe_dir(LOG_DIR)
	t.eq(DataExport.pack(ZIP, [CAL_DIR, LOG_DIR] as Array[String]), 1, "日志目录没有：照样打包")
	zip = ZIPReader.new()
	zip.open(ZIP)
	t.check(zip.get_files().has("test_242_battle_logs/"), "没有的目录也留个目录项")
	zip.close()
	t.eq(DataExport.file_name("2026-10-22"), "背包搜打撤-数据-2026-10-22.zip", "文件名带日期")
	t.check(DataExport.target_dir() != "", "有地方放（桌面或 user://）")
	t.eq(DataExport.DIRS, [CalibrationRecorder.DIR, BattleArchive.DIR] as Array[String], "默认打包校准记录与战斗日志两个目录")
	_cleanup()


static func run_archive_keeps_200(t: TestCase) -> void:
	t.begin("242 ⑥ 战斗日志留 200 场：多出来的最旧几场三份一起删")
	t.eq(BattleArchive.KEEP, 200, "上限 200")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	for i in BattleArchive.KEEP + 3:
		for ext in BattleArchive.EXTS:
			var f := FileAccess.open(LOG_DIR.path_join("20261022-%06d_1_n0_c_e%s" % [i, ext]), FileAccess.WRITE)
			f.close()
	t.eq(BattleArchive.prune(LOG_DIR), 3, "删了最旧的 3 场")
	var left := BattleArchive.stems(LOG_DIR)
	t.eq(left.size(), 200, "剩 200 场")
	t.eq(left[0], "20261022-000003_1_n0_c_e", "最旧的三场没了")
	t.eq(DirAccess.get_files_at(LOG_DIR).size(), 600, "每场三份都在 / 都删")
	_cleanup()
