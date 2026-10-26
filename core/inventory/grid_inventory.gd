## 网格容器：**摆在哪儿是有意义的**那一类。两种模式共用本实现，
## 只差一个 [member requires_bag] 开关：
##
## - **棋盘模式**（`requires_bag = true`）：玩家的作战背包。盘面固定，但**开局全部不可用**，
##   可用格来自玩家自己放上去的「包」。普通物品只能放进某个包覆盖的格子里。
## - **自由容器**（`requires_bag = false`）：敌人尸体、商店货架。整片可用，直接摆放。
##
## 地上[b]不在此列[/b] —— 它只是个列表，见 [ItemStash]。
##
## 棋盘上有两张互相独立的占用表：[member _bag_owner] 记录每格被哪个包覆盖，
## [member _occ] 记录每格被哪件普通物品占据。一个格子可以同时「被包 B 覆盖」和「被物品 I 占据」。
##
## 包只有在棋盘模式下才作为包生效。一个包躺在尸体容器里时就是件普通异形物品，
## 不提供任何格子 —— 这条规则省掉了容器套容器的递归。
class_name GridInventory
extends ItemContainer

const EMPTY_UID := 0
## 120：读档时放不下的东西最多临时加几行来放（比最高的道具还高就够）
const RESCUE_ROWS := 8

var size: Vector2i = Vector2i(8, 6)

## true = 棋盘模式，普通物品必须落在包内
var requires_bag: bool = false

## 容器级准入回调（140：容器级准入标签删了，生产从来不设；包体自身的准入见 [member ItemDef.bag_accept_tags]）：`func(def: ItemDef) -> bool`，无效 = 不限。仓库用它接 [MetaState.keeps]（包进不了局外），规则只写在那一处
var accept_filter: Callable = Callable()
## 147：按标签的准入。`only_tags` 非空 = 只收命中其一的（腰带只收【随身】）；`reject_tags` 命中其一就不收（作战棋盘不收【随身】）。跟着存档走
var only_tags: Array[StringName] = []
var reject_tags: Array[StringName] = []
## 207：这块棋盘兑现生长的「扎根」（[method is_locked]）。只有一局的作战棋盘开（[GrowthModule] 装的时候开），不进存档；
## 基地带回来的棋盘、仓库、容器不锁 —— 扎根是这一局里的事
var growth_locks: bool = false

var _occ: PackedInt32Array = PackedInt32Array()
var _bag_owner: PackedInt32Array = PackedInt32Array()
var _items: Dictionary = {}  # uid -> ItemInstance
var _blocked: PackedByteArray = PackedByteArray()
## 置入序号的计数（8-4）：道具从别的容器进来时 +1 并盖到它身上（[member ItemInstance.placed_seq]）；同容器内挪位置不盖。跟着存档走
## 082：一件道具从别的容器置入了本容器（信力的「置入道具」听它；同容器内挪位置不发）
signal placed(inst: ItemInstance)
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
	return _bag_owner[_idx(c)] != EMPTY_UID or _pinned_cell(_idx(c))


## 255：这一格压着一件随身之物（[method ItemInstance.is_pinned]）—— 它自带底板：格子算被覆盖，包不能压上来
func _pinned_cell(i: int) -> bool:
	var o := _occ[i]
	if o == EMPTY_UID:
		return false
	var inst: ItemInstance = _items.get(o, null)
	return inst != null and inst.is_pinned()


## 标记某格为不可用：非矩形的自由容器；255 起也给作战棋盘的缺格（[member CharacterDef.board_mask]）。
func set_blocked(c: Vector2i, blocked: bool) -> bool:
	if not in_bounds(c):
		return false
	var i := _idx(c)
	if blocked and (_occ[i] != EMPTY_UID or _bag_owner[i] != EMPTY_UID):
		return false
	_blocked[i] = 1 if blocked else 0
	_notify_changed()
	return true


## 255：有没有随身之物
func has_pinned() -> bool:
	for inst in _items.values():
		if (inst as ItemInstance).is_pinned():
			return true
	return false


## 255：缺格数（[method is_blocked] 的格）
func blocked_count() -> int:
	var n := 0
	for b in _blocked:
		if b != 0:
			n += 1
	return n


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


## 这件定义在本容器里记在哪张占用表：作为包生效的记 [member _bag_owner]，其余记 [member _occ]（包装数组按引用传，改的就是原表）
func _table_for(def: ItemDef) -> PackedInt32Array:
	return _bag_owner if acts_as_bag(def) else _occ
