## 099（作者定）：在背包里切信仰的规则 —— **棋盘内把信物重新落下 = 奉它为主信仰**（不是「置入道具」，信力不记）、
## **取消拖拽不切**、**右键信物也能切**；普通道具在棋盘内挪位置不盖置入序号（来回拖不再刷信力）；
## 从别的容器进来仍然算置入，信力照记（原行为不变）。期望从数据推：信力该加几点问行为构件自己。
extends RefCounted

const CELL := InventoryView.CELL


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _start(items: ItemDatabase) -> RunState:
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var chars := GameFlow.load_characters()
	for seed in range(1, 60):
		var s := RunState.start(chapter, seed, items, enemies, sets, [] as Array[StringName], {}, [] as Array[StringName], chars[0] if not chars.is_empty() else null)
		if s != null:
			s.faith_defs = FaithDef.load_all()
			s.pick_spawn(s.map.entry_ids[0])
			return s
	return null


## 某个信仰的信物（没有返回 null）
static func _anchor_of(db: ItemDatabase, fid: StringName) -> ItemDef:
	for id in db.ids():
		var d := db.get_def(id)
		if d.is_anchor() and FaithTags.id_of_tag(d.faith_tag()) == fid:
			return d
	return null


static func _view(inv: GridInventory) -> InventoryView:
	var v := InventoryView.new()
	v.auto_tooltip = false
	v.inventory = inv
	v.position = Vector2.ZERO
	v.size = Vector2(inv.size) * CELL
	return v


static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## 把一件放进棋盘（随便哪个放得下的位置）；放不下返回 null
static func _add(board: GridInventory, def: ItemDef) -> ItemInstance:
	if def == null:
		return null
	var inst := ItemInstance.create(def, 0)
	return inst if board.try_add(inst, true) else null


## 行为构件说这一次置入该给几点
static func _expected_place_gain(def: FaithDef, item: ItemDef) -> int:
	var n := 0
	for d in def.deeds:
		n += maxi(0, (d as FaithDeed).gain(&"place_item", {"value": ItemValue.of(item), "id": String(item.id)}))
	return n


static func run_reseat_rules(t: TestCase) -> void:
	t.begin("099 · reseat：只盖置入序号、不发 placed（信力的 place_item 不记）")
	var db := _db()
	var board := GridInventory.new(Vector2i(6, 4), 1, false)
	var shield := ItemInstance.create(db.get_def(&"blessed_shield"), 0)     # skill 的信物
	var sigil := ItemInstance.create(db.get_def(&"strength_sigil"), 0)      # brute 的信物
	t.check(board.place(shield, Vector2i(0, 0), 0), "放赐福的盾")
	t.check(board.place(sigil, Vector2i(4, 0), 0), "放力量的符号")
	t.eq(FaithState.active_id(board), &"brute", "后放的符号激活暴力之神")
	var placed_times := [0]
	board.placed.connect(func(_i: ItemInstance): placed_times[0] += 1)
	var changed_times := [0]
	board.changed.connect(func(): changed_times[0] += 1)
	t.check(board.reseat(shield.uid), "reseat 盾")
	t.eq(FaithState.active_id(board), &"skill", "盾成了最后置入的 → 技巧之神")
	t.eq(placed_times[0], 0, "reseat 不发 placed：切信仰不是置入道具")
	t.eq(changed_times[0], 1, "但发 changed：界面要重画（谁生效、谁休眠变了）")
	t.eq(board.get_item(shield.uid).origin, Vector2i(0, 0), "格子一点没动")
	t.check(board.reseat(sigil.uid), "再 reseat 符号")
	t.eq(FaithState.active_id(board), &"brute", "切回暴力之神")
	t.check(not board.reseat(9999), "不在这个容器里的 uid：false")


