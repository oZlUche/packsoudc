## 有没有没导入的素材（158）：别人加了图片，本地 `.godot/imported/` 里还没有它导出的文件。
##
## 只有这种情况才真要跑 `--import`（类缓存由 `tools/class_cache.gd` 自己写）。判定：每份 `.import` 的 `[deps] dest_files`
## 有一个不在 = 没导；素材文件旁边连 `.import` 都没有（新图第一次进来）也算没导。
## **不写 `class_name`**、不引用项目全局类：和 `class_cache.gd` 一样在缓存坏着的时候也得能跑（[DevNav] 用 `preload` 拿）
extends RefCounted

## 要导入的素材扩展名（旁边该有 `.import`）
const ASSET_EXTS := ["png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3", "ttf", "otf"]
const SKIP_DIRS := ["res://.godot", "res://.git", "res://.claude"]


## 2026-11-21（作者）：只在版本变了才扫 —— 上次扫完一个不缺时把当时的 Git 提交号记在这里，提交号没变就不再扫。
## 放 `.godot/` 里：跟着这份检出走、不进仓库
const STAMP := "res://.godot/devnav_import_head"


## 要不要扫：读不出提交号（不是 Git 检出）就每次都扫；提交号和上次扫完一个不缺时记下的一样就不扫
static func needs_scan(root: String = "res://", stamp: String = STAMP) -> bool:
	var head := git_head(root)
	if head == "":
		return true
	return FileAccess.get_file_as_string(stamp).strip_edges() != head


## 扫完一个不缺：记下当前提交号，同一版本下次不扫。有缺的不记（导入跑完前下次还得再看）
static func remember_clean(root: String = "res://", stamp: String = STAMP) -> void:
	var head := git_head(root)
	if head == "":
		return
	var f := FileAccess.open(stamp, FileAccess.WRITE)
	if f != null:
		f.store_string(head)
		f.close()


## 这份检出当前的 Git 提交号（只读文件，不起 git 进程）；读不出来返回空。
## `.git` 是目录 = 普通检出；是文件（`gitdir: …`）= 工作树，分支引用在 `commondir` 指的公共目录里
static func git_head(root: String = "res://") -> String:
	var base := ProjectSettings.globalize_path(root).trim_suffix("/")
	var git := base.path_join(".git")
	var gitdir := git
	if FileAccess.file_exists(git):
		var line := FileAccess.get_file_as_string(git).strip_edges()
		if not line.begins_with("gitdir:"):
			return ""
		gitdir = line.trim_prefix("gitdir:").strip_edges()
		if gitdir.is_relative_path():
			gitdir = base.path_join(gitdir).simplify_path()
	elif not DirAccess.dir_exists_absolute(git):
		return ""
	var head := FileAccess.get_file_as_string(gitdir.path_join("HEAD")).strip_edges()
	if not head.begins_with("ref:"):
		return head     # 游离 HEAD：直接是提交号（空 = 读不出来）
	var ref := head.trim_prefix("ref:").strip_edges()
	var common := gitdir
	var common_file := gitdir.path_join("commondir")
	if FileAccess.file_exists(common_file):
		var c := FileAccess.get_file_as_string(common_file).strip_edges()
		common = c if not c.is_relative_path() else gitdir.path_join(c).simplify_path()
	for dir in [gitdir, common]:
		var sha := FileAccess.get_file_as_string(String(dir).path_join(ref)).strip_edges()
		if sha != "":
			return sha
	for line in FileAccess.get_file_as_string(common.path_join("packed-refs")).split("\n"):
		if line.ends_with(" " + ref):
			return line.get_slice(" ", 0)
	return ""


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
