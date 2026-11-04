## 279 第三步：拼接 —— 两件贴着、有拼接配方，接缝上一枚小锤；点锤两件合成一件，成品落在两件原来的占格里（落不下在棋盘上找位）；
## 不贴着、拖合配方、包都不算；勾选模式不画锤；说明页写着
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _put(board: GridInventory, db: ItemDatabase, id: StringName, at: Vector2i, rot := 0) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id), rot)
	return inst if board.place(inst, at, rot) else null


static func run_pairs(t: TestCase) -> void:
	t.begin("279 · 拼接：贴着才算（转向无关、斜角不算），一对只出一次，接缝在两件之间；拖合配方、不贴着都不出锤")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var recipes := RecipeDef.load_all()
	var board := GridInventory.new(Vector2i(6, 4), 1, false)
	var k1 := _put(board, db, &"knife", Vector2i(0, 0))
	var k2 := _put(board, db, &"knife", Vector2i(1, 0))
	var p := Fusion.pairs(board, recipes)
	t.eq(p.size(), 1, "两把匕首贴着：一对")
	if p.size() == 1:
		t.eq([p[0]["a"], p[0]["b"]], [k1.uid, k2.uid], "a < b")
		t.eq(StringName(p[0]["output"]), &"twin_blades", "拼成双刀")
		var seam: Vector2 = p[0]["seam"]
		t.check(is_equal_approx(seam.x, 1.0) and seam.y > 0.0 and seam.y < 2.0, "接缝在两把中间的竖边上（%s）" % seam)
	board.remove(k2.uid)
	_put(board, db, &"knife", Vector2i(1, 2))
	t.eq(Fusion.pairs(board, recipes).size(), 0, "斜角挨着不算")
	ItemInstance.reset_uid_counter()
	var b2 := GridInventory.new(Vector2i(6, 4), 1, false)
	_put(b2, db, &"knife", Vector2i(0, 0))
	_put(b2, db, &"poison_vial", Vector2i(1, 0))
	t.eq(Fusion.pairs(b2, recipes).size(), 0, "涂毒匕首是拖上去合的，贴着不出锤")
	_put(b2, db, &"whetstone", Vector2i(0, 2))
	var q := Fusion.pairs(b2, recipes)
	t.check(q.size() == 1 and StringName(q[0]["output"]) == &"quenched_dagger", "匕首下面贴一块磨刀石：淬火匕首")


static func run_fuse(t: TestCase) -> void:
	t.begin("279 · 点锤合：两件消失，产物落在两件的占格里；并集放不下就在棋盘上找位；哪都放不下原样不动")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var board := GridInventory.new(Vector2i(6, 4), 1, false)
	var k1 := _put(board, db, &"knife", Vector2i(2, 1))
	var k2 := _put(board, db, &"knife", Vector2i(3, 1))
	var out := Fusion.fuse(board, k1.uid, k2.uid, db.get_def(&"twin_blades"))
	t.check(out != null and board.has_item(out.uid), "双刀上了棋盘")
	t.check(not board.has_item(k1.uid) and not board.has_item(k2.uid), "两把匕首没了")
	if out != null:
		t.eq(out.origin, Vector2i(2, 1), "正好落在两把匕首的位置")
	# 木棍 + 燧石（三格）→ 石锤（六格）：并集放不下，在棋盘上找位
	ItemInstance.reset_uid_counter()
	var b2 := GridInventory.new(Vector2i(6, 4), 1, false)
	var stick := _put(b2, db, &"wooden_stick", Vector2i(0, 0))
	var flint := _put(b2, db, &"flint", Vector2i(1, 0))
	var maul := Fusion.fuse(b2, stick.uid, flint.uid, db.get_def(&"stone_maul"))
	t.check(maul != null and b2.has_item(maul.uid) and b2.item_count() == 1, "石锤找了个地方放下")
	# 棋盘只够两件：哪都放不下 → 原样
	ItemInstance.reset_uid_counter()
	var b3 := GridInventory.new(Vector2i(2, 1), 1, false)
	var s1 := _put(b3, db, &"flint", Vector2i(0, 0))
	var s2 := _put(b3, db, &"poison_vial", Vector2i(1, 0))
	t.is_null(Fusion.fuse(b3, s1.uid, s2.uid, db.get_def(&"stone_maul")), "放不下：不合")
	t.check(b3.has_item(s1.uid) and b3.has_item(s2.uid) and s1.origin == Vector2i(0, 0) and s2.origin == Vector2i(1, 0), "两件原样放回")