static func run_drag_board_reseat(t: TestCase) -> void:
	t.begin("099 · 棋盘内落下信物 = 切信仰且信力不记；取消不切；凡物在棋盘内挪不盖序号；从地上进来照记")
	var db := _db()
	var run := _start(db)
	if run == null:
		t.check(false, "开不了一局")
		return
	var board := run.board
	var skill_def := _anchor_of(db, &"skill")
	var brute_def := _anchor_of(db, &"brute")
	t.check(skill_def != null and brute_def != null, "两个信仰各有一件信物（%s / %s）" % [skill_def.id if skill_def != null else &"?", brute_def.id if brute_def != null else &"?"])
	var skill_anchor := _add(board, skill_def)
	var brute_anchor := _add(board, brute_def)
	if skill_anchor == null or brute_anchor == null:
		t.check(false, "棋盘上放不下两件信物")
		return
	t.eq(FaithState.active_id(board), &"brute", "后放的是暴力之神的信物")

	var view := _view(board)
	var drag := DragLayer.new()
	drag.stash = run.storage
	drag.register_view(view)

	# 1 · 棋盘内把技巧之神的信物重新落下：切信仰，信力一点不加
	var before := run.faith_power.points_of(&"skill")
	var before_brute := run.faith_power.points_of(&"brute")
	var home := skill_anchor.origin
	view.grab_requested.emit(view, skill_anchor.uid, _center(view, home) - view.position)
	t.check(drag.is_dragging(), "抓起了技巧之神的信物")
	t.check(drag.drop_at(_center(view, home)), "在棋盘上原处落下")
	t.eq(FaithState.active_id(board), &"skill", "落下 = 奉它为主信仰 → 技巧之神")
	t.eq(run.faith_power.points_of(&"skill"), before, "信力不记这一下：切信仰不是置入道具")
	t.eq(run.faith_power.points_of(&"brute"), before_brute, "别的池子也没动")
	# 来回拖十次也不涨 —— 这是 097 发现的刷点路子
	for _i in range(10):
		view.grab_requested.emit(view, skill_anchor.uid, _center(view, skill_anchor.origin) - view.position)
		drag.drop_at(_center(view, skill_anchor.origin))
	t.eq(run.faith_power.points_of(&"skill"), before, "来回拖十次，信力还是 %d" % before)

	# 2 · 取消拖拽：不切
	view.grab_requested.emit(view, brute_anchor.uid, _center(view, brute_anchor.origin) - view.position)
	drag.cancel()
	t.eq(FaithState.active_id(board), &"skill", "取消拖拽不切信仰")
	t.eq(board.get_item(brute_anchor.uid).origin, brute_anchor.origin, "东西回到原位")

	# 3 · 凡物在棋盘内挪位置：置入序号不变
	var sword := _add(board, db.get_def(&"shortsword"))
	if sword != null:
		var seq := sword.placed_seq
		view.grab_requested.emit(view, sword.uid, _center(view, sword.origin) - view.position)
		t.check(drag.drop_at(_center(view, sword.origin)), "凡物原处落下")
		t.eq(board.get_item(sword.uid).placed_seq, seq, "普通道具不盖置入序号")
		t.eq(FaithState.active_id(board), &"skill", "也不动信仰")

	# 4 · 从地上进来：仍然算置入，信力照记（原行为不变）
	var fresh := ItemInstance.create(brute_def, 0)
	run.storage.insert(fresh, -1)
	var pts := run.faith_power.points_of(&"brute")
	t.check(InventoryService.transfer_auto(run.storage, fresh.uid, board), "从地上置入第二件暴力之神的信物")
	t.eq(FaithState.active_id(board), &"brute", "从别的容器进来照旧切信仰")
	var def_brute := run.faith_defs.get(&"brute", null) as FaithDef
	var want := _expected_place_gain(def_brute, brute_def) if def_brute != null else 0
	t.eq(run.faith_power.points_of(&"brute"), pts + want, "信力按行为构件该加 %d 点" % want)


static func run_right_click(t: TestCase) -> void:
	t.begin("099 B · 右键信物 = 奉为主信仰（视图发 item_context、GameFlow.reseat_anchor 落实；凡物右键什么也不发生）")
	var db := _db()
	var run := _start(db)
	if run == null:
		t.check(false, "开不了一局")
		return
	var board := run.board
	var skill_anchor := _add(board, _anchor_of(db, &"skill"))
	var brute_anchor := _add(board, _anchor_of(db, &"brute"))
	if skill_anchor == null or brute_anchor == null:
		t.check(false, "棋盘上放不下两件信物")
		return
	var flow := GameFlow.new(db, run.enemies, run.sets)
	flow.run = run
	t.eq(FaithState.active_id(board), &"brute", "后放的是暴力之神的信物")
	t.check(flow.reseat_anchor(skill_anchor.uid), "奉技巧之神的信物为主信仰")
	t.eq(FaithState.active_id(board), &"skill", "切成技巧之神")
	var sword := _add(board, db.get_def(&"shortsword"))
	if sword != null:
		t.check(not flow.reseat_anchor(sword.uid), "凡物不是信物：切不了")
	t.check(not flow.reseat_anchor(9999), "棋盘上没有这个 uid：false")

	# 视图层：右键按在一件上发 item_context（左键照旧是抓取）
	var view := _view(board)
	var got: Array = []
	view.item_context.connect(func(_v: ContainerView, uid: int): got.append(uid))
	var grabbed: Array = []
	view.grab_requested.connect(func(_v: ContainerView, uid: int, _p: Vector2): grabbed.append(uid))
	var at := _center(view, skill_anchor.origin)
	view._gui_input(_click(at, MOUSE_BUTTON_RIGHT))
	t.eq(got, [skill_anchor.uid], "右键发 item_context")
	t.check(grabbed.is_empty(), "右键不抓东西")
	view._gui_input(_click(at, MOUSE_BUTTON_LEFT))
	t.eq(grabbed, [skill_anchor.uid], "左键照旧请求抓取")


static func _click(at: Vector2, button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = at
	return ev
