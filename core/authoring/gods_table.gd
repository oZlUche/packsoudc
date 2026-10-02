## 神明总表 `docs/gods.xlsx` ⇄ 信仰 JSON（104 七，作者定：这张表是信仰体系的核心配置）。
##
## 表里机器读的列（「人话」列不参与）：
## - 神明总表：id、名称、代表概念 / 权柄、神话定位、阈值1～5、转化概率、每阶加 → `god`（名称（概念））、`description`（神话定位）、
##   `thresholds`、`convert_chance`、`convert_per_tier`
## - 信力行为：id、类型、参数（JSON）→ `deeds`
## - 献祭：id、条件（`tags: a / b`、`min_cells: 9`、`exact_grade: 2`、`has_stat: crit_chance`，用「；」并列）、收什么、倍率、per_cell → `offerings`
## - 等级效果：id、级、构件、参数（JSON）→ `perks`（`note` 不在表里，同一位置同一构件的沿用 JSON 原有的）
##
## **只覆盖这些字段**，其余（名字、英文名、阵营、赐福模板……）原样保留；某位神在一张表里一行带类型的都没有，那一项也原样保留。
## 生成 → [method apply]；导入再导出一遍（[method normalized]）得到和仓库里一样格式的 JSON —— 默认值不写，所以表里写了默认值也对得上。
## 工具 `tools/gods_xlsx_to_json.gd` 写回，`tools/check_content.gd` / 测试用 [method check] 对照
class_name GodsTable
extends RefCounted

const PATH := "res://docs/gods.xlsx"

const SHEET_GODS := "神明总表"
const SHEET_DEEDS := "信力行为"
const SHEET_OFFERINGS := "献祭"
const SHEET_PERKS := "等级效果"


## 表里每位神的字段：id → {god, description, thresholds, convert_chance, convert_per_tier, deeds?, offerings?, perks?}。
## 出错的写进 [param problems]
static func fields(sheets: Dictionary, problems: Array[String] = []) -> Dictionary:
	var out := {}
	var gods := _table(sheets, SHEET_GODS, problems)
	for row in gods:
		var id := _s(row.get("id", "")).strip_edges()
		if id == "" or not _is_id(id):
			continue
		var f := {}
		var name := _s(row.get("名称", "")).strip_edges()
		var concept := _s(row.get("代表概念 / 权柄", "")).strip_edges()
		f["god"] = name if concept == "" or concept == "暂不引入" else "%s（%s）" % [name, concept]
		f["description"] = _s(row.get("神话定位", "")).strip_edges()
		var th: Array = []
		for i in range(1, 6):
			var v: Variant = row.get("阈值%d" % i, null)
			if v is float or v is int:
				th.append(int(v))
		f["thresholds"] = th
		for pair in [["转化概率", "convert_chance"], ["每阶加", "convert_per_tier"]]:
			var v: Variant = row.get(pair[0], null)
			if v is float or v is int:
				f[pair[1]] = float(v)
		out[id] = f
	for row in _table(sheets, SHEET_DEEDS, problems):
		var id := _s(row.get("id", "")).strip_edges()
		var type := _s(row.get("类型（type）", "")).strip_edges()
		if not out.has(id) or type == "":
			continue
		var entry := _params(row.get("参数（JSON，其余字段）", null), "%s/%s 的信力行为参数" % [SHEET_DEEDS, id], problems)
		entry["type"] = type
		_push(out[id], "deeds", entry)
	for row in _table(sheets, SHEET_OFFERINGS, problems):
		var id := _s(row.get("id", "")).strip_edges()
		if not out.has(id):
			continue
		var entry := _condition(_s(row.get("条件（tags / min_cells / exact_grade）", "")), "%s/%s" % [SHEET_OFFERINGS, id], problems)
		var mult: Variant = _first_starting(row, "倍率")
		entry["multiplier"] = float(mult) if mult is float or mult is int else 1.0
		var per_cell: Variant = _first_starting(row, "再乘格子数")
		if per_cell is bool and per_cell:
			entry["per_cell"] = true
		var what := _s(row.get("收什么（人话）", "")).strip_edges()
		if what != "":
			entry["note"] = "%s（2^稀有度 × %s%s）" % [what, _num(float(entry["multiplier"])), " × 格子数" if entry.get("per_cell", false) else ""]
		_push(out[id], "offerings", entry)
	for row in _table(sheets, SHEET_PERKS, problems):
		var id := _s(row.get("id", "")).strip_edges()
		var type := _s(row.get("构件（type）", "")).strip_edges()
		if not out.has(id) or type == "" or type.begins_with("（"):
			continue     # 「（道具）」= 功能在道具上，不是信仰级效果
		var entry := _params(row.get("参数（JSON，其余字段）", null), "%s/%s 的等级效果参数" % [SHEET_PERKS, id], problems)
		entry["type"] = type
		var tier: Variant = row.get("级", null)
		if (tier is float or tier is int) and int(tier) != 1:
			entry["tier"] = int(tier)
		_push(out[id], "perks", entry)
	return out


