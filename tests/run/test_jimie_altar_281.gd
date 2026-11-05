## 281 寂灭的路（三）：没信仰、背包里全黑法杖 + 四颗元素之核 → 休息点神坛「献祭」；法杖与核消失、寂灭落在法杖的格子上；
## 【魔法之神的残余意识】说完当场结算回基地；结算屏第二页放黑洞（代码占位）
extends RefCounted

const Camp := preload("res://ui/game/rest_camp_screen.gd")


static func _run(runs := 50, cores := 4) -> RunState:
	var c := TestSupport.load_content("free_mode", ["buffs"])
	var layout := [{"id": "war_pack", "origin": [0, 0], "rot": 0}, {"id": "magic_staff", "origin": [0, 0], "rot": 0, "state": {ItemInstance.RUNS_KEY: runs}}]
	var at := [[1, 0], [2, 0], [3, 0], [1, 1]]
	var els: Array = JimiePath.CORES.keys()
	for i in cores:
		layout.append({"id": String(JimiePath.CORES[els[i]]), "origin": at[i], "rot": 0})
	var run := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs, [] as Array[StringName], null, layout)
	run.meta = MetaState.new()
	run.event_defs = EventPlacer.load_all()
	return run


static func _count(run: RunState, id: StringName) -> int:
	return run.board.items().filter(func(i: ItemInstance) -> bool: return i.def.id == id).size()


static func run_ready(t: TestCase) -> void:
	t.begin("281 · 献祭备齐：全黑法杖 + 四颗元素之核在背包里、寂灭哪儿都没有；少一样都不行")
	var run := _run()
	t.eq(run.board.items().size(), 6, "包 + 法杖 + 四颗核都摆上了")
	t.check(JimiePath.sacrifice_ready(run.board, run.meta), "备齐了")
	t.check(not JimiePath.sacrifice_ready(_run(49).board, run.meta), "49 次的法杖：不行")
	t.check(not JimiePath.sacrifice_ready(_run(50, 3).board, run.meta), "只有三颗核：不行")
	var owned := MetaState.new()
	owned.warehouse.try_add(ItemInstance.create(run.items.get_def(JimiePath.RED)), true)
	t.check(not JimiePath.sacrifice_ready(run.board, owned), "仓库里已经有寂灭：不行")


static func run_sacrifice(t: TestCase) -> void:
	t.begin("281 · 献祭：法杖与四颗核消失，寂灭落在法杖的格子上")
	var run := _run()
	var staff: ItemInstance = run.board.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"magic_staff")[0]
	var at := staff.origin
	t.check(JimiePath.sacrifice(run.board, run.storage, run.items), "献了")
	t.eq(_count(run, &"magic_staff"), 0, "法杖没了")
	for el in JimiePath.CORES:
		t.eq(_count(run, JimiePath.CORES[el]), 0, "%s之核没了" % el)
	var reds: Array = run.board.items().filter(func(i: ItemInstance) -> bool: return i.def.id == JimiePath.RED)
	t.eq(reds.size(), 1, "寂灭来了")
	if not reds.is_empty():
		t.eq((reds[0] as ItemInstance).origin, at, "在法杖原来的格子上")
	t.check(not JimiePath.sacrifice(run.board, run.storage, run.items), "再献一次：没东西可献")


static func run_flow(t: TestCase) -> void:
	t.begin("281 · 休息点：没信仰才有「献祭」；选了接【魔法之神的残余意识】，说完这一局按撤离结算（原因 jimie）")
	var run := _run()
	var rest: EventDef = run.event_defs.get(&"rest_default", null)
	t.not_null(rest, "有默认休息事件")
	if rest == null:
		return
	var at := -1
	for i in rest.options.size():
		if (rest.options[i] as EventOption).outcomes.any(func(o): return o is JimieSacrifice):
			at = i
	t.check(at >= 0, "休息事件里有献祭")
	if at < 0:
		return
	t.eq(Camp.piece_of(rest.options[at] as EventOption), &"altar", "营地里画在神坛上")
	t.check((rest.options[at] as EventOption).hide_when_locked, "不够就藏")
	var node: MapNode = null
	for id in run.map.node_ids():
		if run.map.get_node(id).type == &"rest":
			node = run.map.get_node(id)
			break
	t.not_null(node, "图上有休息点")
	if node == null:
		return
	run.events.set_pending(node, rest, &"rest")
	t.check(bool(run.events.option_state(at)["ok"]), "备齐了：能选")
	var bare := _run(50, 3)
	bare.events.set_pending(bare.map.get_node(node.id), rest, &"rest")
	t.check(not bool(bare.events.option_state(at)["ok"]), "少一颗核：不能选")
	t.check(run.events.choose(at), "选献祭")
	t.eq(_count(run, JimiePath.RED), 1, "寂灭在背包里")
	var god := run.events.pending_event()
	t.check(god != null and god.id == JimiePath.GOD_EVENT, "接着是魔法之神的残余意识")
	if god == null:
		return
	t.eq(god.text, "", "正文空着给作者")
	t.check(run.events.choose(0), "说完了")
	t.check(run.is_over() and run.phase == RunState.Phase.EXTRACTED, "撤离结算")
	t.eq(run.end_reason, JimiePath.REASON, "原因：寂灭")


static func frame_black_hole(t: TestCase, root: Window) -> void:
	t.begin("281 · 黑洞（B 劈开）：盖在寂灭那件上，比它大一圈；找不到那件就不放；演完交回棋盘")
	var db := ItemDatabase.new()
	db.load_dir()
	var board := GridInventory.new(Vector2i(3, 3))
	var red := ItemInstance.create(db.get_def(JimiePath.RED))
	board.place(red, Vector2i(1, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	root.add_child(view)
	var hole := JimieBlackHole.cover(view, red.uid)
	t.not_null(hole, "放了")
	if hole != null:
		var rect := view.item_rect(red.uid)
		t.check(Rect2(hole.position, hole.size).encloses(rect), "罩住寂灭")
	t.eq(JimieBlackHole.cover(view, 999), null, "找不到：不放")
	if hole != null:
		t.check(view.veiled.has(red.uid), "演着：棋盘上那件先不画（黑洞自己画）")
		t.eq(hole.grow(), 0.0, "刚开始：洞还没张开")
		hole.t = 0.45
		t.check(hole.grow() == 1.0 and hole.rise() > 0.0 and hole.rise() < 1.0 and hole.tear() == 0.0, "0.45：洞张满、寂灭升到一半、还没劈")
		t.eq(hole._mask.clip_children, CanvasItem.CLIP_CHILDREN_ONLY, "升起时法杖裁在洞里")
		hole.t = 0.65
		t.check(hole.crack() > 0.0 and hole.tear() == 0.0, "0.65：洞面裂纹")
		hole.t = 0.85
		t.check(hole.tear() > 0.0 and hole._mask.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED, "0.85：劈开，法杖整根露出")
		t.check(JimieBlackHole.SEC <= 2.0, "全程不超过 2 s")
		hole.t = 0.0
		var tw := hole.play()
		tw.custom_step(JimieBlackHole.SEC + 0.1)
		t.check(not view.veiled.has(red.uid) and hole.is_queued_for_deletion(), "演完：那件交回棋盘画，黑洞自己摘掉")
	view.free()
