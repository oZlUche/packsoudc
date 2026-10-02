## 「说明文本里的裸数字」检查（104 第十节，作者定 2026-10-02）：一个数只有一个来源 = 字段。
##
## 作者 JSON 里给人看的文字（`note`、`description`、事件 `text`、选项 `label`，及其多语言字典）剥掉 `{…}` 占位符与 BBCode 之后
## 还含阿拉伯数字 → 一条问题：要么写成 `{字段名}`（[TextParams]、[TextTemplate]），要么让 `describe()` 按字段生成。
## 汉字数（「三秒一下」）不算。导入器（`tools/import_content.gd`）与 `tools/check_content.gd` 都查；
## 作者定先 warning 一轮，清零之后升为 error（2026-10-02 已升：[constant STRICT] = true，导入失败、check_content 退 1）
class_name TextLint
extends RefCounted

## true = check_content 把裸数字当不一致（退 1）
const STRICT := true

## 这些键的字符串值是给人看的文字；复数形式是 `{语言: 文字}` 字典
const KEYS := ["note", "description", "label", "text"]
const LOCALIZED := ["descriptions", "labels", "texts"]


## 剥掉 `{…}` 与 BBCode `[…]` 之后还有没有阿拉伯数字
static func has_bare_number(text: String) -> bool:
	var re := RegEx.new()
	re.compile("\\{[^}]*\\}|\\[[^\\]]*\\]")
	var stripped := re.sub(text, "", true)
	for ch in stripped:
		if ch >= "0" and ch <= "9":
			return true
	return false


## 一份作者 JSON 里的问题：[{path, text}]
static func scan(data: Variant, path: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_walk(data, path, out)
	return out


## 整个 data/authoring：["kind/id.json path：文字"]
static func scan_all() -> Array[String]:
	var out: Array[String] = []
	for kind in ContentPaths.ORDER:
		var dir_path: String = ContentPaths.dirs_of(kind)[0]
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var files := dir.get_files()
		files.sort()
		for file in files:
			if not file.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file)))
			for hit in scan(parsed):
				out.append(message("%s/%s" % [kind, file], hit))
	return out


static func message(where: String, hit: Dictionary) -> String:
	return "%s %s：说明文本里有写死的数字「%s」—— 写成 {字段名}（docs/text-placeholders.md）" % [where, hit["path"], hit["text"]]


static func _walk(v: Variant, path: String, out: Array[Dictionary]) -> void:
	if v is Dictionary:
		for k in v:
			var key := String(k)
			var at := key if path == "" else path + "." + key
			var x: Variant = (v as Dictionary)[k]
			if x is String and KEYS.has(key):
				if has_bare_number(x):
					out.append({"path": at, "text": x})
			elif x is Dictionary and LOCALIZED.has(key):
				for lang in x:
					var t: Variant = (x as Dictionary)[lang]
					if t is String and has_bare_number(t):
						out.append({"path": "%s.%s" % [at, lang], "text": t})
			else:
				_walk(x, at, out)
	elif v is Array:
		for i in (v as Array).size():
			_walk(v[i], "%s[%d]" % [path, i], out)
