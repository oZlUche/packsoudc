## 玩家的设置（058 第 3 条）：现在只有一项 —— 离开一个点时暂存区里还有东西要不要提醒、提醒到什么程度。
##
## 档位是数据不是分支：`WARN_MODES` 列出有哪些档，阈值是两个数。将来加别的设置项就是加字段；
## 存 `user://settings.json`，带版本号，读不到就用默认值（没有设置文件不是错）。
class_name GameSettings
extends RefCounted

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://settings.json"

## 离开点时暂存区的提醒档位：有东西就提 / 只提稀有度 ≥ 阈值的 / 只提价值 ≥ 阈值的 / 不提
const WARN_MODES: Array[StringName] = [&"any", &"rarity", &"value", &"never"]
const WARN_MODE_LABELS := {
	&"any": "有东西就提醒",
	&"rarity": "只提醒稀有度达到某档的",
	&"value": "只提醒价值达到某数的",
	&"never": "从不提醒",
}

var storage_warn_mode: StringName = &"any"
var storage_warn_rarity: int = 2
var storage_warn_value: int = 100
## 084（作者定）：拿走战利品 / 容器里最后一件之后要不要自动关那一屏。默认不关，手动关
var loot_auto_close: bool = false


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"storage_warn_mode": String(storage_warn_mode),
		"storage_warn_rarity": storage_warn_rarity,
		"storage_warn_value": storage_warn_value,
		"loot_auto_close": loot_auto_close,
	}


static func from_dict(d: Dictionary) -> GameSettings:
	var s := GameSettings.new()
	if int(d.get("version", -1)) != SAVE_VERSION:
		return s
	var mode := StringName(String(d.get("storage_warn_mode", "any")))
	s.storage_warn_mode = mode if WARN_MODES.has(mode) else &"any"
	s.storage_warn_rarity = int(d.get("storage_warn_rarity", 2))
	s.storage_warn_value = int(d.get("storage_warn_value", 100))
	s.loot_auto_close = bool(d.get("loot_auto_close", false))
	return s


## 读设置；没有文件、文件坏了、版本不对都返回默认值
static func load_from(path: String = DEFAULT_PATH) -> GameSettings:
	if not FileAccess.file_exists(path):
		return GameSettings.new()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(parsed) if parsed is Dictionary else GameSettings.new()


func save_to(path: String = DEFAULT_PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "  ", false) + "\n")
	f.close()
	return OK


static func remove(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
