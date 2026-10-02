## 仓库里的作者 JSON 与导入产出的 `.tres` **是不是一致**（100 第 1 步，架构文档 10 节）。
##
## 两份都进 git（`data/authoring/<kind>/*.json` 与 `data/<kind>/*.tres`），在这之前没人守着它们对不对得上：
## 谁改了 JSON 忘了跑导入、或者编辑器只写成了一半（`ContentEditor` 的「JSON 存了但资产写入失败」分支），
## 仓库就带着两份对不上的内容，而**游戏读的是 `.tres`** —— 作者看着 JSON 调数值，游戏里一点变化都没有。
##
## 原理：仓库里的 JSON 已经是导出器格式（`tools/normalize_content.gd` 导入 → 导出 → 写回），所以
## **`ContentExporter.export_xxx(load(tres))` 的 JSON 文本 == 磁盘上的 JSON 文本** 就是「两份一致」。
## 不重跑导入：重跑会把「导入器变了」和「内容变了」混在一起，而导出器对全部 21 种都现成。
##
## 命令行是 `tools/check_content.gd`，测试是 `test_content_pipeline.run_assets_match_json`，两边调的都是这里。
class_name ContentCheck
extends RefCounted

## 哪些种类过这道检查。[b]加一种内容就在这儿加一行，并在 [method export_of] 的 match 里接上[/b]
## （100 第 3 步会把导出器名并进 `ContentPaths.KINDS` 的种类描述，这张表那时就没了）
const KINDS: Array[String] = [
	"tags", "damage_types", "run_buffs", "faiths", "recipes", "items",
	"loadouts", "characters", "difficulties", "events", "enemies", "enemy_pools", "hunters",
	"drop_rules", "node_rules", "economy_rules", "meta_rules", "chapters", "achievements",
]


## 这一种内容的资产导出成字典。不认识的种类返回 null（调用方报成「没登记导出器」）
static func export_of(kind: String, res: Resource):
	match kind:
		"tags":
			return ContentExporter.export_tag(res as TagDef)
		"damage_types":
			return ContentExporter.export_damage_type(res as DamageTypeDef)
		"buffs":     # 现在不在 ContentPaths.KINDS 里（100）；留着，加回来就不用再写一遍
			return ContentExporter.export_buff(res as BuffDef)
		"sets":
			return ContentExporter.export_set(res as ItemSetDef)
		"run_buffs":
			return ContentExporter.export_run_buff(res as RunBuffDef)
		"faiths":
			return ContentExporter.export_faith(res as FaithDef)
		"recipes":
			return ContentExporter.export_recipe(res as RecipeDef)
		"items":
			return ContentExporter.export_item(res as ItemDef)
		"loadouts":
			return ContentExporter.export_loadout(res as LoadoutDef)
		"characters":
			return ContentExporter.export_character(res as CharacterDef)
		"difficulties":
			return ContentExporter.export_difficulty(res as DifficultyDef)
		"events":
			return ContentExporter.export_event(res as EventDef)
		"enemies":
			return ContentExporter.export_enemy(res as EnemyDef)
		"enemy_pools":
			return ContentExporter.export_enemy_pool(res as EnemyPool)
		"hunters":
			return ContentExporter.export_hunter(res as HunterDef)
		"drop_rules":
			return ContentExporter.export_drop_rule(res as DropRule)
		"node_rules":
			return ContentExporter.export_node_rules(res as NodeRules)
		"economy_rules":
			return ContentExporter.export_economy_rules(res as EconomyRules)
		"meta_rules":
			return ContentExporter.export_meta_rules(res as MetaRules)
		"chapters":
			return ContentExporter.export_chapter(res as ChapterDef)
		"achievements":
			return ContentExporter.export_achievement(res as AchievementDef)
		_:
			return null


## 全部种类过一遍。返回**问题清单**（空 = 一致）。每条都写清是哪一份文件、哪里不对
static func run_all() -> Array[String]:
	var problems: Array[String] = []
	for kind in ContentPaths.ORDER:
		problems.append_array(check_kind(String(kind)))
	return problems


