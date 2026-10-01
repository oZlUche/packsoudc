## 按点暂存（087，作者定）：暂存区是**这个点里的临时区** —— 走出一个点，暂存区里的东西**留在那个点上**，
## 回到那个点它们又回到暂存区。不是丢掉，所以地图上标得出哪些点存着东西；撤离仍然不带走暂存区里的东西。
##
## 101 第 1 刀：状态（哪个点存着什么）、存档、两处接线全在这里，[RunState] 只管发「走开了 / 到了」。
## 取它用 [method of]。
class_name NodeStorageModule
extends RunModule

const ID := &"node_storage"

## 走出一个点，暂存区里的 [param items] 留在了 [param node_id] 上
signal dropped(node_id: int, items: Array)
## 回到一个点，那里留着的 [param items] 回到了暂存区
signal restored(node_id: int, items: Array)

## `node_id → [ItemInstance]`
var nodes: Dictionary = {}
var _run: RunState = null
## 读档拿到的那份，等 install 里有道具库了再装回来
var _saved: Dictionary = {}


## 这一局的按点暂存模块（没装返回 null）
static func of(run: RunState) -> NodeStorageModule:
	return run.module(ID) as NodeStorageModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "暂存区按点独立：走开时暂存区里的东西留在那个点，回来还能拿"


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if nodes.is_empty() and not _saved.is_empty():
		_load(_saved, run.items)
		_saved = {}
	if not run.leaving.is_connected(_on_leaving):
		run.leaving.connect(_on_leaving)
	if not run.arrived.is_connected(_on_arrived):
		run.arrived.connect(_on_arrived)


## 087：某个点上留着的东西（没有就空）
func stored_at(node_id: int) -> Array:
	return (nodes.get(node_id, []) as Array).duplicate()


## 走出现在这个点会不会把暂存区留下：暂存区里有东西就留。
## 暂存区是节点内的临时区 —— 任何时候都能开背包往里挪（换信仰道具的置入顺序就靠它），但一旦移动就不在身上了
func will_drop() -> bool:
	if _run == null or _run.travel == null or _run.storage == null:
		return false
	return _run.travel.current_id >= 0 and _run.storage.item_count() > 0


func to_dict() -> Dictionary:
	var out := {}
	for key in nodes:
		var list: Array = []
		for inst in nodes[key]:
			list.append((inst as ItemInstance).to_dict())
		out[str(key)] = list
	return {"nodes": out}


func restore(d: Dictionary) -> void:
	_saved = d.duplicate(true)


func _load(d: Dictionary, items: ItemDatabase) -> void:
	var raw: Variant = d.get("nodes", {})
	if not (raw is Dictionary):
		return
	for key in (raw as Dictionary):
		var list: Array = []
		for one in ((raw as Dictionary)[key] as Array):
			var inst := ItemInstance.from_dict(one as Dictionary, items)
			if inst != null:
				list.append(inst)
		if not list.is_empty():
			nodes[int(String(key))] = list


## 离开一个点：暂存区里的东西留在那个点上（087：不是丢掉，回来能拿）
func _on_leaving(node_id: int) -> void:
	if _run == null or _run.storage == null or _run.storage.item_count() == 0:
		return
	var leaving_items: Array = _run.storage.items().duplicate()
	_run.storage.clear()
	var kept: Array = nodes.get(node_id, [])
	kept.append_array(leaving_items)
	nodes[node_id] = kept
	dropped.emit(node_id, leaving_items)


## 到了一个点：那里留着的东西回到暂存区
func _on_arrived(node_id: int) -> void:
	if _run == null or _run.storage == null or not nodes.has(node_id):
		return
	var back: Array = nodes[node_id]
	nodes.erase(node_id)
	if back.is_empty():
		return
	for inst in back:
		_run.storage.admit(inst)
	restored.emit(node_id, back)
