## 统一教程 B（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §9）：教程的固定奖励账本。
## 每段教程一个包（[member ChapterDef.tutorial_funds] / [member ChapterDef.tutorial_items]），开局那套也算一个包（[constant START]）。
## 正常撤离和跳过走同一个入口 [method claim]；记在 [member MetaState.tutorial_ledger]，同一个包只发一次 ——
## 不看仓库现在有什么（卖掉、合成、花掉的不补第二次）。随机掉落、得分、见识都不在包里
class_name TutorialRewards
extends RefCounted

## 奖励表的版本：表改了要再发一轮时加一（键里带着它）
const VERSION := 1
const STARTED := "in_progress"
const COMPLETED := "completed"
const SKIPPED := "skipped"
## 这个包之前就领过（统一教程之前的老档：打通或跳过了，奖励按当时的规矩发过），不再补
const LEGACY := "legacy"
## 开局那套（[member MetaRules.first_kit]）的包名
const START := &"start"
const DONE: Array[String] = [COMPLETED, SKIPPED, LEGACY]


static func key(stage: StringName) -> String:
	return "%d/%s" % [VERSION, stage]


## 这一段在账本上的状态（没记 = 空串，即还没开始）
static func state_of(meta: MetaState, stage: StringName) -> String:
	if meta == null:
		return ""
	var row = meta.tutorial_ledger.get(key(stage), {})
	return String((row as Dictionary).get("state", "")) if row is Dictionary else ""


static func claimed(meta: MetaState, stage: StringName) -> bool:
	return DONE.has(state_of(meta, stage))


## 记一笔不发东西的状态（开始了、老档领过）。已经领过的不改
static func mark(meta: MetaState, stage: StringName, state: String) -> void:
	if meta == null or claimed(meta, stage):
		return
	meta.tutorial_ledger[key(stage)] = {"state": state}


## 这一段的包还欠什么：{"funds": 金币, "items": [ItemDef]}。领过了是空包。
## [param carried] = 这一局自己带回来的道具（章节 [member ChapterDef.tutorial_items_carried] 时同名的一件抵一个名额）
static func owed(meta: MetaState, chapter: ChapterDef, items: ItemDatabase, carried: Array = []) -> Dictionary:
	var out := {"funds": 0, "items": [] as Array[ItemDef]}
	if chapter == null or claimed(meta, chapter.id):
		return out
	out["funds"] = maxi(0, chapter.tutorial_funds)
	var have := {}
	if chapter.tutorial_items_carried:
		for inst in carried:
			var def := (inst as ItemInstance).def if inst is ItemInstance else null
			if def != null:
				have[def.id] = int(have.get(def.id, 0)) + 1
	for id in chapter.tutorial_items:
		var def := items.get_def(id) if items != null else null
		if def == null:
			continue
		if int(have.get(id, 0)) > 0:
			have[id] = int(have[id]) - 1
			continue
		(out["items"] as Array[ItemDef]).append(def)
	return out


## 发这一段的包、记账（[param how] = [constant COMPLETED] 或 [constant SKIPPED]）。领过了什么也不动、返回空字典；
## 否则返回 {"stage", "funds", "items": [道具 id], "pending": 放不下待入库几件}。只改内存里的局外，存盘由调用方一起做
static func claim(meta: MetaState, chapter: ChapterDef, items: ItemDatabase, how: String, carried: Array = []) -> Dictionary:
	if meta == null or chapter == null or claimed(meta, chapter.id):
		return {}
	var due := owed(meta, chapter, items, carried)
	var ids: Array = (due["items"] as Array).map(func(d: ItemDef) -> String: return String(d.id))
	meta.funds += int(due["funds"])
	var got := meta.grant_lossless(due["items"] as Array)
	meta.tutorial_ledger[key(chapter.id)] = {"state": how, "funds": int(due["funds"]), "items": ids}
	return {"stage": chapter.id, "funds": int(due["funds"]), "items": ids, "pending": int(got["pending"])}


## 跳过之前给玩家看的清单：这些段还欠的加在一起 {"funds", "items": [ItemDef], "claimed": [已领的段 id]}
static func preview(meta: MetaState, chapters: Array[ChapterDef], items: ItemDatabase) -> Dictionary:
	var out := {"funds": 0, "items": [] as Array[ItemDef], "claimed": [] as Array[StringName]}
	for c in chapters:
		if claimed(meta, c.id):
			(out["claimed"] as Array[StringName]).append(c.id)
			continue
		var due := owed(meta, c, items)
		out["funds"] = int(out["funds"]) + int(due["funds"])
		(out["items"] as Array[ItemDef]).append_array(due["items"] as Array[ItemDef])
	return out
