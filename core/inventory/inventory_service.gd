## 跨容器移动的唯一入口。全部为静态方法，不持有任何状态。
##
## 存在的理由只有一个：[b]移动必须是原子的[/b]。先从源移除、再往目标放，
## 目标放不下时必须把物品原样放回源容器。漏掉回滚分支会导致
## 「拖到非法位置物品消失」—— 这是异形格子背包最常见的严重 bug。
class_name InventoryService
extends RefCounted


## 把 uid 从 from 移到 to 的 origin 处。失败时源容器保持原样，返回 false。
##
## from 与 to 可以是同一个容器（容器内挪位）。
static func move(
	from: GridInventory, uid: int, to: GridInventory, origin: Vector2i, rot: int = 0
) -> bool:
	if from == null or to == null:
		return false
	var inst := from.get_item(uid)
	if inst == null:
		return false
	if from.is_bag_with_contents(uid):
		return _move_bag(from, uid, to, origin, rot)

	var saved_origin := inst.origin
	var saved_rot := inst.rotation

	from.begin_batch()
	if to != from:
		to.begin_batch()

	var moved := false
	if from.remove(uid) != null:
		if from == to:
			inst.container_id = to.id     # 同容器内挪位置不算重新置入（信仰的置入顺序不变）
		if to.place(inst, origin, rot):
			moved = true
		else:
			# 回滚。place 是先校验后写入的全有全无操作，
			# 失败时未触碰任何格子，因此这里一定放得回去。
			if not from.place(inst, saved_origin, saved_rot):
				push_error(
					"InventoryService.move: uid %d 回滚失败，容器状态已损坏" % uid
				)

	if to != from:
		to.end_batch()
	from.end_batch()
	return moved


## 搬运一个带内容物的包：内容物保持相对位置一起走。
##
## 目标放不下时整体退回源容器原位。自由容器收不下带内容物的包
## （它没有覆盖概念，内容物无处安放），这种情况会直接失败并原样退回。
static func _move_bag(
	from: GridInventory, uid: int, to: GridInventory, origin: Vector2i, rot: int
) -> bool:
	var bag := from.get_item(uid)
	var saved_origin := bag.origin
	var saved_rot := bag.rotation

	from.begin_batch()
	if to != from:
		to.begin_batch()

	var moved := false
	var payload := from.detach_bag(uid)
	if not payload.is_empty():
		if to.attach_bag(payload, origin, rot):
			moved = true
		elif not from.attach_bag(payload, saved_origin, saved_rot):
			push_error("InventoryService._move_bag: 包 uid %d 回滚失败，容器状态已损坏" % uid)

	if to != from:
		to.end_batch()
	from.end_batch()
	return moved


## 把 uid 从 from 搬进 to 的任意可用位置。用于「全部拾取」。
##
## 收发两端都是 [ItemContainer] 而不是 [GridInventory]：地上是个列表，
## 没有「位置」可言，而「全部拾取到地上」恰恰是这个动作最常见的用法。
##
## **先问 can_admit 再动手。** 先 remove 再发现目标收不下的话，就得把东西塞回源容器，
## 而「塞回原位」在空间容器里未必还办得到。先问后动，收不下时源容器连碰都不用碰。
static func transfer_auto(from: ItemContainer, uid: int, to: ItemContainer) -> bool:
	if from == null or to == null:
		return false
	var inst := from.get_item(uid)
	if inst == null or not to.can_admit(inst.def):
		return false
	# 087：带东西的包（尸体容器里包当背景、上面摆着东西）：连内容物一起搬 —— 内容物先各自进目标，包最后
	if from is GridInventory and (from as GridInventory).is_bag_with_contents(uid):
		return _transfer_bag(from as GridInventory, uid, to)

	from.begin_batch()
	to.begin_batch()
	var taken := from.remove(uid)
	var ok := taken != null and to.admit(taken)
	if taken != null and not ok:
		# can_admit 说行、admit 却失败，说明两者对不上。不该发生，
		# 但绝不能让物品就这么消失在两个容器之间
		if not from.admit(taken):
			push_error("InventoryService: uid %d 搬运失败且放不回源容器，物品已丢失" % uid)
	to.end_batch()
	from.end_batch()
	return ok


## 087：搬一个带东西的包：摘下来（内容物 + 跨包物），162：包先进目标、内容物再各自进（有机会落回刚放下的包）；
## 有一件进不去就整个放回原处
static func _transfer_bag(from: GridInventory, uid: int, to: ItemContainer) -> bool:
	var bag := from.get_item(uid)
	var home := bag.origin
	var rot := bag.rotation
	var payload := from.detach_bag(uid)
	if payload.is_empty():
		return false
	to.begin_batch()
	var done: Array = []
	var ok := to.admit(bag)
	if ok:
		done.append(bag)
		for inst in _payload_items(payload):
			if to.admit(inst):
				done.append(inst)
			else:
				ok = false
				break
	if not ok:
		done.reverse()     # 后进的先退：包最后退，退的时候已经空了
		for inst in done:
			to.remove((inst as ItemInstance).uid)
		to.end_batch()
		if not from.attach_bag(payload, home, rot):
			push_error("InventoryService: 包 uid %d 搬不动又放不回，物品已丢失" % uid)
		return false
	to.end_batch()
	return true


