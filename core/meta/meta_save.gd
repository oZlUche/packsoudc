## 局外状态的存档文件（M6）：`MetaState.to_dict()` → JSON → `user://meta.json`。与 [RunSave] 同一套做法：
## 带版本号、只写 id、内容库由调用方给。读不到（第一次玩、文件坏了、版本升不上来）返回 null。
## 098：旧版本在 [method from_text] 里先走 [MetaMigrations] 的迁移链；仍然升不上去才返回 null，
## 这时调用方（[GameFlow.use_slot]）**先把文件备份下来再从零开始**，绝不静默覆盖玩家的局外进度。
## 173：写是原子的（[AtomicFile]：`.tmp` → 改名，上一份留成 `.prev`），读不出来先试 `.prev`；
## 版本链之后过一遍内容对账（[SaveReconcile]：删掉 / 改名的道具），放不回原位的由 [MetaState.from_dict] 安置，都记进 [SaveReport]
class_name MetaSave
extends RefCounted

const DEFAULT_PATH := "user://meta.json"


static func exists(path: String = DEFAULT_PATH) -> bool:
	return AtomicFile.exists(path)


static func write(meta: MetaState, path: String = DEFAULT_PATH) -> Error:
	if meta == null:
		return ERR_INVALID_PARAMETER
	return AtomicFile.write(path, to_text(meta))


static func to_text(meta: MetaState) -> String:
	var d := meta.to_dict()
	d["content_stamp"] = ContentPaths.content_stamp()     # 173 §3.5：只作诊断
	return JSON.stringify(d, "  ", false) + "\n"


## [param tech_defs]：科技定义（120）—— 给了就先按进度表算仓库尺寸等派生值再装仓库，见 [method MetaState.from_dict]。
## 173：主文件读不出来再试上一份（`.prev`，[member SaveReport.prev_used]）
static func read(items: ItemDatabase, path: String = DEFAULT_PATH, rules: MetaRules = null, tech_defs: Array = [],
		report: SaveReport = null) -> MetaState:
	var m: MetaState = null
	if FileAccess.file_exists(path):
		m = from_text(FileAccess.get_file_as_string(path), items, rules, tech_defs, report)
	var prev := AtomicFile.prev_path(path)
	if m == null and FileAccess.file_exists(prev):
		var fresh := SaveReport.new() if report != null else null     # 主文件那一遍记下的不算数
		m = from_text(FileAccess.get_file_as_string(prev), items, rules, tech_defs, fresh)
		if m != null and report != null:
			report.clear_items()
			report.merge(fresh)
			report.prev_used = true
			push_warning("MetaSave: %s 读不出来，用了上一份 %s" % [path, prev])
	return m


static func from_text(text: String, items: ItemDatabase, rules: MetaRules = null, tech_defs: Array = [],
		report: SaveReport = null) -> MetaState:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("MetaSave: 存档不是合法的 JSON 对象")
		return null
	var d := MetaMigrations.upgrade(parsed as Dictionary)     # 098：旧版本先按链逐级升（只在读文件这一层做）
	if int(d.get("version", -1)) != MetaState.SAVE_VERSION:
		push_warning("MetaSave: 存档版本 %s 升不到 %d —— 调用方应先备份再从零开始" % [str((parsed as Dictionary).get("version", "?")), MetaState.SAVE_VERSION])
		return null
	if report != null:
		report.stamp_saved = String(d.get("content_stamp", ""))
		report.stamp_now = ContentPaths.content_stamp()
	SaveReconcile.meta(d, items, report)     # 173：删掉 / 改名的道具在这里对账，折的钱进 funds
	return MetaState.from_dict(d, items, rules, tech_defs, report)


static func remove(path: String = DEFAULT_PATH) -> void:
	AtomicFile.remove(path)
