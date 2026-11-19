## 099 → 信仰重构 A（2026-11-19）：在背包里改信只有一条路 —— 信物说明窗的「奉为主信仰」（[method RunState.select_faith]）。
## 棋盘内把信物重新落下、取消拖拽、从地上拿进来**都不改信**；普通道具在棋盘内挪位置不盖置入序号（来回拖不刷信力）；
## 从别的容器进来仍然算置入，信力照记给**有效信仰**。期望从数据推：信力该加几点问行为构件自己。
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
	for seed_ in range(1, 60):
		var s := RunState.start(chapter, seed_, items, enemies, sets, [] as Array[StringName], {}, [] as Array[StringName], chars[0] if not chars.is_empty() else null)
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
	return TestSupport.put(board, def) if def != null else null


## 行为构件说这一次置入该给几点
static func _expected_place_gain(def: FaithDef, item: ItemDef) -> int:
	var n := 0
	for d in def.deeds:
		n += maxi(0, (d as FaithDeed).gain(&"place_item", {"value": ItemValue.of(item), "id": String(item.id)}))
	return n


static func run_reseat_rules(t: TestCase) -> void:
	t.begin("信仰重构 A · reseat 只盖置入序号（晶石装载还读它）、不发 placed、不改信")
	var db := _db()
	var board := GridInventory.new(Vector2i(8, 6), 1, false)
	board.select_faith(&"faith:brute")
	var shield := TestSupport.put(board, db.get_def(&"blessed_shield"))     # skill 的信物
	var sigil := TestSupport.put(board, db.get_def(&"charm_brute"))      # brute 的信物
	t.check(shield != null and sigil != null, "放赐福的盾、再放蛮神的护符")
	if shield == null or sigil == null:
		return
	var shield_at := shield.origin
	t.eq(FaithState.active_id(board), &"brute", "选的是蛮神")
	var placed_times := [0]
	board.placed.connect(func(_i: ItemInstance): placed_times[0] += 1)
	var changed_times := [0]
	board.changed.connect(func(): changed_times[0] += 1)
	var seq := shield.placed_seq
	t.check(board.reseat(shield.uid), "reseat 盾")
	t.check(shield.placed_seq > seq, "序号盖新了")
	t.eq(FaithState.active_id(board), &"brute", "不改信：还是蛮神")
	t.eq(placed_times[0], 0, "reseat 不发 placed")
	t.eq(changed_times[0], 1, "发 changed")
	t.eq(board.get_item(shield.uid).origin, shield_at, "格子一点没动")
	board.select_faith(&"faith:skill")
	t.eq(FaithState.active_id(board), &"skill", "显式选择才改信")
	t.eq(changed_times[0], 2, "改信发 changed（界面、套装重算）")
	board.select_faith(&"faith:skill")
	t.eq(changed_times[0], 2, "选同一个不再发")
	t.check(not board.reseat(9999), "不在这个容器里的 uid：false")


static func run_drag_board_reseat(t: TestCase) -> void:
	t.begin("信仰重构 A · 棋盘内落下信物不改信、信力不记；取消不改；凡物在棋盘内挪不盖序号；从地上进来不改信、信力记给有效信仰")
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
	t.eq(run.active_faith_id(), &"", "放了两件信物：不奉神")
	t.eq(run.select_faith(&"brute"), "", "奉蛮神")

	var view := _view(board)
	var drag := DragLayer.new()
	drag.stash = run.storage
	drag.register_view(view)

	# 1 · 棋盘内把技巧之神的信物重新落下：不改信，信力一点不加
	var before := run.faith_power.points_of(&"skill")
	var before_brute := run.faith_power.points_of(&"brute")
	var home := skill_anchor.origin
	view.grab_requested.emit(view, skill_anchor.uid, _center(view, home) - view.position)
	t.check(drag.is_dragging(), "抓起了技巧之神的信物")
	t.check(drag.drop_at(_center(view, home)), "在棋盘上原处落下")
	t.eq(run.active_faith_id(), &"brute", "落下不改信（099 的旧规则取消）")
	t.eq(run.faith_power.points_of(&"skill"), before, "技巧之神的信力不记")
	t.eq(run.faith_power.points_of(&"brute"), before_brute, "蛮神的也没动（同容器挪位不是置入）")
	for _i in range(10):
		view.grab_requested.emit(view, skill_anchor.uid, _center(view, skill_anchor.origin) - view.position)
		drag.drop_at(_center(view, skill_anchor.origin))
	t.eq(run.faith_power.points_of(&"brute"), before_brute, "来回拖十次，信力还是 %d" % before_brute)

	# 2 · 取消拖拽：不改
	view.grab_requested.emit(view, brute_anchor.uid, _center(view, brute_anchor.origin) - view.position)
	drag.cancel()
	t.eq(run.active_faith_id(), &"brute", "取消拖拽不改信")
	t.eq(board.get_item(brute_anchor.uid).origin, brute_anchor.origin, "东西回到原位")

	# 3 · 凡物在棋盘内挪位置：置入序号不变
	var sword := _add(board, db.get_def(&"shortsword"))
	if sword != null:
		var seq := sword.placed_seq
		view.grab_requested.emit(view, sword.uid, _center(view, sword.origin) - view.position)
		t.check(drag.drop_at(_center(view, sword.origin)), "凡物原处落下")
		t.eq(board.get_item(sword.uid).placed_seq, seq, "普通道具不盖置入序号")
		t.eq(run.active_faith_id(), &"brute", "也不动信仰")

	# 4 · 改奉技巧之神，再从地上拿进来蛮神的信物：不改信；置入信力记给有效信仰（技巧之神）
	t.eq(run.select_faith(&"skill"), "", "改奉技巧之神")
	var fresh := ItemInstance.create(brute_def, 0)
	run.storage.insert(fresh, -1)
	var pts := run.faith_power.points_of(&"skill")
	var pts_brute := run.faith_power.points_of(&"brute")
	t.check(InventoryService.transfer_auto(run.storage, fresh.uid, board), "从地上置入第二件蛮神的信物")
	t.eq(run.active_faith_id(), &"skill", "从别的容器进来也不改信")
	var def_skill := run.faith_defs.get(&"skill", null) as FaithDef
	var want := _expected_place_gain(def_skill, brute_def) if def_skill != null else 0
	t.eq(run.faith_power.points_of(&"skill"), pts + want, "置入的信力按技巧之神的行为构件记 %d 点" % want)
	t.eq(run.faith_power.points_of(&"brute"), pts_brute, "蛮神不奉，不记")


