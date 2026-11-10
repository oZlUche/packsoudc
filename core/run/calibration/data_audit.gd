## 平衡检测方案（2026-11-10）§4.2：校准目录（或导出包解开的目录）的数据审计。只读，不改任何文件。
##
## 读 `snapshots.jsonl`（每步配置）、`runs.jsonl`（对局结果）、`assumptions.jsonl`（每场系数假设）三种行，逐行判：
## 坏行、未知格式、完全重复（同一份导出了两次）、同标识不同内容、缺字段、非有限数、坏种子、读不出的道具、摆不回去的棋盘；
## 再看记录链（局有快照没结果、有结果没快照、步数倒退）和版本、来源有没有混在一起。
## 每个文件对账：总行数 = 坏行 + 重复 + 排除 + 筛掉 + 有效。
## 老格式（没有 `schema` 键）的行照读，复现程度标 unknown；不补造局标识或战斗上下文。
## 结果 [method run] 返回一个字典，[method markdown] 排成表；`tools/audit_balance_data.gd` 写 `audit.json` / `audit.md`
class_name DataAudit
extends RefCounted

## 退出码：0 通过（可能带警告），1 用法或读写错误，2 严格模式下拒绝（严重损坏或版本混合）
const EXIT_OK := 0
const EXIT_USAGE := 1
const EXIT_REJECT := 2

const SNAPSHOTS := "snapshots"
const RUNS := "runs"
const ASSUMPTIONS := "assumptions"
const KINDS: Array[String] = [SNAPSHOTS, RUNS, ASSUMPTIONS]

## 每种行少了就排除的字段
const REQUIRED := {
	SNAPSHOTS: ["version", "seed", "chapter", "steps", "board_size", "layout"],
	RUNS: ["version", "seed", "chapter", "outcome", "steps"],
	ASSUMPTIONS: ["version", "seed", "winner"],
}
## 每种行少了只记一笔的字段（统计时写 null，不当 0）
const OPTIONAL := {
	SNAPSHOTS: ["character", "difficulty", "baseline", "searches", "run_id", "source", "build"],
	RUNS: ["character", "difficulty", "score", "balance", "run_id", "source", "build"],
	ASSUMPTIONS: ["fight_sec", "opponent_dps", "tier", "steps", "character", "run_id", "battle_id", "source", "build"],
}

## 排除原因
const R_UNKNOWN_SCHEMA := "unknown_schema"
const R_MISSING := "missing_field"
const R_NON_FINITE := "non_finite"
const R_BAD_SEED := "bad_seed"
const R_UNKNOWN_ITEM := "unknown_item"
const R_ILLEGAL_LAYOUT := "illegal_layout"
const R_CONFLICT := "conflict"


## 审计 [param dir]。[param opts]：`build` / `chapter` / `character` / `source`（只看这一个值的行）、
## `allow_mixed`（版本混合也放行）、`strict`（严重问题给退出码 2）。[param items] 给了才查道具和棋盘
static func run(dir: String, opts: Dictionary = {}, items: ItemDatabase = null) -> Dictionary:
	var out := {"dir": dir, "opts": opts.duplicate(), "files": {}, "missing_files": [], "severe": [], "warnings": [],
		"groups": {}, "sources": {}, "reproducibility": {}}
	var valid_by_kind := {}
	for kind in KINDS:
		var path := dir.path_join(kind + ".jsonl")
		if not FileAccess.file_exists(path):
			(out["missing_files"] as Array).append(kind + ".jsonl")
			valid_by_kind[kind] = [] as Array[Dictionary]
			continue
		var res := _audit_file(path, kind, opts, items)
		valid_by_kind[kind] = res["valid_rows"]
		res.erase("valid_rows")
		out["files"][kind] = res
	if (out["missing_files"] as Array).size() == KINDS.size():
		(out["severe"] as Array).append("no_data")
	_chains(out, valid_by_kind)
	_mix(out, valid_by_kind, bool(opts.get("allow_mixed", false)))
	for kind in out["files"]:
		var f: Dictionary = out["files"][kind]
		if int(f["bad_lines"]) > 0:
			(out["severe"] as Array).append("%s:bad_lines" % kind)
		if int(f["excluded"].get(R_UNKNOWN_SCHEMA, 0)) > 0:
			(out["severe"] as Array).append("%s:unknown_schema" % kind)
		if int(f["excluded"].get(R_CONFLICT, 0)) > 0:
			(out["severe"] as Array).append("%s:conflict" % kind)
		if int(f["duplicates"]) > 0:
			(out["warnings"] as Array).append("%s:duplicates" % kind)
	var reject := bool(opts.get("strict", false)) and not (out["severe"] as Array).is_empty()
	out["exit_code"] = EXIT_REJECT if reject else EXIT_OK
	return out


