## 一次导入的诊断结果（架构文档 10.3）。
##
## [b]导入器是内容质量的唯一关口，宁可啰嗦。[/b] 所以每条消息都带**定位路径**
## （`rifle.combat.rules[0].cadence.seconds`），而不是只说「有个字段不对」——
## MOD 作者手上没有调试器，报错文本就是他们全部的线索。
##
## 错误与警告分开：**有错误就不产出资产**，宁可什么都不生成，也不生成半成品。
## 警告只是提醒（比如写了个没人用的字段），不阻断。
class_name ImportReport
extends RefCounted

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

## 当前文件名，只为让消息带上出处
var source: String = ""


func error(path: String, message: String) -> void:
	errors.append({"source": source, "path": path, "message": message})


func warn(path: String, message: String) -> void:
	warnings.append({"source": source, "path": path, "message": message})


func ok() -> bool:
	return errors.is_empty()


func merge(other: ImportReport) -> void:
	errors.append_array(other.errors)
	warnings.append_array(other.warnings)


static func _line(entry: Dictionary, mark: String) -> String:
	var where: String = entry["source"]
	if entry["path"] != "":
		where += ("　" if where != "" else "") + entry["path"]
	return "%s %s：%s" % [mark, where, entry["message"]]


## 人读的多行汇总
func to_text() -> String:
	var lines: Array[String] = []
	for e in errors:
		lines.append(_line(e, "✗"))
	for w in warnings:
		lines.append(_line(w, "!"))
	if lines.is_empty():
		lines.append("✓ 没有问题")
	return "\n".join(lines)


## 编辑器状态栏用的 BBCode 版：错误红、警告橙，一条一行；没有问题时绿色写 [param ok_text]（各编辑器的措辞不同，原样传）
func bbcode(ok_text: String = "✓ 没有问题") -> String:
	var lines: Array[String] = []
	for e in errors:
		lines.append("[color=#d9534f]✗ %s：%s[/color]" % [e["path"], e["message"]])
	for w in warnings:
		lines.append("[color=#f0ad4e]! %s：%s[/color]" % [w["path"], w["message"]])
	if lines.is_empty():
		lines.append("[color=#5cb85c]%s[/color]" % ok_text)
	return "\n".join(lines)


func summary() -> String:
	return "%d 条错误，%d 条警告" % [errors.size(), warnings.size()]