static func run_right_click(t: TestCase) -> void:
	t.begin("信仰重构 A · 奉为主信仰：说明窗按钮走 RunState.select_faith；主信仰的键是「不再奉神」；不在棋盘的信物灰着；视图右键发 item_context")
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
	var picked: Array = []
	var pick := func(fid: StringName) -> void:
		picked.append(fid)
		run.select_faith(fid)
	var a := ItemActions.anchor(skill_anchor, board, pick)
	t.eq(a.label, UiText.t("act.anchor"), "没奉神：「奉为主信仰」")
	t.check(a.enabled, "能点")
	a.run.call()
	t.eq(picked, [&"skill"] as Array[StringName], "按钮交出的是神 id")
	t.eq(run.active_faith_id(), &"skill", "奉了技巧之神")
	var again := ItemActions.anchor(skill_anchor, board, pick)
	t.eq(again.label, UiText.t("act.anchor_drop"), "已经奉了：键变成「不再奉神」")
	again.run.call()
	t.eq(run.active_faith_id(), &"", "不再奉神")
	t.eq(run.selected_faith, &"", "选择清空")
	var locked := ItemActions.anchor(brute_anchor, board, pick, UiText.t("act.faith_locked"))
	t.check(not locked.enabled, "此刻不能改信：灰着")
	var stray := ItemInstance.create(_anchor_of(db, &"brute"), 0)
	run.storage.insert(stray, -1)
	t.check(not ItemActions.anchor(stray, board, pick).enabled, "地上的信物：灰着（得先放进棋盘）")
	t.eq(run.select_faith(&"brute"), "", "奉蛮神")
	t.check(InventoryService.transfer_auto(board, brute_anchor.uid, run.storage), "蛮神护符挪到地上")
	t.eq(run.faith_connection(), FaithState.MISSING, "联系中断")
	t.eq(run.active_faith_id(), &"", "有效信仰为空，没有回退到技巧之神")
	t.check(run.faith_context().is_broken(), "快照：联系中断")

	# 视图层：右键按在一件上发 item_context（左键照旧是抓取）
	var view := _view(board)
	var got: Array = []
	view.item_context.connect(func(_v: ContainerView, uid: int): got.append(uid))
	var grabbed: Array = []
	view.grab_requested.connect(func(_v: ContainerView, uid: int, _p: Vector2): grabbed.append(uid))
	var at := _center(view, TestSupport.a_cell_of(skill_anchor))     # 原点格不一定被占（不规则形状）
	view._gui_input(_click(at, MOUSE_BUTTON_RIGHT))
	t.eq(got, [skill_anchor.uid], "右键发 item_context")
	t.check(grabbed.is_empty(), "右键不抓东西")
	view._gui_input(_click(at, MOUSE_BUTTON_LEFT))
	t.eq(grabbed, [skill_anchor.uid], "左键照旧请求抓取")


static func _click(at: Vector2, button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button as MouseButton
	ev.pressed = true
	ev.position = at
	return ev
