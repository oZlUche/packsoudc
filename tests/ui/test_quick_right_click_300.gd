## 300（作者 2026-11-11 13:29 / 13:30 / 13:31）：右键单击 = 这件的双击动作（悬浮窗第一颗按钮）；要两步确认的（放到地上）照旧钉窗。
## 局内商店：右键商人的货 = 拿过来（待成交），右键待成交的 = 收回；进店商人问候一句。铁炉屏：包里双击 / 右键先砧后炉
extends RefCounted

const Shop := preload("res://tests/ui/test_shop_keys.gd")
const F175 := preload("res://tests/run/test_forge_175.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_rule(t: TestCase, root: Window) -> void:
	t.begin("300 · 右键 = 第一颗按钮；灰着 / 两步确认的照旧钉窗、不动东西")
	var board := GridInventory.new(Vector2i(3, 3), 1, false)
	var d := ItemDef.new()
	d.id = &"pebble"
	d.shape = ItemShape.from_ascii(["1"])
	var inst := ItemInstance.create(d)
	board.place(inst, Vector2i.ZERO, 0)
	var view := InventoryView.make(board, null)
	var tip := HoverTip.new()
	root.add_child(view)
	root.add_child(tip)
	tip.watch(view)
	var ran := [0]
	view.actions_for = func(_uid: int) -> Array: return [ItemActions.make(&"quick", "go", func(): ran[0] += 1)]
	view.item_context.emit(view, inst.uid)
	t.eq(ran[0], 1, "右键：做了第一颗按钮的事")
	t.check(not tip.is_pinned(), "没钉窗")
	view.actions_for = func(_uid: int) -> Array: return [ItemActions.make(&"quick", "drop", func(): ran[0] += 1, true)]
	view.item_context.emit(view, inst.uid)
	t.eq(ran[0], 1, "两步确认的（放到地上）：右键不做")
	t.check(tip.is_pinned(), "照旧钉窗")
	tip.hide_tip()
	view.actions_for = func(_uid: int) -> Array: return [ItemActions.lock(inst, board)]
	view.item_context.emit(view, inst.uid)
	t.check(not inst.is_locked_by_player() and tip.is_pinned(), "排第一的是锁：不锁、照旧钉窗")
	tip.hide_tip()
	view.actions_for = func(_uid: int) -> Array: return [ItemActions.disable(ItemActions.make(&"quick", "go", func(): ran[0] += 1), "no")]
	view.item_context.emit(view, inst.uid)
	t.eq(ran[0], 1, "灰着的：不做")
	view.free()
	tip.free()


static func frame_shop(t: TestCase, root: Window) -> void:
	t.begin("300 · 商店：右键商人的货 = 拿过来待成交；右键待成交的 = 收回；进店问候一句、只一次；点头像掷不到问候句")
	var o := Shop._open(root)
	var screen = o["screen"]
	var session: ShopSession = o["session"]
	var tip: HoverTip = screen._tip
	var ware := session.board.items()[0] as ItemInstance
	tip.pin_on(screen._view, ware.uid)
	t.check(not session.board.has_item(ware.uid) and session.is_merchants(ware.uid), "右键货：进了自己这边、待成交")
	var mine: InventoryView = screen._inv.board_view
	if mine.inventory.has_item(ware.uid):
		tip.pin_on(mine, ware.uid)
		t.check(session.board.has_item(ware.uid), "右键待成交的：收回到他的棋盘")
	var npc: NpcBadge = screen.npc
	if npc != null:
		t.check(npc.greet_on_enter, "局内商人进店问候")
		t.check(npc.greet() and npc.is_open() and String(npc.last.get("greet", "")).begins_with("greet_"), "问候一句（%s）" % str(npc.last))
		t.check(npc._note_side in ["l", "r"] and npc.note.get_theme_stylebox("panel") is StyleBoxTexture, "纸条换上羊皮纸条图（%s）" % npc._note_side)
		for l in NpcChatter.open_lines(NpcChatter.get_def(NpcDef.SHOPKEEPER), screen.flow.meta, screen.flow.run, screen.flow.run.items):
			t.check((l as NpcLine).kind != NpcLine.GREET, "点头像的池子里没有问候句（%s）" % (l as NpcLine).id)
	t.eq(NpcChatter.greet(NpcChatter.get_def(NpcDef.BLACKSMITH), RandomNumberGenerator.new()), null, "基地铁匠没有问候句")
	screen.free()
	Support.cleanup(Shop.PREFIX)


static func frame_forge(t: TestCase, root: Window) -> void:
	t.begin("300 · 铁炉屏：包里右键 / 双击先砧后炉；砧的槽右键取回")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("quick300")
	var game = (load(F175.GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("quick300")["run"])
	game.meta_path = String(Support.paths("quick300")["meta"])
	game.settings_path = String(Support.paths("quick300")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	var node := F175._rest_next_to_spawn(flow, c, kit)
	t.check(node != null and flow.step_to(node.id) and flow.open_forge(node), "进铁炉")
	var screen = game.overlay()
	if screen == null or not screen.has_method("anvil"):
		t.check(false, "进了铁炉两栏屏")
		game.queue_free()
		Support.cleanup("quick300")
		return
	var col: AnvilColumn = screen.anvil()
	var inv = screen._inv
	var tip: HoverTip = screen._tip
	var sword := ItemInstance.create(flow.items.get_def(&"broadsword"), 0)
	var claw := ItemInstance.create(flow.items.get_def(&"beast_claw"), 0)
	var salve := ItemInstance.create(flow.items.get_def(&"salve"), 0)
	for it in flow.run.board.items().duplicate():     # 包留着，别的先拿走腾地方
		if not flow.run.board.acts_as_bag((it as ItemInstance).def):
			flow.run.board.remove((it as ItemInstance).uid)
	for it in [sword, claw, salve]:
		t.check(flow.run.board.try_add(it), "包里放 %s" % it.def.id)
	tip.pin_on(inv.board_view, sword.uid)
	t.check(col.weapon_slot.has_item(sword.uid), "右键阔剑（有升级配方）：进砧的武器槽")
	t.check(inv.quick_move(inv.board_view, claw.uid) and col.material_slot.has_item(claw.uid), "双击兽爪：进砧的材料槽")
	t.check(inv.quick_move(inv.board_view, salve.uid) and screen.output() != null and not flow.run.board.has_item(salve.uid) and not col.weapon_slot.has_item(salve.uid), "伤药砧不收：进铸炉的槽")
	tip.pin_on(col._weapon_view, sword.uid)
	t.check(flow.run.board.has_item(sword.uid) and not col.weapon_slot.has_item(sword.uid), "砧的武器槽右键：取回背包")
	game.queue_free()
	Support.cleanup("quick300")
