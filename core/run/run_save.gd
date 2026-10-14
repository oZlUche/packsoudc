## 存档文件（架构文档 7.2，M5）：`RunState.to_dict()` → JSON → `user://`。
##
## 从第一天就写版本号：读到旧版本先走 [RunMigrations] 的迁移链（098），升不上去才返回 null 并说明 ——
## 一局档允许作废（作者定），但走的是同一条链，不写特例。内容库（道具、敌人、章节）不进存档，读档时由调用方给：
## 存档只写 id，内容改了存档照样读得回来（3.1：存档只写 id，绝不写资源路径）。
## 173：原子写 + `.prev` 回退（[AtomicFile]）；版本链之后过一遍内容对账（[SaveReconcile]），折的钱进钱包；
## 作废的一局（版本升不上来、章节查不到）先把棋盘 / 地上 / 保险箱里的道具捞进 [member SaveReport.salvage]，由 [GameFlow] 放回仓库（待定 2 A）
class_name RunSave
extends RefCounted

const DEFAULT_PATH := "user://run.json"


static func exists(path: String = DEFAULT_PATH) -> bool:
	return AtomicFile.exists(path)


static func write(state: RunState, path: String = DEFAULT_PATH) -> Error:
	if state == null:
		return ERR_INVALID_PARAMETER
	return AtomicFile.write(path, to_text(state))


static func to_text(state: RunState) -> String:
	var d := state.to_dict()
	d["content_stamp"] = ContentPaths.content_stamp()     # 173 §3.5：只作诊断
	return JSON.stringify(d, "  ", false) + "\n"


## 读回来。章节按 id 从资产目录取；找不到、版本不对、文件坏了都返回 null，原因打进 push_warning。
## 173：主文件读不出来再试上一份（`.prev`）；两份都读不出来时，能捞的道具留在 [param report] 的 `salvage` 里
static func read(items: ItemDatabase, enemies: EnemyDatabase, sets: SetDatabase = null, path: String = DEFAULT_PATH,
		report: SaveReport = null) -> RunState:
	var s: RunState = null
	if FileAccess.file_exists(path):
		s = from_text(FileAccess.get_file_as_string(path), items, enemies, sets, report)
	var prev := AtomicFile.prev_path(path)
	if s == null and FileAccess.file_exists(prev):
		var fresh := SaveReport.new()
		var older := from_text(FileAccess.get_file_as_string(prev), items, enemies, sets, fresh)
		if older != null:
			s = older
			if report != null:
				report.clear_items()     # 主文件那一遍记的（含打捞）作废
				report.merge(fresh)
				report.prev_used = true
			push_warning("RunSave: %s 读不出来，用了上一份 %s" % [path, prev])
	return s


static func from_text(text: String, items: ItemDatabase, enemies: EnemyDatabase, sets: SetDatabase = null,
		report: SaveReport = null) -> RunState:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("RunSave: 存档不是合法的 JSON 对象")
		return null
	var d := RunMigrations.upgrade(parsed as Dictionary)     # 098：一局档走同一条链，升不上去就作废（局外进度不受影响）
	var version := int(d.get("version", -1))
	if version != RunState.SAVE_VERSION:
		push_warning("RunSave: 存档版本 %s 升不到 %d —— 这一局作废" % [str((parsed as Dictionary).get("version", "?")), RunState.SAVE_VERSION])
		if version < RunState.SAVE_VERSION:
			_salvage(d, items, report)     # 新版本的档不碰（调用方锁只读）
		return null
	var chapter := load_chapter(StringName(String(d.get("chapter", ""))))
	if chapter == null:
		push_warning("RunSave: 找不到章节 '%s'" % d.get("chapter", ""))
		_salvage(d, items, report)
		return null
	if report != null:
		report.stamp_saved = String(d.get("content_stamp", ""))
		report.stamp_now = ContentPaths.content_stamp()
	SaveReconcile.run(d, items, report)     # 173：删掉 / 改名的道具在这里对账，折的钱进钱包
	return RunState.from_dict(d, chapter, items, enemies, sets, report)


## 待定 2 A：这一局要作废了 —— 对账后把棋盘、地上、保险箱的道具字典捞进报告（退役的折钱记进 salvage_funds，进局外）
static func _salvage(d: Dictionary, items: ItemDatabase, report: SaveReport) -> void:
	if report == null or items == null:
		return
	report.salvage_funds += SaveReconcile.items(d, items, report, SaveReconcile.SALVAGE_ROOTS)
	report.salvage = SaveReconcile.salvageable(d)


static func load_chapter(id: StringName) -> ChapterDef:
	var res := ContentPaths.load_asset("chapters", String(id))
	if res == null:
		res = ContentPaths.load_asset("chapters", String(IdAliases.chapter(id)))     # 114：改过名的章节
	return res as ChapterDef


static func remove(path: String = DEFAULT_PATH) -> void:
	AtomicFile.remove(path)
