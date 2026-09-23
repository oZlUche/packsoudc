## 存档文件（架构文档 7.2，M5）：`RunState.to_dict()` → JSON → `user://`。
##
## 从第一天就写版本号：读到不认识的版本不猜，返回 null 并说明 —— 迁移是将来加字段时的事，
## 有版本号才有迁移的余地。内容库（道具、敌人、章节）不进存档，读档时由调用方给：
## 存档只写 id，内容改了存档照样读得回来（3.1：存档只写 id，绝不写资源路径）。
class_name RunSave
extends RefCounted

const DEFAULT_PATH := "user://run.json"


static func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func write(state: RunState, path: String = DEFAULT_PATH) -> Error:
	if state == null:
		return ERR_INVALID_PARAMETER
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_text(state))
	f.close()
	return OK


static func to_text(state: RunState) -> String:
	return JSON.stringify(state.to_dict(), "  ", false) + "\n"


## 读回来。章节按 id 从资产目录取；找不到、版本不对、文件坏了都返回 null，原因打进 push_warning
static func read(items: ItemDatabase, enemies: EnemyDatabase, sets: SetDatabase = null, path: String = DEFAULT_PATH) -> RunState:
	if not FileAccess.file_exists(path):
		return null
	return from_text(FileAccess.get_file_as_string(path), items, enemies, sets)


static func from_text(text: String, items: ItemDatabase, enemies: EnemyDatabase, sets: SetDatabase = null) -> RunState:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("RunSave: 存档不是合法的 JSON 对象")
		return null
	var d := parsed as Dictionary
	if int(d.get("version", -1)) != RunState.SAVE_VERSION:
		push_warning("RunSave: 存档版本 %s，本版只认 %d —— 迁移还没写" % [str(d.get("version", "?")), RunState.SAVE_VERSION])
		return null
	var chapter := load_chapter(StringName(String(d.get("chapter", ""))))
	if chapter == null:
		push_warning("RunSave: 找不到章节 '%s'" % d.get("chapter", ""))
		return null
	return RunState.from_dict(d, chapter, items, enemies, sets)


static func load_chapter(id: StringName) -> ChapterDef:
	var path := ContentPaths.asset_file("chapters", String(id))
	return load(path) as ChapterDef if ResourceLoader.exists(path) else null


static func remove(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
