## 网格容器。两种模式共用本实现，只差一个 [member requires_bag] 开关：
##
## - **棋盘模式**（`requires_bag = true`）：玩家的作战背包。盘面固定，但**开局全部不可用**，
##   可用格来自玩家自己放上去的「包」。普通物品只能放进某个包覆盖的格子里。
## - **自由容器**（`requires_bag = false`）：暂存区、敌人尸体、商店货架。整片可用，直接摆放。
##
## 棋盘上有两张互相独立的占用表：[member _bag_owner] 记录每格被哪个包覆盖，
## [member _occ] 记录每格被哪件普通物品占据。一个格子可以同时「被包 B 覆盖」和「被物品 I 占据」。
##
## 包只有在棋盘模式下才作为包生效。一个包躺在尸体容器里时就是件普通异形物品，
## 不提供任何格子 —— 这条规则省掉了容器套容器的递归。
##
## 本类是纯 [RefCounted]，不进场景树。表现层连 [signal changed] 后
## [b]从状态完整重建视图[/b]，不要做增量猜测。
class_name GridInventory
extends RefCounted

## 内容发生任何变化时发出。批量操作期间会被合并成一次。
signal changed

const EMPTY_UID := 0

var id: int = 0
var size: Vector2i = Vector2i(8, 6)

## true = 棋盘模式，普通物品必须落在包内
var requires_bag: bool = false

## 容器级准入标签。为空表示不限制。包体自身的准入见 [member ItemDef.bag_accept_tags]。
var accept_tags: Array[StringName] = []

var _occ: PackedInt32Array = PackedInt32Array()
var _bag_owner: PackedInt32Array = PackedInt32Array()
var _items: Dictionary = {}  # uid -> ItemInstance
var _blocked: PackedByteArray = PackedByteArray()

var _batch_depth: int = 0
var _dirty: bool = false


func _init(p_size: Vector2i = Vector2i(8, 6), p_id: int = 0, p_requires_bag: bool = false) -> void:
	id = p_id
	size = p_size
	requires_bag = p_requires_bag
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


## 该格被哪件普通物品占据，空格返回 [constant EMPTY_UID]。
func cell_uid(c: Vector2i) -> int:
	if not in_bounds(c):
		return EMPTY_UID
	return _occ[_idx(c)]


## 覆盖该格的包 uid。自由容器恒为 [constant EMPTY_UID]。
func bag_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return EMPTY_UID
	return _bag_owner[_idx(c)]


## 该格是否可用于摆放普通物品（棋盘模式下须被包覆盖）。
func is_covered(c: Vector2i) -> bool:
	if not in_bounds(c) or is_blocked(c):
		return false
	if not requires_bag:
		return true
	return _bag_owner[_idx(c)] != EMPTY_UID


## 标记某格为不可用，用于非矩形的自由容器。
func set_blocked(c: Vector2i, blocked: bool) -> bool:
	if not in_bounds(c):
		return false
	var i := _idx(c)
	if blocked and (_occ[i] != EMPTY_UID or _bag_owner[i] != EMPTY_UID):
		return false
	_blocked[i] = 1 if blocked else 0
	_notify_changed()
	return true


## 可摆放普通物品且当前为空的格数。
func free_cell_count() -> int:
	var n := 0
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if is_covered(c) and _occ[_idx(c)] == EMPTY_UID:
				n += 1
	return n


## 可摆放普通物品的总格数（棋盘模式下 = 已被包覆盖的格数）。
func usable_cell_count() -> int:
	var n := 0
	for y in size.y:
		for x in size.x:
			if is_covered(Vector2i(x, y)):
				n += 1
	return n


func _idx(c: Vector2i) -> int:
	return c.y * size.x + c.x
#endregion


#region 准入
## 容器是否接受这件定义（仅看容器级标签，不看空间）。
func accepts(def: ItemDef) -> bool:
	if def == null:
		return false
	if accept_tags.is_empty():
		return true
	for tag in def.tags:
		if accept_tags.has(tag):
			return true
	return false


## 该定义在本容器中是否作为「包」生效。
func acts_as_bag(def: ItemDef) -> bool:
	return requires_bag and def != null and def.is_bag


