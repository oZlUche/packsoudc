## 网格容器：玩家背包、敌人尸体、商店货架、仓库、装备栏全部复用本类。
##
## 装备栏就是 1x1 且设了 [member accept_tags] 的容器；尸体就是战后临时生成的容器。
## 不要为这些场景另写实现 —— 掉落系统几乎零成本，正是因为它直接复用了这里。
##
## 本类是纯 [RefCounted]，不进场景树。表现层连 [signal changed] 后
## [b]从状态完整重建视图[/b]，不要做增量猜测：拖拽中断、跨容器失败回滚、旋转撤销
## 这些路径上，增量状态极易与真实状态脱节。
class_name GridInventory
extends RefCounted

## 内容发生任何变化时发出。批量操作期间会被合并成一次。
signal changed

const EMPTY_UID := 0

var id: int = 0
var size: Vector2i = Vector2i(8, 6)

## 准入标签。为空表示不限制；非空时物品需至少命中一个标签。
var accept_tags: Array[StringName] = []

var _occ: PackedInt32Array = PackedInt32Array()
var _items: Dictionary = {}  # uid -> ItemInstance
var _blocked: PackedByteArray = PackedByteArray()

var _batch_depth: int = 0
var _dirty: bool = false


func _init(p_size: Vector2i = Vector2i(8, 6), p_id: int = 0) -> void:
	id = p_id
	size = p_size
	_reset_cells()


#region 批量操作
## 成对使用，把区间内的多次改动合并成一次 [signal changed]。
## 跨容器移动必须用它包起来，否则 UI 会看到「已从源移除、尚未放入目标」的中间态。
func begin_batch() -> void:
	_batch_depth += 1


func end_batch() -> void:
	_batch_depth = maxi(0, _batch_depth - 1)
	if _batch_depth == 0 and _dirty:
		_dirty = false
		changed.emit()


func _notify_changed() -> void:
	if _batch_depth > 0:
		_dirty = true
	else:
		changed.emit()
#endregion


