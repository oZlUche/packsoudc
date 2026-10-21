## 成就与解锁（091；101 第 4 刀从 [GameFlow] 抽出来）。
##
## 纯逻辑：看局外状态（[MetaState]）与内容（成就表、道具库、章节、难度）算「有没有新成就」「这个解锁开了什么」
## 「现在哪些道具锁着」。**不碰存盘、不碰转屏** —— 那两件事是 [GameFlow] 的（它调完这里按返回值决定要不要存）。
##
## 「全部解锁」（老手开关，[GameSettings.unlock_all]）开着时成就不计、一切都算解锁（作者定 10.2 第 4 条）：
## 这个开关由持有方在 [member unlock_all] 上给，服务不认识 [GameSettings]。
class_name Achievements
extends RefCounted

var meta: MetaState = null
var defs: Array[AchievementDef] = []
var items: ItemDatabase = null
var chapters: Array[ChapterDef] = []
var difficulties: Array[DifficultyDef] = []
## 老手的「全部解锁」开着吗（持有方设）
var unlock_all: bool = false
## 新完成的成就攒下的通知（地图屏取走打进日志）。[method check] 往里加，持有方 [method GameFlow.take_notes] 取
var notes: Array[String] = []


## 看有没有新完成的成就：完成了记进局外、给它许诺的解锁、攒一句通知。返回新完成的（非空 = 局外变了，持有方该存盘）
func check() -> Array[AchievementDef]:
	var got: Array[AchievementDef] = []
	if meta == null or unlock_all:
		return got
	for def in defs:
		if def == null or meta.has_achievement(def.id) or not def.is_met(meta):
			continue
		meta.complete_achievement(def.id)
		var opened: Array[String] = []
		for g in def.grants:
			meta.grant_unlock(g)
			opened.append_array(unlock_names(g))
		notes.append(UiText.t("ach.done_note") % [Names.of(def), UiText.t("ach.done_unlocks") % UiText.t("hud.buff_sep").join(opened) if not opened.is_empty() else ""])
		got.append(def)
	return got


func of_id(id: StringName) -> AchievementDef:
	for def in defs:
		if def != null and def.id == id:
			return def
	return null


## 哪一枚成就给这个解锁 id；没有 null
func granting(unlock_id: StringName) -> AchievementDef:
	for def in defs:
		if def != null and def.grants.has(unlock_id):
			return def
	return null


## 这个解锁 id 开的是什么（成就页写「解锁：道具 X、地图 Y、难度 Z」）
func unlock_names(unlock_id: StringName) -> Array[String]:
	var out: Array[String] = []
	if items != null:
		for id in items.all_ids():
			var def := items.get_def(id)
			if def != null and def.requires_unlock == unlock_id:
				out.append(UiText.t("ach.unlock_item") % Names.of(def))
	for c in chapters:
		if c != null and c.requires_unlock == unlock_id:
			out.append(UiText.t("ach.unlock_map") % Names.of(c))
	for d in difficulties:
		if d != null and d.requires_unlock == unlock_id:
			out.append(UiText.t("ach.unlock_difficulty") % Names.of(d))
	return out


## 解锁了吗（空 = 不需要解锁；「全部解锁」开着 = 都算）
func unlocked(id: StringName) -> bool:
	if id == &"" or unlock_all:
		return true
	return meta != null and meta.has_unlock(id)


## 现在锁着的道具（`requires_unlock` 还没解锁）
func locked_item_ids() -> Array:
	var out: Array = []
	if items == null:
		return out
	for id in items.gated_ids():
		var def := items.get_def(id)
		if def != null and not unlocked(def.requires_unlock):
			out.append(id)
	return out


## 把锁着的道具设进道具库（搜索 / 掉落 / 商店 / 敌人的池都从 `ids()` 拿）。开局前调；设置改了也调
func apply_item_locks() -> void:
	if items != null:
		items.set_locked(locked_item_ids())


## 091（10.2 第 3 条）：这一章有「本图规则」卡、而且还没看过 → 地图屏第一次打开时弹
func rules_card_pending(chapter: ChapterDef) -> bool:
	return chapter != null and not chapter.rules.is_empty() and meta != null and not meta.has_seen_rules(chapter.id)


## 看过了。返回局外变了没有（持有方据此存盘）
func mark_rules_seen(chapter: ChapterDef) -> bool:
	if chapter == null or meta == null or meta.has_seen_rules(chapter.id):
		return false
	meta.mark_rules_seen(chapter.id)
	return true
