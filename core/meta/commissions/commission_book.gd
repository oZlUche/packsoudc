## 336（W0，报告 335 第三节）：委托的局外状态 —— 跟局外存档（[member MetaState.commissions]，键 `commissions`）。
## 老档没有这一键 = 全空：没接过委托、各方声望 0（新字段带默认值，不升存档版本，098 的规矩）。
##
## 只存数，不认定义：规则（能不能接、给几点）都在 [Commissions]
class_name CommissionBook
extends RefCounted

## 一份委托的状态（[member entries] 里每份的 `state`；没有这一份 = 还没接过）
const TAKEN := "taken"
const PAUSED := "paused"
const DONE := "done"
## 作者 2026-11-21：办成了、还没点【完成】—— 留在委托页上，点了才发酬金、开设施、出下一份（交货除外：交够直接结案）
const READY := "ready"
## 回执最多留几条（新的在前）
const RECEIPTS_MAX := 20

## 阵营 id → 声望
var rep: Dictionary = {}
## 做完了结案（署名）的阵营 id → true（报告 389 起节点只看声望，这一项只是记一笔）
var signed: Dictionary = {}
## 委托 id → {"state", "stage": 第几步（0 起）, "progress": 这一步做了几次, "keys": 记过账的去重键, "times": 完成过几次, "pick": 接单时选的（配方 id）}
var entries: Dictionary = {}
## 互斥组 → 结了这一组的委托 id
var mutex: Dictionary = {}
## 回执：{"id": 委托 id, "kind": done / step / redo, "stage": 第几步, "run": 第几局}，新的在前
var receipts: Array[Dictionary] = []
## 登记的线索（W2 用）：{"id", "faction", "run"}
var clues: Array[Dictionary] = []
## 342 B2：剧情办成后开放的基地设施，设施 id → true
var grants: Dictionary = {}
## 342 B2：这份进度从新档开始（建档时设，[method GameFlow.new_meta]）—— 只有它，教程走完后铁匠铺、科技、集市才要剧情开放；
## 老档、测试直接建的局外都是假：设施一直开着
var gated := false
## 342 B2 告示栏（[NoticeBoard]）：纸条 id → 纸条（阵营、目标、件数、档、酬金、还剩几局）
var notes: Dictionary = {}
## 钉位：每格一张没接的纸条 id，空串 = 空着
var pins: Array = []
## 纸条编号
var note_seq := 0
## 贴过第一批没有
var board_init := false
## 342 B3：后来的几方到营地的那一局，阵营 id → 第几局（[method Commissions.arrive]）
var arrived: Dictionary = {}
## 377：教程之后成功撤离过几局正式探索（万神院按它来营地，[member FactionDef.arrive_after]）
var formal_extractions := 0
## 报告 389：刚跨过、还没通知玩家的节点 [{"faction", "node"}]，先到的在前（营地里一条一条亮出来）
var node_news: Array[Dictionary] = []


func _init() -> void:
	Commissions.active = self


func rep_of(faction: StringName) -> int:
	return int(rep.get(String(faction), 0))


func entry(id: StringName) -> Dictionary:
	return entries.get(String(id), {})


func state_of(id: StringName) -> String:
	return String(entry(id).get("state", ""))


## 正在做（接了、没暂缓）的委托 id，按接单先后
func taken() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in entries:
		if String((entries[k] as Dictionary).get("state", "")) == TAKEN:
			out.append(StringName(k))
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		var sa := int(entry(a).get("seq", 0))
		var sb := int(entry(b).get("seq", 0))
		return sa < sb if sa != sb else String(a) < String(b))
	return out


## 办成了等点【完成】的委托 id，按接单先后
func ready() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in entries:
		if String((entries[k] as Dictionary).get("state", "")) == READY:
			out.append(StringName(k))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return int(entry(a).get("seq", 0)) < int(entry(b).get("seq", 0)))
	return out