## 摘下来的包上那些东西（内容物 + 跨包物）
static func _payload_items(payload: Dictionary) -> Array:
	var out: Array = []
	out.append_array(payload.get("contents", []))
	for sd in payload.get("straddlers", []):
		out.append((sd as Dictionary)["inst"])
	return out


## 尽可能多地把 from 的内容搬进 to，返回成功搬运的件数（没有退路容器；收不下的留在 from）。
##
## 按占格数从大到小搬 —— 先安置大件，小件更容易见缝插针，总装入量明显优于随机顺序。
## 087：作为包生效的排最后（先把包上的东西搬走，包就空了，当普通物品搬）
static func transfer_all(from: ItemContainer, to: ItemContainer) -> int:
	if to == null or from == null:
		return 0
	var moved := 0
	from.begin_batch()
	to.begin_batch()
	for inst in _take_order(from):
		if transfer_auto(from, (inst as ItemInstance).uid, to):
			moved += 1
	to.end_batch()
	from.end_batch()
	return moved


## 084 / 123：全拿走 —— 每件先试 first（棋盘，自动找位），放不下才进 fallback（地上）。返回 {board: n, storage: n}（按件数，包和包里的各算一件）
##
## 162（作者定）：**先包后件**。包按大小先塞（放不下的抛到 fallback）；带东西的包摘下来，包自己先去，
## 包上的东西和其余道具一起按占格数从大到小逐件试 —— 棋盘上多了刚塞进去的包，能进的更多。
## 两边都收不下的留在 from（带东西的包整个放回原处）
static func transfer_all_prefer(from: ItemContainer, first: ItemContainer, fallback: ItemContainer) -> Dictionary:
	var out := {"board": 0, "storage": 0}
	if from == null:
		return out
	from.begin_batch()
	if first != null:
		first.begin_batch()
	if fallback != null:
		fallback.begin_batch()
	var grid := from as GridInventory
	var tried := {}
	var loose: Array = []     # 从包上摘下来的（已不在 from 里）
	for inst in _take_order(from, true):
		var it := inst as ItemInstance
		if not it.def.is_bag:
			break     # 包都在前面
		tried[it.uid] = true
		if grid != null and grid.is_bag_with_contents(it.uid):
			_take_bag_apart(grid, it.uid, first, fallback, loose, out)
		else:
			_take_one(from, it.uid, first, fallback, out)
	var rest: Array = loose.duplicate()
	for inst in from.items():
		if not tried.has((inst as ItemInstance).uid):
			rest.append(inst)
	_sort_by_cells(rest)
	for inst in rest:
		var it := inst as ItemInstance
		if from.has_item(it.uid):
			_take_one(from, it.uid, first, fallback, out)
		elif first != null and first.can_admit(it.def) and first.admit(it):
			out["board"] += 1
		elif fallback != null and fallback.can_admit(it.def) and fallback.admit(it):
			out["storage"] += 1
		elif not from.admit(it):
			push_error("InventoryService: uid %d 两边都放不下也回不去，物品已丢失" % it.uid)
	if fallback != null:
		fallback.end_batch()
	if first != null:
		first.end_batch()
	from.end_batch()
	return out


static func _take_one(from: ItemContainer, uid: int, first: ItemContainer, fallback: ItemContainer, out: Dictionary) -> void:
	if first != null and transfer_auto(from, uid, first):
		out["board"] += 1
	elif fallback != null and transfer_auto(from, uid, fallback):
		out["storage"] += 1


## 162：带东西的包摘下来，包自己先进 first / fallback，包上的东西进 loose 等着按件试；包两边都进不去就整个放回原处
static func _take_bag_apart(from: GridInventory, uid: int, first: ItemContainer, fallback: ItemContainer,
		loose: Array, out: Dictionary) -> void:
	var bag := from.get_item(uid)
	var home := bag.origin
	var rot := bag.rotation
	var payload := from.detach_bag(uid)
	if payload.is_empty():
		return
	if first != null and first.can_admit(bag.def) and first.admit(bag):
		out["board"] += 1
	elif fallback != null and fallback.can_admit(bag.def) and fallback.admit(bag):
		out["storage"] += 1
	else:
		if not from.attach_bag(payload, home, rot):
			push_error("InventoryService: 包 uid %d 搬不动又放不回，物品已丢失" % uid)
		return
	loose.append_array(_payload_items(payload))


## 搬运顺序：按占格数从大到小。[param bags_first] 假（[method transfer_all]）：作为包生效的排最后（包上的东西先走，包空了当普通件）；
## 真（162，全拿走）：是包的排最前（大包先）
static func _take_order(from: ItemContainer, bags_first: bool = false) -> Array:
	var sorted: Array = from.items()
	var grid := from as GridInventory
	sorted.sort_custom(
		func(a, b):
			var da := (a as ItemInstance).def
			var dbf := (b as ItemInstance).def
			var ab := da.is_bag if bags_first else (grid != null and grid.acts_as_bag(da))
			var bb := dbf.is_bag if bags_first else (grid != null and grid.acts_as_bag(dbf))
			if ab != bb:
				return ab if bags_first else bb
			return da.shape.cell_count() > dbf.shape.cell_count()
	)
	return sorted


static func _sort_by_cells(list: Array) -> void:
	list.sort_custom(func(a, b): return (a as ItemInstance).def.shape.cell_count() > (b as ItemInstance).def.shape.cell_count())
