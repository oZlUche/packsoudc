## 科技树配置表 `docs/techs.xlsx` → 科技 JSON（119，作者定：科技树写成配置表，是否点亮读另一张表 = 存档的 `tech_levels`）。
##
## 表里机器读的两张（「说明」页是人话，不读）：
## - 节点：id、名称、英文名、列、排序、前置（「、」分开）、说明、效果构件、构件参数（JSON）、每级说明模板 → `techs/<id>.json`
## - 等级：科技 id、级、钱、材料（`steel_ingot: 2；rivet_box: 1`）、效果参数（JSON）→ `tiers`；`tech_run_buff` 节点每级再生成
##   `run_buffs/tech_<id>_<级>.json`（scope META，`effects[0]` = 节点的 `effect` 类型 + 这一级的参数），节点的 `effect.buffs` 跟着填好
##
## 和神明总表（[GodsTable]）不同：**全量生成** —— 表里写的就是 JSON 的全部字段，科技没有表外字段；表里没有的科技连它的 `tech_*` run_buff 一起删。
## 生成 → [method build]（任何一处有错返回空，全有或全无）；导入再导出一遍，和仓库里的 JSON 同一种格式（默认值不写）。
## 工具 `tools/techs_xlsx_to_json.gd` 写回并生成镜像 `docs/techs.md`，`tools/check_content.gd` / 测试用 [method check] 对照
class_name TechsTable
extends RefCounted

const PATH := "res://docs/techs.xlsx"
## 工具顺手生成的只读镜像
const MIRROR := "res://docs/techs.md"

const SHEET_NODES := "节点"
const SHEET_LEVELS := "等级"

## `run_buffs` 目录里归这张表管的文件前缀
const BUFF_PREFIX := "tech_"


## 表里每个科技：id → {name, en, column, order, requires, description, effect, params, template, tiers: [{funds, items, params}]}。
## 出错的写进 [param problems]
static func fields(sheets: Dictionary, problems: Array[String] = []) -> Dictionary:
	var out := {}
	for row in XlsxReader.rows_as_dicts(sheets, SHEET_NODES, PATH, problems):
		var id := XlsxReader.cell_text(row.get("id", "")).strip_edges()
		if id == "":
			continue
		var where := "%s/%s" % [SHEET_NODES, id]
		if not XlsxReader.is_id(id):
			problems.append("%s：id 只能是英文小写、数字、下划线" % where)
			continue
		if out.has(id):
			problems.append("%s：同一个 id 写了两行" % where)
			continue
		var f := {
			"name": XlsxReader.cell_text(row.get("名称", "")).strip_edges(),
			"en": XlsxReader.cell_text(row.get("英文名", "")).strip_edges(),
			"column": 0, "order": 0, "requires": [],
			"description": XlsxReader.cell_text(row.get("说明", "")).strip_edges(),
			"effect": XlsxReader.cell_text(row.get("效果构件", "")).strip_edges(),
			"params": XlsxReader.json_cell(row.get("构件参数（JSON）", null), "%s 的构件参数" % where, problems),
			"template": XlsxReader.cell_text(row.get("每级说明模板", "")).strip_edges(),
			"tiers": [],
		}
		if f["name"] == "":
			problems.append("%s：没写名称" % where)
		for pair in [["列", "column"], ["排序", "order"]]:
			var raw: Variant = row.get(pair[0], null)
			if raw == null or XlsxReader.cell_text(raw).strip_edges() == "":
				continue
			var n: Variant = _int(raw)
			if n == null or (pair[1] == "column" and int(n) < 0):
				problems.append("%s：%s得是不小于 0 的整数：%s" % [where, pair[0], XlsxReader.cell_text(raw)])
			else:
				f[pair[1]] = int(n)
		for part in XlsxReader.cell_text(row.get("前置", "")).replace("，", "、").replace(",", "、").split("、", false):
			if part.strip_edges() != "":
				(f["requires"] as Array).append(part.strip_edges())
		var type := String(f["effect"])
		if not RunRegistry.TECH_EFFECTS.has(StringName(type)):
			problems.append("%s：效果构件「%s」不在 RunRegistry.TECH_EFFECTS 里（可用 %s）" % [where, type, "、".join(PackedStringArray(RunRegistry.TECH_EFFECTS.keys()))])
		elif type == "tech_run_buff":
			var run_effect := XlsxReader.cell_text((f["params"] as Dictionary).get("effect", ""))
			if not RunRegistry.RUN_EFFECTS.has(StringName(run_effect)):
				problems.append("%s：tech_run_buff 的构件参数得写 {\"effect\": \"<RUN_EFFECTS 里的类型>\"}，「%s」不认得" % [where, run_effect])
			if f["template"] == "":
				problems.append("%s：tech_run_buff 节点得写每级说明模板" % where)
			elif TextLint.has_bare_number(f["template"]):
				problems.append("%s：每级说明模板里有写死的数字，写成 {字段} 占位符：%s" % [where, f["template"]])
		elif f["template"] != "":
			problems.append("%s：每级说明模板只 tech_run_buff 用，%s 这格留空" % [where, type])
		if TextLint.has_bare_number(f["description"]):
			problems.append("%s：说明里有写死的数字：%s" % [where, f["description"]])
		out[id] = f
	for id in out:
		for req in out[id]["requires"]:
			if not out.has(req):
				problems.append("%s/%s：前置 %s 不在节点表里" % [SHEET_NODES, id, req])
	var probe: Array[TechDef] = []
	for id in out:
		var d := TechDef.new()
		d.id = StringName(id)
		for req in out[id]["requires"]:
			d.requires.append(StringName(req))
		probe.append(d)
	var loop := TechService.cycle_members(probe)
	if not loop.is_empty():
		problems.append("%s：前置成环：%s" % [SHEET_NODES, "、".join(loop)])
	_read_levels(sheets, out, problems)
	return out


