## 网格容器：**摆在哪儿是有意义的**那一类。两种模式共用本实现，
## 只差一个 [member requires_bag] 开关：
##
## - **棋盘模式**（`requires_bag = true`）：玩家的作战背包。盘面固定，但**开局全部不可用**，
##   可用格来自玩家自己放上去的「包」。普通物品只能放进某个包覆盖的格子里。
## - **自由容器**（`requires_bag = false`）：敌人尸体、商店货架。整片可用，直接摆放。
##
## 暂存区[b]不在此列[/b] —— 它只是个列表，见 [ItemStash]。
##
## 棋盘上有两张互相独立的占用表：[member _bag_owner] 记录每格被哪个包覆盖，
## [member _occ] 记录每格被哪件普通物品占据。一个格子可以同时「被包 B 覆盖」和「被物品 I 占据」。
##
## 包只有在棋盘模式下才作为包生效。一个包躺在尸体容器里时就是件普通异形物品，
## 不提供任何格子 —— 这条规则省掉了容器套容器的递归。
class_name GridInventory
extends ItemContainer

const EMPTY_UID := 0

var size: Vector2i = Vector2i(8, 6)

## true = 棋盘模式，普通物品必须落在包内
var requires_bag: bool = false

## 容器级准入标签。为空表示不限制。包体自身的准入见 [member ItemDef.bag_accept_tags]。
var accept_tags: Array[StringName] = []
## 容器级准入回调：`func(def: ItemDef) -> bool`，无效 = 不限。仓库用它接 [MetaState.keeps]（包进不了局外），规则只写在那一处
var accept_filter: Callable = Callable()

var _occ: PackedInt32Array = PackedInt32Array()
var _bag_owner: PackedInt32Array = PackedInt32Array()
var _items: Dictionary = {}  # uid -> ItemInstance
var _blocked: PackedByteArray = PackedByteArray()
## 置入序号的计数（8-4）：道具从别的容器进来时 +1 并盖到它身上（[member ItemInstance.placed_seq]）；同容器内挪位置不盖。跟着存档走
var place_seq: int = 0


func _init(p_size: Vector2i = Vector2i(8, 6), p_id: int = 0, p_requires_bag: bool = false) -> void:
	id = p_id
	size = p_size
	requires_bag = p_requires_bag
	_reset_cells()


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
	if accept_filter.is_valid() and not bool(accept_filter.call(def)):
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
## 只看**地形**：出界、禁用格、包覆盖。不看有没有别的物品挡着。
##
## 每一格被【某个】包覆盖即可，**允许一件东西横跨两个包**（3.2）。
## 「归属于哪个包」由 [method bag_of] 另行回答：整件落在一个包里才算它的内容物。
##
## 抽出来是因为「这儿根本放不下」和「挡着但能挤开」是两回事：前者只能拒绝，
## 后者可以顶替。两条路径必须共用同一套地形判断，否则会出现
## 「直接拖进去不行、顶着别人反而进得去」这种玩家看不懂的事。
func _terrain_ok(cells: Array[Vector2i], origin: Vector2i) -> bool:
	if cells.is_empty():
		return false
	for c in cells:
		var p := origin + c
		if not in_bounds(p):
			return false
		var i := _idx(p)
		if _blocked[i] != 0:
			return false
		if requires_bag and _bag_owner[i] == EMPTY_UID:
			return false          # 未被任何包覆盖
	return true


## 这件东西落在这些格子上时，**每一个**被它碰到的包都得接受它 ——
## 只收药水的药水带，哪怕只被一把步枪压住一格，也不该收。
func _touched_bags_accept(cells: Array[Vector2i], origin: Vector2i, def: ItemDef) -> bool:
	if not requires_bag:
		return true
	var seen := {}
	for c in cells:
		var owner := _bag_owner[_idx(origin + c)]
		if owner == EMPTY_UID or seen.has(owner):
			continue
		seen[owner] = true
		var bag_inst: ItemInstance = _items.get(owner, null)
		if bag_inst != null and not _bag_accepts(bag_inst.def, def):
			return false
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
	return _touched_bags_accept(cells, origin, def)


