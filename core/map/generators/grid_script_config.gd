## 手绘地图生成器的配置：指向一份网格脚本（架构文档 5.4.1）。
class_name GridScriptConfig
extends Resource

## 网格脚本文件。作者在电子表格里画，`tools/map_xlsx_to_text.py` 转成这个
@export_file("*.txt") var path: String = ""

## 直接给文本。非空时优先于 [member path] —— 测试与编辑器里临时改图用
@export_multiline var text: String = ""


func read() -> String:
	if text != "":
		return text
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