## 按 [method fields] 生成：{作者 JSON 路径: 字典}（节点 + `tech_run_buff` 每级的 run_buff），已导入再导出过。导入有错进 [param problems]
static func generate(f: Dictionary, problems: Array[String] = []) -> Dictionary:
	var out := {}
	var ctx := ContentImporter.Context.new()
	for id in f:
		var t: Dictionary = f[id]
		var effect := (t["params"] as Dictionary).duplicate(true)
		effect.erase("effect")
		effect["type"] = t["effect"]
		if t["effect"] == "tech_run_buff":
			var buffs: Array = []
			for k in (t["tiers"] as Array).size():
				var bid := "%s%s_%d" % [BUFF_PREFIX, id, k + 1]
				var e := ((t["tiers"][k] as Dictionary)["params"] as Dictionary).duplicate(true)
				e["type"] = XlsxReader.cell_text(t["params"].get("effect", ""))
				var buff := {"id": bid, "display_name": "%s（科技）" % t["name"], "description": t["template"], "scope": "META", "effects": [e]}
				var report := ImportReport.new()
				var def := ContentImporter.import_run_buff(buff, ctx, report)
				if not report.ok():
					problems.append("run_buffs/%s：按表生成的 JSON 导入不了：%s" % [bid, report.to_text()])
					continue
				out[ContentPaths.authoring_file("run_buffs", bid)] = ContentExporter.export_run_buff(def)
				buffs.append(bid)
			effect["buffs"] = buffs
		var tiers: Array = []
		for tier in t["tiers"]:
			var td := {"funds": tier["funds"]}
			if not (tier["items"] as Dictionary).is_empty():
				td["items"] = (tier["items"] as Dictionary).duplicate()
			tiers.append(td)
		var node := {"id": id, "display_name": t["name"], "order": t["order"], "requires": (t["requires"] as Array).duplicate(),
			"column": t["column"], "description": t["description"], "effect": effect, "tiers": tiers}
		if t["en"] != "":
			node["display_names"] = {"en": t["en"]}
		var report := ImportReport.new()
		var def := ContentImporter.import_tech(node, ctx, report)
		if not report.ok():
			problems.append("techs/%s：按表生成的 JSON 导入不了：%s" % [id, report.to_text()])
			continue
		out[ContentPaths.authoring_file("techs", id)] = ContentExporter.export_tech(def)
	return out