func _bag_accepts(bag_def: ItemDef, def: ItemDef) -> bool:
	if bag_def == null or bag_def.bag_accept_tags.is_empty():
		return true
	for tag in def.tags:
		if bag_def.bag_accept_tags.has(tag):
			return true
	return false
#endregion


#region 落点判定
## 只看**地形**：出界、禁用格、包覆盖、是否跨了两个包。不看有没有别的物品挡着。
##
## 抽出来是因为「这儿根本放不下」和「挡着但能挤开」是两回事：前者只能拒绝，
## 后者可以顶替。两条路径必须共用同一套地形判断，否则会出现
## 「直接拖进去不行、顶着别人反而进得去」这种玩家看不懂的事。
func _terrain_ok(cells: Array[Vector2i], origin: Vector2i) -> bool:
	if cells.is_empty():
		return false
	var bag := EMPTY_UID
	for c in cells:
		var p := origin + c
		if not in_bounds(p):
			return false
		var i := _idx(p)
		if _blocked[i] != 0:
			return false
		if requires_bag:
			var owner := _bag_owner[i]
			if owner == EMPTY_UID:
				return false          # 未被任何包覆盖
			if bag == EMPTY_UID:
				bag = owner
			elif bag != owner:
				return false          # 跨了两个包，不允许
	return true


## 普通物品的落点判定。棋盘模式下要求每格都被**同一个包**覆盖。
func can_place(cells: Array[Vector2i], origin: Vector2i, ignore_uid: int = EMPTY_UID) -> bool:
	if not _terrain_ok(cells, origin):
		return false
	for c in cells:
		var occupant := _occ[_idx(origin + c)]
		if occupant != EMPTY_UID and occupant != ignore_uid:
			return false
	return true


## 包体的落点判定。包之间不能重叠，但包本身不需要被覆盖。
func can_place_bag(cells: Array[Vector2i], origin: Vector2i, ignore_uid: int = EMPTY_UID) -> bool:
	if cells.is_empty() or not requires_bag:
		return false
	for c in cells:
		var p := origin + c
		if not in_bounds(p):
			return false
		var i := _idx(p)
		if _blocked[i] != 0:
			return false
		var owner := _bag_owner[i]
		if owner != EMPTY_UID and owner != ignore_uid:
			return false
	return true


## 指定定义能否以该朝向落在 origin（含容器级与包体级标签校验）。
func can_place_def(def: ItemDef, origin: Vector2i, rot: int, ignore_uid: int = EMPTY_UID) -> bool:
	if def == null or not accepts(def):
		return false
	var cells := def.cells_rotated(rot)
	if acts_as_bag(def):
		return can_place_bag(cells, origin, ignore_uid)
	if not can_place(cells, origin, ignore_uid):
		return false
	if requires_bag:
		var bag_uid := _bag_owner[_idx(origin + cells[0])]
		var bag_inst: ItemInstance = _items.get(bag_uid, null)
		if bag_inst != null and not _bag_accepts(bag_inst.def, def):
			return false
	return true


func can_place_item(inst: ItemInstance, origin: Vector2i, rot: int) -> bool:
	if inst == null or inst.def == null:
		return false
	var effective_rot := rot if inst.def.can_rotate else 0
	return can_place_def(inst.def, origin, effective_rot, inst.uid)


## 这件定义在这个落点上，**地形**允不允许 —— 出界、禁用格、包覆盖、
## 容器与包的准入标签全都看，唯独不看有没有别的物品挡着。
##
## 表现层用它把落点分成三档：地形不允许（红）、允许且空着（绿）、
## 允许但压着别人（黄，会顶掉）。
func terrain_allows(def: ItemDef, origin: Vector2i, rot: int) -> bool:
	if def == null or not accepts(def) or acts_as_bag(def):
		return false
	var cells := def.cells_rotated(rot)
	if not _terrain_ok(cells, origin):
		return false
	if requires_bag:
		var bag_inst: ItemInstance = _items.get(_bag_owner[_idx(origin + cells[0])], null)
		if bag_inst != null and not _bag_accepts(bag_inst.def, def):
			return false
	return true


