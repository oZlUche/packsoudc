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


## 容器内挪位的便捷写法。
static func move_within(inv: GridInventory, uid: int, origin: Vector2i, rot: int = 0) -> bool:
	return move(inv, uid, inv, origin, rot)


## 把 uid 从 from 搬进 to 的任意可用位置。用于「全部拾取」。
##
## 收发两端都是 [ItemContainer] 而不是 [GridInventory]：暂存区是个列表，
## 没有「位置」可言，而「全部拾取到暂存区」恰恰是这个动作最常见的用法。
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


## 087：搬一个带东西的包：摘下来（内容物 + 跨包物），内容物先各自进目标，再进包；有一件进不去就整个放回原处
static func _transfer_bag(from: GridInventory, uid: int, to: ItemContainer) -> bool:
	var bag := from.get_item(uid)
	var home := bag.origin
	var rot := bag.rotation
	var payload := from.detach_bag(uid)
	if payload.is_empty():
		return false
	var loose: Array = []
	loose.append_array(payload.get("contents", []))
	for sd in payload.get("straddlers", []):
		loose.append((sd as Dictionary)["inst"])
	to.begin_batch()
	var done: Array = []
	var ok := true
	for inst in loose:
		if to.admit(inst):
			done.append(inst)
		else:
			ok = false
			break
	if ok:
		ok = to.admit(bag)
	if not ok:
		for inst in done:
			to.remove((inst as ItemInstance).uid)
		to.end_batch()
		if not from.attach_bag(payload, home, rot):
			push_error("InventoryService: 包 uid %d 搬不动又放不回，物品已丢失" % uid)
		return false
	to.end_batch()
	return true


## 尽可能多地把 from 的内容搬进 to，返回成功搬运的件数。
##
## 按占格数从大到小搬 —— 先安置大件，小件更容易见缝插针，总装入量明显优于随机顺序。
## 087：作为包生效的排最后（先把包上的东西搬走，包就空了，当普通物品搬）
static func transfer_all(from: ItemContainer, to: ItemContainer) -> int:
	if from == null or to == null:
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


## 084 / 123：全拿走 —— 每件先试 first（棋盘，自动找位），放不下才进 fallback（暂存区）。
## 顺序同 transfer_all（非包先、大件先；包最后，不替玩家决定棋盘布局）。返回 {board: n, storage: n}
static func transfer_all_prefer(from: ItemContainer, first: ItemContainer, fallback: ItemContainer) -> Dictionary:
	var out := {"board": 0, "storage": 0}
	if from == null:
		return out
	from.begin_batch()
	if first != null:
		first.begin_batch()
	if fallback != null:
		fallback.begin_batch()
	for inst in _take_order(from):
		var uid := (inst as ItemInstance).uid
		if first != null and transfer_auto(from, uid, first):
			out["board"] += 1
		elif fallback != null and transfer_auto(from, uid, fallback):
			out["storage"] += 1
	if fallback != null:
		fallback.end_batch()
	if first != null:
		first.end_batch()
	from.end_batch()
	return out


## 搬运顺序：按占格数从大到小；作为包生效的排最后
static func _take_order(from: ItemContainer) -> Array:
	var sorted: Array = from.items()
	var grid := from as GridInventory
	sorted.sort_custom(
		func(a, b):
			var ab := grid != null and grid.acts_as_bag((a as ItemInstance).def)
			var bb := grid != null and grid.acts_as_bag((b as ItemInstance).def)
			if ab != bb:
				return bb     # 不是包的排前面
			return (a as ItemInstance).def.shape.cell_count() > (b as ItemInstance).def.shape.cell_count()
	)
	return sorted