## 读表 → 生成。任何一处有错返回空字典（全有或全无），问题进 [param problems]；[param f] 给了就把读出来的字段也放进去（生成镜像用）
static func build(sheets: Dictionary, problems: Array[String], f: Dictionary = {}) -> Dictionary:
	var read := fields(sheets, problems)
	f.merge(read, true)
	if not problems.is_empty():
		return {}
	var out := generate(read, problems)
	return out if problems.is_empty() else {}


## 归这张表管的、磁盘上现有的作者 JSON：`techs/*.json` 与 `run_buffs/tech_*.json`
static func owned_files() -> Array[String]:
	var out: Array[String] = []
	for pair in [["techs", ""], ["run_buffs", BUFF_PREFIX]]:
		var dir_path: String = ContentPaths.dirs_of(pair[0])[0]
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.ends_with(".json") and file.begins_with(pair[1]):
				out.append("%s/%s" % [dir_path, file])
	return out


## 对照：按表生成的和磁盘上的逐份一致、磁盘上归表管的都在表里、镜像是最新的。返回问题清单（空 = 一致）
static func check(path: String = PATH) -> Array[String]:
	var problems: Array[String] = []
	var sheets := XlsxReader.read(path)
	if sheets.is_empty():
		problems.append("%s 读不了（不是 .xlsx？）" % path)
		return problems
	var f := {}
	var want := build(sheets, problems, f)
	if not problems.is_empty():
		return problems
	var fix := "改表就跑 tools/techs_xlsx_to_json.gd，改 JSON 就回去改表"
	for file in want:
		var short := _short(file)
		if not FileAccess.file_exists(file):
			problems.append("科技表有 %s，磁盘上没有 —— 跑 tools/techs_xlsx_to_json.gd" % short)
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(file)) != OK or not (json.data is Dictionary):
			problems.append("%s 解析不了" % short)
			continue
		var where := ContentCheck._diff_path(json.data as Dictionary, want[file], "")
		if where != "":
			problems.append("%s 与科技表不一致（%s）—— %s" % [short, where.replace("资产", "表"), fix])
	for file in owned_files():
		if not want.has(file):
			problems.append("%s 不在科技表里 —— %s" % [_short(file), fix])
	if FileAccess.get_file_as_string(MIRROR) != markdown(f):
		problems.append("%s 不是按科技表生成的最新镜像 —— 跑 tools/techs_xlsx_to_json.gd" % MIRROR.trim_prefix("res://"))
	return problems


## 只读镜像 `docs/techs.md`：节点表 + 等级表两张 Markdown 表
static func markdown(f: Dictionary) -> String:
	var lines: Array[String] = [
		"# 科技树配置表（镜像）",
		"",
		"> **源是 `docs/techs.xlsx`**，这份由 `tools/techs_xlsx_to_json.gd` 生成，别手改：改表、跑工具，再跑 `tools/import_content.gd`。",
		"> 是否点亮不在这里，看存档的 `tech_levels`（119）。列的含义见表里的「说明」页。",
		"",
		"## 节点",
		"",
		"| id | 名称 | 英文名 | 列 | 排序 | 前置 | 说明 | 效果构件 | 构件参数 | 每级说明模板 |",
		"|---|---|---|---|---|---|---|---|---|---|",
	]
	for id in f:
		var t: Dictionary = f[id]
		lines.append(_row([id, t["name"], t["en"], str(t["column"]), str(t["order"]), "、".join(PackedStringArray(t["requires"])),
			t["description"], t["effect"], _json_text(t["params"]), t["template"]]))
	lines.append_array(["", "## 等级", "", "| 科技 id | 级 | 钱 | 材料 | 效果参数 |", "|---|---|---|---|---|"])
	for id in f:
		var tiers: Array = f[id]["tiers"]
		for k in tiers.size():
			var tier: Dictionary = tiers[k]
			var mats: Array[String] = []
			for item in tier["items"]:
				mats.append("%s: %d" % [item, tier["items"][item]])
			lines.append(_row([id, str(k + 1), str(tier["funds"]), "；".join(PackedStringArray(mats)), _json_text(tier["params"])]))
	return "\n".join(lines) + "\n"