#endregion


#region 准入
## 容器是否接受这件定义（只看 [member accept_filter]，不看空间）。
func accepts(def: ItemDef) -> bool:
	if def == null:
		return false
	if not only_tags.is_empty() and not _has_any_tag(def, only_tags):
		return false
	if not reject_tags.is_empty() and _has_any_tag(def, reject_tags):
		return false
	return not accept_filter.is_valid() or bool(accept_filter.call(def))


static func _has_any_tag(def: ItemDef, tags: Array[StringName]) -> bool:
	for t in def.tags:
		if tags.has(t):
			return true
	return false


## 该定义在本容器中是否作为「包」生效。
func acts_as_bag(def: ItemDef) -> bool:
	return requires_bag and def != null and def.is_bag


func _bag_accepts(bag_def: ItemDef, def: ItemDef) -> bool:
	if bag_def == null or bag_def.bag_accept_tags.is_empty():
		return true
	for tag in bag_def.bag_accept_tags:
		if def.has_tag(tag):     # 250：材质（草药、兽皮……）不再是标签，包照样认
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
	if not _cells_in_board(cells, origin):
		return false
	if requires_bag:
		for c in cells:
			if _bag_owner[_idx(origin + c)] == EMPTY_UID:
				return false          # 未被任何包覆盖
	return true


## 这些格子都在盘内、都不是禁用格 —— 包与普通物品共用的那一半地形判断。空形状不算
func _cells_in_board(cells: Array[Vector2i], origin: Vector2i) -> bool:
	if cells.is_empty():
		return false
	for c in cells:
		var p := origin + c
		if not in_bounds(p) or _blocked[_idx(p)] != 0:
			return false
	return true


## 这些格子上没有别的普通物品（[param ignore_uid] 自己不算）。先过地形再问，格子都在盘内
func _cells_free(cells: Array[Vector2i], origin: Vector2i, ignore_uid: int) -> bool:
	for c in cells:
		var occupant := _occ[_idx(origin + c)]
		if occupant != EMPTY_UID and occupant != ignore_uid:
			return false
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


## 普通物品的落点判定：地形允许（棋盘模式下每格都被包覆盖），且没被别的物品占着。
func can_place(cells: Array[Vector2i], origin: Vector2i, ignore_uid: int = EMPTY_UID) -> bool:
	return _terrain_ok(cells, origin) and _cells_free(cells, origin, ignore_uid)


## 包体的落点判定。包之间不能重叠，但包本身不需要被覆盖。
func can_place_bag(cells: Array[Vector2i], origin: Vector2i, ignore_uid: int = EMPTY_UID) -> bool:
	if not requires_bag or not _cells_in_board(cells, origin):
		return false
	for c in cells:
		var i := _idx(origin + c)
		var owner := _bag_owner[i]
		if owner != EMPTY_UID and owner != ignore_uid:
			return false
		if _pinned_cell(i):
			return false     # 255：包不能盖住随身之物（当障碍绕开）
	return true


## 指定定义能否以该朝向落在 origin（含容器级与包体级标签校验）。
## 普通物品 = [method terrain_allows] 再加「没被别的物品占着」—— 直接放与顶替（3.3.1）共用同一套地形判断
func can_place_def(def: ItemDef, origin: Vector2i, rot: int, ignore_uid: int = EMPTY_UID) -> bool:
	if acts_as_bag(def):
		return accepts(def) and can_place_bag(def.cells_rotated(rot), origin, ignore_uid)
	return terrain_allows(def, origin, rot) and _cells_free(def.cells_rotated(rot), origin, ignore_uid)


func can_place_item(inst: ItemInstance, origin: Vector2i, rot: int) -> bool:
	if inst == null or inst.def == null:
		return false
	if inst.is_pinned() and requires_bag:
		return _pin_fits(inst.def.cells_rotated(rot), origin, inst.uid, not inst.is_anchored(), inst.def)
	return can_place_def(inst.def, origin, rot, inst.uid)


