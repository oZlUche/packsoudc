## 173 §3.1：存档文件的原子写与「上一份」回退。
##
## 写：先写 `<file>.tmp`，再把现有的 `<file>` 改名成 `<file>.prev`，最后 `.tmp` 改名成 `<file>` —— 同目录改名是原子的，
## 存盘途中崩溃 / 断电最多留下一份没改名的 `.tmp`，`<file>` 要么是旧的完整一份、要么是新的完整一份，不会是半截 JSON。
## 读：`<file>` 读不出来（坏了、或两次改名之间断电它暂时不在）再试 `.prev`。
## `.tmp` / `.prev` 不算存档：[SaveSlots] 判断有没有档不看它们，删档时一起删
class_name AtomicFile
extends RefCounted

const TMP := ".tmp"
const PREV := ".prev"


static func prev_path(path: String) -> String:
	return path + PREV


static func tmp_path(path: String) -> String:
	return path + TMP


## 写一份。失败时 `<file>` 保持原样（还是上一份）
static func write(path: String, text: String) -> Error:
	var tmp := tmp_path(path)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	var target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var prev := ProjectSettings.globalize_path(prev_path(path))
		if FileAccess.file_exists(prev):
			DirAccess.remove_absolute(prev)
		var moved := DirAccess.rename_absolute(target, prev)
		if moved != OK:
			DirAccess.remove_absolute(target)     # 改不了名就只能直接换掉（.tmp 已经是完整的一份）
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), target)


## 这份文件或它的上一份在不在（两次改名之间断电时只剩 `.prev`）
static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(prev_path(path))


## 文件内容；没有返回空串
static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## 连同 `.prev`、残留的 `.tmp` 一起删
static func remove(path: String) -> void:
	for p in [path, prev_path(path), tmp_path(path)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