static func _audit_file(path: String, kind: String, opts: Dictionary, items: ItemDatabase) -> Dictionary:
	var res := {"path": path, "lines": 0, "bad_lines": 0, "bad_line_numbers": [], "duplicates": 0, "excluded": {},
		"filtered": 0, "valid": 0, "missing_optional": {}, "legacy": 0, "reconciled": true}
	var valid: Array[Dictionary] = []
	var seen := {}     # 规范文本 → true
	var by_id := {}    # 标识 → 规范文本
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		res["read_error"] = true
		res["valid_rows"] = valid
		return res
	var n := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		n += 1
		if line == "":
			continue
		res["lines"] = int(res["lines"]) + 1
		var parsed: Variant = JSON.parse_string(line)
		if not (parsed is Dictionary):
			res["bad_lines"] = int(res["bad_lines"]) + 1
			if (res["bad_line_numbers"] as Array).size() < 20:
				(res["bad_line_numbers"] as Array).append(n)
			continue
		var row := parsed as Dictionary
		var canon := JSON.stringify(row, "", true)
		if seen.has(canon):
			res["duplicates"] = int(res["duplicates"]) + 1
			continue
		seen[canon] = true
		var reason := _exclusion(row, kind, items)
		if reason == "":
			var key := identity(row, kind)
			if key != "":
				if by_id.has(key):
					reason = R_CONFLICT     # 同一个标识、内容不一样（完全一样的已经在上面当重复去掉了）
				else:
					by_id[key] = canon
		if reason != "":
			res["excluded"][reason] = int(res["excluded"].get(reason, 0)) + 1
			continue
		if not _passes(row, opts):
			res["filtered"] = int(res["filtered"]) + 1
			continue
		if not row.has(ExperimentManifest.K_SCHEMA):
			res["legacy"] = int(res["legacy"]) + 1
		for k in OPTIONAL[kind]:
			if not row.has(k) or row[k] == null:
				res["missing_optional"][k] = int(res["missing_optional"].get(k, 0)) + 1
		valid.append(row)
	f.close()
	res["valid"] = valid.size()
	var excluded := 0
	for r in res["excluded"]:
		excluded += int(res["excluded"][r])
	res["excluded_total"] = excluded
	res["reconciled"] = int(res["lines"]) == int(res["bad_lines"]) + int(res["duplicates"]) + excluded + int(res["filtered"]) + valid.size()
	res["valid_rows"] = valid
	return res


## 一行的标识：快照 = 局 + 步数 + 搜索次数；对局 = 局；系数假设 = 战斗。老格式没有局标识返回空（不查冲突）
static func identity(row: Dictionary, kind: String) -> String:
	var run_id := String(row.get(ExperimentManifest.K_RUN, ""))
	match kind:
		SNAPSHOTS:
			return "" if run_id == "" else "%s:%s:%s" % [run_id, str(row.get("steps", "")), str(row.get("searches", ""))]
		RUNS:
			return run_id
		ASSUMPTIONS:
			return String(row.get(ExperimentManifest.K_BATTLE, ""))
	return ""


## 这一行该不该排除；该排除返回原因
static func _exclusion(row: Dictionary, kind: String, items: ItemDatabase) -> String:
	if row.has(ExperimentManifest.K_SCHEMA):
		var sv: Variant = row[ExperimentManifest.K_SCHEMA]
		if not (sv is float or sv is int) or int(sv) > ExperimentManifest.ROW_SCHEMA or int(sv) < 1:
			return R_UNKNOWN_SCHEMA
	for k in REQUIRED[kind]:
		if not row.has(k) or row[k] == null:
			return R_MISSING
	if not _finite(row):
		return R_NON_FINITE
	var s: Variant = row.get("seed")
	if not (s is float or s is int) or float(s) != floorf(float(s)):
		return R_BAD_SEED
	if kind == SNAPSHOTS and items != null:
		return layout_problem(row, items)
	return ""