## 这个落点会顶掉哪些普通物品，uid 升序去重。
##
## 只在 [method terrain_allows] 为真时才有意义 —— 空数组既可能是「落点干净」，
## 也可能是「这儿压根放不下」，两者靠这里分不开，调用方先问地形。
func displaced_by(def: ItemDef, origin: Vector2i, rot: int, ignore_uid: int = EMPTY_UID) -> Array[int]:
	var out: Array[int] = []
	if def == null:
		return out
	var seen := {}
	for c in def.cells_rotated(rot):
		var p := origin + c
		if not in_bounds(p):
			continue
		var occupant := _occ[_idx(p)]
		if occupant == EMPTY_UID or occupant == ignore_uid or seen.has(occupant):
			continue
		seen[occupant] = true
		out.append(occupant)
	out.sort()
	return out
#endregion


#region 顶替式放置
## 放置，并把挡路的普通物品**挤出来**交还给调用方。
##
## 成功返回被顶出来的实例数组（可能为空）；失败返回 [code]null[/code]，
## 且容器保持原样 —— 半数物品被摘下、另一半不知去向，比「这一下不生效」糟得多。
##
## [b]包不参与顶替[/b]：包是棋盘的地基，往包上丢东西该落进包里，而不是把包连同
## 一整袋内容物掀掉；反过来，拖一个包去顶掉另一个包，内容物也没有着落。
## 两个方向都拒绝 —— 被顶的只可能是 [member _occ] 里的普通物品。
##
## 调用方拿到返回的实例后[b]必须[/b]给它们找地方（抓在手上、塞暂存区），
## 它们此刻处于游离态，谁也不持有。
func place_displacing(inst: ItemInstance, origin: Vector2i, rot: int = 0):
	if inst == null or inst.def == null or acts_as_bag(inst.def):
		return null
	var effective_rot := rot if inst.def.can_rotate else 0
	if not terrain_allows(inst.def, origin, effective_rot):
		return null
	if _items.has(inst.uid):
		push_warning("GridInventory.place_displacing: uid %d 已在本容器中" % inst.uid)
		return null

	var victims: Array[ItemInstance] = []
	# 原位记下来，放不成的时候要一件不差地摆回去
	var homes: Array[Vector2i] = []
	var rots: Array[int] = []

	begin_batch()
	for uid in displaced_by(inst.def, origin, effective_rot, inst.uid):
		var v: ItemInstance = _items.get(uid, null)
		if v == null:
			continue
		homes.append(v.origin)
		rots.append(v.rotation)
		if remove(uid) == null:
			# 摘不下来（非空的包等）—— 已经摘掉的先还原，整件事作废
			homes.resize(victims.size())
			rots.resize(victims.size())
			_put_back(victims, homes, rots)
			end_batch()
			return null
		victims.append(v)

	if not place(inst, origin, effective_rot):
		# 地形已经确认过，挡路的也清空了，走到这里说明有别的校验没被地形覆盖。
		# 不猜原因，原样还回去。
		_put_back(victims, homes, rots)
		end_batch()
		return null

	end_batch()
	return victims


## 把一批实例放回各自的原位。这些格子刚刚才腾出来，正常必然放得回去。
func _put_back(items: Array[ItemInstance], homes: Array[Vector2i], rots: Array[int]) -> void:
	for i in items.size():
		if not place(items[i], homes[i], rots[i]):
			push_error("GridInventory: uid %d 放不回原位，物品已丢失" % items[i].uid)
#endregion


#region 放置与移除
## 放置。成功后会写回 [member ItemInstance.origin]、[member ItemInstance.rotation]
## 与 [member ItemInstance.container_id]，这三个字段必须与占用表一致，外部不要直接改。
func place(inst: ItemInstance, origin: Vector2i, rot: int = 0) -> bool:
	if not can_place_item(inst, origin, rot):
		return false
	if _items.has(inst.uid):
		push_warning("GridInventory.place: uid %d 已在本容器中，应先 remove" % inst.uid)
		return false

	var effective_rot := rot if inst.def.can_rotate else 0
	var cells := inst.def.cells_rotated(effective_rot)
	var table := _bag_owner if acts_as_bag(inst.def) else _occ
	for c in cells:
		table[_idx(origin + c)] = inst.uid

	inst.origin = origin
	inst.rotation = effective_rot
	inst.container_id = id
	_items[inst.uid] = inst
	_notify_changed()
	return true


