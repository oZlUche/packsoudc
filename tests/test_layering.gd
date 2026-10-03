## 依赖方向（101 第 5 刀，架构文档 1 节）：**`core/` 不认识 `ui/`，底下的层不认识上面的层。**
##
## 这类错误编译不红、测试也不红 —— 它只是让逻辑层再也不能单独跑（沙盒、无头模拟、将来换界面都要跟着拖上一堆控件）。
## 所以在这里按源码查：
##
## - `core/` 里不许出现 `ui/` 的类名（配色、控件、悬浮窗）。要颜色就产出**名字**，查表是界面的事。
## - `core/battle`、`core/inventory`、`core/sets` 里不许出现 `core/run` 的类名 —— 战斗与背包不该认识一局。
## - 新加的反向依赖如果确实有理由，写进白名单并写原因（这两张表越短越好）。
extends RefCounted

## `ui/` 的类名（或 `res://ui/` 的路径）在 `core/` 里出现是反向依赖。例外写在这里（键 = `文件:名字`，值 = 原因）
const CORE_TO_UI_OK := {}

## `core/run` 的类名（或路径）在底层出现是反向依赖。例外写在这里（键 = `文件:名字`，值 = 原因）
const LOW_TO_RUN_OK := {
	"core/inventory/item_database.gd:res://core/run/": "095：赐福版是按信仰的模板派生的（preload 两个脚本）；100 第 4 步 ContentLibrary 落地后挪过去 —— 101 第 5 刀留的尾巴",
}

## 底下这几棵树不许认识 core/run
const LOW_DIRS := ["core/battle", "core/inventory", "core/sets"]


static func _scripts_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open("res://" + dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := "%s/%s" % [dir, name]
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_scripts_under(path))
		elif name.ends_with(".gd"):
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


## 一棵树里声明的 `class_name`（类名 → 文件）
static func _class_names_under(dir: String) -> Dictionary:
	var out: Dictionary = {}
	for path in _scripts_under(dir):
		for line in FileAccess.get_file_as_string("res://" + path).split("\n"):
			var s := (line as String).strip_edges()
			if s.begins_with("class_name "):
				out[s.substr(11).strip_edges()] = path
				break
	return out


## 这个文件里**当成代码**用到了哪些给定的类名（文档注释 `##` 与 `#` 注释不算：它们只是指路）
static func _code_uses(path: String, names: Dictionary, paths: Array = []) -> Array[String]:
	var out: Array[String] = []
	var text := FileAccess.get_file_as_string("res://" + path)
	var code := ""
	for line in text.split("\n"):
		var s := line as String
		if s.strip_edges().begins_with("#"):
			continue
		var hash_at := s.find("#")
		code += (s.substr(0, hash_at) if hash_at >= 0 else s) + "\n"
	# 绕开类名的那条路也要查：`preload("res://ui/…")` / `load("res://core/run/…")`
	for prefix in paths:
		if code.contains(String(prefix)) and not out.has(String(prefix)):
			out.append(String(prefix))
	for name in names:
		var n := String(name)
		# 词边界：前后不能是标识符字符（避免 FaithDef 命中 FaithDefScript）
		var re := RegEx.new()
		re.compile("(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)" % n)
		if re.search(code) != null and not out.has(n):
			out.append(n)
	out.sort()
	return out


static func run_core_does_not_know_ui(t: TestCase) -> void:
	t.begin("依赖方向 · core 不认识 ui（101 第 5 刀）：逻辑层里不许出现界面的类名，例外写进白名单")
	var ui_classes := _class_names_under("ui")
	t.check(ui_classes.size() >= 20, "扫到了 ui/ 里的类：%d 个" % ui_classes.size())
	t.check(ui_classes.has("UiPalette") and ui_classes.has("ItemTooltip"), "两个最容易被反向依赖的在名单里")
	var core := _scripts_under("core")
	t.check(core.size() >= 200, "扫到了 core/ 的脚本：%d 个" % core.size())
	var bad: Array[String] = []
	for path in core:
		for name in _code_uses(path, ui_classes, ["res://ui/"]):
			var key := "%s:%s" % [path, name]
			if CORE_TO_UI_OK.has(key):
				t.check(not String(CORE_TO_UI_OK[key]).is_empty(), "%s 在白名单里，写了原因" % key)
				continue
			bad.append(key)
	t.check(bad.is_empty(), "core/ 里没有界面的类名%s" % ("" if bad.is_empty() else "，但是：%s" % str(bad)))
	# 自检：这张网抓得到东西（否则「全绿」只是没在查）
	t.check(_code_uses("ui/ui_palette.gd", ui_classes, ["res://ui/"]).has("UiPalette"), "查法本身有效：调色板那个文件里查得到 UiPalette")
	t.check(_code_uses("core/text/text_template.gd", {"TextTemplate": 1}, []).has("TextTemplate"),
		"词边界不会漏（TextTemplate 在自己文件里查得到）")
	t.check(not _code_uses("core/run/faith/faith_def.gd", {"FaithTag": 1}, []).has("FaithTag"),
		"词边界不会误报（FaithTags 不算 FaithTag）")


static func run_low_layers_do_not_know_run(t: TestCase) -> void:
	t.begin("依赖方向 · 战斗与背包不认识一局（101 第 5 刀）：core/battle、core/inventory、core/sets 里不许出现 core/run 的类名")
	var run_classes := _class_names_under("core/run")
	t.check(run_classes.size() >= 50, "扫到了 core/run 里的类：%d 个" % run_classes.size())
	t.check(not run_classes.has("FaithState"), "FaithState 已经搬到道具层（101 第 5 刀）")
	t.check(run_classes.has("RunRegistry"), "一局的注册表在 core/run（101 第 5 刀拆出来的）")
	var bad: Array[String] = []
	for dir in LOW_DIRS:
		for path in _scripts_under(dir):
			for name in _code_uses(path, run_classes, ["res://core/run/"]):
				var key := "%s:%s" % [path, name]
				if LOW_TO_RUN_OK.has(key):
					t.check(not String(LOW_TO_RUN_OK[key]).is_empty(), "%s 在白名单里，写了原因" % key)
					continue
				bad.append(key)
	t.check(bad.is_empty(), "底下三棵树里没有 core/run 的类名%s" % ("" if bad.is_empty() else "，但是：%s" % str(bad)))
