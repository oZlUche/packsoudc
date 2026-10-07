## 神明总表 `docs/gods.xlsx` ⇄ 信仰 JSON（104 七，作者定：这张表是信仰体系的核心配置）。
##
## 表里机器读的列（「人话」列不参与）：
## - 神明总表：id、名称、代表概念 / 权柄、神话定位、阈值1～5、转化概率、每阶加 → `god`（名称（概念））、`description`（神话定位）、
##   `thresholds`、`convert_chance`、`convert_per_tier`
## - 信力行为：id、类型、参数（JSON）→ `deeds`
## - 献祭：id、条件（`tags: a / b`、`min_cells: 9`、`exact_grade: 2`、`has_stat: crit_chance`，用「；」并列）、倍率、per_cell → `offerings`
##   （「收什么（人话）」不进 JSON：界面上的一句由 [method OfferingRule.describe] 按字段拼，104 第十节）
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
	var gods := XlsxReader.rows_as_dicts(sheets, SHEET_GODS, PATH, problems)
	for row in gods:
		var id := XlsxReader.cell_text(row.get("id", "")).strip_edges()
		if id == "" or not XlsxReader.is_id(id):
			continue
		var f := {}
		var name := XlsxReader.cell_text(row.get("名称", "")).strip_edges()
		var concept := XlsxReader.cell_text(row.get("代表概念 / 权柄", "")).strip_edges()
		f["god"] = name if concept == "" or concept == "暂不引入" else "%s（%s）" % [name, concept]
		f["description"] = XlsxReader.cell_text(row.get("神话定位", "")).strip_edges()
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
	for row in XlsxReader.rows_as_dicts(sheets, SHEET_DEEDS, PATH, problems):
		var id := XlsxReader.cell_text(row.get("id", "")).strip_edges()
		var type := XlsxReader.cell_text(row.get("类型（type）", "")).strip_edges()
		if not out.has(id) or type == "":
			continue
		var entry := XlsxReader.json_cell(row.get("参数（JSON，其余字段）", null), "%s/%s 的信力行为参数" % [SHEET_DEEDS, id], problems)
		entry["type"] = type
		_push(out[id], "deeds", entry)
	for row in XlsxReader.rows_as_dicts(sheets, SHEET_OFFERINGS, PATH, problems):
		var id := XlsxReader.cell_text(row.get("id", "")).strip_edges()
		if not out.has(id):
			continue
		var entry := _condition(XlsxReader.cell_text(row.get("条件（tags / min_cells / exact_grade）", "")), "%s/%s" % [SHEET_OFFERINGS, id], problems)
		var mult: Variant = _first_starting(row, "倍率")
		entry["multiplier"] = float(mult) if mult is float or mult is int else 1.0
		var per_cell: Variant = _first_starting(row, "再乘格子数")
		if per_cell is bool and per_cell:
			entry["per_cell"] = true
		_push(out[id], "offerings", entry)
	for row in XlsxReader.rows_as_dicts(sheets, SHEET_PERKS, PATH, problems):
		var id := XlsxReader.cell_text(row.get("id", "")).strip_edges()
		var type := XlsxReader.cell_text(row.get("构件（type）", "")).strip_edges()
		if not out.has(id) or type == "" or type.begins_with("（"):
			continue     # 「（道具）」= 功能在道具上，不是信仰级效果
		var entry := XlsxReader.json_cell(row.get("参数（JSON，其余字段）", null), "%s/%s 的等级效果参数" % [SHEET_PERKS, id], problems)
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


## 表头以某个前缀开头的那一列的值（「倍率（信力 = 2^稀有度 × 倍率……）」这种长表头）
static func _first_starting(row: Dictionary, prefix: String) -> Variant:
	for k in row:
		if String(k).begins_with(prefix):
			return row[k]
	return null


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