## 255：随身之物自带底板 —— 不要包，只要格子在盘内、不是缺格、没有包、没被别的东西占着。
## 256：可以挪的（[param on_bags]）也能压在包上（碰到的包都得收它），这时它就是那个包的内容物
func _pin_fits(cells: Array[Vector2i], origin: Vector2i, ignore_uid: int, on_bags: bool = false, def: ItemDef = null) -> bool:
	if not _cells_in_board(cells, origin) or not _cells_free(cells, origin, ignore_uid):
		return false
	if on_bags:
		return _touched_bags_accept(cells, origin, def)
	for c in cells:
		if _bag_owner[_idx(origin + c)] != EMPTY_UID:
			return false
	return true


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
## 调用方拿到返回的实例后[b]必须[/b]给它们找地方（抓在手上、塞地上），
## 它们此刻处于游离态，谁也不持有。
func place_displacing(inst: ItemInstance, origin: Vector2i, rot: int = 0):
	if inst == null or inst.def == null or acts_as_bag(inst.def):
		return null
	if not terrain_allows(inst.def, origin, rot):
		return null
	if _items.has(inst.uid):
		push_warning("GridInventory.place_displacing: uid %d 已在本容器中" % inst.uid)
		return null

	if any_locked(displaced_by(inst.def, origin, rot, inst.uid)):
		return null     # 207：扎了根的不被顶替（顶它 = 放不下）

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
## 099：把这件已在本容器里的道具盖成「最新置入」（信仰切换用）。只改 [member ItemInstance.placed_seq]，
## 不动格子、**不发 [signal placed]** —— 切换信仰不是「置入一件道具」，信力的 `place_item` 行为不该记它。
## 发 changed 让界面重画（棋盘上谁在生效、谁休眠跟着变）。不在本容器里返回 false
func reseat(uid: int) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null:
		return false
	place_seq += 1
	inst.placed_seq = place_seq
	_notify_changed()
	return true


## 放置。成功后会写回 [member ItemInstance.origin]、[member ItemInstance.rotation]
## 与 [member ItemInstance.container_id]，这三个字段必须与占用表一致，外部不要直接改。
func place(inst: ItemInstance, origin: Vector2i, rot: int = 0) -> bool:
	if not can_place_item(inst, origin, rot):
		return false
	if _items.has(inst.uid):
		push_warning("GridInventory.place: uid %d 已在本容器中，应先 remove" % inst.uid)
		return false

	var table := _table_for(inst.def)
	for c in inst.def.cells_rotated(rot):
		table[_idx(origin + c)] = inst.uid

	# 从别的容器进来的才算「置入」（同容器内挪位置、原样放回都先把 container_id 设回本容器）
	var arrived := inst.container_id != id
	if arrived:
		place_seq += 1
		inst.placed_seq = place_seq
	inst.origin = origin
	inst.rotation = rot
	inst.container_id = id
	_items[inst.uid] = inst
	_notify_changed()
	if arrived:
		placed.emit(inst)
	return true


## 移除并返回该实例；不存在时返回 null。
##
## **非空的包会被拒绝**（返回 null 并告警）—— 连内容物一起摘下请用 [method detach_bag]。
func remove(uid: int) -> ItemInstance:
	var inst: ItemInstance = _items.get(uid, null)
	if inst == null:
		return null
	if acts_as_bag(inst.def) and not contents_of(uid).is_empty():
		push_warning("GridInventory.remove: uid %d 是非空的包，请改用 detach_bag" % uid)
		return null

	var table := _table_for(inst.def)
	for c in inst.def.cells_rotated(inst.rotation):
		var i := _idx(inst.origin + c)
		if table[i] == uid:
			table[i] = EMPTY_UID
	_items.erase(uid)
	inst.container_id = 0
	_notify_changed()
	return inst


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


#region 生长的扎根（207）
## 玩家动不了这一件：它自己扎了根（茎叶起），或者它是包、包里有一件连包扎了根（绽放）。
## 只有 [member growth_locks] 开着的棋盘才锁；核心层的 [method remove] 不看它（结算、存档、死亡清棋盘照旧）
## 255：随身之物（[method ItemInstance.is_pinned]）不看开关，永远动不了。
## 256：可以挪的随身之物（军功牌）不锁 —— 它离不开棋盘由 [method keeps] 管；压着它的包锁住（包一走它就跟着离开棋盘）
func is_locked(uid: int) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	if inst != null and inst.is_anchored():
		return true
	if inst != null and requires_bag and acts_as_bag(inst.def) and holds_pinned(uid):
		return true
	if not growth_locks:
		return false
	if inst == null or inst.def == null:
		return false
	if acts_as_bag(inst.def):
		return bag_locked(uid)
	return inst.def.growth != null and GrowthProfile.locks_item(inst)


