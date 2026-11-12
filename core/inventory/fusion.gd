## 279 拼接（白 → 绿，待定 2：点锤合、不自动合）：同一块棋盘上两件**贴着**（任一格上下左右相邻，转向无关）、
## 有一张 `adjacent` 配方（[member RecipeDef.adjacent]）—— 接缝上浮一枚小锤，点它两件合成一件，成品落在两件原来的占格里。
## 纯逻辑：找对、找落点、合。包不参加；包里的件照样能拼（只看棋盘上的格）
class_name Fusion
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


## 棋盘上能拼的每一对：`{"a": uid, "b": uid（a < b）, "output": 配方上的产物 id（原件；赐福怎么继承看 core/run 的解析入口）, "recipe": 配方 id, "seam": Vector2（接缝中点，格为单位，左上角 = 0,0）}`。
## 一对只出一次；接缝取两件相邻的格边里最靠中间的那一条。按 (a, b) 排好
static func pairs(board: GridInventory, recipes: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if board == null or recipes.is_empty():
		return out
	var edges := {}     # Vector2i(a, b) -> [格边中点 Vector2, ...]
	for raw in board.items():
		var it := raw as ItemInstance
		if it == null or it.def == null or board.acts_as_bag(it.def):
			continue
		for c in it.cells():
			var g := it.origin + c
			for d in DIRS:
				var o := board.cell_uid(g + d) if board.in_bounds(g + d) else GridInventory.EMPTY_UID
				if o == GridInventory.EMPTY_UID or o <= it.uid:
					continue
				var key := Vector2i(it.uid, o)
				(edges.get_or_add(key, []) as Array).append(Vector2(g) + Vector2.ONE * 0.5 + Vector2(d) * 0.5)
	var keys: Array = edges.keys()
	keys.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return x.x < y.x or (x.x == y.x and x.y < y.y))
	for key in keys:
		var a := board.get_item(key.x)
		var b := board.get_item(key.y)
		if not spendable(board, a) or not spendable(board, b):
			continue
		var r := RecipeDef.find(recipes, _base(a.def), _base(b.def))     # 312：赐福版按原件配
		if r == null:
			continue
		out.append({"a": key.x, "b": key.y, "output": r.output, "recipe": r.id, "seam": _middle(edges[key])})
	return out


## 几条格边中点里最靠它们平均位置的那一条（L 形贴法也落在真有的边上）
static func _middle(points: Array) -> Vector2:
	var avg := Vector2.ZERO
	for p in points:
		avg += p
	avg /= float(points.size())
	var best: Vector2 = points[0]
	for p in points:
		if (p as Vector2).distance_squared_to(avg) < best.distance_squared_to(avg) - 0.0001:
			best = p
	return best


## 305（改造 A）：这件能被合成吃掉吗 —— 玩家锁定的、扎了根的、随身之物都不行
static func spendable(board: GridInventory, inst: ItemInstance) -> bool:
	return inst != null and not inst.is_locked_by_player() and (board == null or not board.keeps(inst.uid))


## 两件拿掉之后，[param out_def] 落在它们原来占格并集里的位置：`{"origin": Vector2i, "rot": int}`；落不下 = 空。
## 先试 a 的朝向，再试别的；同朝向里取最靠左上的
static func landing(board: GridInventory, a: ItemInstance, b: ItemInstance, out_def: ItemDef) -> Dictionary:
	var union := {}
	for it in [a, b]:
		for c in (it as ItemInstance).cells():
			union[(it as ItemInstance).origin + c] = true
	var cells: Array = union.keys()
	cells.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return x.y < y.y or (x.y == y.y and x.x < y.x))
	var rots: Array[int] = [a.rotation]
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


## 合：两件拿掉，产物落在并集里；落不下就在棋盘上找第一处放得下的；还不行原样放回、返回 null。
## 成了返回产物（已在棋盘上）
static func fuse(board: GridInventory, a_uid: int, b_uid: int, out_def: ItemDef) -> ItemInstance:
	var a := board.get_item(a_uid)
	var b := board.get_item(b_uid)
	if a == null or b == null or out_def == null:
		return null
	var homes := [[a, a.origin, a.rotation], [b, b.origin, b.rotation]]
	board.begin_batch()
	board.remove(a_uid)
	board.remove(b_uid)
	var out := ItemInstance.create(out_def, a.rotation)
	var spot := landing(board, a, b, out_def)
	var ok := false
	if not spot.is_empty():
		ok = board.place(out, spot["origin"], int(spot["rot"]))
	if not ok:
		ok = board.try_add(out, true)
	if not ok:
		for h in homes:
			board.place(h[0], h[1], h[2])
		board.end_batch()
		return null
	board.end_batch()
	return out


## 312：原件 id（赐福版找回原件）
static func _base(def: ItemDef) -> StringName:
	return def.blessed_of if def.is_blessed() else def.id