## 一种内容。三类问题：JSON 有 .tres 没有（没导入）、.tres 有 JSON 没有（孤儿资产，`ids()` 会把它当内容用）、
## 两边都有但对不上（打印第一处差异的键路径）
static func check_kind(kind: String) -> Array[String]:
	var problems: Array[String] = []
	if not KINDS.has(kind):
		problems.append("%s：这道检查还不认识它 —— 新种类要在 ContentCheck.KINDS 与 export_of 各加一行" % kind)
		return problems
	if not ContentPaths.KINDS.has(kind):
		problems.append("%s：ContentPaths.KINDS 里没有这一种（只有编辑器用的那两种不走这道检查）" % kind)
		return problems
	var dirs := ContentPaths.dirs_of(kind)
	var in_dir: String = dirs[0]
	var out_dir: String = dirs[1]
	var json_ids := _ids(in_dir, ".json")
	var asset_ids := _ids(out_dir, ".tres")

	for id in json_ids:
		if not asset_ids.has(id):
			problems.append("%s/%s.json 没有对应的资产 —— 跑一次 tools/import_content.gd" % [kind, id])
	for id in asset_ids:
		if not json_ids.has(id):
			problems.append("%s/%s.tres 没有对应的作者数据 —— 孤儿资产（游戏会把它当内容用）" % [kind, id])

	for id in json_ids:
		if not asset_ids.has(id):
			continue
		var res := ResourceLoader.load(ContentPaths.asset_file(kind, id))
		if res == null:
			problems.append("%s/%s.tres 装不进来" % [kind, id])
			continue
		var dumped: Variant = export_of(kind, res)
		if not (dumped is Dictionary):
			problems.append("%s/%s：导出器没给出字典" % [kind, id])
			continue
		var on_disk := FileAccess.get_file_as_string(ContentPaths.authoring_file(kind, id))
		var parsed: Variant = JSON.parse_string(on_disk)
		if not (parsed is Dictionary):
			problems.append("%s/%s.json 解析不了（不是合法的 JSON 对象）" % [kind, id])
			continue
		# 深比较，不比字节：字典字段（属性表、事件配额……）从 .tres 装回来的键顺序和手写 JSON 不一定一样，
		# 那不是「内容对不上」。数字也不较真 int / float —— JSON 里一律是 float
		var where := _diff_path(parsed as Dictionary, dumped as Dictionary, "")
		if where != "":
			problems.append("%s/%s：JSON 与资产不一致（%s）—— 跑一次 tools/import_content.gd" % [kind, id, where])
	return problems


## 一个目录下某后缀的 id（去掉 `.remap`，导出后 `.tres` 会被转成 `.res`，一并认）
static func _ids(dir_path: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if suffix == ".tres" and name.ends_with(".res"):
			name = name.trim_suffix(".res") + ".tres"
		if name.ends_with(suffix):
			out.append(name.trim_suffix(suffix))
	out.sort()
	return out


## 两个字典第一处不同的键路径（`combat.rules[1].effects[0].percent`）。a = 磁盘上的，b = 资产导出的
static func _diff_path(a: Variant, b: Variant, prefix: String) -> String:
	if a is Dictionary and b is Dictionary:
		var da := a as Dictionary
		var db := b as Dictionary
		var keys: Array = da.keys()
		for k in db.keys():
			if not keys.has(k):
				keys.append(k)
		for k in keys:
			var here := "%s.%s" % [prefix, k] if prefix != "" else String(k)
			if not da.has(k):
				return "%s 只在资产里有（值 %s）" % [here, _brief(db[k])]
			if not db.has(k):
				return "%s 只在 JSON 里有（值 %s）" % [here, _brief(da[k])]
			var deeper := _diff_path(da[k], db[k], here)
			if deeper != "":
				return deeper
		return ""
	if a is Array and b is Array:
		var aa := a as Array
		var ba := b as Array
		if aa.size() != ba.size():
			return "%s 件数不同（JSON %d，资产 %d）" % [prefix, aa.size(), ba.size()]
		for i in aa.size():
			var deeper := _diff_path(aa[i], ba[i], "%s[%d]" % [prefix, i])
			if deeper != "":
				return deeper
		return ""
	# JSON 里的数字一律是 float，`2` 与 `2.0` 不算差异
	if a is float or a is int:
		if (b is float or b is int) and is_equal_approx(float(a), float(b)):
			return ""
	if a == b:
		return ""
	return "%s：JSON 是 %s，资产是 %s" % [prefix, _brief(a), _brief(b)]


static func _brief(v: Variant) -> String:
	var s := JSON.stringify(v)
	return s if s.length() <= 60 else s.left(57) + "…"
