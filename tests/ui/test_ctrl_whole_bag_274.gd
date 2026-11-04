## 274：按住 Ctrl 点包里的道具 = 拿起整个包；勾选模式不变；说明页写着
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


static func _board() -> Array:
	var c = NodeScreens._content()
	ItemInstance.reset_uid_counter()
	var board := GridInventory.new(Vector2i(6, 4), 1, true)
	var bag := ItemInstance.create(c.items.get_def(&"bag_leather"), 0)
	board.try_add(bag, true)
	var knife := ItemInstance.create(c.items.get_def(&"knife"), 0)
	board.try_add(knife, true)
	return [board, bag, knife]


static func _click(view: InventoryView, cell: Vector2i, ctrl: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.position = view.cell_origin_px(cell) + Vector2.ONE * view.cell_px * 0.5
	view._gui_input(ev)


static func frame_click(t: TestCase, root: Window) -> void:
	t.begin("274 · 按住 Ctrl 点包里的道具：拿起、右键都落在包上；不按照旧；勾选模式不受影响")
	var parts := _board()
	var board: GridInventory = parts[0]
	var bag: ItemInstance = parts[1]
	var knife: ItemInstance = parts[2]
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	root.add_child(view)
	var cell := knife.origin + knife.cells()[0]
	t.check(board.bag_at(cell) == bag.uid, "刀在包里")
	var grabbed: Array = []
	var ctx: Array = []
	var picked: Array = []
	view.grab_requested.connect(func(_v: ContainerView, uid: int, _p: Vector2) -> void: grabbed.append(uid))
	view.item_context.connect(func(_v: ContainerView, uid: int) -> void: ctx.append(uid))
	view.item_picked.connect(func(_v: InventoryView, uid: int) -> void: picked.append(uid))
	_click(view, cell, false)
	_click(view, cell, true)
	t.eq(grabbed, [knife.uid, bag.uid], "不按 Ctrl 拿刀，按着拿包")
	_click(view, cell, true, MOUSE_BUTTON_RIGHT)
	t.eq(ctx, [bag.uid], "按着 Ctrl 右键：包的菜单")
	t.eq(view.uid_at_cell(cell, true), bag.uid, "悬浮窗同一套取法：按着 Ctrl 是包")
	t.eq(view.uid_at_cell(Vector2i(5, 3), true), GridInventory.EMPTY_UID, "包外的空格：什么都不是")
	view.select_mode = true
	_click(view, cell, true)
	t.eq(picked, [knife.uid], "勾选模式：按着 Ctrl 也是勾刀")
	view.queue_free()


static func run_help(t: TestCase) -> void:
	t.begin("274 · 说明页：拖放与旋转、按键一览都写着 Ctrl")
	for id in ["drag_and_rotate", "keys"]:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/authoring/help_pages/%s.json" % id))
		t.check(String(d["text"]).contains("{key:Ctrl}") and String(d["texts"]["en"]).contains("{key:Ctrl}"), "%s 中英都有" % id)
