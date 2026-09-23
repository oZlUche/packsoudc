## 把作者数据 JSON 重写成导出器的格式（架构文档 10.4「往返」）。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/normalize_content.gd
##
## 手写或脚本生成的 JSON 键序、缩进、整数/浮点的写法和导出器不一定一样；仓库里的作者数据
## 应该就是导出器的格式（测试拿它和再导出的文本逐字节比）。跑一遍这个：导入 → 导出 → 不一样就写回。
## 导不进去的文件不动，错误照导入器的格式打出来。不产出资产 —— 那是 import_content 的事。
extends CliTool


func run() -> void:
	var ctx := ContentImporter.Context.new()
	var report := ImportReport.new()
	var rewritten := 0
	var checked := 0
	for kind in ContentPaths.ORDER:
		var dir: String = ContentPaths.KINDS[kind][0]
		var d := DirAccess.open(dir)
		if d == null:
			continue
		var files: Array[String] = []
		for f in d.get_files():
			if f.ends_with(".json"):
				files.append(dir + "/" + f)
		files.sort()
		for path in files:
			report.source = path
			var text := FileAccess.get_file_as_string(path)
			var parsed = JSON.parse_string(text)
			if not (parsed is Dictionary):
				report.error("", "不是合法的 JSON 对象")
				continue
			var local := ImportReport.new()
			local.source = path
			var res := _import(kind, parsed, ctx, local)
			report.merge(local)
			if res == null or not local.ok():
				continue
			checked += 1
			var again := ContentExporter.to_json(_export(kind, res))
			if again != text:
				if ContentExporter.save(_export(kind, res), path) == OK:
					rewritten += 1
					print("重写 " + path)
	if not report.ok():
		print(report.to_text())
	print("检查了 %d 份，重写 %d 份，%d 条错误" % [checked, rewritten, report.errors.size()])
	finish(0 if report.ok() else 1)


func _import(kind: String, data: Dictionary, ctx: ContentImporter.Context, report: ImportReport) -> Resource:
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
		"chapters":
			return ContentImporter.import_chapter(data, ctx, report)
		_:
			return ContentImporter.import_item(data, ctx, report)


func _export(kind: String, res: Resource) -> Dictionary:
	match kind:
		"buffs":
			return ContentExporter.export_buff(res)
		"sets":
			return ContentExporter.export_set(res)
		"enemies":
			return ContentExporter.export_enemy(res)
		"enemy_pools":
			return ContentExporter.export_enemy_pool(res)
		"drop_rules":
			return ContentExporter.export_drop_rule(res)
		"node_rules":
			return ContentExporter.export_node_rules(res)
		"economy_rules":
			return ContentExporter.export_economy_rules(res)
		"loadouts":
			return ContentExporter.export_loadout(res)
		"chapters":
			return ContentExporter.export_chapter(res)
		_:
			return ContentExporter.export_item(res)
