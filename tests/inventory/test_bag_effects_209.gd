## 209（作者 21:30 夜间六条之三，待定按推荐）：包的种类、效果与稀有度 —— 包体效果（bag_mods）+ 三个局内字段
## （不耗耐久 / 卖价倍率 / 负重倍率），十个新包、四个老包补字段
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _put(board: GridInventory, db: ItemDatabase, id: StringName, at: Vector2i, rot: int = 0) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id), rot)
	board.place(inst, at, rot)
	return inst


static func run_catalog(t: TestCase) -> void:
	t.begin("209 · ① 包的目录：十个新包都是包、稀有度按表；老包补了稀有度，药水带补了急速；只收标签对得上")
	var db := _db()
	var want := {"bag_small": 0, "bag_long": 0, "bag_leather": 0, "sack": 0, "belt_potion": 1, "fanny_pack": 1, "quiver": 1,
		"tool_roll": 1, "herb_pouch": 1, "studded_satchel": 2, "rune_pouch": 2, "hunting_bag": 2, "treasure_satchel": 3, "war_pack": 4}
	for id in want:
		var d := db.get_def(StringName(id))
		t.check(d != null and d.is_bag, "%s 是包" % id)
		if d != null:
			t.eq(d.rarity, int(want[id]), "%s 稀有度 %d" % [id, want[id]])
	t.eq(db.get_def(&"belt_potion").bag_mods.size(), 1, "药水带：里面的东西急速")
	t.eq(db.get_def(&"quiver").bag_accept_tags, [&"ammo", &"bow", &"ranged"] as Array[StringName], "箭囊只收箭与弓")
	t.check(db.get_def(&"rune_pouch").bag_wear_free, "符文囊：不耗耐久")
	t.eq([db.get_def(&"treasure_satchel").bag_value_mult, db.get_def(&"treasure_satchel").bag_weight_mult], [1.25, 0.5], "百宝囊：卖价 ×1.25、负重减半")
	t.eq(db.get_def(&"war_pack").cell_count(), 12, "军用行囊十二格")


static func run_mods(t: TestCase) -> void:
	t.begin("209 · ② 包体效果：铆钉挎包里整件的东西护甲上限 +2；跨两个包的不加；包外的不加")
	var db := _db()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	_put(board, db, &"studded_satchel", Vector2i(0, 0))
	_put(board, db, &"bag_small", Vector2i(2, 0))
	var inside := _put(board, db, &"knife", Vector2i(0, 0))
	var across := _put(board, db, &"iron_ore", Vector2i(1, 1), 1)     # 横过来压在挎包右下与小包左下
	var other := _put(board, db, &"knife", Vector2i(3, 0))
	t.check(board.has_item(across.uid), "跨包那件摆上了")
	var spec := BattleCompiler.compile(board, CompileInput.new())
	t.eq(spec.item_of(inside.uid).stats.total_of(BattleStats.MAX_ARMOR), StatMath.from_float(2.0), "挎包里的匕首：护甲上限 +2")
	t.eq(spec.item_of(across.uid).stats.total_of(BattleStats.MAX_ARMOR), 0, "跨两个包：不加")
	t.eq(spec.item_of(other.uid).stats.total_of(BattleStats.MAX_ARMOR), 0, "别的包里：不加")


static func run_value_weight(t: TestCase) -> void:
	t.begin("209 · ③ 百宝囊：里面的东西卖价 ×1.25、负重减半；不在里面的照旧；悬浮窗写这两句")
	var db := _db()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	_put(board, db, &"treasure_satchel", Vector2i(0, 0))
	_put(board, db, &"bag_small", Vector2i(3, 0))
	var a := _put(board, db, &"iron_ore", Vector2i(0, 0))
	var b := _put(board, db, &"iron_ore", Vector2i(3, 0))
	t.eq(ItemValue.of_in(a, board), roundi(ItemValue.of_instance(a) * 1.25), "百宝囊里：卖价 ×1.25")
	t.eq(ItemValue.of_in(b, board), ItemValue.of_instance(b), "小包里：照旧")
	t.eq(ItemWeight.of_in(a, board), roundi(ItemWeight.of(a.def) * 0.5), "百宝囊里：负重减半")
	t.eq(ItemWeight.total(board), ItemWeight.of_in(a, board) + ItemWeight.of(b.def), "总负重按包算")
	var lines := ItemTooltip.bag_field_lines(db.get_def(&"treasure_satchel"))
	t.check(lines.has("里面的东西卖价 +25%") and lines.has("里面的东西负重减半"), "悬浮窗两句（%s）" % [lines])
	t.eq(ItemTooltip.bag_field_lines(db.get_def(&"rune_pouch")), ["里面的魔晶石不耗耐久"] as Array[String], "符文囊一句")
	t.eq(ItemTooltip.bag_field_lines(db.get_def(&"knife")), [] as Array[String], "不是包：没有")


static func run_wear_free(t: TestCase) -> void:
	t.begin("209 · ④ 符文囊：里面的晶石打一场不扣耐久，外面的照扣")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	_put(board, c.items, &"rune_pouch", Vector2i(0, 0))
	_put(board, c.items, &"bag_small", Vector2i(2, 0))
	var safe := _put(board, c.items, &"fire_crystal", Vector2i(0, 0))
	var worn := _put(board, c.items, &"ice_crystal", Vector2i(2, 0))
	s.board = board
	var spec := s.compile_player()
	spec.fed_uids = [safe.uid, worn.uid] as Array[int]     # 两颗都算这一场供给了（只测耐久这一步）
	var node := CS._battle_node(s)
	s.events.last_battle = {"player": spec, "node": node.id}
	s.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(safe.charges(), safe.def.wear.max_charges, "符文囊里的：不扣")
	t.eq(worn.charges(), worn.def.wear.max_charges - 1, "小包里的：扣一次")


static func run_import(t: TestCase) -> void:
	t.begin("209 · ⑤ 导入：三个包体字段写在非包上提醒")
	var r := ImportReport.new()
	ContentImporter.import_item({"id": "t_not_bag", "shape": ["1"], "bag_wear_free": true}, ContentImporter.Context.new(), r)
	t.check(r.to_text().contains("不是包"), "提醒（%s）" % r.to_text())