static func run_bag_board(t: TestCase) -> void:
	t.begin("279 · 包里的两件照样能拼，包本身不参加；合完产物还在包里")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	var bag := ItemInstance.create(db.get_def(&"bag_leather"), 0)
	board.try_add(bag, true)
	var k1 := ItemInstance.create(db.get_def(&"knife"), 0)
	var k2 := ItemInstance.create(db.get_def(&"knife"), 0)
	board.try_add(k1, false)
	board.try_add(k2, false)
	var p := Fusion.pairs(board, RecipeDef.load_all())
	var touching := false
	for c in k1.cells():
		for d in Fusion.DIRS:
			touching = touching or board.cell_uid(k1.origin + c + d) == k2.uid
	t.eq(p.size(), 1 if touching else 0, "包不算一件，贴着的两把匕首才算")
	if p.size() == 1:
		var out := Fusion.fuse(board, k1.uid, k2.uid, db.get_def(&"twin_blades"))
		t.check(out != null and board.bag_of(out.uid) == bag.uid, "双刀在包里")


static func frame_badge(t: TestCase, root: Window) -> void:
	t.begin("279 · 小锤：画在接缝上，点它发 fuse_requested、不拿起；点别处照旧拿起；勾选模式不响应")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var board := GridInventory.new(Vector2i(6, 4), 1, false)
	var k1 := _put(board, db, &"knife", Vector2i(0, 0))
	var k2 := _put(board, db, &"knife", Vector2i(1, 0))
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	root.add_child(view)
	view.fusions = Fusion.pairs(board, RecipeDef.load_all())
	var fused: Array = []
	var grabbed: Array = []
	view.fuse_requested.connect(func(_v: InventoryView, a: int, b: int) -> void: fused.append([a, b]))
	view.grab_requested.connect(func(_v: ContainerView, uid: int, _p: Vector2) -> void: grabbed.append(uid))
	var seam: Vector2 = view.fusions[0]["seam"] if not view.fusions.is_empty() else Vector2.ZERO
	var at := seam * view.cell_px
	t.eq(view.fusion_at(at).get("b", -1), k2.uid, "接缝上找得到这一对")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	view._gui_input(ev)
	t.eq(fused, [[k1.uid, k2.uid]], "点锤：发合成请求")
	t.eq(grabbed, [], "点锤不拿起")
	ev.position = view.cell_origin_px(Vector2i(0, 1)) + Vector2.ONE * view.cell_px * 0.5
	view._gui_input(ev)
	t.eq(grabbed, [k1.uid], "点匕首下半截：照旧拿起")
	view.select_mode = true
	t.eq(view.fusion_at(at), {}, "勾选模式：锤不响应")
	view.queue_free()


static func run_help(t: TestCase) -> void:
	t.begin("279 · 说明页「拖放与旋转」中英都写了小锤")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/help_pages/drag_and_rotate.json"))
	t.check(String(d["text"]).contains("小锤") and String(d["texts"]["en"]).contains("hammer"), "中英都有")


static func run_module(t: TestCase) -> void:
	t.begin("279 · 一局里的合成模块：fusion_pairs 列出能拼的；fuse 合了记一次合成、发 done；不是一对的不合")
	var c := TestSupport.load_content()
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var crafting := CraftingModule.of(s)
	t.not_null(crafting, "装了合成模块")
	if crafting == null:
		return
	crafting.recipes = RecipeDef.load_all()
	s.board = GridInventory.new(Vector2i(6, 4), 1, false)
	var k1 := _put(s.board, c.items, &"knife", Vector2i(0, 0))
	var k2 := _put(s.board, c.items, &"knife", Vector2i(1, 0))
	var far := _put(s.board, c.items, &"knife", Vector2i(4, 0))
	t.eq(crafting.fusion_pairs().size(), 1, "一对")
	t.check(not bool(crafting.fuse(k1.uid, far.uid)["ok"]), "不贴着的两把：不合")
	var seen: Array = []
	crafting.done.connect(func(detail: Dictionary) -> void: seen.append(detail))
	var before := int(s.tally.get("crafts", 0))
	var d := crafting.fuse(k2.uid, k1.uid)
	t.check(bool(d["ok"]) and d["output"] == "twin_blades" and d["where"] == "board", "合成双刀，在棋盘上")
	t.eq(seen.size(), 1, "发了一次 done")
	t.eq(int(s.tally.get("crafts", 0)), before + 1, "结算账单记一次合成")