## 256：这一件离不开这块棋盘 —— 锁着（[method is_locked]），或者它是随身之物（可以挪的也算）。
## 「拿到别的容器去」（地上、卖、存、托盘、双击搬走）都问它；棋盘内挪位置只问 [method is_locked]
func keeps(uid: int) -> bool:
	var inst: ItemInstance = _items.get(uid, null)
	return is_locked(uid) or (inst != null and inst.is_pinned())


## 256：这个包上压着随身之物（可以挪的那种才压得上包）
func holds_pinned(bag_uid: int) -> bool:
	for uid in contents_of(bag_uid):
		var inst: ItemInstance = _items.get(uid, null)
		if inst != null and inst.is_pinned():
			return true
	return false


## 这个包被包里扎了根的东西钉住了（包里别的东西照旧能动）
func bag_locked(bag_uid: int) -> bool:
	if not growth_locks:
		return false
	for uid in contents_of(bag_uid):
		var inst: ItemInstance = _items.get(uid, null)
		if inst != null and inst.def != null and inst.def.growth != null and GrowthProfile.locks_bag(inst):
			return true
	return false


## 这些里有没有扎了根的
func any_locked(uids: Array) -> bool:
	for uid in uids:
		if is_locked(int(uid)):
			return true
	return false
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
	return {"origin": ItemShape.min_of(local_cells), "rot": local_rot}


## 本地位置在「包摆在 origin、朝向 rot」时的全局位置。
static func to_global(bag: ItemInstance, local: Dictionary, inst: ItemInstance,
		origin: Vector2i, rot: int) -> Dictionary:
	var global_rot := posmod(int(local["rot"]) + rot, 4)
	var cells: Array[Vector2i] = []
	for c in inst.def.cells_rotated(int(local["rot"])):
		cells.append(bag.def.shape.transform_point((local["origin"] as Vector2i) + c, rot))
	return {"origin": origin + ItemShape.min_of(cells), "rot": global_rot}

#endregion


#region 放包
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
## `fallen` 里的实例已处于游离态，调用方[b]必须[/b]给它们找地方（通常是地上）。
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
	var report := bag_fit_report(payload, origin, rot)
	if not report["ok"] or not (report["fallen"] as Array).is_empty():
		return false
	return attach_bag_shedding(payload, origin, rot)["ok"]
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
	var out := {
		"id": id,
		"size": [size.x, size.y],
		"requires_bag": requires_bag,
		"blocked": blocked_idx,
		"items": item_dicts,
		"place_seq": place_seq,
	}
	# 147：有标签准入才写（老存档与别的容器字节不变）
	if not only_tags.is_empty():
		out["only_tags"] = Array(only_tags).map(func(t): return String(t))
	if not reject_tags.is_empty():
		out["reject_tags"] = Array(reject_tags).map(func(t): return String(t))
	return out


## 120：[param size_override] 给了（非零）就按它建格子、忽略存档里的 size（仓库尺寸由科技推算）；
## 这时原位越界或被占的物品先找个空位放（[method try_add]），还放不下就在底下临时加行放下并告警 —— 一件也不丢。
## 没给时照旧：放不回原位的告警丢弃
## 173：给了 [param homeless_out]（一个 Array）就把原位放不回的道具交出去，由持有方安置（找空位、落地、进仓库、折钱）并记报告；
## 没给照旧告警丢弃（回放浏览器这类只看不存的）
static func from_dict(d: Dictionary, db: ItemDatabase, size_override: Vector2i = Vector2i.ZERO, homeless_out: Variant = null) -> GridInventory:
	var s: Array = d.get("size", [8, 6])
	var overridden := size_override.x > 0 and size_override.y > 0
	var inv := GridInventory.new(
		size_override if overridden else Vector2i(int(s[0]), int(s[1])), int(d.get("id", 0)), bool(d.get("requires_bag", false))
	)

	# 140：老存档里的 accept_tags（恒为空）不读了
	for t in d.get("only_tags", []):
		inv.only_tags.append(StringName(String(t)))
	for t in d.get("reject_tags", []):
		inv.reject_tags.append(StringName(String(t)))
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
	var homeless: Array = []
	for inst in bags_first + rest:
		if inv.place(inst, inst.origin, inst.rotation):
			continue
		if overridden:
			homeless.append(inst)
			continue
		if homeless_out is Array:
			(homeless_out as Array).append(inst)     # 173：交给持有方安置
			continue
		push_warning(
			"GridInventory.from_dict: uid %d 无法放回 %s，已丢弃（存档与当前定义不一致？）"
			% [inst.uid, inst.origin]
		)
	# 120：尺寸是算出来的（比存档里的小了）—— 原位放不下的找空位，再不行就加行
	for inst in homeless:
		if inv.try_add(inst):
			continue
		var grown := 0
		while not inv.try_add(inst):
			if grown >= RESCUE_ROWS:
				break
			inv.grow_rows(1)
			grown += 1
		if inv.has_item(inst.uid):
			push_warning("GridInventory.from_dict: uid %d 在算出的 %s 里放不下，临时加了 %d 行（东西不丢；之后有空行时科技重算会收回）" % [inst.uid, size_override, grown])
		elif homeless_out is Array:
			(homeless_out as Array).append(inst)
		else:
			push_warning("GridInventory.from_dict: uid %d 加行也放不下，已丢弃（定义比仓库还宽？）" % inst.uid)
	inv.end_batch()
	var top := 0
	for inst in inv.items():
		(inst as ItemInstance).placed_seq = int(saved_seq.get((inst as ItemInstance).uid, 0))
		top = maxi(top, (inst as ItemInstance).placed_seq)
	inv.place_seq = maxi(int(d.get("place_seq", 0)), top)
	return inv