## 把表里的字段盖到一份信仰 JSON 上（不改原字典）
static func apply(json: Dictionary, f: Dictionary) -> Dictionary:
	var out := json.duplicate(true)
	for key in ["god", "description", "thresholds", "convert_chance", "convert_per_tier", "deeds", "offerings"]:
		if f.has(key):
			out[key] = (f[key] as Variant) if not (f[key] is Array) else (f[key] as Array).duplicate(true)
	if f.has("perks"):
		var old: Array = json.get("perks", [])
		var perks: Array = (f["perks"] as Array).duplicate(true)
		for i in perks.size():
			var p := perks[i] as Dictionary
			if i < old.size() and old[i] is Dictionary and String((old[i] as Dictionary).get("type", "")) == String(p.get("type", "")) \
					and (old[i] as Dictionary).has("note") and not p.has("note"):
				p["note"] = (old[i] as Dictionary)["note"]
		out["perks"] = perks
	return out


## 导入再导出：和仓库里的 JSON 同一种格式（默认值不写）。导入有错返回空字典，错误进 [param problems]
static func normalized(json: Dictionary, problems: Array[String] = []) -> Dictionary:
	var report := ImportReport.new()
	var def := ContentImporter.import_faith(json, ContentImporter.Context.new(), report)
	if not report.ok():
		problems.append("faiths/%s：按表生成的 JSON 导入不了：%s" % [json.get("id", "?"), report.to_text()])
		return {}
	return ContentExporter.export_faith(def)


## 对照：表里的每位神都得有 JSON、JSON 里的信仰都得在表里，按表生成的和磁盘上的一致。返回问题清单（空 = 一致）
static func check(path: String = PATH) -> Array[String]:
	var problems: Array[String] = []
	var sheets := XlsxReader.read(path)
	if sheets.is_empty():
		problems.append("%s 读不了（不是 .xlsx？）" % path)
		return problems
	var table := fields(sheets, problems)
	var on_disk := {}
	var dir := DirAccess.open(ContentPaths.dirs_of("faiths")[0])
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".json"):
				on_disk[file.get_basename()] = true
	for id in table:
		if not on_disk.has(id):
			problems.append("神明总表有 %s，faiths/%s.json 没有 —— 跑 tools/gods_xlsx_to_json.gd" % [id, id])
	for id in on_disk:
		if not table.has(id):
			problems.append("faiths/%s.json 不在神明总表里" % id)
	for id in table:
		if not on_disk.has(id):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file("faiths", id)))
		if not (parsed is Dictionary):
			problems.append("faiths/%s.json 解析不了" % id)
			continue
		var want := normalized(apply(parsed as Dictionary, table[id]), problems)
		if want.is_empty():
			continue
		var where := ContentCheck._diff_path(parsed as Dictionary, want, "")
		if where != "":
			problems.append("faiths/%s.json 与神明总表不一致（%s）—— 改表就跑 tools/gods_xlsx_to_json.gd，改 JSON 就回去改表" % [id, where.replace("资产", "表")])
	return problems


## 表头那一行当键：每行变成 {表头: 值}
static func _table(sheets: Dictionary, name: String, problems: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not sheets.has(name):
		problems.append("%s 里没有「%s」这张表" % [PATH, name])
		return out
	var rows: Array = sheets[name]
	if rows.is_empty():
		return out
	var header: Array = rows[0]
	for r in range(1, rows.size()):
		var line: Array = rows[r]
		var d := {}
		for c in mini(header.size(), line.size()):
			if header[c] != null:
				d[String(header[c])] = line[c]
		out.append(d)
	return out


## 表头以某个前缀开头的那一列的值（「倍率（信力 = 2^稀有度 × 倍率……）」这种长表头）
static func _first_starting(row: Dictionary, prefix: String) -> Variant:
	for k in row:
		if String(k).begins_with(prefix):
			return row[k]
	return null


static func _is_id(s: String) -> bool:
	for ch in s:
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"):
			return false
	return true


static func _params(raw: Variant, where: String, problems: Array[String]) -> Dictionary:
	if raw == null or _s(raw).strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(_s(raw))
	if not (parsed is Dictionary):
		problems.append("%s 不是 JSON 对象：%s" % [where, raw])
		return {}
	return parsed as Dictionary


## `tags: gear / armor / shield；min_cells: 9` → {"tags": [...], "min_cells": 9}
static func _condition(text: String, where: String, problems: Array[String]) -> Dictionary:
	var out := {}
	for part in text.replace("；", ";").split(";", false):
		var kv := part.split(":", true, 1)
		if kv.size() != 2:
			problems.append("%s 的条件看不懂：%s" % [where, part])
			continue
		var key := kv[0].strip_edges()
		var val := kv[1].strip_edges()
		match key:
			"tags":
				var tags: Array = []
				for t in val.split("/", false):
					tags.append(t.strip_edges())
				out["tags"] = tags
			"min_cells", "exact_grade":
				out[key] = int(val)
			"has_stat":
				out[key] = val
			_:
				problems.append("%s 的条件认不得：%s（可用 tags / min_cells / exact_grade / has_stat）" % [where, key])
	return out


static func _push(f: Dictionary, key: String, entry: Dictionary) -> void:
	if not f.has(key):
		f[key] = []
	(f[key] as Array).append(entry)


static func _s(v: Variant) -> String:
	if v == null:
		return ""
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v))
	return str(v)


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)
