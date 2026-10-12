## 全局类缓存（158）：不起编辑器，自己扫 `.gd` 文件头、写出 `res://.godot/global_script_class_cache.cfg`。
##
## 更新代码后本地缓存缺了别人新加的 `class_name`，原来是起一个 `--headless --import`（整个编辑器子系统，半分钟以上）；
## 这份缓存其实只是一个 `ConfigFile`：`list = [{base, class, icon, is_abstract, is_tool, language, path} …]`，按 class 排序，
## 要的东西全在每个脚本头几行。[DevNav] 缺类时调 `write(scan())`，不到一秒，然后重开。
##
## **不写 `class_name`**、不引用任何项目全局类：它就是在缓存坏了的时候跑的（[DevNav] 用 `preload` 拿）。
## 和编辑器写的那份逐条对照的测试在 `tests/tools/test_class_cache.gd` —— Godot 升级改了格式那条先红
extends RefCounted

const CACHE_PATH := "res://.godot/global_script_class_cache.cfg"
## 不扫的目录（隐藏目录、带 `.gdignore` 的也不扫 —— 和编辑器一样）
const SKIP_DIRS := ["res://.godot", "res://.git", "res://.claude"]
## 文件头里能出现的注解（遇到别的注解就是成员了，头读完）
const HEAD_ANNOTATIONS := ["@tool", "@abstract", "@icon", "@static_unload"]


## 扫全项目：每个写了 `class_name` 的脚本一条 `{base, class, icon, is_abstract, is_tool, language, path}`，按 class 排序
static func scan(root: String = "res://") -> Array[Dictionary]:
	var heads := {}     # path → 头信息
	_walk(root, heads)
	var by_path := {}
	for path in heads:
		var h: Dictionary = heads[path]
		if String(h["class"]) != "":
			by_path[path] = h
	var out: Array[Dictionary] = []
	for path in by_path:
		var h: Dictionary = by_path[path]
		out.append({
			"base": StringName(_base_of(h, heads)),
			"class": StringName(h["class"]),
			"icon": String(h["icon"]),
			"is_abstract": bool(h["is_abstract"]),
			"is_tool": bool(h["is_tool"]),
			"language": &"GDScript",
			"path": String(path),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["class"]) < String(b["class"]))
	return out


## 写成编辑器那份的样子（`.godot/` 没有就先建）
static func write(entries: Array[Dictionary], path: String = CACHE_PATH) -> Error:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			return err
	var plain: Array = []     # 不带类型：编辑器写的是 `list=[{…}]`，带类型会写成 `Array[Dictionary]([…])`
	plain.append_array(entries)
	var cfg := ConfigFile.new()
	cfg.set_value("", "list", plain)
	return cfg.save(path)


## 读一份缓存（测试对照用）：class → 那一条
static func read(path: String = CACHE_PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {}
	var out := {}
	for e in cfg.get_value("", "list", []):
		out[String((e as Dictionary).get("class", ""))] = e
	return out


static func _walk(path: String, heads: Dictionary) -> void:
	if SKIP_DIRS.has(path.trim_suffix("/")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	if dir.file_exists(".gdignore"):
		return
	dir.include_hidden = false
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_walk(path.path_join(sub), heads)
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var p := path.path_join(f)
			heads[p] = head_of(p)


## 一个脚本的文件头：`{class, extends, icon, is_tool, is_abstract}`（从头读到第一行不是空行 / 注释 / 文件头注解 / class_name / extends 为止）
static func head_of(path: String) -> Dictionary:
	var h := {"class": "", "extends": "", "icon": "", "is_tool": false, "is_abstract": false}
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return h
	while not fa.eof_reached():
		var line := fa.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("@"):
			var word := line.get_slice("(", 0).get_slice(" ", 0)
			if not HEAD_ANNOTATIONS.has(word):
				break
			match word:
				"@tool":
					h["is_tool"] = true
				"@abstract":
					h["is_abstract"] = true
				"@icon":
					h["icon"] = line.get_slice("\"", 1)
			var rest := line.substr(word.length()).strip_edges()
			if word == "@icon":
				rest = line.substr(line.find(")") + 1).strip_edges()
			if rest == "":
				continue
			line = rest     # 注解和 class_name / extends 写在同一行
		var matched := false
		for part in _split_decls(line):
			if part.begins_with("class_name "):
				h["class"] = part.substr(11).strip_edges().get_slice(" ", 0)
				matched = true
			elif part.begins_with("extends "):
				h["extends"] = part.substr(8).strip_edges()
				matched = true
		if not matched:
			break
	return h


## `class_name A extends B` 一行写两件：拆开
static func _split_decls(line: String) -> Array[String]:
	var out: Array[String] = []
	var cut := line.find(" extends ")
	if line.begins_with("class_name ") and cut > 0:
		out.append(line.substr(0, cut).strip_edges())
		out.append(line.substr(cut + 1).strip_edges())
	else:
		out.append(line)
	return out


## 基类：裸名字照写（原生类或别的全局类，和编辑器一样）；`"res://…"` 路径就看那份脚本（有 class_name 用它，没有接着往上找）；没写是 RefCounted
static func _base_of(h: Dictionary, heads: Dictionary, depth: int = 0) -> String:
	var ext := String(h["extends"]).strip_edges()
	if ext == "":
		return "RefCounted"
	if ext.begins_with("\"") or ext.begins_with("'"):
		var parent_path := ext.substr(1, ext.length() - 2)
		var parent: Dictionary = heads[parent_path] if heads.has(parent_path) else head_of(parent_path)
		if String(parent["class"]) != "":
			return String(parent["class"])
		return _base_of(parent, heads, depth + 1) if depth < 16 else "RefCounted"
	return ext.get_slice(".", 0).get_slice(" ", 0).get_slice(":", 0)