func can_place_item(inst: ItemInstance, origin: Vector2i, rot: int) -> bool:
	if inst == null or inst.def == null:
		return false
	return can_place_def(inst.def, origin, rot, inst.uid)


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
	return _touched_bags_accept(cells, origin, def)


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
	if not terrain_allows(inst.def, origin, rot):
		return null
	if _items.has(inst.uid):
		push_warning("GridInventory.place_displacing: uid %d 已在本容器中" % inst.uid)
		return null

	var victims: Array[ItemInstance] = []
	# 原位记下来，放不成的时候要一件不差地摆回去
	var homes: Array[Vector2i] = []
	var rots: Array[int] = []

	begin_batch()
	for uid in displaced_by(inst.def, origin, rot, inst.uid):
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

	if not place(inst, origin, rot):
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
		items[i].container_id = id     # 原样放回，不算重新置入
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

	var cells := inst.def.cells_rotated(rot)
	var table := _bag_owner if acts_as_bag(inst.def) else _occ
	for c in cells:
		table[_idx(origin + c)] = inst.uid

	# 从别的容器进来的才算「置入」（同容器内挪位置、原样放回都先把 container_id 设回本容器）
	if inst.container_id != id:
		place_seq += 1
		inst.placed_seq = place_seq
	inst.origin = origin
	inst.rotation = rot
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
## **有内容物的包请走 [method rotate_bag]**：包转了之后，依附不上的内容物要脱落，
## 而脱落的东西必须交还给调用方安置 —— 这个方法只回一个 bool，接不住它们。
## 在这里转一个非空的包会被拒绝并告警，而不是把内容物弄丢。
func rotate_item(uid: int, steps: int = 1) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null:
		return false
	var is_bag := acts_as_bag(inst.def)
	if is_bag and not contents_of(uid).is_empty():
		push_warning("GridInventory.rotate_item: uid %d 是非空的包，请改用 rotate_bag" % uid)
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
## 该物品所属的包 uid：**整件**落在哪个包里。
##
## 横跨两个包的物品不属于任何包（返回 [constant EMPTY_UID]）—— 它只是「摆在棋盘上」。
## 包的效果只给自己整件装着的东西，拿起包时也只带走这些；跨包的那件谁也不带走。
## 归属因此仍然无歧义，只是多了一种「谁的都不是」。
func bag_of(uid: int) -> int:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null or not requires_bag or acts_as_bag(inst.def):
		return EMPTY_UID
	var owner := EMPTY_UID
	for c in inst.def.cells_rotated(inst.rotation):
		var o := _bag_owner[_idx(inst.origin + c)]
		if o == EMPTY_UID:
			return EMPTY_UID
		if owner == EMPTY_UID:
			owner = o
		elif o != owner:
			return EMPTY_UID      # 跨包
	return owner


## 该物品碰到的所有包，uid 升序。整件在一个包里就只有一个；跨包就是两个以上。
func bags_touching(uid: int) -> Array[int]:
	var out: Array[int] = []
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null or not requires_bag or acts_as_bag(inst.def):
		return out
	for c in inst.def.cells_rotated(inst.rotation):
		var o := _bag_owner[_idx(inst.origin + c)]
		if o != EMPTY_UID and not out.has(o):
			out.append(o)
	out.sort()
	return out


## 该包内的所有物品 uid（整件在包里的），按 uid 升序 ——
## 顺序必须稳定，否则战斗编译结果会随之抖动。
func contents_of(bag_uid: int) -> Array[int]:
	var out: Array[int] = []
	if bag_uid == EMPTY_UID or not requires_bag:
		return out
	for uid in _items:
		if bag_of(uid) == bag_uid:
			out.append(uid)
	out.sort()
	return out


## 压在该包上、但没有整件落在里面的物品（跨包的那些），uid 升序。
## 包一动，它们就少了一半依托 —— 得脱落。
func straddlers_of(bag_uid: int) -> Array[int]:
	var out: Array[int] = []
	if bag_uid == EMPTY_UID or not requires_bag:
		return out
	for uid in _items:
		var touched := bags_touching(uid)
		if touched.size() > 1 and touched.has(bag_uid):
			out.append(uid)
	out.sort()
	return out


