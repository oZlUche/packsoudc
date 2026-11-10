## 平衡检测方案（2026-11-10）§4：实验元数据、记录行的来源 / 构建 / 局标识、校准数据审计（夹具：坏行、重复导出、
## 同种子不同局、老格式、未知格式、缺字段、非有限数、两个构建混合）
extends RefCounted

const MIXED := "res://tests/fixtures/audit/mixed"
const CLEAN := "res://tests/fixtures/audit/clean"


static func _items() -> ItemDatabase:
	var items := ItemDatabase.new()
	items.load_dir()
	return items


static func run_manifest(t: TestCase) -> void:
	t.begin("实验元数据")
	var m := ExperimentManifest.make(ExperimentManifest.SYNTHETIC, {"fights": 100}, ["res://tests/fixtures/audit/clean"] as Array[String], {"b": 1, "a": 2})
	for k in ["schema_version", "experiment_id", "source", "build_id", "engine_version", "content_hash", "suite_hash", "seed_manifest", "config", "started_at"]:
		t.check(m.has(k), "manifest 有 %s" % k)
	t.eq(m["source"], ExperimentManifest.SYNTHETIC, "来源照写")
	t.check(String(m["build_id"]) != "", "构建标识不空")
	t.eq(ExperimentManifest.canonical_hash({"a": 2, "b": 1}), m["suite_hash"], "摘要不看键的顺序")
	t.check(ExperimentManifest.canonical_hash({"a": 1}) != ExperimentManifest.canonical_hash({"a": 2}), "内容不同摘要不同")
	var h1 := ExperimentManifest.content_hash(["res://tests/fixtures/audit/clean"] as Array[String])
	t.eq(h1, ExperimentManifest.content_hash(["res://tests/fixtures/audit/clean"] as Array[String]), "同一目录摘要稳定")
	t.check(h1 != ExperimentManifest.content_hash(["res://tests/fixtures/audit/mixed"] as Array[String]), "不同目录摘要不同")
	t.eq(ExperimentManifest.content_hash(["res://no_such_dir"] as Array[String]), "", "目录不在 = 空串")
	t.check(ExperimentManifest.new_id("run") != ExperimentManifest.new_id("run"), "标识不重")
	var row := ExperimentManifest.stamp({"x": 1}, ExperimentManifest.AUTO)
	t.eq(row[ExperimentManifest.K_SCHEMA], ExperimentManifest.ROW_SCHEMA, "打上格式版本")
	t.eq(row[ExperimentManifest.K_SOURCE], ExperimentManifest.AUTO, "打上来源")


static func run_build_info(t: TestCase) -> void:
	t.begin("构建标识")
	var dir := "user://test_audit_git"
	DirAccess.make_dir_recursive_absolute(dir + "/.git/refs/heads")
	var f := FileAccess.open(dir + "/.git/HEAD", FileAccess.WRITE)
	f.store_string("ref: refs/heads/main\n")
	f.close()
	f = FileAccess.open(dir + "/.git/refs/heads/main", FileAccess.WRITE)
	f.store_string("0123456789abcdef0123456789abcdef01234567\n")
	f.close()
	t.eq(BuildInfo.git_head(ProjectSettings.globalize_path(dir)), "0123456789abcdef0123456789abcdef01234567", "跟着 HEAD 的分支找提交号")
	DirAccess.remove_absolute(dir + "/.git/refs/heads/main")
	f = FileAccess.open(dir + "/.git/packed-refs", FileAccess.WRITE)
	f.store_string("# pack-refs\nfedcba9876543210fedcba9876543210fedcba98 refs/heads/main\n")
	f.close()
	t.eq(BuildInfo.git_head(ProjectSettings.globalize_path(dir)), "fedcba9876543210fedcba9876543210fedcba98", "分支在 packed-refs 里也找得到")
	t.eq(BuildInfo.git_head(ProjectSettings.globalize_path("user://no_repo_here")), "", "不是仓库 = 空")
	BuildInfo.reset()
	t.check(BuildInfo.id() != "", "构建标识总有值")


static func run_recorder_rows(t: TestCase) -> void:
	t.begin("记录行带来源、构建、局标识")
	t.eq(CalibrationRecorder.current_source(), ExperimentManifest.TEST, "测试里写的行标成 test")
	var saved := CalibrationRecorder.source_override
	CalibrationRecorder.source_override = ""
	t.eq(CalibrationRecorder.current_source(), ExperimentManifest.HUMAN, "没人改就是真人")
	CalibrationRecorder.source_override = saved
	t.check("run_id" in AssumptionStats.META and "battle_id" in AssumptionStats.META and "source" in AssumptionStats.META,
		"系数假设行抄这几个键")
	var head := ExperimentManifest.stamp({"run_id": "run-x", "battle_id": "run-x:5", "rng_seed": 5}, ExperimentManifest.TEST)
	var row := AssumptionStats.of(null, head)
	t.eq(row.get("battle_id", ""), "run-x:5", "战斗标识进了行")
	t.eq(row.get("schema", 0), ExperimentManifest.ROW_SCHEMA, "格式版本进了行")


