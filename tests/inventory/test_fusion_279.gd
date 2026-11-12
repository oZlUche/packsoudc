## 279 拼接 → 314：拿起一件、拖到能和它合的另一件上松手 —— 拖拽层先把手上那件放回原处、交给持有方开确认窗；
## 拿起时能合的那几件标小锤（放下收）；成品落在被压那件的位置（不够再加上手里那件原来的格、再在棋盘上找位；哪都放不下原样不动）；
## 不再看贴不贴着；棋盘和地上都算；包里的件照样能合；说明页写着
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _put(board: GridInventory, db: ItemDatabase, id: StringName, at: Vector2i, rot := 0) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id), rot)
	return inst if board.place(inst, at, rot) else null


static func _run() -> RunState:
	var c := TestSupport.load_content()
	var s := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	s.meta = MetaState.new()
	s.faith_defs = FaithDef.load_all()
	CraftingModule.of(s).recipes = RecipeDef.load_all()
	s.board = GridInventory.new(Vector2i(6, 4), 1, false)
	return s


static func run_fuse(t: TestCase) -> void:
	t.begin("314 · 合：两件消失，成品落在被压那件的位置（不够加上手里那件的格）；不贴着也能合；哪都放不下原样不动")
	var s := _run()
	var cm := CraftingModule.of(s)
	var k1 := _put(s.board, s.items, &"knife", Vector2i(2, 1))
	var k2 := _put(s.board, s.items, &"knife", Vector2i(3, 1))
	var d := cm.fuse(k1.uid, k2.uid)
	t.check(bool(d["ok"]) and d["where"] == "board", "合成双刀，在棋盘上")
	var out := s.board.items()[0] as ItemInstance if s.board.item_count() == 1 else null
	t.check(out != null and out.def.id == &"twin_blades" and out.origin == Vector2i(2, 1), "双刀正好落在两把匕首的位置")
	s.board.clear()
	var far1 := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var far2 := _put(s.board, s.items, &"knife", Vector2i(4, 2))
	t.check(bool(cm.fuse(far1.uid, far2.uid)["ok"]), "隔得远的两把：照样合（314 不看贴不贴着）")
	t.check(s.board.items().any(func(i: ItemInstance) -> bool: return i.def.id == &"twin_blades" and i.origin == Vector2i(4, 2)), "成品落在被压那把的位置")
	s.board.clear()
	var stick := _put(s.board, s.items, &"wooden_stick", Vector2i(0, 0))
	var flint := _put(s.board, s.items, &"flint", Vector2i(1, 0))
	t.check(bool(cm.fuse(stick.uid, flint.uid)["ok"]) and s.board.item_count() == 1, "石锤（六格）两件的格放不下：在棋盘上找了个地方")
	s.board = GridInventory.new(Vector2i(3, 1), 1, false)
	var f1 := _put(s.board, s.items, &"wooden_stick", Vector2i(0, 0), 1)
	var f2 := _put(s.board, s.items, &"flint", Vector2i(2, 0))
	t.check(f1 != null and f2 != null, "三格的棋盘摆下横放的木棍和燧石")
	if f1 != null and f2 != null:
		var no := cm.fuse(f1.uid, f2.uid)
		t.check(not bool(no["ok"]) and no.get("reason", "") == "no_room", "石锤哪都放不下：不合")
		t.check(s.board.has_item(f1.uid) and s.board.has_item(f2.uid) and f2.origin == Vector2i(2, 0) and f1.origin == Vector2i(0, 0), "两件原样放回")


