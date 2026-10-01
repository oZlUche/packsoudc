## 存档位（089，作者定）：三个位，每位一份局外（meta.json）+ 可能有一份进行中的一局（run.json）。
##
## 「新的游戏」= 在一个空位上开一份新存档（不是继续现有的）；「继续」= 读当前位；「读取存档」= 换位。
## 目录 `user://slots/<n>/`。老的单文件存档（`user://run.json` / `user://meta.json`）第一次进游戏时搬进第 1 位（[method migrate_legacy]）。
## 纯文件层：不认识 [GameFlow]，谁是当前位记在 [GameSettings.save_slot]
class_name SaveSlots
extends RefCounted

const COUNT := 3
const DEFAULT_ROOT := "user://slots"

var root: String = DEFAULT_ROOT


func _init(p_root: String = DEFAULT_ROOT) -> void:
	root = p_root


func run_path(n: int) -> String:
	return "%s/%d/run.json" % [root, n]


func meta_path(n: int) -> String:
	return "%s/%d/meta.json" % [root, n]


func ensure_dir(n: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%d" % [root, n]))


## 这一位有没有存档（局外文件在就算有）
func exists(n: int) -> bool:
	return n >= 1 and n <= COUNT and (FileAccess.file_exists(meta_path(n)) or FileAccess.file_exists(run_path(n)))


## 这一位有没有进行中的一局
func has_run(n: int) -> bool:
	return FileAccess.file_exists(run_path(n))


func any() -> bool:
	for n in range(1, COUNT + 1):
		if exists(n):
			return true
	return false


## 第一个空位；都满了 -1
func first_empty() -> int:
	for n in range(1, COUNT + 1):
		if not exists(n):
			return n
	return -1


## 098（作者定）：读不出来的存档**先备份再从零开始**，绝不静默覆盖。把这一位的某份文件改名成
## `<名字>.<unix 秒>.bak`，返回备份文件的路径（没这份文件、改名失败返回空）。
## [param which] 是 "meta" 或 "run"。备份文件不算存档：[method exists] / [method remove] 都不看 `.bak`
func backup(n: int, which: String) -> String:
	var from := meta_path(n) if which == "meta" else run_path(n)
	if not FileAccess.file_exists(from):
		return ""
	var to := "%s.%d.bak" % [from, int(Time.get_unix_time_from_system())]
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	if err != OK:
		push_warning("SaveSlots: 备份 %s 失败（%d）" % [from, err])
		return ""
	return to


## 删掉这一位的两份文件
func remove(n: int) -> void:
	for p in [run_path(n), meta_path(n)]:
		var absolute := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


## 老的单文件存档搬进第 1 位（第 1 位空着才搬）。返回搬了没有
func migrate_legacy(legacy_run: String = RunSave.DEFAULT_PATH, legacy_meta: String = MetaSave.DEFAULT_PATH) -> bool:
	var has_legacy := FileAccess.file_exists(legacy_run) or FileAccess.file_exists(legacy_meta)
	if not has_legacy or exists(1):
		return false
	ensure_dir(1)
	var moved := false
	for pair in [[legacy_run, run_path(1)], [legacy_meta, meta_path(1)]]:
		var from: String = pair[0]
		if not FileAccess.file_exists(from):
			continue
		var f := FileAccess.open(from, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		var out := FileAccess.open(pair[1], FileAccess.WRITE)
		if out == null:
			continue
		out.store_string(text)
		out.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(from))
		moved = true
	return moved


## 一位的摘要（读取存档屏写一行）：{"exists", "has_run", "runs", "extractions", "deaths", "modified"（unix 秒，0 = 没有）}
func summary(n: int, items: ItemDatabase, rules: MetaRules = null) -> Dictionary:
	var out := {"exists": exists(n), "has_run": has_run(n), "runs": 0, "extractions": 0, "deaths": 0, "modified": 0}
	if not out["exists"]:
		return out
	var meta := MetaSave.read(items, meta_path(n), rules) if items != null and FileAccess.file_exists(meta_path(n)) else null
	if meta != null:
		out["runs"] = meta.runs
		out["extractions"] = meta.extractions
		out["deaths"] = meta.deaths
	var newest := 0
	for p in [run_path(n), meta_path(n)]:
		if FileAccess.file_exists(p):
			newest = maxi(newest, int(FileAccess.get_modified_time(p)))
	out["modified"] = newest
	return out