#region 格子查询
func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func is_blocked(c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	return _blocked[_idx(c)] != 0


## 该格被哪件物品占据，空格返回 [constant EMPTY_UID]。
func cell_uid(c: Vector2i) -> int:
	if not in_bounds(c):
		return EMPTY_UID
	return _occ[_idx(c)]


## 标记某格为不可用，用于非矩形容器（如 L 形背包）。
## 已被占据的格子不能封禁，返回 false。
func set_blocked(c: Vector2i, blocked: bool) -> bool:
	if not in_bounds(c):
		return false
	if blocked and cell_uid(c) != EMPTY_UID:
		return false
	_blocked[_idx(c)] = 1 if blocked else 0
	_notify_changed()
	return true


func free_cell_count() -> int:
	var n := 0
	for i in _occ.size():
		if _occ[i] == EMPTY_UID and _blocked[i] == 0:
			n += 1
	return n


func _idx(c: Vector2i) -> int:
	return c.y * size.x + c.x
#endregion


#region 放置与移除
## 该容器是否接受这件定义（仅看标签，不看空间）。
func accepts(def: ItemDef) -> bool:
	if def == null:
		return false
	if accept_tags.is_empty():
		return true
	for tag in def.tags:
		if accept_tags.has(tag):
			return true
	return false


## 指定占格集合能否落在 origin 处。
## [param ignore_uid] 用于「原地旋转」「移动自己」这类需要忽略自身占用的判定。
func can_place(cells: Array[Vector2i], origin: Vector2i, ignore_uid: int = EMPTY_UID) -> bool:
	if cells.is_empty():
		return false
	for c in cells:
		var p := origin + c
		if not in_bounds(p):
			return false
		var i := _idx(p)
		if _blocked[i] != 0:
			return false
		var occupant := _occ[i]
		if occupant != EMPTY_UID and occupant != ignore_uid:
			return false
	return true


## 实例能否以指定旋转落在 origin 处（含标签校验）。
func can_place_item(inst: ItemInstance, origin: Vector2i, rot: int) -> bool:
	if inst == null or inst.def == null or not accepts(inst.def):
		return false
	var effective_rot := rot if inst.def.can_rotate else 0
	return can_place(inst.def.cells_rotated(effective_rot), origin, inst.uid)


## 放置。成功后会写回 [member ItemInstance.origin]、[member ItemInstance.rotation]
## 与 [member ItemInstance.container_id]，这三个字段必须与占用表一致，外部不要直接改。
func place(inst: ItemInstance, origin: Vector2i, rot: int = 0) -> bool:
	if not can_place_item(inst, origin, rot):
		return false
	if _items.has(inst.uid):
		push_warning("GridInventory.place: uid %d 已在本容器中，应先 remove" % inst.uid)
		return false

	var effective_rot := rot if inst.def.can_rotate else 0
	for c in inst.def.cells_rotated(effective_rot):
		_occ[_idx(origin + c)] = inst.uid

	inst.origin = origin
	inst.rotation = effective_rot
	inst.container_id = id
	_items[inst.uid] = inst
	_notify_changed()
	return true


## 移除并返回该实例；不存在时返回 null。
func remove(uid: int) -> ItemInstance:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null:
		return null
	for c in inst.def.cells_rotated(inst.rotation):
		var i := _idx(inst.origin + c)
		if _occ[i] == uid:
			_occ[i] = EMPTY_UID
	_items.erase(uid)
	inst.container_id = 0
	_notify_changed()
	return inst


## 原地旋转。放不下则保持原样并返回 false。
func rotate_item(uid: int, steps: int = 1) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null or not inst.def.can_rotate:
		return false
	var new_rot := posmod(inst.rotation + steps, 4)
	if new_rot == inst.rotation:
		return true
	if not can_place(inst.def.cells_rotated(new_rot), inst.origin, uid):
		return false

	begin_batch()
	var old_rot := inst.rotation
	for c in inst.def.cells_rotated(old_rot):
		_occ[_idx(inst.origin + c)] = EMPTY_UID
	for c in inst.def.cells_rotated(new_rot):
		_occ[_idx(inst.origin + c)] = inst.uid
	inst.rotation = new_rot
	_notify_changed()
	end_batch()
	return true


func clear() -> void:
	begin_batch()
	for uid in _items.keys():
		(_items[uid] as ItemInstance).container_id = 0
	_items.clear()
	_occ.fill(EMPTY_UID)
	_notify_changed()
	end_batch()
#endregion


#region 自动装填
## 找第一个放得下的位置。返回 {"found": bool, "origin": Vector2i, "rotation": int}。
##
## 按行优先扫描位置，每个位置内先试 rot0 再试其他朝向 —— 自动拾取时优先保持
## 物品的原始朝向，这比「优先塞满」更符合直觉。
func find_first_fit(def: ItemDef, allow_rotate: bool = true, ignore_uid: int = EMPTY_UID) -> Dictionary:
	var miss := {"found": false, "origin": Vector2i.ZERO, "rotation": 0}
	if def == null or not accepts(def):
		return miss
	var rot_count := 1
	if allow_rotate and def.can_rotate and def.shape != null:
		rot_count = def.shape.distinct_rotation_count()

	for y in size.y:
		for x in size.x:
			var origin := Vector2i(x, y)
			for rot in rot_count:
				if can_place(def.cells_rotated(rot), origin, ignore_uid):
					return {"found": true, "origin": origin, "rotation": rot}
	return miss


## 自动找位置放入。放不下返回 false，实例保持游离态。
func try_add(inst: ItemInstance, allow_rotate: bool = true) -> bool:
	if inst == null:
		return false
	var fit := find_first_fit(inst.def, allow_rotate)
	if not fit["found"]:
		return false
	return place(inst, fit["origin"], fit["rotation"])
#endregion


#region 读取
func get_item(uid: int) -> ItemInstance:
	return _items.get(uid, null)


func has_item(uid: int) -> bool:
	return _items.has(uid)


func items() -> Array:
	return _items.values()


func item_count() -> int:
	return _items.size()


## 与该物品四邻相接的其他物品 uid。M2 的战斗编译期用它解析邻接加成。
func neighbors_of(uid: int) -> Array[int]:
	var result: Array[int] = []
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null:
		return result
	const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var seen := {}
	for c in inst.def.cells_rotated(inst.rotation):
		for d in DIRS:
			var other := cell_uid(inst.origin + c + d)
			if other != EMPTY_UID and other != uid and not seen.has(other):
				seen[other] = true
				result.append(other)
	return result
#endregion


#region 序列化
func to_dict() -> Dictionary:
	var blocked_idx: Array = []
	for i in _blocked.size():
		if _blocked[i] != 0:
			blocked_idx.append(i)
	var item_dicts: Array = []
	for inst in _items.values():
		item_dicts.append((inst as ItemInstance).to_dict())
	# uid 升序，保证同一状态总是序列化成同样的字节，便于比对与测试
	item_dicts.sort_custom(func(a, b): return a["uid"] < b["uid"])
	var tags: Array = []
	for tag in accept_tags:
		tags.append(String(tag))
	return {
		"id": id,
		"size": [size.x, size.y],
		"accept_tags": tags,
		"blocked": blocked_idx,
		"items": item_dicts,
	}


static func from_dict(d: Dictionary, db: ItemDatabase) -> GridInventory:
	var s: Array = d.get("size", [8, 6])
	var inv := GridInventory.new(Vector2i(int(s[0]), int(s[1])), int(d.get("id", 0)))

	var tags: Array[StringName] = []
	for tag in d.get("accept_tags", []):
		tags.append(StringName(tag))
	inv.accept_tags = tags

	for i in d.get("blocked", []):
		var idx := int(i)
		if idx >= 0 and idx < inv._blocked.size():
			inv._blocked[idx] = 1

	inv.begin_batch()
	for raw in d.get("items", []):
		var inst := ItemInstance.from_dict(raw, db)
		if inst == null:
			continue  # 定义已不存在，from_dict 已告警
		if not inv.place(inst, inst.origin, inst.rotation):
			push_warning(
				"GridInventory.from_dict: uid %d 无法放回 %s，已丢弃（存档与当前形状定义不一致？）"
				% [inst.uid, inst.origin]
			)
	inv.end_batch()
	return inv


func _reset_cells() -> void:
	var total := maxi(0, size.x * size.y)
	_occ.resize(total)
	_occ.fill(EMPTY_UID)
	_blocked.resize(total)
	_blocked.fill(0)
	_items.clear()
#endregion