func is_bag_with_contents(uid: int) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null or not acts_as_bag(inst.def):
		return false
	return not contents_of(uid).is_empty() or not straddlers_of(uid).is_empty()


## 棋盘上所有作为包生效的物品。
func bags() -> Array:
	var out: Array = []
	for uid in _items:
		var inst: ItemInstance = _items[uid]
		if acts_as_bag(inst.def):
			out.append(inst)
	return out


## 连同内容物一起摘下一个包，返回可交给 [method attach_bag] 的载荷。失败返回空字典，容器不变。
##
## 内容物记的是**本地坐标**：相对包原点、且折回包 rot 0 坐标系的位置与朝向。
## 包换个朝向放下时，内容物按同一个变换跟着转 —— 包怎么转它们就怎么转，
## 不会出现「包转了、里面的东西还横着」这种错位。这就是本地坐标与全局坐标的区别。
##
## 跨包的物品带不走（另一半在别的包里），也留不下（少了一半依托）。它们一并摘下，
## 记在 `straddlers` 里连同原来的全局位置：原样放回时能回到原处，放到别处时脱落。
##
## [codeblock]
## {
##   "bag": ItemInstance, "rotation": int,
##   "contents": [ItemInstance], "locals": [{"origin": Vector2i, "rot": int}],
##   "straddlers": [{"inst": ItemInstance, "origin": Vector2i, "rot": int}],
## }
## [endcodeblock]
func detach_bag(bag_uid: int) -> Dictionary:
	var bag: ItemInstance = _items.get(bag_uid, null)
	if bag == null or not acts_as_bag(bag.def):
		return {}

	var content_uids := contents_of(bag_uid)
	var straddler_uids := straddlers_of(bag_uid)
	var contents: Array = []
	var locals: Array = []
	var straddlers: Array = []

	begin_batch()
	for uid in content_uids:
		var inst: ItemInstance = _items[uid]
		locals.append(to_local(bag, inst))
		contents.append(remove(uid))
	for uid in straddler_uids:
		var inst: ItemInstance = _items[uid]
		straddlers.append({"inst": inst, "origin": inst.origin, "rot": inst.rotation})
		remove(uid)
	var removed := remove(bag_uid)
	end_batch()

	if removed == null:
		return {}
	return {
		"bag": bag,
		"rotation": bag.rotation,
		"contents": contents,
		"locals": locals,
		"straddlers": straddlers,
		"from": id,
	}


#region 本地坐标 ↔ 全局坐标
## 内容物在包里的本地位置：相对包原点、折回包 rot 0 坐标系。
static func to_local(bag: ItemInstance, inst: ItemInstance) -> Dictionary:
	var local_rot := posmod(inst.rotation - bag.rotation, 4)
	var rel := inst.origin - bag.origin
	var local_cells: Array[Vector2i] = []
	for c in inst.def.cells_rotated(inst.rotation):
		local_cells.append(bag.def.shape.untransform_point(rel + c, bag.rotation))
	return {"origin": _min_of(local_cells), "rot": local_rot}


## 本地位置在「包摆在 origin、朝向 rot」时的全局位置。
static func to_global(bag: ItemInstance, local: Dictionary, inst: ItemInstance,
		origin: Vector2i, rot: int) -> Dictionary:
	var global_rot := posmod(int(local["rot"]) + rot, 4)
	var cells: Array[Vector2i] = []
	for c in inst.def.cells_rotated(int(local["rot"])):
		cells.append(bag.def.shape.transform_point((local["origin"] as Vector2i) + c, rot))
	return {"origin": origin + _min_of(cells), "rot": global_rot}


static func _min_of(cs: Array[Vector2i]) -> Vector2i:
	var m := cs[0]
	for c in cs:
		m.x = mini(m.x, c.x)
		m.y = mini(m.y, c.y)
	return m
