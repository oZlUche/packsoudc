## 合成的纯逻辑（279 起；314 起触发方式是「拖到能合的那件上 → 确认窗」，不再看贴不贴着）：哪件能被吃掉、成品落在哪。
## 配哪张配方、出哪件成品看 core/run 的解析入口；拿掉、放下在 [CraftingModule]
class_name Fusion
extends RefCounted


## 305（改造 A）：这件能被合成吃掉吗 —— 玩家锁定的、扎了根的、随身之物都不行
static func spendable(board: GridInventory, inst: ItemInstance) -> bool:
	return inst != null and not inst.is_locked_by_player() and (board == null or not board.keeps(inst.uid))


## 几件拿掉之后，[param out_def] 落在它们原来占格并集里的位置：`{"origin": Vector2i, "rot": int}`；落不下 = 空。
## 先试第一件的朝向，再试别的；同朝向里取最靠左上的。314：拖放合成先只给被压的那件（成品落在它的位置），再加上手里那件原来的格
static func landing(board: GridInventory, freed: Array, out_def: ItemDef) -> Dictionary:
	var union := {}
	for it in freed:
		for c in (it as ItemInstance).cells():
			union[(it as ItemInstance).origin + c] = true
	if union.is_empty():
		return {}
	var cells: Array = union.keys()
	cells.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return x.y < y.y or (x.y == y.y and x.x < y.x))
	var rots: Array[int] = [(freed[0] as ItemInstance).rotation]
	for r in 4:
		if not rots.has(r):
			rots.append(r)
	for rot in rots:
		var shape := out_def.cells_rotated(rot)
		for u in cells:
			for c in shape:
				var origin: Vector2i = u - c
				var inside := true
				for k in shape:
					if not union.has(origin + k):
						inside = false
						break
				if inside and board.can_place_def(out_def, origin, rot):
					return {"origin": origin, "rot": rot}
	return {}


## 314：落不进那几件原来的格时，找一处盖住 [param inst] 原来某一格的位置（成品「落在被压那件的位置」，往四周空格里伸）；
## 先试它的朝向，同朝向里按它的格、成品的格依次试。没有 = 空
static func covering(board: GridInventory, inst: ItemInstance, out_def: ItemDef) -> Dictionary:
	var rots: Array[int] = [inst.rotation]
	for r in 4:
		if not rots.has(r):
			rots.append(r)
	for rot in rots:
		var shape := out_def.cells_rotated(rot)
		for ic in inst.cells():
			for c in shape:
				var origin: Vector2i = inst.origin + ic - c
				if board.can_place_def(out_def, origin, rot):
					return {"origin": origin, "rot": rot}
	return {}
