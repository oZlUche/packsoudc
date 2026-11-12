## 合成与锻造改造 C 批（报告 307 第三、四节）：新增六张拼接配方 —— 三张局内限定（成品照旧不进随机来源），三张另加的（成品原来的随机来源照旧）
extends RefCounted

const NEW := {
	&"fuse_flame_fang": [&"bloodbone_spike", &"fire_crystal", &"flame_fang"],
	&"fuse_frost_fang": [&"bloodbone_spike", &"ice_crystal", &"frost_fang"],
	&"fuse_thunder_heavy_crossbow": [&"heavy_crossbow", &"lightning_crystal", &"thunder_heavy_crossbow"],
	&"fuse_bloodletter": [&"cleaver", &"beast_fang", &"bloodletter"],
	&"fuse_horn_bow": [&"shortbow", &"antler", &"horn_bow"],
	&"fuse_heavy_crossbow": [&"steel_crossbow", &"hardwood_plank", &"heavy_crossbow"],
}
const LIMITED: Array[StringName] = [&"flame_fang", &"frost_fang", &"thunder_heavy_crossbow"]


static func run_new_pairs(t: TestCase) -> void:
	t.begin("307 C 批 · 六张新拼接配方：贴着出锤、点锤合成对的成品；局内限定的三件不进随机来源，另加的三件照旧在")
	var db := ItemDatabase.new()
	db.load_dir()
	var recipes := RecipeDef.load_all()
	var pool := db.ids()
	for id in NEW:
		var spec: Array = NEW[id]
		var r := RecipeDef.find(recipes, spec[0], spec[1], true)
		t.check(r != null and r.id == id and r.output == spec[2], "%s：%s + %s → %s" % [id, spec[0], spec[1], spec[2]])
		t.is_null(RecipeDef.find(recipes, spec[0], spec[1]), "%s 不是拖合" % id)
		ItemInstance.reset_uid_counter()
		var board := GridInventory.new(Vector2i(10, 6), 1, false)
		var a := ItemInstance.create(db.get_def(spec[0]))
		var b := ItemInstance.create(db.get_def(spec[1]))
		var placed := false
		for y in board.size.y:
			for x in board.size.x:
				if placed or not board.can_place_item(a, Vector2i(x, y), 0):
					continue
				board.place(a, Vector2i(x, y), 0)
				for c in a.cells():
					var right := a.origin + c + Vector2i(1, 0)
					if not placed and board.can_place_item(b, right, 0):
						board.place(b, right, 0)
						placed = true
				if not placed:
					board.remove(a.uid)
		var p := Fusion.pairs(board, recipes)
		t.check(placed and p.size() == 1 and StringName(p[0]["output"]) == spec[2], "%s：贴着摆出一枚锤" % id)
		t.eq(pool.has(spec[2]), not LIMITED.has(spec[2]), "%s：随机来源%s" % [spec[2], "不出" if LIMITED.has(spec[2]) else "照旧"])
