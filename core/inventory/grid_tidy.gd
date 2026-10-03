## 109（作者定）：仓库的「整理」—— 把格子里的东西重新排一遍，占用的格聚到左上、空格聚到右下。
##
## 纯逻辑，不放进 [GridInventory] 本体：整理是一种摆法策略，不是容器能力。只认**自由容器**（不要求包的格子，仓库就是）；
## 棋盘上摆的是阵，不归它管。
##
## 做法：全部取下 → 先大后小（占格多的先放，小件去填缝）→ 同大小稀有度高的先 → 再按 id、uid（只为确定性：同一堆东西整理两次一样）
## → 逐件 [method GridInventory.find_first_fit] 放回。有一件放不下（异形件装箱确实可能）就整批放回原位、返回 false ——
## **整理永远不丢东西**。整个过程只发一次 changed；同容器内挪位不是置入，不盖 placed_seq、不发 placed（8-4 的约定）
class_name GridTidy
extends RefCounted


## 整理 [param grid]。真的重排了返回 true；放不下（已回滚）、棋盘模式、空的返回 false
static func tidy(grid: GridInventory) -> bool:
	if grid == null or grid.requires_bag or grid.item_count() == 0:
		return false
	var items: Array[ItemInstance] = []
	var homes := {}     # uid -> [origin, rot]
	for inst in grid.items():
		var item := inst as ItemInstance
		items.append(item)
		homes[item.uid] = [item.origin, item.rotation]
	items.sort_custom(_before)
	grid.begin_batch()
	for item in items:
		grid.remove(item.uid)
	var placed: Array[ItemInstance] = []
	var ok := true
	for item in items:
		var fit := grid.find_first_fit(item.def, true)
		if not fit["found"]:
			ok = false
			break
		item.container_id = grid.id     # 同容器内挪位，不算置入
		grid.place(item, fit["origin"], fit["rotation"])
		placed.append(item)
	if not ok:
		for item in placed:
			grid.remove(item.uid)
		for item in items:
			item.container_id = grid.id
			grid.place(item, homes[item.uid][0], homes[item.uid][1])
	grid.end_batch()
	return ok


## 排序：占格多 → 稀有度高 → def id → uid
static func _before(a: ItemInstance, b: ItemInstance) -> bool:
	var ca := _cells(a)
	var cb := _cells(b)
	if ca != cb:
		return ca > cb
	if a.def.rarity != b.def.rarity:
		return a.def.rarity > b.def.rarity
	if a.def.id != b.def.id:
		return String(a.def.id) < String(b.def.id)
	return a.uid < b.uid


static func _cells(inst: ItemInstance) -> int:
	return inst.def.shape.cell_count() if inst.def.shape != null else 1
