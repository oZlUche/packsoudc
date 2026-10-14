## 173 §3.2.5：读档时的修复报告 —— 对账层（[SaveReconcile]）与各容器的 `from_dict` 把每一件「没按原样回来」的道具记在这里，
## **没有一次丢东西是静默的**。写到存档位里的 `last_repair.json`，读取存档屏 / 主菜单说一句，看过即删（[GameFlow.repair_notice]）。
class_name SaveReport
extends RefCounted

const FILE := "last_repair.json"

## 折了钱的：`{id, value, from}`（查不到定义、退役、或哪儿都放不下）
var refunded: Array = []
## 换了位置的：`{id, from, to}`（原位放不下，挪到别的空位 / 别的页 / 地上 / 仓库）
var rehomed: Array = []
## 退役表让它换成另一件的：`{id, to, from}`
var replaced: Array = []
## 退役表写明「丢掉」的：`{id, from}`
var dropped: Array = []
## 一局档因版本更新作废，带的东西放回了仓库
var salvaged: bool = false
## 一局档作废前捞出来的道具字典（对账过的），等调用方放进仓库；不写进文件
var salvage: Array = []
## 捞的时候退役道具折的钱（进局外 funds；一局的钱包随这一局作废）
var salvage_funds: int = 0
## 主文件读不出来，用了上一份（`.prev`）
var prev_used: bool = false
## 098：读不出来、备份下来的文件
var backup: String = ""
## 3.5：存档里记的内容版本与现在的（只作诊断）
var stamp_saved: String = ""
var stamp_now: String = ""


func refund(id: StringName, value: int, from: String) -> void:
	refunded.append({"id": String(id), "value": maxi(0, value), "from": from})


func rehome(id: StringName, from: String, to: String) -> void:
	rehomed.append({"id": String(id), "from": from, "to": to})


func replace(id: StringName, to: StringName, from: String) -> void:
	replaced.append({"id": String(id), "to": String(to), "from": from})


func drop(id: StringName, from: String) -> void:
	dropped.append({"id": String(id), "from": from})


func refund_total() -> int:
	var n := 0
	for r in refunded:
		n += int((r as Dictionary).get("value", 0))
	return n


## 有没有要告诉玩家的
func is_empty() -> bool:
	return refunded.is_empty() and rehomed.is_empty() and replaced.is_empty() and dropped.is_empty() and not salvaged and not prev_used


## 清掉逐件的记录（换用上一份存档时，主文件那一遍记下的作废）
func clear_items() -> void:
	refunded.clear()
	rehomed.clear()
	replaced.clear()
	dropped.clear()
	salvage.clear()
	salvage_funds = 0


## 把另一份并进来（局外与一局各读一次，写进同一个文件）
func merge(other: SaveReport) -> void:
	if other == null:
		return
	refunded.append_array(other.refunded)
	rehomed.append_array(other.rehomed)
	replaced.append_array(other.replaced)
	dropped.append_array(other.dropped)
	salvaged = salvaged or other.salvaged
	prev_used = prev_used or other.prev_used
	if other.backup != "":
		backup = other.backup
	if other.stamp_saved != "":
		stamp_saved = other.stamp_saved
	if other.stamp_now != "":
		stamp_now = other.stamp_now


func to_dict() -> Dictionary:
	return {"refunded": refunded.duplicate(true), "rehomed": rehomed.duplicate(true), "replaced": replaced.duplicate(true),
		"dropped": dropped.duplicate(true), "salvaged": salvaged, "prev_used": prev_used, "backup": backup,
		"content_stamp": {"saved": stamp_saved, "now": stamp_now}}


static func from_dict(d: Dictionary) -> SaveReport:
	var r := SaveReport.new()
	for key in ["refunded", "rehomed", "replaced", "dropped"]:
		var raw: Variant = d.get(key, [])
		if raw is Array:
			for row in raw:
				if row is Dictionary:
					(r.get(key) as Array).append((row as Dictionary).duplicate())
	r.salvaged = bool(d.get("salvaged", false))
	r.prev_used = bool(d.get("prev_used", false))
	r.backup = String(d.get("backup", ""))
	var stamp: Variant = d.get("content_stamp", {})
	if stamp is Dictionary:
		r.stamp_saved = String((stamp as Dictionary).get("saved", ""))
		r.stamp_now = String((stamp as Dictionary).get("now", ""))
	return r


## 给玩家看的一句（空报告返回空串）
func summary() -> String:
	if is_empty():
		return ""
	var parts: Array[String] = []
	if prev_used:
		parts.append(UiText.t("repair.prev"))
	if salvaged:
		parts.append(UiText.t("repair.salvaged"))
	if not refunded.is_empty():
		parts.append(UiText.t("repair.refunded") % [refunded.size(), refund_total()])
	if not replaced.is_empty():
		parts.append(UiText.t("repair.replaced") % replaced.size())
	if not rehomed.is_empty():
		parts.append(UiText.t("repair.rehomed") % rehomed.size())
	if not dropped.is_empty():
		parts.append(UiText.t("repair.dropped") % dropped.size())
	return UiText.t("repair.head") + UiText.t("repair.sep").join(parts)


## 写进 [param path]；已经有一份没看过的就并起来（局外读一次、继续那一局再读一次）
func append_to(path: String) -> Error:
	if is_empty():
		return OK
	var all := read(path)
	if all == null:
		all = SaveReport.new()
	all.merge(self)
	return AtomicFile.write(path, JSON.stringify(all.to_dict(), "  ", false) + "\n")


## 读一份（没有或坏了返回 null）
static func read(path: String) -> SaveReport:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(parsed as Dictionary) if parsed is Dictionary else null


## 读出来就删（看过即删）
static func consume(path: String) -> SaveReport:
	var r := read(path)
	AtomicFile.remove(path)
	return r