## 093（大地之神：锻炼 +1 行）：底下加 [param n] 行，里面的东西原地不动
func grow_rows(n: int) -> void:
	if n <= 0:
		return
	size = Vector2i(size.x, size.y + n)
	var total := maxi(0, size.x * size.y)
	var old := _occ.size()
	_occ.resize(total)
	_bag_owner.resize(total)
	_blocked.resize(total)
	for i in range(old, total):
		_occ[i] = EMPTY_UID
		_bag_owner[i] = EMPTY_UID
		_blocked[i] = 0
	changed.emit()


## 120：从底往上删掉至多 [param n] 行**空行**（没有物品、也没有包覆盖）；碰到有东西的那一行就停下并告警。返回实际删了几行
func shrink_rows(n: int) -> int:
	var removed := 0
	while removed < n and size.y > 1 and _row_empty(size.y - 1):
		size = Vector2i(size.x, size.y - 1)
		removed += 1
	if removed < n and size.y > 1:
		push_warning("GridInventory.shrink_rows: 第 %d 行有东西，只缩了 %d / %d 行" % [size.y - 1, removed, n])
	if removed > 0:
		var total := maxi(0, size.x * size.y)
		_occ.resize(total)
		_bag_owner.resize(total)
		_blocked.resize(total)
		changed.emit()
	return removed


## 120：行数变成 [param rows]：多了就 [method grow_rows]，少了就 [method shrink_rows]（只删空行）。返回变化后的行数
func resize_rows(rows: int) -> int:
	if rows > size.y:
		grow_rows(rows - size.y)
	elif rows < size.y:
		shrink_rows(size.y - rows)
	return size.y


## 147（腰带扩格）：列数变成 [param cols]：多了在右边加空列；少了只删右边的**空列**（碰到有东西的就停）。东西原地不动。返回变化后的列数
func resize_cols(cols: int) -> int:
	var want := maxi(1, cols)
	var keep := want
	if want < size.x:
		keep = size.x
		while keep > want and _col_empty(keep - 1):
			keep -= 1
	if keep == size.x:
		return size.x
	var occ := PackedInt32Array()
	var bags := PackedInt32Array()
	var blocked := PackedByteArray()
	occ.resize(keep * size.y)
	bags.resize(keep * size.y)
	blocked.resize(keep * size.y)
	for y in size.y:
		for x in keep:
			var j := y * keep + x
			if x < size.x:
				var i := y * size.x + x
				occ[j] = _occ[i]
				bags[j] = _bag_owner[i]
				blocked[j] = _blocked[i]
			else:
				occ[j] = EMPTY_UID
				bags[j] = EMPTY_UID
				blocked[j] = 0
	_occ = occ
	_bag_owner = bags
	_blocked = blocked
	size = Vector2i(keep, size.y)
	changed.emit()
	return size.x


func _col_empty(x: int) -> bool:
	for y in size.y:
		var i := y * size.x + x
		if _occ[i] != EMPTY_UID or _bag_owner[i] != EMPTY_UID:
			return false
	return true


func _row_empty(y: int) -> bool:
	for x in size.x:
		var i := y * size.x + x
		if _occ[i] != EMPTY_UID or _bag_owner[i] != EMPTY_UID:
			return false
	return true


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
