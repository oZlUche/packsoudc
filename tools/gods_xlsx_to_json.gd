## 神明总表 → 信仰 JSON（104 七，作者定）：改了 `docs/gods.xlsx` 的数就跑它，再跑 `tools/import_content.gd`。
##
##     "E:/Godot/..._console.exe" --headless --path . --script res://tools/gods_xlsx_to_json.gd
##
## 只覆盖表里机器读的字段（阈值、行为、献祭、等级效果、神名与神话定位、转化概率），别的字段原样保留；规则见 [GodsTable]。
## 表里有、仓库里没有的神会新建一份 JSON（名字取表里的「名称」）。按导出器格式写回，默认值不写。
## 表里任何一处有错就一份都不写（全有或全无，同 import_content）。`tools/test.sh` 会对照表与 JSON，忘跑这一步当场红
extends CliTool


func run() -> void:
	var problems: Array[String] = []
	var sheets := XlsxReader.read(GodsTable.PATH)
	if sheets.is_empty():
		print("读不了 %s" % GodsTable.PATH)
		finish(1)
		return
	var table := GodsTable.fields(sheets, problems)
	var out := {}
	for id in table:
		var path := ContentPaths.authoring_file("faiths", id)
		var current := {}
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not (parsed is Dictionary):
				problems.append("%s 解析不了" % path)
				continue
			current = parsed
		else:
			current = {"id": id, "display_name": String(table[id].get("god", id)).get_slice("（", 0)}
		var want := GodsTable.normalized(GodsTable.apply(current, table[id]), problems)
		if not want.is_empty():
			out[path] = want
	if not problems.is_empty():
		print("神明总表有 %d 处问题，一份都没写：" % problems.size())
		for p in problems:
			print("  ✗ " + p)
		finish(1)
		return
	var written := write_json_if_changed(out)
	if written < 0:
		return
	print("神明总表 → JSON：%d 位神，改了 %d 份。接着跑 tools/import_content.gd" % [out.size(), written])
	finish(0)
