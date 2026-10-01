## 保险箱（092，作者定）：地图上的保险箱点，放进去的东西**视为已带出** —— 就算这一局行动失败也带得出。
## 关上（或者走开）就送回基地，不能再改动；空着关不算关（还能再开）。
##
## 101 第 0 / 1 刀的样板模块：状态（容器、锁没锁）、存档、接线全在这里，[RunState] 一行都不认识保险箱。
## 自己接两处：走开就锁上（`RunState.leaving`）、节点事件问「还能开吗」（`NodeEvents.safe_open`）。
## 取它用 [method of]。
class_name SafeModule
extends RunModule

const ID := &"safe"
## 容器 id（092 就是 3，存档里按它认 —— 别改）
const CONTAINER_ID := 3

## 关上了：里面的 n 件送回基地，不能再改
signal closed(count: int)

## 几格。内容里写默认，局外成长（[member MetaRules.safe_size]）在开局时按 `module_inputs` 覆盖
@export var size: Vector2i = Vector2i(3, 3)

var inventory: GridInventory = null
var locked: bool = false
var _run: RunState = null
## 读档拿到的那份，等 install 里有内容库了再还原
var _saved: Dictionary = {}


## 这一局的保险箱模块（没装返回 null）
static func of(run: RunState) -> SafeModule:
	return run.module(ID) as SafeModule if run != null else null


func id() -> StringName:
	return ID


func describe() -> String:
	return "保险箱：放进去的东西视为已带出（%d×%d）；关上或走开就送回基地" % [size.x, size.y]


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if inventory == null:
		var want: Vector2i = run.module_input(ID).get("size", size)
		size = want if want.x > 0 and want.y > 0 else size
		var saved_grid: Variant = _saved.get("inventory", null)
		if saved_grid is Dictionary:
			inventory = GridInventory.from_dict(saved_grid as Dictionary, run.items)
			inventory.id = CONTAINER_ID
			size = inventory.size
		else:
			inventory = GridInventory.new(size, CONTAINER_ID, false)
		locked = bool(_saved.get("locked", locked))
	# 作者定：走开 = 关上（里面有东西才算关）。走一步、被事件挪走都在真正动之前发 leaving
	if not run.leaving.is_connected(_on_leaving):
		run.leaving.connect(_on_leaving)
	if run.events != null:
		run.events.safe_open = is_open     # 092：锁上的保险箱再踩上去不开（刀 3 会变成 RunHooks 的一个方法）


## 还能开（装了、没锁）
func is_open() -> bool:
	return inventory != null and not locked


## 关上：里面的送回基地，不能再改。空着关不算关（还能再开）。返回这次锁没锁
func lock() -> bool:
	if locked or inventory == null or inventory.item_count() == 0:
		return false
	locked = true
	if _run != null and _run.map != null and _run.travel != null:
		for id_ in _run.map.node_ids():
			if _run.map.get_node(id_).type == &"safe":
				_run.travel.mark_visited(id_)     # 锁了就灰：再踩上不开
	closed.emit(inventory.item_count())
	return true


## 里面的件数（没装就是 0）
func item_count() -> int:
	return inventory.item_count() if inventory != null else 0


func to_dict() -> Dictionary:
	return {
		"inventory": inventory.to_dict() if inventory != null else null,
		"locked": locked,
	}


func restore(d: Dictionary) -> void:
	_saved = d.duplicate(true)
	locked = bool(d.get("locked", false))


func _on_leaving(_node_id: int) -> void:
	lock()