#region 读表
static func _read_levels(sheets: Dictionary, out: Dictionary, problems: Array[String]) -> void:
	var by_id := {}     # id → {级: {funds, items, params}}
	for row in XlsxReader.rows_as_dicts(sheets, SHEET_LEVELS, PATH, problems):
		var id := XlsxReader.cell_text(row.get("科技 id", "")).strip_edges()
		if id == "":
			continue
		var lv: Variant = _int(row.get("级", null))
		var where := "%s/%s 第 %s 级" % [SHEET_LEVELS, id, XlsxReader.cell_text(row.get("级", "?"))]
		if not out.has(id):
			problems.append("%s：节点表里没有 %s" % [where, id])
			continue
		if lv == null or int(lv) < 1:
			problems.append("%s：级得是从 1 起的整数" % where)
			continue
		if not by_id.has(id):
			by_id[id] = {}
		if (by_id[id] as Dictionary).has(int(lv)):
			problems.append("%s：这一级写了两行" % where)
			continue
		var funds: Variant = _int(row.get("钱", null))
		if funds == null or int(funds) < 0:
			problems.append("%s：钱得是不小于 0 的整数：%s" % [where, XlsxReader.cell_text(row.get("钱", ""))])
			funds = 0
		var params := XlsxReader.json_cell(row.get("效果参数（JSON）", null), "%s 的效果参数" % where, problems)
		if not params.is_empty() and out[id]["effect"] != "tech_run_buff":
			problems.append("%s：效果参数只 tech_run_buff 用，%s 这格留空" % [where, out[id]["effect"]])
		by_id[id][int(lv)] = {"funds": int(funds), "items": _materials(XlsxReader.cell_text(row.get("材料", "")), where, problems), "params": params}
	for id in out:
		var levels: Dictionary = by_id.get(id, {})
		if levels.is_empty():
			problems.append("%s/%s：等级表里一级都没有" % [SHEET_LEVELS, id])
			continue
		var keys := levels.keys()
		keys.sort()
		for k in keys.size():
			if int(keys[k]) != k + 1:
				problems.append("%s/%s：级号得从 1 起连续，第 %d 级缺了" % [SHEET_LEVELS, id, k + 1])
				break
		for k in keys:
			(out[id]["tiers"] as Array).append(levels[k])


## `steel_ingot: 2；rivet_box: 1` → {"steel_ingot": 2, "rivet_box": 1}：道具得在道具库里、件数是正整数
static func _materials(text: String, where: String, problems: Array[String]) -> Dictionary:
	var out := {}
	for part in text.replace(";", "；").split("；", false):
		if part.strip_edges() == "":
			continue
		var kv := part.replace("：", ":").split(":", true, 1)
		var item := kv[0].strip_edges()
		var n: Variant = _int(kv[1].strip_edges()) if kv.size() == 2 else null
		if kv.size() != 2 or n == null or int(n) < 1:
			problems.append("%s：材料看不懂（写成「道具 id: 件数」，件数是正整数）：%s" % [where, part.strip_edges()])
			continue
		if not XlsxReader.is_id(item) or not FileAccess.file_exists(ContentPaths.authoring_file("items", item)):
			problems.append("%s：材料 %s 不是道具库里的道具" % [where, item])
			continue
		out[item] = int(n)
	return out


## 整数格：数或数字字符串，带小数的不算
static func _int(v: Variant) -> Variant:
	if v is String and (v as String).strip_edges().is_valid_float():
		v = (v as String).strip_edges().to_float()
	if v is int:
		return v
	if v is float and TextTemplate.is_whole(v):
		return int(v)
	return null
#endregion


## 镜像里的 JSON 格：整数值的数写成整数（xlsx 读出来全是浮点）
static func _json_text(d: Dictionary) -> String:
	if d.is_empty():
		return ""
	var parts := PackedStringArray()
	for k in d:
		var v: Variant = d[k]
		parts.append("%s: %s" % [JSON.stringify(k), XlsxReader.cell_text(v) if v is float else JSON.stringify(v)])
	return "{%s}" % ", ".join(parts)


static func _row(cells: Array) -> String:
	var out := PackedStringArray()
	for v in cells:
		out.append(String(v).replace("|", "\\|").replace("\n", " "))
	return "| %s |" % " | ".join(out)


static func _short(file: String) -> String:
	return file.trim_prefix(ContentPaths.AUTHORING + "/") if file.begins_with(ContentPaths.AUTHORING) else file
