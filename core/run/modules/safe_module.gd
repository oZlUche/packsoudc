## 保险箱（092，作者定）：放进去的东西**视为已带出** —— 就算这一局行动失败也带得出。
## 287（作者 11-07 选 C）：图上不再单放保险箱点，并进**免费撤离点** ——「托付」给出口那儿接应的人（[method GameFlow.open_safe]）。
## 一局一块格子、整局共用：关上（或者走开）时放进去的那几件交出去（[member sealed]），拿不回来；**空格照旧能放**，出口还开着就能回来再托。
##
## 101 第 0 / 1 刀的样板模块：状态（容器、锁没锁）、存档、接线全在这里，[RunState] 一行都不认识保险箱。
## 自己接两处：走开就锁上（`RunState.leaving`）、节点事件问「还能开吗」（`RunHooks` 的 `safe_open`）。
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
## 092 时代整块锁上；287 起不再整块锁（老档读进来转成 [member sealed]）
var locked: bool = false
## 287：已经交出去的件（uid → true）：拿不回来、不能挪出格子
var sealed: Dictionary = {}
## 读档拿到的那份，等 install 里有内容库了再还原
var _saved: Dictionary = {}


## 这一局的保险箱模块（没装返回 null）
static func of(run: RunState) -> SafeModule:
	return run.module(ID) as SafeModule if run != null else null


func id() -> StringName:
	return ID


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	if inventory == null:
		var want: Vector2i = run.module_input(ID).get("size", size)
		size = want if want.x > 0 and want.y > 0 else size
		var saved_grid: Variant = _saved.get("inventory", null)
		if saved_grid is Dictionary:
			var lost: Array = []     # 173：原位放不回的先箱里找空位、再落地
			inventory = GridInventory.from_dict(saved_grid as Dictionary, run.items, Vector2i.ZERO, lost)
			inventory.id = CONTAINER_ID
			size = inventory.size
			for inst in lost:
				run.rehome(inst, inventory, "modules.safe")
		else:
			inventory = GridInventory.new(size, CONTAINER_ID, false)
		locked = bool(_saved.get("locked", locked))
		for u in _saved.get("sealed", []):
			sealed[int(u)] = true
		if locked:     # 287：老档整块锁着的 —— 里面的都算交出去了，格子还能用
			for inst in inventory.items():
				sealed[(inst as ItemInstance).uid] = true
			locked = false
	# 作者定：走开 = 关上（里面有东西才算关）。走一步、被事件挪走都在真正动之前发 leaving
	if not run.leaving.is_connected(_on_leaving):
		run.leaving.connect(_on_leaving)
	run.hooks.register(&"safe_open", is_open)     # 092：锁上的保险箱再踩上去不开


## 还能开（装了、没锁）
func is_open() -> bool:
	return inventory != null and not locked


## 287：这一件已经交出去了（拿不回来）
func is_sealed(uid: int) -> bool:
	return sealed.has(uid)


## 关上：格子里还没交出去的几件交出去，不能再拿回；空格留着。没有新放的不算关。返回这次交没交
func lock() -> bool:
	if locked or inventory == null:
		return false
	var fresh := 0
	for inst in inventory.items():
		var uid := (inst as ItemInstance).uid
		if not sealed.has(uid):
			sealed[uid] = true
			fresh += 1
	if fresh == 0:
		return false
	if _run != null and _run.map != null and _run.travel != null:
		for id_ in _run.map.node_ids():
			if _run.map.get_node(id_).type == &"safe":
				_run.travel.mark_visited(id_)     # 老档的保险箱点：交过就灰
	closed.emit(fresh)
	return true


## 里面的件数（没装就是 0）
func item_count() -> int:
	return inventory.item_count() if inventory != null else 0


func to_dict() -> Dictionary:
	var inv: Variant = null
	if inventory != null:
		inv = inventory.to_dict()
	return {
		"inventory": inv,
		"locked": locked,
		"sealed": sealed.keys(),
	}


func restore(d: Dictionary) -> void:
	_saved = d.duplicate(true)
	locked = bool(d.get("locked", false))


func _on_leaving(_node_id: int) -> void:
	lock()