## 棋盘：每件都认得（改过名的按 [IdAliases] 认），每件都能按记的落点、朝向摆回去；摆得回去返回空串（[ScenarioCheck] 也用）
static func layout_problem(row: Dictionary, items: ItemDatabase) -> String:
	var layout: Variant = row.get("layout")
	var size_raw: Variant = row.get("board_size")
	if not (layout is Array) or not (size_raw is Array) or (size_raw as Array).size() < 2:
		return R_ILLEGAL_LAYOUT
	var defs: Array[ItemDef] = []
	for e in layout:
		if not (e is Dictionary):
			return R_ILLEGAL_LAYOUT
		var d := items.get_def(IdAliases.item(StringName(String((e as Dictionary).get("id", "")))))
		if d == null:
			return R_UNKNOWN_ITEM
		defs.append(d)
	var board := GridInventory.new(Vector2i(int(size_raw[0]), int(size_raw[1])), RunState.BOARD_ID, bool(row.get("requires_bag", true)))
	board.begin_batch()
	var ok := true
	for i in defs.size():
		var e := layout[i] as Dictionary
		var at: Variant = e.get("origin", [0, 0])
		if not (at is Array) or (at as Array).size() < 2:
			ok = false
			break
		var inst := ItemInstance.create(defs[i], 0)
		if e.get("state", null) is Dictionary:
			inst.state = (e["state"] as Dictionary).duplicate(true)
		if not board.place(inst, Vector2i(int(at[0]), int(at[1])), int(e.get("rot", 0))):
			ok = false
			break
	board.end_batch()
	return "" if ok else R_ILLEGAL_LAYOUT


## 所有数都是有限的（递归看数组和字典）
static func _finite(v: Variant) -> bool:
	if v is float:
		return is_finite(v)
	if v is Dictionary:
		for k in v:
			if not _finite(v[k]):
				return false
	elif v is Array:
		for x in v:
			if not _finite(x):
				return false
	return true


## 筛选：给了哪个就只留这个值的行（来源没写的老行算 unknown）
static func _passes(row: Dictionary, opts: Dictionary) -> bool:
	if opts.has("build") and String(row.get(ExperimentManifest.K_BUILD, row.get("version", ""))) != String(opts["build"]):
		return false
	if opts.has("chapter") and String(row.get("chapter", "")) != String(opts["chapter"]):
		return false
	if opts.has("character") and String(row.get("character", "")) != String(opts["character"]):
		return false
	if opts.has("source") and source_of(row) != String(opts["source"]):
		return false
	return true


## 一行的来源；老行没写 = unknown
static func source_of(row: Dictionary) -> String:
	return String(row.get(ExperimentManifest.K_SOURCE, "unknown"))


## 一行属于哪个构建分组：有构建号用构建号，没有用游戏版本号
static func group_of(row: Dictionary) -> String:
	var b := String(row.get(ExperimentManifest.K_BUILD, ""))
	return b if b != "" else "ver:" + String(row.get("version", ""))


## 记录链：有快照没结果的局（可能还没打完）、有结果没快照的局、同一局步数倒退
static func _chains(out: Dictionary, valid: Dictionary) -> void:
	var snap_runs := {}
	var regress := 0
	var last := {}
	for row in valid[SNAPSHOTS]:
		var id := String(row.get(ExperimentManifest.K_RUN, ""))
		if id == "":
			continue
		snap_runs[id] = true
		var steps := int(row.get("steps", 0))
		if last.has(id) and steps < int(last[id]):
			regress += 1
		last[id] = steps
	var result_runs := {}
	for row in valid[RUNS]:
		var id := String(row.get(ExperimentManifest.K_RUN, ""))
		if id != "":
			result_runs[id] = true
	var no_result := 0
	for id in snap_runs:
		if not result_runs.has(id):
			no_result += 1
	var no_snap := 0
	for id in result_runs:
		if not snap_runs.has(id):
			no_snap += 1
	out["chains"] = {"runs_with_snapshots": snap_runs.size(), "runs_with_result": result_runs.size(),
		"snapshots_without_result": no_result, "result_without_snapshots": no_snap, "step_regressions": regress}
	if no_snap > 0:
		(out["warnings"] as Array).append("result_without_snapshots")
	if regress > 0:
		(out["warnings"] as Array).append("step_regressions")


