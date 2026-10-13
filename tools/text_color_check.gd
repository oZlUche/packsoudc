## 169：字色模板的校验 —— 文件读得到、每个名字两版都在（[method UiPalette.load_text_colors] 的问题），
## 浅版对纸 [constant UiTheme.PAPER] 的对比至少 [constant UiTheme.MIN_CONTRAST]（不够算错）；
## 深版对面板 [constant UiPalette.PANEL] 不够、内容里写死的 `{c:#…}` 只列成警告（待定 3：先不卡内容，建议换成名字）
class_name TextColorCheck
extends RefCounted

const CONTENT := "res://data/authoring"


## 算错的（`tools/check_content.gd` 红）：读文件的问题 + 浅版对比不够
static func problems() -> Array[String]:
	var out: Array[String] = []
	var read := UiPalette.load_text_colors(UiPalette.TEXT_COLORS_PATH)
	for p in read:
		out.append("169 字色：%s" % p)
	if not read.is_empty():
		return out
	for e in entries():
		var k := UiTheme.contrast(e["light"], UiTheme.PAPER)
		if k < UiTheme.MIN_CONTRAST:
			out.append("169 字色：%s 的浅版 #%s 在纸上对比 %.2f，差 %.2f（至少 %.1f）" % [e["name"], (e["light"] as Color).to_html(false), k, UiTheme.MIN_CONTRAST - k, UiTheme.MIN_CONTRAST])
	return out


## 只提醒的：深版对比不够、内容里写死的十六进制颜色
static func warnings() -> Array[String]:
	var out: Array[String] = []
	for e in entries():
		var k := UiTheme.contrast(e["dark"], UiPalette.PANEL)
		if k < UiTheme.MIN_CONTRAST:
			out.append("169 字色：%s 的深版 #%s 在深面板上对比 %.2f，差 %.2f" % [e["name"], (e["dark"] as Color).to_html(false), k, UiTheme.MIN_CONTRAST - k])
	for hit in hardcoded_hex():
		out.append("169 字色：%s 写死了颜色 %s（建议换成颜色名，浅底时只能按算法压暗）" % hit)
	return out


## 模板里每一条：[{name, dark, light}]
static func entries() -> Array:
	var tc := UiPalette.text_colors()
	var out := []
	for name in tc["styles"]:
		out.append({"name": "styles.%s" % name, "dark": tc["styles"][name]["dark"], "light": tc["styles"][name]["light"]})
	for r in (tc["rarity"] as Array).size():
		out.append({"name": "rarity[%d]" % r, "dark": tc["rarity"][r]["dark"], "light": tc["rarity"][r]["light"]})
	for type in tc["damage"]:
		out.append({"name": "damage.%s" % type, "dark": tc["damage"][type]["dark"], "light": tc["damage"][type]["light"]})
	return out


## 作者 JSON 里写死的 `{c:#hex}`：[[文件, 颜色]]
static func hardcoded_hex() -> Array:
	var re := RegEx.create_from_string("\\{c:(#[0-9a-fA-F]{3,8})\\}")
	var out := []
	_scan(CONTENT, re, out)
	return out


static func _scan(dir: String, re: RegEx, out: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), re, out)
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var path := dir.path_join(f)
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			out.append([path.trim_prefix("res://"), m.get_string(1)])