#endregion


#region 放包
## 非破坏性地检查载荷能否**一件不少**地落在 origin。
func can_attach_bag(payload: Dictionary, origin: Vector2i, rot: int) -> bool:
	var report := bag_fit_report(payload, origin, rot)
	return report["ok"] and (report["fallen"] as Array).is_empty()


## 载荷落在 origin 时会发生什么：包本身放不放得下，以及**哪些东西会脱落**。不改任何状态。
##
## [codeblock]
## {"ok": bool, "fallen": Array[ItemInstance]}
## [endcodeblock]
##
## 内容物按本地坐标跟着包转，永远落在包的轮廓里，所以不会脱落。
## 会脱落的只有**跨包的**那些：它们记着原来的全局位置，放回去之后那个位置
## 仍然每格有包覆盖、没被占，就还能回去；否则脱落。
func bag_fit_report(payload: Dictionary, origin: Vector2i, rot: int) -> Dictionary:
	var failed := {"ok": false, "fallen": []}
	if payload.is_empty():
		return failed
	var bag: ItemInstance = payload["bag"]
	var contents: Array = payload["contents"]
	var straddlers: Array = payload.get("straddlers", [])
	if not requires_bag:
		# 自由容器收不下带内容物的包：它没有覆盖概念，内容物无处安放
		if not contents.is_empty() or not straddlers.is_empty() \
				or not can_place_def(bag.def, origin, rot, bag.uid):
			return failed
		return {"ok": true, "fallen": []}
	if not can_place_bag(bag.def.cells_rotated(rot), origin, bag.uid):
		return failed

	# 包放下之后的覆盖与占用：原有的 + 这个包 + 它的内容物
	var covered := {}
	for c in bag.def.cells_rotated(rot):
		covered[origin + c] = true
	var taken := {}
	var locals: Array = payload["locals"]
	for i in contents.size():
		var inst: ItemInstance = contents[i]
		var g := to_global(bag, locals[i], inst, origin, rot)
		for c in inst.def.cells_rotated(int(g["rot"])):
			var p: Vector2i = (g["origin"] as Vector2i) + c
			if not covered.has(p) or _occ[_idx(p)] != EMPTY_UID or taken.has(p):
				return failed     # 按本地坐标转过来还落在包外，说明载荷本身不对
			taken[p] = true

	var fallen: Array = []
	for s in straddlers:
		var inst: ItemInstance = s["inst"]
		var ok := true
		for c in inst.def.cells_rotated(int(s["rot"])):
			var p: Vector2i = (s["origin"] as Vector2i) + c
			if not in_bounds(p) or _blocked[_idx(p)] != 0:
				ok = false
			elif not covered.has(p) and _bag_owner[_idx(p)] == EMPTY_UID:
				ok = false        # 原来那半边的依托没了
			elif _occ[_idx(p)] != EMPTY_UID or taken.has(p):
				ok = false
			if not ok:
				break
		if not ok:
			fallen.append(inst)
	return {"ok": true, "fallen": fallen}


## 把载荷放到 origin，**依附不上的脱落**并交还给调用方。
##
## 返回与 [method bag_fit_report] 同形。`ok` 为假时容器原样不动；为真时
## `fallen` 里的实例已处于游离态，调用方[b]必须[/b]给它们找地方（通常是暂存区）。
func attach_bag_shedding(payload: Dictionary, origin: Vector2i, rot: int) -> Dictionary:
	var report := bag_fit_report(payload, origin, rot)
	if not report["ok"]:
		return report
	var fallen: Array = report["fallen"]
	var bag: ItemInstance = payload["bag"]
	var contents: Array = payload["contents"]
	var locals: Array = payload["locals"]
	var straddlers: Array = payload.get("straddlers", [])

	# 在同一个容器里挪包：包和内容物都不算重新置入（信仰的置入顺序不变）
	if int(payload.get("from", -1)) == id:
		bag.container_id = id
		for c in contents:
			(c as ItemInstance).container_id = id
		for s in straddlers:
			(s["inst"] as ItemInstance).container_id = id
	begin_batch()
	if not place(bag, origin, rot):
		end_batch()
		return {"ok": false, "fallen": []}
	var placed: Array = []
	var failed := false
	for i in contents.size():
		var inst: ItemInstance = contents[i]
		var g := to_global(bag, locals[i], inst, origin, rot)
		if not place(inst, g["origin"], int(g["rot"])):
			failed = true
			break
		placed.append(inst)
	if not failed:
		for s in straddlers:
			var inst: ItemInstance = s["inst"]
			if fallen.has(inst):
				continue
			if not place(inst, s["origin"], int(s["rot"])):
				failed = true
				break
			placed.append(inst)
	if failed:
		# 报告刚验过，走到这里说明有别处改了容器状态。回滚干净。
		push_error("GridInventory.attach_bag_shedding: 放置失败，回滚")
		for p in placed:
			remove((p as ItemInstance).uid)
		remove(bag.uid)
		end_batch()
		return {"ok": false, "fallen": []}
	end_batch()
	return report


