## 有没有没导入的素材（158）：别人加了图片，本地 `.godot/imported/` 里还没有它导出的文件。
##
## 只有这种情况才真要跑 `--import`（类缓存由 `tools/class_cache.gd` 自己写）。判定：每份 `.import` 的 `[deps] dest_files`
## 有一个不在 = 没导；素材文件旁边连 `.import` 都没有（新图第一次进来）也算没导。
## **不写 `class_name`**、不引用项目全局类：和 `class_cache.gd` 一样在缓存坏着的时候也得能跑（[DevNav] 用 `preload` 拿）
extends RefCounted

## 要导入的素材扩展名（旁边该有 `.import`）
const ASSET_EXTS := ["png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3", "ttf", "otf"]
const SKIP_DIRS := ["res://.godot", "res://.git", "res://.claude"]


## 没导入的素材（源文件路径，排好序）；空 = 都导过了
static func missing(root: String = "res://") -> Array[String]:
	var out: Array[String] = []
	_walk(root, out)
	out.sort()
	return out


## 一份 `.import` 的目标都在不在（读不了当不在）
static func imported(import_path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return false
	var dests: Array = cfg.get_value("deps", "dest_files", [])
	for d in dests:
		if not FileAccess.file_exists(String(d)):
			return false
	return true


static func _walk(path: String, out: Array[String]) -> void:
	if SKIP_DIRS.has(path.trim_suffix("/")):
		return
	var dir := DirAccess.open(path)
	if dir == null or dir.file_exists(".gdignore"):
		return
	dir.include_hidden = false
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_walk(path.path_join(sub), out)
	var files := dir.get_files()
	for f in files:
		var p := path.path_join(f)
		if f.ends_with(".import"):
			if not imported(p):
				out.append(p.trim_suffix(".import"))
		elif ASSET_EXTS.has(f.get_extension().to_lower()) and not files.has(f + ".import"):
			out.append(p)
