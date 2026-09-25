## 作者数据 JSON → 引擎资产 .tres（架构文档 10.2 / 10.3）。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/import_content.gd
##
## [b]全有或全无。[/b] 任何一个文件有错就整批不产出 —— 半套资产比没有资产更难查，
## 因为游戏照样跑得起来，只是有几件道具悄悄不对。
##
## 导入顺序是有讲究的：增益 → 套装 → 物品。后者可以按 id 引用前者。
extends CliTool

## 目录约定集中在 [ContentPaths] —— 编辑器也用同一份，免得两边读写不同目录


func run() -> void:
	var ctx := ContentImporter.Context.new()
	var report := ImportReport.new()
	var built := {}  # 相对输出路径 -> Resource

	for kind in ContentPaths.ORDER:
		var dir: String = ContentPaths.KINDS[kind][0]
		for file in _json_files(dir):
			var id := file.get_file().get_basename()
			report.source = "%s/%s.json" % [kind, id]
			var data := _read_json(file, report)
			if data.is_empty():
				continue
			# id 必须和文件名一致：不一致时产出的资产名对不上，
			# 而游戏按 id 查表，表现为「这件道具凭空消失」
			if String(data.get("id", "")) != id:
				report.error("id", "id '%s' 与文件名 '%s' 不一致" % [data.get("id", ""), id])
				continue
			var res := _build(kind, data, ctx, report)
			if res != null:
				built[ContentPaths.asset_file(kind, id)] = res

	if not report.warnings.is_empty():
		print(report.to_text())
	if not report.ok():
		print("")
		print("导入失败，%s —— 未产出任何资产" % report.summary())
		print(report.to_text())
		finish(1)
		return

	for path in built:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if ResourceSaver.save(built[path], path) != OK:
			push_error("写入失败: " + path)
			finish(1)
			return

	print("导入成功：%d 份资产，%d 条警告" % [built.size(), report.warnings.size()])
	finish(0)


func _build(
	kind: String, data: Dictionary, ctx: ContentImporter.Context, report: ImportReport
) -> Resource:
	match kind:
		"buffs":
			return ContentImporter.import_buff(data, ctx, report)
		"sets":
			return ContentImporter.import_set(data, ctx, report)
		"enemies":
			return ContentImporter.import_enemy(data, ctx, report)
		"enemy_pools":
			return ContentImporter.import_enemy_pool(data, ctx, report)
		"drop_rules":
			return ContentImporter.import_drop_rule(data, ctx, report)
		"node_rules":
			return ContentImporter.import_node_rules(data, ctx, report)
		"economy_rules":
			return ContentImporter.import_economy_rules(data, ctx, report)
		"loadouts":
			return ContentImporter.import_loadout(data, ctx, report)
		"characters":
			return ContentImporter.import_character(data, ctx, report)
		"difficulties":
			return ContentImporter.import_difficulty(data, ctx, report)
		"hunters":
			return ContentImporter.import_hunter(data, ctx, report)
		"meta_rules":
			return ContentImporter.import_meta_rules(data, ctx, report)
		"run_buffs":
			return ContentImporter.import_run_buff(data, ctx, report)
		"faiths":
			return ContentImporter.import_faith(data, ctx, report)
		"recipes":
			return ContentImporter.import_recipe(data, ctx, report)
		"events":
			return ContentImporter.import_event(data, ctx, report)
		"chapters":
			return ContentImporter.import_chapter(data, ctx, report)
		_:
			return ContentImporter.import_item(data, ctx, report)


func _json_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(dir_path + "/" + f)
	out.sort()  # 顺序稳定，报错顺序才可复现
	return out


func _read_json(path: String, report: ImportReport) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		report.error("", "读不到文件或文件为空")
		return {}
	var parsed = JSON.parse_string(text)
	if parsed == null:
		report.error("", "JSON 语法错误")
		return {}
	if not (parsed is Dictionary):
		report.error("", "顶层应该是一个对象")
		return {}
	return parsed
