## 225 包架（补充一 §9.4 / 补充二 §十一，作者 18:27 定甲 包架列表）：包是装备不是货 —— 局外的包住在包架上，不占仓库格。
## 包架本身（只收包、同种叠一格、存档只记 id → uid）；局外的发包 / 收包 / 卖包 / 丢棋盘不丢包 / 暂存往返；
## 开局屏（初始包从包架摆上来、拖回包架、兜底发袋子）；拖拽落进包架；基地出售页卖包
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const META := "user://test_225_meta.json"
const SETTINGS := "user://test_225_settings.json"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _flow() -> GameFlow:
	var f := GameFlow.new(_db(), EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	return f


static func _cleanup() -> void:
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func run_rack_basics(t: TestCase) -> void:
	t.begin("225 · 包架：只收包；同种叠一格（按先来后到）；存档只记 id → uid，读回来 uid 不变；旧档写只数也认；删了的包记进 lost")
	var db := _db()
	var sack := db.get_def(&"sack")
	var small := db.get_def(&"bag_small")
	var knife := db.get_def(&"knife")
	t.check(BagRack.holds(sack) and BagRack.holds(small), "包进包架")
	t.check(not BagRack.holds(knife) and not BagRack.holds(null), "货不进")
	var rack := BagRack.new(MetaState.RACK_ID)
	t.check(not rack.insert(ItemInstance.create(knife, 0)), "包架拒收货")
	var uids: Array[int] = []
	for def in [small, sack, small]:
		var inst := ItemInstance.create(def, 0)
		inst.uid = 500 + uids.size()
		uids.append(inst.uid)
		rack.insert(inst)
	t.eq(rack.kinds(), [&"bag_small", &"sack"] as Array[StringName], "两种，按第一只进来的先后")
	t.eq(rack.count_of(&"bag_small"), 2, "小包两只")
	t.eq(rack.first_of(&"bag_small").uid, uids[0], "第一只")
	t.eq(rack.counts(), {"bag_small": 2, "sack": 1}, "只数")
	t.eq(rack.next_free_spot(rack.items()[0]), ItemStash.NO_SPOT, "包架上不画落点")
	var saved := rack.to_save()
	t.eq(saved, {"bag_small": [uids[0], uids[2]], "sack": [uids[1]]}, "存档：id → uid")
	var back := BagRack.from_save(saved, db, func() -> int: return -1, MetaState.RACK_ID)
	t.eq(back.to_save(), saved, "读回来逐字节一样")
	var next := [900]
	var lost: Array = []
	var legacy := BagRack.from_save({"sack": 2, "no_such_bag": 1}, db, func() -> int:
		next[0] += 1
		return next[0], MetaState.RACK_ID, lost)
	t.eq(legacy.count_of(&"sack"), 2, "旧档写只数：发两只")
	t.eq(legacy.items().map(func(i): return (i as ItemInstance).uid), [901, 902], "uid 问号段要")
	t.eq(lost, ["no_such_bag"], "没有的包记进 lost")


static func run_meta_rack(t: TestCase) -> void:
	t.begin("225 · 局外：发包、角色初始包只发一次、收包、卖包进钱；丢掉带回来的棋盘包照旧进包架；暂存往返包铺回原位；存档往返")
	var db := _db()
	var m := MetaState.new(GameFlow.load_meta_rules())
	t.eq(m.grant_bags([db.get_def(&"sack"), db.get_def(&"knife"), db.get_def(&"bag_small")]), 2, "货不发")
	t.eq(m.bags(), {"sack": 1, "bag_small": 1}, "包架两种")
	var ch := CharacterDef.new()
	ch.id = &"t_225"
	ch.starting_bags = [&"sack", &"sack"] as Array[StringName]
	t.eq(m.grant_starting_bags(ch, db), 2, "第一次选：两只初始包")
	t.eq(m.grant_starting_bags(ch, db), 0, "第二次不再发")
	t.eq(m.rack.count_of(&"sack"), 3, "粗麻袋三只")
	var funds := m.funds
	var uid := m.rack.first_of(&"bag_small").uid
	var got := m.sell_bag(uid, 0.5)
	t.check(got >= 0 and m.funds == funds + got, "卖一只进钱（%d）" % got)
	t.eq(m.rack.get_item(uid), null, "卖掉就没了")
	t.eq(m.sell_bag(uid), -1, "再卖：没这只")
	t.check(not m.put_bag(ItemInstance.create(db.get_def(&"knife"), 0)), "货收不进包架")
	# 丢掉带回来的棋盘：货没了，包进包架
	m.board = GridInventory.new(RunState.BOARD_SIZE, MetaState.BOARD_ID, true)
	var bag := ItemInstance.create(db.get_def(&"bag_small"), 0)
	bag.uid = m.allocate_uid()
	t.check(m.board.try_add(bag, true), "棋盘上铺一只小包")
	var knife := ItemInstance.create(db.get_def(&"knife"), 0)
	knife.uid = m.allocate_uid()
	t.check(m.board.try_add(knife, true), "包里一把刀")
	m.discard_board()
	t.eq(m.board, null, "棋盘丢了")
	t.check(m.rack.get_item(bag.uid) != null, "包还在（进了包架）")
	# 暂存往返：包进包架、回主菜单铺回原位
	m.board = GridInventory.new(RunState.BOARD_SIZE, MetaState.BOARD_ID, true)
	m.rack.remove(bag.uid)
	m.board.try_add(bag, true)
	var origin := bag.origin
	var knife2 := ItemInstance.create(db.get_def(&"knife"), 0)
	knife2.uid = m.allocate_uid()
	m.board.try_add(knife2, true)
	var stash := ItemStash.new(110)
	var pending := m.take_board_to_stash(stash)
	t.check(bool((pending[bag.uid] as Dictionary).get("rack", false)), "包记作进了包架")
	t.check(m.rack.get_item(bag.uid) != null and stash.get_item(bag.uid) == null, "包不倒地")
	t.check(stash.get_item(knife2.uid) != null, "货倒在地上")
	t.eq(m.return_stash(stash, pending), [] as Array[StringName], "全放回去了")
	t.check(m.board != null and m.board.get_item(bag.uid) != null and m.board.get_item(bag.uid).origin == origin, "包铺回原位")
	t.check(m.board.get_item(knife2.uid) != null, "货也回去了")
	t.eq(m.rack.get_item(bag.uid), null, "包架上没有它了")
	# 存档往返
	var d := m.to_dict()
	t.eq(d["bags"], m.rack.to_save(), "存档里有包架")
	t.check((d["bag_grants"] as Array).has("t_225"), "发过初始包的角色记着")
	var back := MetaState.from_dict(d, db, m.rules)
	t.eq(back.rack.to_save(), m.rack.to_save(), "包架读回来一样")
	t.check(back.bag_grants.has(&"t_225"), "发过的不再发")
	t.eq(JSON.stringify(back.to_dict()), JSON.stringify(d), "整份存档逐字节一样")
	t.check(back.allocate_uid() > m.rack.items().map(func(i): return (i as ItemInstance).uid).max(), "局外号段在包架的 uid 后面")


static func _game(root: Window, prefix: String) -> Node:
	Support.cleanup(prefix)
	var p := Support.paths(prefix)
	var game = load("res://ui/game/game.tscn").instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	for c in flow.tutorial_chapters():
		flow.meta.grant_unlock(c.hidden_by_unlock)
	flow.new_run()
	return game


static func frame_setup_rack(t: TestCase, root: Window) -> void:
	t.begin("225 · 开局屏：第一次选角色初始包发进包架再摆上棋盘；双击包 ⇄ 包架；包架只收空包、货不进；预设套的包和兜底袋子进不了包架；回主菜单包回包架")
	var game = _game(root, "rack225a")
	var flow: GameFlow = game.flow
	var setup = game.base()
	setup.show_page(1)
	var ch: CharacterDef = setup.character()
	t.check(flow.meta.bag_grants.has(ch.id), "这个角色发过初始包")
	t.eq(setup.board.bags().size(), ch.starting_bags.size(), "初始包都在棋盘上")
	t.eq(flow.meta.rack.item_count(), 0, "包架上不剩（都摆上去了）")
	t.check(setup._rack_view != null and setup._rack_view.container() == flow.meta.rack, "中间一列是包架")
	var bag: ItemInstance = setup.board.bags()[0]
	t.check(setup.quick_move(setup._board_view, bag.uid), "双击棋盘上的包：收回包架")
	t.check(flow.meta.rack.get_item(bag.uid) != null and setup.board.get_item(bag.uid) == null, "包在包架上了")
	t.eq(setup._rack_view.uid_at_local(setup._rack_view.slot_rect(0).get_center()), bag.uid, "包架第一格就是它")
	t.check(setup.quick_move(setup._rack_view, bag.uid), "双击包架上的包：摆上棋盘")
	t.check(setup.board.get_item(bag.uid) != null and flow.meta.rack.item_count() == 0, "又回棋盘了")
	var knife := ItemInstance.create(flow.items.get_def(&"knife"), 0)
	t.check(not setup._allow_drop(knife, flow.meta.rack), "货不进包架")
	t.check(setup._allow_drop(bag, flow.meta.rack), "包可以")
	# 包里有东西：收不回去
	knife.uid = flow.meta.allocate_uid()
	t.check(setup.board.try_add(knife, true), "包里放一把刀")
	var holder := -1
	for b in setup.board.bags():
		if setup.board.is_bag_with_contents((b as ItemInstance).uid):
			holder = (b as ItemInstance).uid
	t.check(holder >= 0 and not setup.rack_bag(holder), "有东西的包收不回包架")
	setup.board.remove(knife.uid)
	# 回主菜单：包回包架
	setup._return_bags()
	t.eq(setup.board.bags().size(), 0, "棋盘上的包都下来了")
	t.eq(flow.meta.rack.item_count(), ch.starting_bags.size(), "都回了包架")
	# 包架空、棋盘没包、不带预设：发一只粗麻袋（发的不进包架）
	for inst in flow.meta.rack.items():
		flow.meta.rack.remove((inst as ItemInstance).uid)
	t.check(setup.ensure_bag(), "发了一只")
	var sack: ItemInstance = setup.board.bags()[0]
	t.eq(sack.def.id, &"sack", "粗麻袋")
	t.check(setup.status_text().contains(Names.of(sack.def)), "状态那句说军需官发的")
	t.check(not setup._allow_drop(sack, flow.meta.rack) and not setup.rack_bag(sack.uid), "发的袋子进不了包架")
	setup._return_bags()
	t.eq(flow.meta.rack.item_count(), 0, "回主菜单也不进包架（免得白拿去卖）")
	t.eq(setup.board.bags().size(), 0, "发的袋子收走了")
	t.check(setup.ensure_bag(), "再进来再发一只")
	t.check(not setup.ensure_bag(), "棋盘上已经有包：不再发")
	game.queue_free()
	Support.cleanup("rack225a")


static func frame_drag_into_rack(t: TestCase, root: Window) -> void:
	t.begin("225 · 拖拽：空包拖进包架收下、包架上的包拖回棋盘；装着东西的包拖不进")
	var db := _db()
	var rack := BagRack.new(MetaState.RACK_ID)
	var board := GridInventory.new(Vector2i(6, 4), MetaState.BOARD_ID, true)
	var bag := ItemInstance.create(db.get_def(&"bag_small"), 0)
	bag.uid = 7001
	t.check(board.try_add(bag, true), "棋盘上一只小包")
	var bv := InventoryView.new()
	bv.inventory = board
	var rv := BagRackView.new().setup(rack)
	rv.position = Vector2(700, 0)
	var drag := DragLayer.new()
	drag.register_view(bv)
	drag.register_view(rv)
	var cell := float(InventoryView.CELL)
	bv.grab_requested.emit(bv, bag.uid, (Vector2(bag.origin) + Vector2(0.5, 0.5)) * cell)
	t.check(drag.is_dragging(), "抓起来了")
	t.check(drag.drop_at(rv.position + rv.slot_rect(0).get_center()), "落进包架")
	t.check(rack.get_item(bag.uid) != null and board.get_item(bag.uid) == null, "包在包架上")
	t.eq(rv.slot_count(), 1, "包架一格")
	rv.grab_requested.emit(rv, bag.uid, rv.slot_rect(0).get_center())
	t.check(drag.is_dragging(), "从包架抓起来")
	t.check(drag.drop_at((Vector2(1, 1) + Vector2(0.5, 0.5)) * cell), "放回棋盘")
	t.check(board.get_item(bag.uid) != null and rack.item_count() == 0, "回棋盘了")
	var knife := ItemInstance.create(db.get_def(&"knife"), 0)
	knife.uid = 7002
	t.check(board.try_add(knife, true), "包里放一把刀")
	var at: Vector2 = (Vector2(board.get_item(bag.uid).origin) + Vector2(0.5, 0.5)) * cell
	bv.grab_requested.emit(bv, bag.uid, at)
	if drag.is_dragging():
		t.check(not drag.drop_at(rv.position + rv.slot_rect(0).get_center()), "装着东西的包落不进包架")
	t.eq(rack.item_count(), 0, "包架还是空的")
	for n in [bv, rv, drag]:
		n.free()


static func frame_sell_bag(t: TestCase, root: Window) -> void:
	t.begin("225 · 基地：仓库页最左一列是包架；出售页有包架，双击卖一只进钱")
	ItemInstance.reset_uid_counter()
	var f := _flow()
	f.meta.grant_bags([f.items.get_def(&"sack"), f.items.get_def(&"sack"), f.items.get_def(&"bag_small")])
	f.meta.board = GridInventory.new(Vector2i(6, 4), MetaState.BOARD_ID, false)
	f.meta.board.try_add(ItemInstance.create(f.items.get_def(&"knife")))
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	var wh = screen._wh
	t.check(wh.rack_view() != null and wh.rack_view().container() == f.meta.rack, "仓库页有包架")
	t.check(wh.rack_room() > 0.0, "包架占了宽度")
	var view: BagRackView = screen.sell_rack_view()
	t.check(view != null and view.container() == f.meta.rack, "出售页有包架")
	t.eq(view.slot_count(), 2, "两种包两格")
	var funds := f.meta.funds
	var uid: int = view.uid_at_local(view.slot_rect(0).get_center())
	t.check(uid >= 0, "第一格有包")
	view.item_double_clicked.emit(view, uid)
	t.check(f.meta.funds > funds, "卖了进钱（%d → %d）" % [funds, f.meta.funds])
	t.eq(f.meta.rack.count_of(&"sack"), 1, "粗麻袋剩一只")
	t.check(screen.notice_layer().current_text() != "", "出售行说了一句")
	screen.queue_free()
	_cleanup()
