## 168：打包字体的覆盖检查 —— 文案里用到的字是不是都裁进了子集。扫的范围和 `tools/font_charset.py` 是同一张表。
##
## 两条：用到的字都在 `assets/fonts/charset.txt` 里（不在 = 文案新加了字，重跑裁字）；用到的汉字文楷子集都有
## （没有 = 子集过期了）。符号类字体本身就没有的（⌛ ✦ ……）不算错，走系统字体后备
class_name FontCoverage
extends RefCounted

const CHARSET := "res://assets/fonts/charset.txt"
## [目录, 后缀]
const SCAN := [["res://data", ["json", "tres", "txt"]], ["res://ui", ["gd", "tscn"]], ["res://core", ["gd"]], ["res://tools", ["gd", "tscn"]]]
const SKIP := [0xFEFF, 0x2028, 0x2029]


## 内容校验（`tools/check_content.gd`）用：两条都查，一条一行；空 = 没问题
static func problems() -> Array[String]:
	var used := used_chars()
	var out: Array[String] = []
	for m in not_in_charset(used):
		out.append("168 字体：「%s」不在字集里 —— 重跑 python3 tools/font_charset.py 与 tools/subset_fonts.sh" % m)
	var body := UiPalette.font_file(UiPalette.FONT_REGULAR)
	if body == null:
		out.append("168 字体：%s%s 不在" % [UiPalette.FONT_DIR, UiPalette.FONT_REGULAR])
	else:
		for m in missing_hanzi(body, used):
			out.append("168 字体：正文字体缺「%s」—— 子集过期了，重跑 tools/subset_fonts.sh" % m)
	return out


## 文案里用到的非 ASCII 字：码位 → 第一次出现在哪个文件
static func used_chars() -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("[^\\x{00}-\\x{7F}]+")
	for pair in SCAN:
		for path in _files(pair[0], pair[1]):
			for m in re.search_all(FileAccess.get_file_as_string(path)):
				var run := m.get_string()
				for i in run.length():
					var c := run.unicode_at(i)
					if not out.has(c) and not SKIP.has(c):
						out[c] = path
	return out


## 字集里的字（码位集合）
static func charset() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(CHARSET):
		return out
	for line in FileAccess.get_file_as_string(CHARSET).split("\n", false):
		if line.length() > 0:
			out[line.unicode_at(0)] = true
	return out


## 用到了、字集里没有的（「字 文件」）
static func not_in_charset(used: Dictionary = {}) -> Array[String]:
	var u := used if not used.is_empty() else used_chars()
	var cs := charset()
	var out: Array[String] = []
	for c in u:
		if not cs.has(c):
			out.append("%s %s" % [String.chr(c), u[c]])
	return out


## 用到了、[param font] 没有的汉字（CJK 统一表意文字与扩展 A）
static func missing_hanzi(font: Font, used: Dictionary = {}) -> Array[String]:
	return _missing(font, used, true)


## 用到了、[param font] 没有的任何字（包括符号）
static func missing_any(font: Font, used: Dictionary = {}) -> Array[String]:
	return _missing(font, used, false)


static func is_hanzi(c: int) -> bool:
	return (c >= 0x4E00 and c <= 0x9FFF) or (c >= 0x3400 and c <= 0x4DBF)


static func _missing(font: Font, used: Dictionary, hanzi_only: bool) -> Array[String]:
	var u := used if not used.is_empty() else used_chars()
	var out: Array[String] = []
	for c in u:
		if hanzi_only and not is_hanzi(c):
			continue
		if not font.has_char(c):
			out.append("%s %s" % [String.chr(c), u[c]])
	return out


static func _files(dir: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if exts.has(f.get_extension()):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), exts))
	return out