static func run_audit_mixed(t: TestCase) -> void:
	t.begin("审计：坏数据夹具")
	var a := DataAudit.run(MIXED, {}, _items())
	var s: Dictionary = a["files"][DataAudit.SNAPSHOTS]
	t.eq(s["lines"], 14, "快照 14 行")
	t.eq(s["bad_lines"], 1, "一行坏 JSON")
	t.eq(s["bad_line_numbers"], [3], "坏在第 3 行")
	t.eq(s["duplicates"], 1, "完全重复的导出去掉一行")
	var ex: Dictionary = s["excluded"]
	for r in [DataAudit.R_UNKNOWN_SCHEMA, DataAudit.R_MISSING, DataAudit.R_BAD_SEED, DataAudit.R_UNKNOWN_ITEM,
			DataAudit.R_ILLEGAL_LAYOUT, DataAudit.R_CONFLICT, DataAudit.R_NON_FINITE]:
		t.eq(int(ex.get(r, 0)), 1, "排除 1 行：%s" % r)
	t.eq(s["valid"], 5, "有效 5 行（含同种子另一局、老格式、另一个构建）")
	t.eq(s["legacy"], 1, "老格式 1 行")
	t.check(s["reconciled"], "快照对得上账")
	var asm: Dictionary = a["files"][DataAudit.ASSUMPTIONS]
	t.eq(int(asm["excluded"].get(DataAudit.R_MISSING, 0)), 1, "系数假设缺 winner 的排除")
	t.check(asm["reconciled"], "系数假设对得上账")
	t.check(a["mixed"], "三个构建分组：混了")
	t.eq((a["groups"] as Dictionary).size(), 3, "git:aaa、git:bbb、老版本号各一组")
	t.check("mixed_builds" in a["severe"], "不放行混合：算严重")
	t.check("snapshots:bad_lines" in a["severe"] and "snapshots:conflict" in a["severe"] and "snapshots:unknown_schema" in a["severe"], "坏行、冲突、未知格式算严重")
	t.check("mixed_sources" in a["warnings"], "来源混了：警告")
	t.eq(a["exit_code"], DataAudit.EXIT_OK, "不严格：退出码 0")
	var ch: Dictionary = a["chains"]
	t.eq(ch["result_without_snapshots"], 1, "有结果没快照的局 1 个")
	t.eq(ch["snapshots_without_result"], 2, "有快照没结果的局 2 个")
	t.eq(ch["step_regressions"], 0, "同一局步数没倒退")
	t.eq(a["reproducibility"], {"approximate": 4, "unknown": 1}, "新格式快照 approximate，老格式 unknown")
	t.eq(DataAudit.run(MIXED, {"strict": true}, _items())["exit_code"], DataAudit.EXIT_REJECT, "严格：退出码 2")
	var allow := DataAudit.run(MIXED, {"strict": true, "allow_mixed": true}, _items())
	t.check("mixed_builds" in allow["warnings"] and not ("mixed_builds" in allow["severe"]), "放行混合：降为警告")
	t.eq(allow["exit_code"], DataAudit.EXIT_REJECT, "还有坏行，严格照样拒绝")
	var md := DataAudit.markdown(a)
	t.check(md.contains("## 对账") and md.contains("git:bbb") and md.contains("unknown_item"), "报告列对账、分组、原因")


static func run_audit_filters(t: TestCase) -> void:
	t.begin("审计：筛选与干净数据")
	var human := DataAudit.run(MIXED, {"source": "human"}, _items())
	t.eq(human["files"][DataAudit.RUNS]["filtered"], 1, "按来源筛：自动脚本那一局筛掉")
	t.eq(human["files"][DataAudit.SNAPSHOTS]["filtered"], 1, "老格式没写来源（unknown）也筛掉")
	t.check(human["files"][DataAudit.SNAPSHOTS]["reconciled"], "筛完照样对账")
	var bbb := DataAudit.run(MIXED, {"build": "git:bbb"}, _items())
	t.eq(bbb["files"][DataAudit.SNAPSHOTS]["valid"], 1, "按构建筛只剩 1 行")
	t.check(not bbb["mixed"], "筛完不混")
	var clean := DataAudit.run(CLEAN, {"strict": true}, _items())
	t.eq(clean["exit_code"], DataAudit.EXIT_OK, "干净数据严格也通过")
	t.check((clean["severe"] as Array).is_empty(), "干净数据没有严重问题")
	var none := DataAudit.run("res://tests/fixtures/audit/no_such", {"strict": true})
	t.check("no_data" in none["severe"], "一个文件都没有：严重")
	t.eq(none["exit_code"], DataAudit.EXIT_REJECT, "严格：拒绝")