## 版本和来源：有效行按构建分组、按来源计数；复现程度（新格式带局标识的快照 = approximate，其余 unknown）
static func _mix(out: Dictionary, valid: Dictionary, allow_mixed: bool) -> void:
	var groups := {}
	var sources := {}
	var repro := {"approximate": 0, "unknown": 0}
	for kind in KINDS:
		for row in valid[kind]:
			var g := group_of(row)
			if not groups.has(g):
				groups[g] = {SNAPSHOTS: 0, RUNS: 0, ASSUMPTIONS: 0}
			groups[g][kind] = int(groups[g][kind]) + 1
			var s := source_of(row)
			sources[s] = int(sources.get(s, 0)) + 1
			if kind == SNAPSHOTS:
				var tag := "approximate" if row.has(ExperimentManifest.K_SCHEMA) and String(row.get(ExperimentManifest.K_RUN, "")) != "" else "unknown"
				repro[tag] = int(repro[tag]) + 1
	out["groups"] = groups
	out["sources"] = sources
	out["reproducibility"] = repro
	out["mixed"] = groups.size() > 1
	if groups.size() > 1:
		var bucket: Array = out["warnings"] if allow_mixed else out["severe"]
		bucket.append("mixed_builds")
	if sources.size() > 1:
		(out["warnings"] as Array).append("mixed_sources")


## 人读的报告
static func markdown(a: Dictionary) -> String:
	var lines: Array[String] = ["# 校准数据审计", "", "- 目录 `%s`" % a["dir"]]
	if not (a["opts"] as Dictionary).is_empty():
		lines.append("- 参数 `%s`" % JSON.stringify(a["opts"], "", true))
	lines.append("- 结论：%s（退出码 %d）" % ["**拒绝**" if int(a["exit_code"]) == EXIT_REJECT else "通过", int(a["exit_code"])])
	if not (a["severe"] as Array).is_empty():
		lines.append("- 严重：" + ", ".join(a["severe"]))
	if not (a["warnings"] as Array).is_empty():
		lines.append("- 警告：" + ", ".join(a["warnings"]))
	if not (a["missing_files"] as Array).is_empty():
		lines.append("- 缺文件：" + ", ".join(a["missing_files"]))
	lines.append_array(["", "## 对账", "", "| 文件 | 总行 | 坏行 | 重复 | 排除 | 筛掉 | 有效 | 老格式 | 对得上 |", "|---|---:|---:|---:|---:|---:|---:|---:|---|"])
	for kind in a["files"]:
		var f: Dictionary = a["files"][kind]
		lines.append("| %s | %d | %d | %d | %d | %d | %d | %d | %s |" % [kind, f["lines"], f["bad_lines"], f["duplicates"], f["excluded_total"],
			f["filtered"], f["valid"], f["legacy"], "是" if f["reconciled"] else "**否**"])
	lines.append_array(["", "## 排除原因", "", "| 文件 | 原因 | 行数 |", "|---|---|---:|"])
	for kind in a["files"]:
		var ex: Dictionary = a["files"][kind]["excluded"]
		for r in ex:
			lines.append("| %s | %s | %d |" % [kind, r, ex[r]])
	lines.append_array(["", "## 缺的可选字段（统计时记 null）", "", "| 文件 | 字段 | 行数 |", "|---|---|---:|"])
	for kind in a["files"]:
		var mo: Dictionary = a["files"][kind]["missing_optional"]
		for k in mo:
			lines.append("| %s | %s | %d |" % [kind, k, mo[k]])
	lines.append_array(["", "## 构建分组", "", "| 构建 | 快照 | 对局 | 系数假设 |", "|---|---:|---:|---:|"])
	for g in a["groups"]:
		var c: Dictionary = a["groups"][g]
		lines.append("| `%s` | %d | %d | %d |" % [g, c[SNAPSHOTS], c[RUNS], c[ASSUMPTIONS]])
	lines.append_array(["", "## 来源", ""])
	for s in a["sources"]:
		lines.append("- %s：%d 行" % [s, a["sources"][s]])
	var ch: Dictionary = a.get("chains", {})
	lines.append_array(["", "## 记录链", "",
		"- 有快照的局 %d，有结果的局 %d" % [ch.get("runs_with_snapshots", 0), ch.get("runs_with_result", 0)],
		"- 有快照没结果 %d（可能还没打完），有结果没快照 %d，步数倒退 %d" % [ch.get("snapshots_without_result", 0),
			ch.get("result_without_snapshots", 0), ch.get("step_regressions", 0)],
		"- 快照复现程度：approximate %d，unknown %d（快照编译成木桩时不带套装和 buff，最多是近似）" % [
			a["reproducibility"].get("approximate", 0), a["reproducibility"].get("unknown", 0)]])
	return "\n".join(lines) + "\n"