## 把载荷整体放到 origin，**一件都不能少**。失败时不留任何残迹，容器保持原样。
##
## 这是「原样放回」用的严格版；玩家放手走的是 [method attach_bag_shedding]。
func attach_bag(payload: Dictionary, origin: Vector2i, rot: int) -> bool:
	if not can_attach_bag(payload, origin, rot):
		return false
	return attach_bag_shedding(payload, origin, rot)["ok"]


## 原地转一个包，内容物按本地坐标跟着转；跨包的脱落。
##
## 成功返回脱落的实例数组（可能为空），失败返回 [code]null[/code] 且容器不变。
## 实现上就是「摘下来、换个朝向放回去」—— 与拖拽中按 R 走的是同一条路，
## 两处不会给出不同的脱落结果。
func rotate_bag(bag_uid: int, steps: int = 1):
	var bag: ItemInstance = _items.get(bag_uid, null)
	if bag == null or not acts_as_bag(bag.def):
		return null
	var origin := bag.origin
	var old_rot := bag.rotation
	var new_rot := posmod(old_rot + steps, 4)
	if new_rot == old_rot:
		return []

	begin_batch()
	var payload := detach_bag(bag_uid)
	if payload.is_empty():
		end_batch()
		return null
	var result := attach_bag_shedding(payload, origin, new_rot)
	if not result["ok"]:
		if not attach_bag(payload, origin, old_rot):
			push_error("GridInventory.rotate_bag: uid %d 转不动，也放不回原样，物品已丢失" % bag_uid)
		end_batch()
		return null
	end_batch()
	return result["fallen"]
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
	if allow_rotate and def.shape != null:
		rot_count = def.shape.distinct_rotation_count()

	for y in size.y:
		for x in size.x:
			var origin := Vector2i(x, y)
			for rot in rot_count:
				if can_place_def(def, origin, rot, ignore_uid):
					return {"found": true, "origin": origin, "rotation": rot}
	return miss


func admit(inst: ItemInstance) -> bool:
	return try_add(inst)


func can_admit(def: ItemDef) -> bool:
	return def != null and find_first_fit(def)["found"]


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
		"place_seq": place_seq,
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

	# 放回去会盖新序号，所以先记住存档里的序号，放完再写回；计数以存档为准（没存就取最大的）
	var saved_seq := {}
	for inst in bags_first + rest:
		saved_seq[inst.uid] = inst.placed_seq
	inv.begin_batch()
	for inst in bags_first + rest:
		if not inv.place(inst, inst.origin, inst.rotation):
			push_warning(
				"GridInventory.from_dict: uid %d 无法放回 %s，已丢弃（存档与当前定义不一致？）"
				% [inst.uid, inst.origin]
			)
	inv.end_batch()
	var top := 0
	for inst in inv.items():
		(inst as ItemInstance).placed_seq = int(saved_seq.get((inst as ItemInstance).uid, 0))
		top = maxi(top, (inst as ItemInstance).placed_seq)
	inv.place_seq = maxi(int(d.get("place_seq", 0)), top)
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
