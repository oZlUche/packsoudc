## 把一堆道具 id 摆进一块棋盘（架构文档 6.1）：尸体容器、搜索点的收获都这么装。
##
## 就是一个 [GridInventory]，M1 的代码原样复用。大小给定，塞不下就加高，最多加到两倍；
## 再塞不下的丢掉 —— 容器配得太小是数据问题，回报里能看见（[method pack] 返回的 `left`）。
class_name LootPacker
extends RefCounted


## 摆。返回 {"board": GridInventory, "left": [没装下的 id]}
static func pack(ids: Array[StringName], size: Vector2i, items: ItemDatabase) -> Dictionary:
	var base := Vector2i(maxi(1, size.x), maxi(1, size.y))
	var grow := 0
	while true:
		var board := GridInventory.new(base + Vector2i(0, grow), 0, false)
		var left: Array[StringName] = []
		for id in ids:
			var def := items.get_def(id) if items != null else null
			if def == null:
				continue
			if not board.try_add(ItemInstance.create(def, 0), true):
				left.append(id)
		if left.is_empty() or grow >= base.y:
			return {"board": board, "left": left}
		grow += 1
	return {"board": null, "left": ids}


## 只要棋盘，不关心装没装下
static func board_of(ids: Array[StringName], size: Vector2i, items: ItemDatabase) -> GridInventory:
	return pack(ids, size, items)["board"]


## 往已有的容器里再摆几件（搜索点每搜一次装一批，M6-2）。放不下就换一个高一格的，原来的东西原位搬过去
## （同一批实例，uid 不变），最多加到 [param base_height] 的两倍；再塞不下的报回来。
## 返回 {"board": 可能换了的容器, "left": [没装下的 id]}
static func add(board: GridInventory, ids: Array[StringName], items: ItemDatabase, base_height: int = -1) -> Dictionary:
	var base_h := base_height if base_height > 0 else board.size.y
	var current := board
	var pending: Array[ItemInstance] = []
	for id in ids:
		var def := items.get_def(id) if items != null else null
		if def != null:
			pending.append(ItemInstance.create(def, 0))
	while true:
		var left: Array[ItemInstance] = []
		current.begin_batch()
		for inst in pending:
			if not current.try_add(inst, true):
				left.append(inst)
		current.end_batch()
		if left.is_empty() or current.size.y >= base_h * 2:
			var left_ids: Array[StringName] = []
			for inst in left:
				left_ids.append(inst.def.id)
			return {"board": current, "left": left_ids}
		var bigger := GridInventory.new(current.size + Vector2i(0, 1), current.id, false)
		bigger.begin_batch()
		for inst in current.items():
			var item := inst as ItemInstance
			bigger.place(item, item.origin, item.rotation)
		bigger.end_batch()
		current = bigger
		pending = left
	return {"board": current, "left": [] as Array[StringName]}
