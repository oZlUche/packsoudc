## 一局里的地图 buff（062）：事件的后果给的那些，有的整局有效、有的几步就没（`left`）。
## 走一步（或原地耗时）少一步，到 0 就没了；给重复的只刷新时限。
##
## 101 第 1 刀：一局里拿到的 buff 的状态、给 / 去 / 查 / 走表的接线全在这里，[RunState] 只管发「花掉行动点了」。
## 局外带进来的 buff（`meta_buffs`）与定义表仍然在 [RunState] 上 —— 开局那一刻（模块还装不上的时候）
## 要用它们算体力上限与开局钱，见报告 101 的「落地」。取它用 [method of]。
class_name BuffModule
extends RunModule

const ID := &"buff"

## 这一局的 buff 变了（给了、到期了）
signal buffs_changed()

## 每条 `{"id": String, "left": int}`（left = 还能走几步，-1 = 整局）
var entries: Array[Dictionary] = []


## 这一局的 buff 模块（没装返回 null）
static func of(run: RunState) -> BuffModule:
	return run.module(ID) as BuffModule if run != null else null


## 这一局现在挂着的地图 buff（没装就是空）
static func entries_of(run: RunState) -> Array[Dictionary]:
	var m := of(run)
	return m.entries if m != null else [] as Array[Dictionary]


func id() -> StringName:
	return ID


func describe() -> String:
	return "一局里能拿到 buff：事件给的，有的整局有效、有的几步就没"


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	run.hooks.register(&"grant_map_buff", grant)     # 8-3：事件的后果给 / 去 / 查
	run.hooks.register(&"remove_map_buff", remove)
	run.hooks.register(&"has_map_buff", has)
	if not run.stepped.is_connected(_on_stepped):
		run.stepped.connect(_on_stepped)


## 给一个地图 buff（事件的后果）。不认识的 id、局外的 buff 给不了；已经有的刷新时限
func grant(bid: StringName) -> bool:
	var def: RunBuffDef = _run.buff_defs.get(bid, null) if _run != null else null
	if def == null or not def.is_map():
		return false
	var left := def.duration_steps if def.duration_steps > 0 else -1
	for entry in entries:
		if String(entry["id"]) == String(bid):
			entry["left"] = left
			buffs_changed.emit()
			return true
	entries.append({"id": String(bid), "left": left})
	buffs_changed.emit()
	return true


func remove(bid: StringName) -> bool:
	for i in entries.size():
		if String(entries[i]["id"]) == String(bid):
			entries.remove_at(i)
			buffs_changed.emit()
			return true
	return false


func has(bid: StringName) -> bool:
	for entry in entries:
		if String(entry["id"]) == String(bid):
			return true
	return false


## 这一局现在挂着的 buff 的定义（按 [member RunState.buff_defs] 查；查不到的跳过）
func defs() -> Array:
	var out: Array = []
	if _run == null:
		return out
	for entry in entries:
		var def: RunBuffDef = _run.buff_defs.get(StringName(String(entry["id"])), null)
		if def != null:
			out.append(def)
	return out


## 花掉了行动点：有时限的少一步，到 0 就没了
func tick() -> void:
	var changed_any := false
	var i := entries.size() - 1
	while i >= 0:
		var left := int(entries[i]["left"])
		if left > 0:
			left -= 1
			if left == 0:
				entries.remove_at(i)
			else:
				entries[i]["left"] = left
			changed_any = true
		i -= 1
	if changed_any:
		buffs_changed.emit()


func to_dict() -> Dictionary:
	return {"map": entries.duplicate(true)}


func restore(d: Dictionary) -> void:
	for entry in d.get("map", []):
		if entry is Dictionary:
			entries.append({"id": String((entry as Dictionary).get("id", "")), "left": int((entry as Dictionary).get("left", -1))})


func _on_stepped(_node_id: int, _reason: StringName) -> void:
	tick()
