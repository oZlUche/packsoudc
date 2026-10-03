## 科技树配置表 → 科技 JSON（119，作者定：科技树写成配置表）：改了 `docs/techs.xlsx` 就跑它，再跑 `tools/import_content.gd`。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/techs_xlsx_to_json.gd
##
## **全量生成**：`data/authoring/techs/*.json` 与 `data/authoring/run_buffs/tech_*.json` 都由表写出，表里没有的删掉；顺手写只读镜像 `docs/techs.md`。
## 规则见 [TechsTable]。表里任何一处有错就一份都不写（全有或全无，同 import_content）。`tools/test.sh` 会对照表与 JSON，忘跑这一步当场红
extends CliTool


func run() -> void:
	var problems: Array[String] = []
	var sheets := XlsxReader.read(TechsTable.PATH)
	if sheets.is_empty():
		print("读不了 %s" % TechsTable.PATH)
		finish(1)
		return
	var f := {}
	var out := TechsTable.build(sheets, problems, f)
	if not problems.is_empty():
		print("科技表有 %d 处问题，一份都没写：" % problems.size())
		for p in problems:
			print("  ✗ " + p)
		finish(1)
		return
	var written := 0
	for path in out:
		var text := ContentExporter.to_json(out[path])
		if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == text:
			continue
		if ContentExporter.save(out[path], path) != OK:
			print("写不了 " + path)
			finish(1)
			return
		written += 1
		print("写了 " + path)
	var removed := 0
	for path in TechsTable.owned_files():
		if out.has(path):
			continue
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			print("删不了 " + path)
			finish(1)
			return
		removed += 1
		print("删了 %s（表里没有）" % path)
	var md := TechsTable.markdown(f)
	if FileAccess.get_file_as_string(TechsTable.MIRROR) != md:
		var file := FileAccess.open(TechsTable.MIRROR, FileAccess.WRITE)
		if file == null:
			print("写不了 " + TechsTable.MIRROR)
			finish(1)
			return
		file.store_string(md)
		file.close()
		print("写了 " + TechsTable.MIRROR)
	print("科技表 → JSON：%d 个科技、%d 份文件，改了 %d 份、删了 %d 份。接着跑 tools/import_content.gd" % [f.size(), out.size(), written, removed])
	finish(0)
