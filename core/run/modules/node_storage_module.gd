## 按点暂存（087，作者定）：地上是**这个点里的临时区** —— 走出一个点，地上的东西**留在那个点上**，
## 回到那个点它们又回到地上。不是丢掉，所以地图上标得出哪些点存着东西；撤离仍然不带走地上的东西。
##
## 101 第 1 刀：状态（哪个点存着什么）、存档、两处接线全在这里，[RunState] 只管发「走开了 / 到了」。
## 取它用 [method of]。
class_name NodeStorageModule
extends RunModule

const ID := &"node_storage"

## 走出一个点，地上的 [param items] 留在了 [param node_id] 上
signal dropped(node_id: int, items: Array)
## 回到一个点，那里留着的 [param items] 回到了地上
signal restored(node_id: int, items: Array)

## `node_id → [ItemInstance]`
var nodes: Dictionary = {}
## 128：`node_id → {uid: Vector2}` —— 地上每件的落点跟着留在那个点上，回来还在原处
var spots: Dictionary = {}
var _run: RunState = null
## 读档拿到的那份，等 install 里有道具库了再装回来
var _saved: Dictionary = {}


## 这一局的按点暂存模块（没装返回 null）
static func of(run: RunState) -> NodeStorageModule:
	return run.module(ID) as NodeStorageModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "地上按点独立：走开时地上的东西留在那个点，回来还在原处"


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


## 走出现在这个点会不会把地上留下：地上有东西就留。
## 地上是节点内的临时区 —— 任何时候都能开背包往里挪（换信仰道具的置入顺序就靠它），但一旦移动就不在身上了
func will_drop() -> bool:
	if _run == null or _run.travel == null or _run.storage == null:
		return false
	return _run.travel.current_id >= 0 and _run.storage.item_count() > 0


func to_dict() -> Dictionary:
	var out := {}
	var where := {}
	for key in nodes:
		var list: Array = []
		var at: Array = []
		var node_spots: Dictionary = spots.get(key, {})
		for inst in nodes[key]:
			list.append((inst as ItemInstance).to_dict())
			var p: Vector2 = node_spots.get((inst as ItemInstance).uid, ItemStash.NO_SPOT)
			at.append([p.x, p.y])
		out[str(key)] = list
		where[str(key)] = at
	return {"nodes": out, "spots": where}     # 128：落点与 nodes 里的道具一一对应；旧档没有就回来时重新铺


func restore(d: Dictionary) -> void:
	_saved = d.duplicate(true)


func _load(d: Dictionary, items: ItemDatabase) -> void:
	var raw: Variant = d.get("nodes", {})
	if not (raw is Dictionary):
		return
	var where: Dictionary = d.get("spots", {}) if d.get("spots", {}) is Dictionary else {}
	for key in (raw as Dictionary):
		var list: Array = []
		var node_spots := {}
		var raws: Array = (raw as Dictionary)[key] as Array
		var at: Array = where.get(key, []) as Array
		for i in raws.size():
			var inst := ItemInstance.from_dict(raws[i] as Dictionary, items)
			if inst != null:
				list.append(inst)
				var p := ItemStash.read_spot(at[i] if i < at.size() else null)
				if ItemStash.has_spot_value(p):
					node_spots[inst.uid] = p
		if not list.is_empty():
			nodes[int(String(key))] = list
			spots[int(String(key))] = node_spots


## 离开一个点：地上的东西留在那个点上（087：不是丢掉，回来能拿）
func _on_leaving(node_id: int) -> void:
	if _run == null or _run.storage == null or _run.storage.item_count() == 0:
		return
	var leaving_items: Array = _run.storage.items().duplicate()
	var node_spots: Dictionary = spots.get(node_id, {})
	for inst in leaving_items:
		node_spots[(inst as ItemInstance).uid] = _run.storage.spot_of((inst as ItemInstance).uid)     # 128：落点一起留下
	_run.storage.clear()
	var kept: Array = nodes.get(node_id, [])
	kept.append_array(leaving_items)
	nodes[node_id] = kept
	spots[node_id] = node_spots
	dropped.emit(node_id, leaving_items)


## 到了一个点：那里留着的东西回到地上
func _on_arrived(node_id: int, _first_time: bool) -> void:
	if _run == null or _run.storage == null or not nodes.has(node_id):
		return
	var back: Array = nodes[node_id]
	var node_spots: Dictionary = spots.get(node_id, {})
	nodes.erase(node_id)
	spots.erase(node_id)
	if back.is_empty():
		return
	for inst in back:
		_run.storage.insert(inst, -1, node_spots.get((inst as ItemInstance).uid, ItemStash.NO_SPOT))     # 128：回到原处
	restored.emit(node_id, back)
