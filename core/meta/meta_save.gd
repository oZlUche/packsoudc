## 局外状态的存档文件（M6）：`MetaState.to_dict()` → JSON → `user://meta.json`。与 [RunSave] 同一套做法：
## 带版本号、只写 id、内容库由调用方给。读不到（第一次玩、文件坏了、版本升不上来）返回 null。
## 098：旧版本在 [method from_text] 里先走 [MetaMigrations] 的迁移链；仍然升不上去才返回 null，
## 这时调用方（[GameFlow.use_slot]）**先把文件备份下来再从零开始**，绝不静默覆盖玩家的局外进度。
class_name MetaSave
extends RefCounted

const DEFAULT_PATH := "user://meta.json"


static func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func write(meta: MetaState, path: String = DEFAULT_PATH) -> Error:
	if meta == null:
		return ERR_INVALID_PARAMETER
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_text(meta))
	f.close()
	return OK


static func to_text(meta: MetaState) -> String:
	return JSON.stringify(meta.to_dict(), "  ", false) + "\n"


static func read(items: ItemDatabase, path: String = DEFAULT_PATH, rules: MetaRules = null) -> MetaState:
	if not FileAccess.file_exists(path):
		return null
	return from_text(FileAccess.get_file_as_string(path), items, rules)


static func from_text(text: String, items: ItemDatabase, rules: MetaRules = null) -> MetaState:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("MetaSave: 存档不是合法的 JSON 对象")
		return null
	var d := MetaMigrations.upgrade(parsed as Dictionary)     # 098：旧版本先按链逐级升（只在读文件这一层做）
	if int(d.get("version", -1)) != MetaState.SAVE_VERSION:
		push_warning("MetaSave: 存档版本 %s 升不到 %d —— 调用方应先备份再从零开始" % [str((parsed as Dictionary).get("version", "?")), MetaState.SAVE_VERSION])
		return null
	return MetaState.from_dict(d, items, rules)


static func remove(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
