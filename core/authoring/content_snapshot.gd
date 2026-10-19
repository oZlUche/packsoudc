## 173 §3.3：内容快照 —— 把「改了内容忘了交代存档」变成红测试。
##
## 冻结一份 `tests/fixtures/content_snapshot.json`：每个道具的 id、占格数、尺寸、形状、是否包，以及标签、信仰、章节、敌人的 id 表。
## [method problems] 拿冻结的和现在的比：
## - 快照里有、库里没了的道具 → 要在 [constant IdAliases.ITEMS]（改名）或 [constant IdAliases.RETIRED_ITEMS]（退役）里；
## - 形状 / 尺寸 / 是否包变了的 → 要登记进 [constant IdAliases.RESHAPED]（对账层会重摆；同时看一眼敌人预设棋盘的 `at`）；
## - 标签 / 信仰 / 章节 / 敌人消失的 → 要有改名（TAGS / FAITHS / CHAPTERS）或退役记录（[constant IdAliases.RETIRED]）；
## - 新增的不管。
## 补完表之后重生成快照：`bash tools/snapshot_content.sh`
class_name ContentSnapshot
extends RefCounted

const PATH := "res://tests/fixtures/content_snapshot.json"
## 只记 id 的几种：种类 → 作者数据目录
const ID_KINDS := {
	"tags": ContentPaths.AUTHORING_TAGS,
	"faiths": ContentPaths.AUTHORING_FAITHS,
	"chapters": ContentPaths.AUTHORING_CHAPTERS,
	"enemies": ContentPaths.AUTHORING_ENEMIES,
}
## 种类 → 改名表
const ALIAS_TABLES := {
	"tags": IdAliases.TAGS,
	"faiths": IdAliases.FAITHS,
	"chapters": IdAliases.CHAPTERS,
}


## 现在的内容拍一张（[param db] 不给就从资产目录装一份）
static func capture(db: ItemDatabase = null) -> Dictionary:
	if db == null:
		db = ItemDatabase.new()
		db.load_dir()
	var items := {}
	var ids: Array = db.all_ids()
	ids.sort()
	for id in ids:
		items[String(id)] = item_entry(db.get_def(id))
	var out := {"items": items}
	for kind in ID_KINDS:
		out[kind] = Array(ContentPaths.ids_in(String(ID_KINDS[kind])))
	return out


## 一件道具在快照里记什么
static func item_entry(def: ItemDef) -> Dictionary:
	var cells: Array = []
	var size := Vector2i.ZERO
	if def != null and def.shape != null:
		for c in def.shape.cells_rotated(0):
			cells.append([c.x, c.y])
		size = def.shape.size_rotated(0)
	return {"cells": cells.size(), "size": [size.x, size.y], "shape": cells, "bag": def != null and def.is_bag}


## 冻结的那份（没有返回空字典）
static func load_frozen(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## 一件道具一行（改了哪件，diff 一眼看得到）
static func to_text(snap: Dictionary) -> String:
	var keys: Array = snap.keys()
	keys.sort()
	var blocks: PackedStringArray = []
	for key in keys:
		if key == "items":
			var rows: PackedStringArray = []
			var ids: Array = (snap["items"] as Dictionary).keys()
			ids.sort()
			for id in ids:
				rows.append("    %s: %s" % [JSON.stringify(String(id)), JSON.stringify(snap["items"][id], "", true)])
			blocks.append('  "items": {\n' + ",\n".join(rows) + "\n  }")
		else:
			blocks.append("  %s: %s" % [JSON.stringify(String(key)), JSON.stringify(snap[key], "", true)])
	return "{\n" + ",\n".join(blocks) + "\n}\n"


## 冻结的 [param old] 对现在的 [param now]：没交代的改动，一条一句。空 = 都交代了。
## 表可以换（测试里造假表验这套规矩本身）
static func problems(old: Dictionary, now: Dictionary, items_alias: Dictionary = IdAliases.ITEMS,
		retired_items: Dictionary = IdAliases.RETIRED_ITEMS, reshaped: Dictionary = IdAliases.RESHAPED,
		retired: Dictionary = IdAliases.RETIRED, alias_tables: Dictionary = ALIAS_TABLES) -> Array[String]:
	var out: Array[String] = []
	var old_items: Dictionary = old.get("items", {})
	var now_items: Dictionary = now.get("items", {})
	for id in old_items:
		var sid := StringName(String(id))
		if not now_items.has(id):
			if not items_alias.has(sid) and not retired_items.has(sid):
				out.append("道具 %s 没了：改名写进 IdAliases.ITEMS，删掉写进 IdAliases.RETIRED_ITEMS（折钱 / 换件 / 丢掉）" % id)
			continue
		var was: Dictionary = old_items[id]
		var is_now: Dictionary = now_items[id]
		var changed: bool = _ints(was.get("shape", [])) != _ints(is_now.get("shape", [])) \
			or _ints(was.get("size", [])) != _ints(is_now.get("size", [])) or bool(was.get("bag", false)) != bool(is_now.get("bag", false))
		if changed and not reshaped.has(sid):
			out.append("道具 %s 的形状 / 尺寸 / 是否包变了：登记进 IdAliases.RESHAPED，并看一眼敌人预设棋盘的 at" % id
				+ ("；这件有道具图（201），改形状要通知美术重画" if FileAccess.file_exists("res://assets/items/%s.png" % id) else ""))
	for kind in ID_KINDS:
		var table: Dictionary = alias_tables.get(kind, {})
		var gone_ok: Array = retired.get(kind, [])
		var now_ids: Array = now.get(kind, [])
		for id in old.get(kind, []):
			if now_ids.has(id):
				continue
			if table.has(StringName(String(id))) or gone_ok.has(id) or gone_ok.has(StringName(String(id))):
				continue
			out.append("%s 里的 %s 没了：改名写进改名表，删掉写进 IdAliases.RETIRED[\"%s\"]" % [kind, id, kind])
	return out


## JSON 读回来的数都是浮点：比之前一律换成整数
static func _ints(v: Variant) -> Variant:
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_ints(x))
		return out
	if v is float:
		return int(v)
	return v
