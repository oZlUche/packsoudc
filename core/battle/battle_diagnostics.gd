## 平衡检测方案（2026-11-10）§5.2：战斗诊断包（[BattleDiagPack]）的开关、落盘、滚动清理与固定导出。
##
## 默认关：完整包只在开发实验和明确的诊断采集模式下抓（命令行 `-- --diag-capture`、环境变量 `PACKSDC_DIAG=1`，或代码里设 [member enabled]）。
## 落在 [constant DIR]，只留最近 [constant KEEP] 份；[method pin] 把某一份复制进 [constant PINNED]（玩家反馈的样本），那里不清理。
## 写盘失败只记一条警告，不影响对局；[member failures] 数着，报告诊断覆盖缺口用
class_name BattleDiagnostics
extends RefCounted

const ROOT := "user://diagnostics"
const DIR := ROOT + "/battles"
const PINNED := ROOT + "/pinned"
const KEEP := 200
const ARG := "--diag-capture"
const ENV := "PACKSDC_DIAG"

## null = 按命令行和环境变量定（第一次问时定下）
static var enabled: Variant = null
## 落在哪（测试改到自己的目录）
static var target_dir: String = DIR
static var written: int = 0
static var failures: int = 0
## 最近一次写盘花的毫秒、写出的字节（测开销用）
static var last_ms: float = 0.0
static var last_bytes: int = 0


static func on() -> bool:
	if enabled == null:
		enabled = OS.get_cmdline_user_args().has(ARG) or OS.get_environment(ENV) == "1"
	return bool(enabled)


## 写一份到 [param p_dir]（空 = [member target_dir]），文件名 = [param stem] + [constant BattleDiagPack.EXT]；返回路径，写不了返回空
static func write(pack: BattleDiagPack, stem: String, p_dir: String = "", keep: int = KEEP) -> String:
	var t0 := Time.get_ticks_usec()
	var dir := p_dir if p_dir != "" else target_dir
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		failures += 1
		push_warning("BattleDiagnostics: 建不了 %s" % dir)
		return ""
	var path := dir.path_join(_safe(stem) + BattleDiagPack.EXT)
	var err := ResourceSaver.save(pack, path)
	if err != OK:
		failures += 1
		push_warning("BattleDiagnostics: 写不了 %s（%s）" % [path, error_string(err)])
		return ""
	written += 1
	last_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var f := FileAccess.open(path, FileAccess.READ)
	last_bytes = f.get_length() if f != null else 0
	prune(dir, keep)
	return path


## 读一份；读不出来（坏文件、缺资源、不是诊断包）返回 null
static func load_pack(path: String) -> BattleDiagPack:
	if not FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BattleDiagPack


## 只留最近 [param keep] 份（按文件名 = 时间排）。返回删了几份
static func prune(dir: String = DIR, keep: int = KEEP) -> int:
	var files := list(dir)
	var drop := files.size() - keep
	for i in maxi(0, drop):
		DirAccess.remove_absolute(dir.path_join(files[i]))
	return maxi(0, drop)


## 目录里的诊断包文件名，升序
static func list(dir: String = DIR) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(BattleDiagPack.EXT):
			out.append(f)
	out.sort()
	return out


## 固定导出一份（复制到 [constant PINNED]，不受滚动清理）。返回新路径，失败返回空
static func pin(path: String, pinned_dir: String = PINNED) -> String:
	if not FileAccess.file_exists(path):
		return ""
	DirAccess.make_dir_recursive_absolute(pinned_dir)
	var dst := pinned_dir.path_join(path.get_file())
	return dst if DirAccess.copy_absolute(path, dst) == OK else ""


## 文件名：时间 + 战斗标识（没有就用种子）
static func stem_of(meta: Dictionary) -> String:
	var t := Time.get_datetime_dict_from_system()
	var id := String(meta.get("battle_id", "seed%d" % int(meta.get("rng_seed", 0))))
	return "%04d%02d%02d-%02d%02d%02d_%s" % [int(t["year"]), int(t["month"]), int(t["day"]), int(t["hour"]), int(t["minute"]),
		int(t["second"]), id]


static func _safe(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or ch == "_" or ch == "-":
			out += ch
		elif ch == ":":
			out += "_"
	return out if out != "" else "x"