## 移除并返回该实例；不存在时返回 null。
##
## **非空的包会被拒绝**（返回 null 并告警）—— 连内容物一起摘下请用 [method detach_bag]。
func remove(uid: int) -> ItemInstance:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null:
		return null
	var is_bag := acts_as_bag(inst.def)
	if is_bag and not contents_of(uid).is_empty():
		push_warning("GridInventory.remove: uid %d 是非空的包，请改用 detach_bag" % uid)
		return null

	var table := _bag_owner if is_bag else _occ
	for c in inst.def.cells_rotated(inst.rotation):
		var i := _idx(inst.origin + c)
		if table[i] == uid:
			table[i] = EMPTY_UID
	_items.erase(uid)
	inst.container_id = 0
	_notify_changed()
	return inst


## 原地旋转。放不下则保持原样并返回 false。
##
## **有内容物的包不能旋转** —— 旋转包意味着内容物要跟着做坐标变换，边界情况多且玩家难以预期。
## 要转先掏空。这是一条有意的简化。
func rotate_item(uid: int, steps: int = 1) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null or not inst.def.can_rotate:
		return false
	var is_bag := acts_as_bag(inst.def)
	if is_bag and not contents_of(uid).is_empty():
		return false
	var new_rot := posmod(inst.rotation + steps, 4)
	if new_rot == inst.rotation:
		return true

	var table := _bag_owner if is_bag else _occ
	var ok := can_place_bag(inst.def.cells_rotated(new_rot), inst.origin, uid) if is_bag \
		else can_place(inst.def.cells_rotated(new_rot), inst.origin, uid)
	if not ok:
		return false

	begin_batch()
	for c in inst.def.cells_rotated(inst.rotation):
		table[_idx(inst.origin + c)] = EMPTY_UID
	for c in inst.def.cells_rotated(new_rot):
		table[_idx(inst.origin + c)] = inst.uid
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
	_bag_owner.fill(EMPTY_UID)
	_notify_changed()
	end_batch()
#endregion


#region 包与容纳关系
## 该物品所属的包 uid。物品本身是包、或容器不是棋盘时返回 [constant EMPTY_UID]。
func bag_of(uid: int) -> int:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null or not requires_bag or acts_as_bag(inst.def):
		return EMPTY_UID
	var cells := inst.def.cells_rotated(inst.rotation)
	if cells.is_empty():
		return EMPTY_UID
	return _bag_owner[_idx(inst.origin + cells[0])]


## 该包内的所有物品 uid，按 uid 升序 —— 顺序必须稳定，否则战斗编译结果会随之抖动。
func contents_of(bag_uid: int) -> Array[int]:
	var out: Array[int] = []
	if bag_uid == EMPTY_UID or not requires_bag:
		return out
	for uid in _items:
		if bag_of(uid) == bag_uid:
			out.append(uid)
	out.sort()
	return out


func is_bag_with_contents(uid: int) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null or not acts_as_bag(inst.def):
		return false
	return not contents_of(uid).is_empty()


## 棋盘上所有作为包生效的物品。
func bags() -> Array:
	var out: Array = []
	for uid in _items:
		var inst: ItemInstance = _items[uid]
		if acts_as_bag(inst.def):
			out.append(inst)
	return out


## 连同内容物一起摘下一个包，返回可交给 [method attach_bag] 的载荷。
## 失败返回空字典，容器不变。
func detach_bag(bag_uid: int) -> Dictionary:
	var bag: ItemInstance = _items.get(bag_uid, null)
	if bag == null or not acts_as_bag(bag.def):
		return {}

	var content_uids := contents_of(bag_uid)
	var contents: Array = []
	var offsets: Array[Vector2i] = []

	begin_batch()
	for uid in content_uids:
		var inst: ItemInstance = _items[uid]
		offsets.append(inst.origin - bag.origin)
		contents.append(remove(uid))
	var removed := remove(bag_uid)
	end_batch()

	if removed == null:
		return {}
	return {
		"bag": bag,
		"rotation": bag.rotation,
		"contents": contents,
		"offsets": offsets,
	}