static func run_ground(t: TestCase) -> void:
	t.begin("314 · 跨容器：地上那件压到棋盘那件上，成品在棋盘；棋盘那件压到地上那件上，成品落在地上那一处")
	var s := _run()
	var cm := CraftingModule.of(s)
	var on_board := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var loose := ItemInstance.create(s.items.get_def(&"knife"))
	s.storage.insert(loose, -1, Vector2(0.4, 0.5))
	var d := cm.fuse(loose.uid, on_board.uid)
	t.check(bool(d["ok"]) and d["where"] == "board" and s.storage.item_count() == 0, "地上压棋盘：成品在棋盘，地上那把没了")
	s.board.clear()
	var k := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var g := ItemInstance.create(s.items.get_def(&"knife"))
	s.storage.insert(g, -1, Vector2(0.3, 0.6))
	var d2 := cm.fuse(k.uid, g.uid)
	t.check(bool(d2["ok"]) and d2["where"] == "storage" and s.board.item_count() == 0, "棋盘压地上：成品在地上，棋盘那把没了")
	var made := s.storage.items()[0] as ItemInstance if s.storage.item_count() == 1 else null
	t.check(made != null and made.def.id == &"twin_blades" and s.storage.spot_of(made.uid).is_equal_approx(Vector2(0.3, 0.6)), "落在被压那把的那一处")


static func run_bag_board(t: TestCase) -> void:
	t.begin("279 · 包里的两件照样能合，包本身不参加；合完成品还在包里")
	var s := _run()
	s.board = GridInventory.new(Vector2i(6, 4), 1, true)
	var bag := ItemInstance.create(s.items.get_def(&"bag_leather"), 0)
	s.board.try_add(bag, true)
	var k1 := ItemInstance.create(s.items.get_def(&"knife"), 0)
	var k2 := ItemInstance.create(s.items.get_def(&"knife"), 0)
	s.board.try_add(k1, false)
	s.board.try_add(k2, false)
	var cm := CraftingModule.of(s)
	t.check(not cm.partner_ok(k1, bag), "包不算搭档")
	var d := cm.fuse(k1.uid, k2.uid)
	var out := s.board.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"twin_blades")
	t.check(bool(d["ok"]) and out.size() == 1 and s.board.bag_of((out[0] as ItemInstance).uid) == bag.uid, "双刀在包里")


static func run_drag(t: TestCase) -> void:
	t.begin("314 · 拖拽层：拿起标出能合的那几件；压到搭档上预览是绿的；松手先放回原处、叫 fuse_drop；没搭档照常顶替")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var board := GridInventory.new(Vector2i(6, 4), 1, false)
	var k1 := _put(board, db, &"knife", Vector2i(0, 0))
	var k2 := _put(board, db, &"knife", Vector2i(3, 0))
	var vial := _put(board, db, &"poison_vial", Vector2i(5, 0))
	var fish := _put(board, db, &"smoked_fish", Vector2i(5, 2))
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	var drag := DragLayer.new()
	drag.register_view(view)
	var recipes := RecipeDef.load_all()
	drag.fuse_partner = func(a: ItemInstance, b: ItemInstance) -> bool: return RecipeDef.find(recipes, a.def.id, b.def.id) != null
	var asked: Array = []
	drag.fuse_drop = func(held: ItemInstance, home: ItemContainer, target: ItemInstance, target_home: ItemContainer, ghost: Rect2) -> void:
		asked.append([held.uid, home, target.uid, target_home, ghost])
	view.grab_requested.emit(view, k1.uid, Vector2(24, 24))
	t.check(drag.is_dragging(), "拿起匕首")
	t.check(view.fuse_marks.has(k2.uid) and view.fuse_marks.has(vial.uid) and not view.fuse_marks.has(fish.uid), "另一把匕首、毒药瓶标小锤，熏鱼不标（%s）" % [view.fuse_marks.keys()])
	t.not_null(UiTheme.art_cached(InventoryView.FUSE_ART), "小锤有图（占位）")
	var at := (Vector2(3, 0) + Vector2(0.5, 0.5)) * InventoryView.CELL
	drag.update_preview(at)
	t.check(view.preview_ok(), "压在另一把匕首上：预览绿的")
	t.check(not drag.drop_at(at), "松手：这一下不算放下")
	t.eq(asked.size(), 1, "叫了一次 fuse_drop")
	if asked.size() == 1:
		t.check(asked[0][0] == k1.uid and asked[0][1] == board and asked[0][2] == k2.uid and asked[0][3] == board, "手上那把、被压那把、各在哪")
		t.check((asked[0][4] as Rect2).has_area(), "带着残影的外框")
	t.check(board.has_item(k1.uid) and k1.origin == Vector2i(0, 0), "手上那把已经回到原处")
	t.check(board.has_item(k2.uid), "被压那把没动")
	t.check(view.fuse_marks.is_empty(), "放下：小锤收了")
	drag.fuse_partner = func(_a: ItemInstance, _b: ItemInstance) -> bool: return false
	view.grab_requested.emit(view, k1.uid, Vector2(24, 24))
	drag.update_preview(at)
	t.check(drag.drop_at(at), "没搭档：照常顶替")
	t.eq(asked.size(), 1, "不叫 fuse_drop")