## 手上的：在做的 + 办成了等点【完成】的（委托页、手头托盘列这些）
func in_hand() -> Array[StringName]:
	var out := taken()
	out.append_array(ready())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return int(entry(a).get("seq", 0)) < int(entry(b).get("seq", 0)))
	return out


func is_done(id: StringName) -> bool:
	return int(entry(id).get("times", 0)) > 0


func add_receipt(row: Dictionary) -> void:
	receipts.push_front(row)
	while receipts.size() > RECEIPTS_MAX:
		receipts.pop_back()


func is_empty() -> bool:
	return rep.is_empty() and entries.is_empty() and receipts.is_empty() and clues.is_empty() and grants.is_empty() and not gated and notes.is_empty() and not board_init and arrived.is_empty() and node_news.is_empty()


## 存档：字典的键排好序（同一份状态逐字节相同）
func to_dict() -> Dictionary:
	return {
		"rep": _sorted(rep),
		"signed": _sorted(signed),
		"entries": _sorted(entries),
		"mutex": _sorted(mutex),
		"receipts": receipts.duplicate(true),
		"clues": clues.duplicate(true),
		"grants": _sorted(grants),
		"gated": gated,
		"notes": _sorted(notes),
		"pins": pins.duplicate(),
		"note_seq": note_seq,
		"board_init": board_init,
		"arrived": _sorted(arrived),
		"formal_extractions": formal_extractions,
		"node_news": node_news.duplicate(true),
	}


static func _sorted(d: Dictionary) -> Dictionary:
	var out := {}
	var keys := d.keys()
	keys.sort()
	for k in keys:
		out[k] = d[k].duplicate(true) if d[k] is Dictionary or d[k] is Array else d[k]
	return out


static func from_dict(d: Variant) -> CommissionBook:
	var b := CommissionBook.new()
	if not (d is Dictionary):
		return b
	var src := d as Dictionary
	for k in src.get("rep", {}):
		b.rep[String(k)] = maxi(0, int(src["rep"][k]))
	for k in src.get("signed", {}):
		if bool(src["signed"][k]):
			b.signed[String(k)] = true
	for k in src.get("entries", {}):
		var e: Variant = src["entries"][k]
		if not (e is Dictionary):
			continue
		var keys: Array = []
		for x in (e as Dictionary).get("keys", []):
			keys.append(String(x))
		b.entries[String(k)] = {
			"state": String(e.get("state", "")),
			"stage": maxi(0, int(e.get("stage", 0))),
			"progress": maxi(0, int(e.get("progress", 0))),
			"keys": keys,
			"times": maxi(0, int(e.get("times", 0))),
			"pick": String(e.get("pick", "")),
			"seq": int(e.get("seq", 0)),
		}
	for k in src.get("mutex", {}):
		b.mutex[String(k)] = String(src["mutex"][k])
	for row in src.get("receipts", []):
		if row is Dictionary:
			b.receipts.append(MapGraph.normalize(row))
	for row in src.get("clues", []):
		if row is Dictionary:
			b.clues.append(MapGraph.normalize(row))
	for k in src.get("grants", {}):
		if bool(src["grants"][k]):
			b.grants[String(k)] = true
	b.gated = bool(src.get("gated", false))
	for k in src.get("notes", {}):
		if src["notes"][k] is Dictionary:
			b.notes[String(k)] = MapGraph.normalize(src["notes"][k])
	for x in src.get("pins", []):
		b.pins.append(String(x) if x != null else "")
	b.note_seq = int(src.get("note_seq", 0))
	b.board_init = bool(src.get("board_init", false))
	if src.get("arrived", null) is Dictionary:
		for k in src["arrived"]:
			b.arrived[String(k)] = int(src["arrived"][k])
	b.formal_extractions = maxi(0, int(src.get("formal_extractions", 0)))     # 377：老档没有 = 0
	for row in src.get("node_news", []):
		if row is Dictionary:
			b.node_news.append({"faction": String(row.get("faction", "")), "node": String(row.get("node", ""))})
	Commissions.active = b
	return b