## 非破坏性地检查载荷能否整体落在 origin。
func can_attach_bag(payload: Dictionary, origin: Vector2i, rot: int) -> bool:
	if payload.is_empty():
		return false
	var bag: ItemInstance = payload["bag"]
	var contents: Array = payload["contents"]
	if not requires_bag:
		# 自由容器收不下带内容物的包：它没有覆盖概念，内容物无处安放
		return contents.is_empty() and can_place_def(bag.def, origin, rot, bag.uid)
	# 有内容物时不允许换朝向，与 rotate_item 的限制保持一致
	if not contents.is_empty() and rot != int(payload["rotation"]):
		return false
	if not can_place_bag(bag.def.cells_rotated(rot), origin, bag.uid):
		return false

	var bag_cells := {}
	for c in bag.def.cells_rotated(rot):
		bag_cells[origin + c] = true
	var offsets: Array = payload["offsets"]
	for i in contents.size():
		var inst: ItemInstance = contents[i]
		var at: Vector2i = origin + offsets[i]
		for c in inst.def.cells_rotated(inst.rotation):
			var p: Vector2i = at + c
			if not bag_cells.has(p):
				return false          # 超出包的轮廓
			if _occ[_idx(p)] != EMPTY_UID:
				return false          # 被目标容器里已有的物品占了
	return true


## 把载荷整体放到 origin。失败时不留任何残迹，容器保持原样。
func attach_bag(payload: Dictionary, origin: Vector2i, rot: int) -> bool:
	if not can_attach_bag(payload, origin, rot):
		return false
	var bag: ItemInstance = payload["bag"]
	var contents: Array = payload["contents"]
	var offsets: Array = payload["offsets"]

	begin_batch()
	if not place(bag, origin, rot):
		end_batch()
		return false
	for i in contents.size():
		var inst: ItemInstance = contents[i]
		if not place(inst, origin + offsets[i], inst.rotation):
			# can_attach_bag 已经验过，走到这里说明有别处改了容器状态。回滚干净。
			push_error("GridInventory.attach_bag: 内容物 uid %d 放置失败，回滚" % inst.uid)
			for j in i:
				remove((contents[j] as ItemInstance).uid)
			remove(bag.uid)
			end_batch()
			return false
	end_batch()
	return true
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
				if can_place_def(def, origin, rot, ignore_uid):
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


## 与该物品四邻相接的其他物品 uid。M2 的插槽配对以它为输入。
## 包不参与邻接 —— 包与内容物之间是容纳关系，不是邻接关系。
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
	result.sort()
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
		"requires_bag": requires_bag,
		"accept_tags": tags,
		"blocked": blocked_idx,
		"items": item_dicts,
	}


static func from_dict(d: Dictionary, db: ItemDatabase) -> GridInventory:
	var s: Array = d.get("size", [8, 6])
	var inv := GridInventory.new(
		Vector2i(int(s[0]), int(s[1])), int(d.get("id", 0)), bool(d.get("requires_bag", false))
	)

	var tags: Array[StringName] = []
	for tag in d.get("accept_tags", []):
		tags.append(StringName(tag))
	inv.accept_tags = tags

	for i in d.get("blocked", []):
		var idx := int(i)
		if idx >= 0 and idx < inv._blocked.size():
			inv._blocked[idx] = 1

	# 必须先放包再放内容物：内容物的落点合法性依赖包提供的覆盖
	var bags_first: Array = []
	var rest: Array = []
	for raw in d.get("items", []):
		var inst := ItemInstance.from_dict(raw, db)
		if inst == null:
			continue  # 定义已不存在，from_dict 已告警
		if inv.acts_as_bag(inst.def):
			bags_first.append(inst)
		else:
			rest.append(inst)

	inv.begin_batch()
	for inst in bags_first + rest:
		if not inv.place(inst, inst.origin, inst.rotation):
			push_warning(
				"GridInventory.from_dict: uid %d 无法放回 %s，已丢弃（存档与当前定义不一致？）"
				% [inst.uid, inst.origin]
			)
	inv.end_batch()
	return inv


func _reset_cells() -> void:
	var total := maxi(0, size.x * size.y)
	_occ.resize(total)
	_occ.fill(EMPTY_UID)
	_bag_owner.resize(total)
	_bag_owner.fill(EMPTY_UID)
	_blocked.resize(total)
	_blocked.fill(0)
	_items.clear()
#endregion