static func run_help(t: TestCase) -> void:
	t.begin("279 / 314 · 说明页「拖放与旋转」中英都写了拖到上面合成")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/help_pages/drag_and_rotate.json"))
	t.check(String(d["text"]).contains("小锤") and String(d["texts"]["en"]).contains("hammer"), "中英都有")


static func run_module(t: TestCase) -> void:
	t.begin("279 · 一局里的合成模块：fuse 合了记一次合成、发 done；没配方的不合")
	var s := _run()
	var crafting := CraftingModule.of(s)
	var k1 := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var k2 := _put(s.board, s.items, &"knife", Vector2i(1, 0))
	var fish := _put(s.board, s.items, &"smoked_fish", Vector2i(4, 0))
	t.check(not bool(crafting.fuse(k1.uid, fish.uid)["ok"]), "匕首 + 熏鱼：不合")
	var seen: Array = []
	crafting.done.connect(func(detail: Dictionary) -> void: seen.append(detail))
	var before := int(s.tally.get("crafts", 0))
	var d := crafting.fuse(k2.uid, k1.uid)
	t.check(bool(d["ok"]) and d["output"] == "twin_blades" and d["where"] == "board", "合成双刀，在棋盘上")
	t.eq(seen.size(), 1, "发了一次 done")
	t.eq(int(s.tally.get("crafts", 0)), before + 1, "结算账单记一次合成")


static func frame_panel(t: TestCase, root: Window) -> void:
	t.begin("314 · 背包面板：拿起匕首拖到另一把上松手 —— 开确认窗、手上那把回原处先不画、残影半透明；取消什么都不变；合成后双刀落在被压那把的位置")
	var s := _run()
	var panel: Control = preload("res://ui/game/inventory_panel.gd").new()
	panel.setup(s, null)
	root.add_child(panel)
	var k1 := _put(s.board, s.items, &"knife", Vector2i(0, 0))
	var k2 := _put(s.board, s.items, &"knife", Vector2i(3, 0))
	var view: InventoryView = panel.get("board_view")
	var drag: DragLayer = panel.call("drag_layer")
	var at := view.get_global_transform() * view.cell_origin_px(Vector2i(3, 0)) + Vector2.ONE * view.cell_px * 0.5
	view.grab_requested.emit(view, k1.uid, Vector2.ONE * view.cell_px * 0.5)
	t.check(view.fuse_marks.has(k2.uid), "拿起：另一把标小锤")
	drag.update_preview(at)
	drag.drop_at(at)
	var note: FuseNote = panel.get("fuse_note")
	t.check(note != null and note.is_open(), "松手：开确认窗")
	t.check(s.board.has_item(k1.uid) and k1.origin == Vector2i(0, 0), "手上那把回到原处")
	t.check(view.veiled.has(k1.uid) and note.ghost_item == k1, "原处先不画，残影留在松手处")
	if note != null and note.cancel_key != null:
		note.cancel_key.pressed.emit()
		t.check(not view.veiled.has(k1.uid) and s.board.item_count() == 2 and not s.knows_recipe(&"fuse_twin_blades"), "取消：两把都在、不记配方")
		view.grab_requested.emit(view, k1.uid, Vector2.ONE * view.cell_px * 0.5)
		drag.update_preview(at)
		drag.drop_at(at)
		note.go_key.pressed.emit()
		t.check(s.board.item_count() == 1 and (s.board.items()[0] as ItemInstance).def.id == &"twin_blades", "合成：剩一把双刀")
		t.eq((s.board.items()[0] as ItemInstance).origin, Vector2i(3, 0), "落在被压那把的位置")
	panel.queue_free()
