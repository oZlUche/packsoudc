## v6.14 切片体验修复（方案 docs/plans/2026-11-13-slice-v614-fixes-and-improvements.md）
## A / B01：背包面板挂在悬浮窗上的「不弹」条件要随面板走 —— 地上那块的窗跨面板常驻，面板释放后不能再调到它
extends RefCounted

const F279 := preload("res://tests/inventory/test_fusion_279.gd")
const InvPanel := preload("res://ui/game/inventory_panel.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _panel(root: Window, s: RunState) -> Control:
	var panel: Control = InvPanel.new()
	panel.setup(s, null)
	root.add_child(panel)
	return panel


static func frame_quiet_lifecycle(t: TestCase, root: Window) -> void:
	t.begin("切片 v6.14 A · 不弹条件：登记不叠、面板走了就撤；共享的地上窗经过多块面板开关、顺序 / 逆序释放后不留条件、不调已释放的面板")
	var s := F279._run()
	var saved := GroundLayer.current()
	var ground := GroundLayer.new()
	ground.stash = s.storage
	root.add_child(ground)
	GroundLayer.set_current(ground)
	var gt := ground.tip
	t.not_null(gt, "地上那块有自己的窗")
	if gt == null:
		ground.free()
		GroundLayer.set_current(saved)
		return
	var a := _panel(root, s)
	t.eq(gt.quiet_count(), 1, "开一块面板：地上的窗挂一条")
	var k1 := F279._put(s.board, s.items, &"knife", Vector2i(0, 0))
	var k2 := F279._put(s.board, s.items, &"knife", Vector2i(3, 0))
	t.check(bool(a.call("ask_fuse", k1.uid, k2.uid)), "开确认窗")
	t.eq(gt.quiet_count(), 1, "开确认窗不再往地上的窗叠条件")
	t.check(gt.is_quiet(ground, k2.uid), "确认窗开着：地上的窗也不弹")
	(a.get("fuse_note") as FuseNote).close()
	var b := _panel(root, s)
	var c := _panel(root, s)
	t.eq(gt.quiet_count(), 3, "三块面板各一条")
	b.free()
	t.eq(gt.quiet_count(), 2, "中间那块走了：撤它那条")
	c.free()
	a.free()
	t.eq(gt.quiet_count(), 0, "逆序走完：一条不剩")
	t.check(not gt.is_quiet(ground, k1.uid), "面板都没了：照常弹，不调已释放的面板")
	for i in 100:
		var p := _panel(root, s)
		if i % 2 == 0:
			p.call("ask_fuse", k1.uid, k2.uid)
		p.free()
	t.eq(gt.quiet_count(), 0, "开关 100 次：条件不随次数增长")
	var stray := Node.new()
	gt.quiet_on(stray, func(_v: ContainerView, _u: int) -> bool: return true)
	gt.quiet_on(stray, func(_v: ContainerView, _u: int) -> bool: return true)
	t.eq(gt.quiet_count(), 1, "同一个登记者再登记：换掉，不叠")
	stray.free()
	t.check(not gt.is_quiet(ground, k1.uid) and gt.quiet_count() == 0, "登记者释放了却没撤：查的时候丢掉那条（报警告），不调它")
	ground.free()
	GroundLayer.set_current(saved)


static func _slice() -> ChapterDef:
	return ContentPaths.load_asset("chapters", "slice_ruins") as ChapterDef


static func _ids(insts: Array) -> Array[String]:
	var out: Array[String] = []
	for inst in insts:
		out.append(String((inst as ItemInstance).def.id))
	out.sort()
	return out


static func run_presets(t: TestCase) -> void:
	t.begin("切片 v6.14 B02 · 切片只列自己的两套预设（只用清单里的东西）；正式章节不列它们；后端拒绝别章的预设和多出来的东西")
	var flow := GameFlow.new(TestSupport.load_content("free_mode").items)
	flow.loadouts = GameFlow.load_loadouts()
	var ch := _slice()
	var sets := flow.presets(ch)
	t.eq(sets.map(func(l: LoadoutDef) -> StringName: return l.id), [&"slice_offense", &"slice_defense"], "切片：强攻、坚守两套切片专用")
	var allowed: Array = SliceAudit.load_manifest("slice_ruins").get("allowed_item_ids", [])
	for l in sets:
		t.check(l.items.all(func(id: StringName) -> bool: return allowed.has(String(id))), "%s 全在清单里" % l.id)
	t.check(flow.presets().all(func(l: LoadoutDef) -> bool: return not l.chapter_only), "不点名的地方不列切片专用的")
	var formal := flow.presets().filter(func(l: LoadoutDef) -> bool: return l.id == &"preset_offense")
	t.check(not formal.is_empty() and flow.start_refusal(ch, [], formal[0]) != "", "正式版强攻在切片：后端拒绝")
	var off := sets[0] as LoadoutDef
	var bags := [{"id": "bag_leather", "origin": [0, 0], "rot": 0}]
	var ok_rows := bags.duplicate()
	for id in off.items:
		ok_rows.append({"id": String(id), "origin": [0, 0], "rot": 0})
	ok_rows.append({"id": "knife", "origin": [0, 0], "rot": 0, RunState.SUPPLY_KEY: true})
	t.eq(flow.start_refusal(ch, ok_rows, off), "", "包 + 强攻 + 补给：放行")
	var extra := ok_rows.duplicate()
	extra.append({"id": "longsword", "origin": [0, 0], "rot": 0})
	t.check(flow.start_refusal(ch, extra, off) != "", "多一把长剑：拒绝")
	var fake_supply := bags.duplicate()
	fake_supply.append({"id": "knife", "origin": [0, 0], "rot": 0, RunState.SUPPLY_KEY: true})
	fake_supply.append({"id": "knife", "origin": [0, 0], "rot": 0, RunState.SUPPLY_KEY: true})
	t.check(flow.start_refusal(ch, fake_supply, null) != "", "补给标多了（章节只发一把匕首）：拒绝")
	t.eq(RunState.supply_left(ch, ok_rows), [&"bandage", &"ration"] as Array[StringName], "摆了匕首：只另发纱布、口粮")
	t.eq(RunState.supply_left(ch, []), ch.starting_items, "什么都没摆：照章全发")


static func run_audit_entries(t: TestCase) -> void:
	t.begin("切片 v6.14 B02 · 审计按开局屏同一份枚举入口（不带 + 两套）；带了清单外的东西查得出来")
	var ch := _slice()
	var labels: Array = SliceAudit.entries(ch).map(func(e: Dictionary) -> String: return String(e["label"]))
	t.eq(labels.size(), 3, "三个入口（%s）" % [labels])
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var m := SliceAudit.load_manifest("slice_ruins")
	var bad := SliceAudit.check_static(m, items, enemies, RecipeDef.load_all(), EventPlacer.load_all(), [&"longsword"])
	t.check(bad.has("开局带的 longsword 不在清单里"), "带长剑：报（%s）" % [bad])
	for e in SliceAudit.entries(ch):
		var kit: Array[StringName] = []
		kit.assign(e["items"])
		t.eq(SliceAudit.check_static(m, items, enemies, RecipeDef.load_all(), EventPlacer.load_all(), kit), [] as Array[String], "%s：没问题" % e["label"])


static func frame_setup_supply(t: TestCase, root: Window) -> void:
	t.begin("切片 v6.14 U02 · 整备页：章节补给摆在棋盘上、只能在棋盘上挪；切预设 A→B→A 不叠；出发后背包和预览一样；仓库位置换成纸条")
	var Setup := preload("res://tests/ui/test_setup_180.gd")
	var game = Setup._game(root, "slice_v614_setup")
	var flow: GameFlow = game.flow
	var setup = game.base()
	var ch := _slice()
	setup._chapters.append(ch)
	setup.choose_chapter(setup._chapters.size() - 1)
	setup.show_page(1)
	var supply: Array[String] = []
	for id in ch.starting_items:
		supply.append(String(id))
	supply.sort()
	t.eq(_ids(setup.supply_items()), supply, "补给三件摆上了棋盘")
	var roster := setup._char_box.find_child("RosterNote", false, false) as Label if setup._char_box != null else null
	t.check(roster != null and roster.text == UiText.t("setup.roster_one"), "选人栏写着试玩只开放这一位")
	t.check(not setup._warehouse_box.visible and setup._no_carry_note.visible, "仓库框藏起、换成纸条")
	var knife: ItemInstance = setup.supply_items()[0]
	t.check(not setup.carry_out(knife.uid), "补给进不了仓库")
	var sets: Array[LoadoutDef] = setup._preset_list()
	t.eq(sets.size(), 2, "两套切片预设")
	setup.choose_preset(0)
	setup.choose_preset(1)
	setup.choose_preset(0)
	var want := supply.duplicate()
	for id in sets[0].items:
		want.append(String(id))
	want.sort()
	var on_board: Array[String] = []
	for inst in setup.board.items():
		if not (inst as ItemInstance).def.is_bag:
			on_board.append(String((inst as ItemInstance).def.id))
	on_board.sort()
	t.eq(on_board, want, "A→B→A：补给 + 强攻，各一份")
	setup.show_page(2)
	setup.set_run_seed(7)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var ids: Array[int] = pv.entry_ids()
	if not ids.is_empty():
		setup.pick_spawn(ids[0])
		setup.close_hint()
	t.check(Support.depart(setup), "出发（%s）" % setup.can_depart())
	if flow.run != null:
		var got: Array[String] = []
		for inst in flow.run.board.items() + flow.run.storage.items():
			if not (inst as ItemInstance).def.is_bag:
				got.append(String((inst as ItemInstance).def.id))
		got.sort()
		t.eq(got, want, "出发后背包 + 地上 = 预览，补给没多发")
	game.queue_free()


static func _drag_rig(board: GridInventory) -> Dictionary:
	var view := InventoryView.new()
	view.inventory = board
	view.size = Vector2(board.size) * InventoryView.CELL
	var drag := DragLayer.new()
	drag.register_view(view)
	drag.stash = ItemStash.new()
	var recipes := RecipeDef.load_all()
	drag.fuse_partner = func(a: ItemInstance, b: ItemInstance) -> bool: return RecipeDef.find(recipes, a.def.id, b.def.id) != null
	var rig := {"view": view, "drag": drag, "asked": [], "said": []}
	drag.fuse_drop = func(held: ItemInstance, _h: ItemContainer, target: ItemInstance, _th: ItemContainer, _g: Rect2) -> void:
		(rig["asked"] as Array).append([held.uid, target.uid])
	drag.fuse_refused.connect(func(text: String) -> void: (rig["said"] as Array).append(text))
	return rig


static func _cell(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * InventoryView.CELL


static func run_multi_overlap(t: TestCase) -> void:
	t.begin("切片 v6.14 U01 · 布卷压着纱布又压着别的：不顶替、弹回、说一句；对准的不是搭档照常顶替；只压纱布照常合成；压两块纱布让对准一件")
	ItemInstance.reset_uid_counter()
	var db := F279._db()
	var board := GridInventory.new(Vector2i(6, 4), 1, false)
	var bolt := F279._put(board, db, &"linen_bolt", Vector2i(0, 3))
	var gauze := F279._put(board, db, &"bandage", Vector2i(1, 0))
	var fish := F279._put(board, db, &"smoked_fish", Vector2i(2, 0))
	var rig := _drag_rig(board)
	var view: InventoryView = rig["view"]
	var drag: DragLayer = rig["drag"]
	view.grab_requested.emit(view, bolt.uid, _cell(Vector2i(0, 3)))
	drag.update_preview(_cell(Vector2i(1, 0)))
	t.check(not view.preview_ok(), "对准纱布、还压着熏鱼：预览红的")
	t.eq(drag.drop_hint, UiText.t("fuse.overlap"), "残影旁写着换一侧")
	t.check(not drag.drop_at(_cell(Vector2i(1, 0))), "松手：不算放下")
	t.check(bolt.origin == Vector2i(0, 3) and gauze.origin == Vector2i(1, 0) and fish.origin == Vector2i(2, 0) and board.items().size() == 3, "三件都在原处，没挤出")
	t.eq((rig["asked"] as Array).size(), 0, "不开确认窗")
	t.eq(rig["said"], [UiText.t("fuse.overlap")], "说一句")
	t.check(not drag.is_dragging(), "手上空了")
	view.grab_requested.emit(view, bolt.uid, _cell(Vector2i(1, 3)))
	drag.update_preview(_cell(Vector2i(2, 0)))
	t.check(view.preview_ok() and drag.drop_hint == "", "对准熏鱼（不是搭档）：照常顶替，绿的")
	t.check(drag.drop_at(_cell(Vector2i(2, 0))) and bolt.origin == Vector2i(1, 0), "放下：布卷进去了")
	t.check(drag.stash.has_item(gauze.uid) and drag.stash.has_item(fish.uid), "两件照旧被顶到地上")
	ItemInstance.reset_uid_counter()
	board = GridInventory.new(Vector2i(6, 4), 1, false)
	bolt = F279._put(board, db, &"linen_bolt", Vector2i(0, 3))
	gauze = F279._put(board, db, &"bandage", Vector2i(1, 0))
	var gauze2 := F279._put(board, db, &"bandage", Vector2i(2, 0))
	rig = _drag_rig(board)
	view = rig["view"]
	drag = rig["drag"]
	view.grab_requested.emit(view, bolt.uid, _cell(Vector2i(0, 3)))
	drag.update_preview(_cell(Vector2i(1, 0)))
	t.eq(drag.drop_hint, UiText.t("fuse.two_partners"), "压两块纱布：让对准一件")
	t.check(not drag.drop_at(_cell(Vector2i(1, 0))) and board.items().size() == 3 and gauze2.origin == Vector2i(2, 0), "不自动挑一件，都不动")
	view.grab_requested.emit(view, bolt.uid, _cell(Vector2i(0, 3)))
	drag.update_preview(_cell(Vector2i(2, 0)))
	t.check(view.preview_ok(), "只压一块（布卷伸向右边空处）：绿的")
	t.check(not drag.drop_at(_cell(Vector2i(2, 0))) and (rig["asked"] as Array).size() == 1, "松手：开确认窗")
	view.free()
	drag.free()


static func _hint_run(on: bool) -> RunState:
	var s := F279._run()
	s.chapter = s.chapter.duplicate() as ChapterDef
	s.chapter.fuse_hint = on
	return s


static func frame_first_fuse_hint(t: TestCase, root: Window) -> void:
	t.begin("切片 v6.14 C · 第一次能合成：标出两件、说一句，只说一次；没搭档、手上拿着、认过配方、别的章节都不说；真合成了才记合过")
	var s := _hint_run(true)
	var k1 := F279._put(s.board, s.items, &"knife", Vector2i(0, 0))
	var fish := F279._put(s.board, s.items, &"smoked_fish", Vector2i(4, 0))
	var a := _panel(root, s)
	t.check(not bool(a.call("_try_fuse_hint")), "只有一把匕首和熏鱼：不说")
	t.eq(s.meta.flag(a.FLAG_FUSE_HINT), 0, "也不记说过")
	var k2 := F279._put(s.board, s.items, &"knife", Vector2i(2, 0))
	var drag: DragLayer = a.call("drag_layer")
	var view: InventoryView = a.get("board_view")
	view.grab_requested.emit(view, fish.uid, Vector2.ONE * view.cell_px * 0.5 + view.cell_origin_px(Vector2i(4, 0)))
	t.check(drag.is_dragging() and not bool(a.call("_try_fuse_hint")), "手上拿着东西：先不说")
	drag.cancel()
	t.eq(a.call("fuse_hint_pair"), [k1, k2], "找到两把匕首")
	t.check(bool(a.call("_try_fuse_hint")), "放下了：说")
	t.eq(a.get("last_hint"), UiText.t("fuse.first_hint"), "说的是怎么合")
	t.check(view.fuse_marks.has(k1.uid) and view.fuse_marks.has(k2.uid) and not view.fuse_marks.has(fish.uid), "两把标小锤，熏鱼不标")
	t.eq(s.meta.flag(a.FLAG_FUSE_HINT), 1, "记说过")
	t.eq(s.meta.flag(a.FLAG_FUSE_DONE), 0, "只是说过，不算合过")
	t.check(not bool(a.call("_try_fuse_hint")), "再来一次：不说")
	var b := _panel(root, s)
	t.check(not bool(b.call("_try_fuse_hint")), "另一块面板：也不说")
	t.check(bool(CraftingModule.of(s).fuse(k1.uid, k2.uid)["ok"]), "合成双刀")
	t.eq(s.meta.flag(a.FLAG_FUSE_DONE), 1, "真合成了：记合过")
	a.free()
	b.free()

	s = _hint_run(true)
	F279._put(s.board, s.items, &"knife", Vector2i(0, 0))
	var loose := ItemInstance.create(s.items.get_def(&"knife"))
	s.storage.insert(loose)
	var saved := GroundLayer.current()
	var ground := GroundLayer.new()
	ground.stash = s.storage
	root.add_child(ground)
	GroundLayer.set_current(ground)
	var c := _panel(root, s)
	t.check(bool(c.call("_try_fuse_hint")) and ground.fuse_marks.has(loose.uid), "一把在棋盘、一把在地上：说，地上那把标小锤")
	c.free()
	ground.free()
	GroundLayer.set_current(saved)

	s = _hint_run(true)
	s.meta.lore.recipes["twin_blades"] = true
	F279._put(s.board, s.items, &"knife", Vector2i(0, 0))
	F279._put(s.board, s.items, &"knife", Vector2i(2, 0))
	var d := _panel(root, s)
	t.check(not bool(d.call("_try_fuse_hint")), "认过配方的人：不说")
	d.free()

	s = _hint_run(false)
	F279._put(s.board, s.items, &"knife", Vector2i(0, 0))
	F279._put(s.board, s.items, &"knife", Vector2i(2, 0))
	var e := _panel(root, s)
	t.check(not bool(e.call("_try_fuse_hint")), "章节没开：不说")
	e.free()

	s = _hint_run(true)
	F279._put(s.board, s.items, &"knife", Vector2i(0, 0))
	F279._put(s.board, s.items, &"knife", Vector2i(2, 0))
	var f := _panel(root, s)
	f.set("fuse_filter", func(_i: ItemInstance) -> bool: return false)
	t.check(not bool(f.call("_try_fuse_hint")), "这一屏不许合（商店的货）：不说")
	f.free()
	t.check(_slice().fuse_hint, "切片开着")


static func run_route_and_events(t: TestCase) -> void:
	t.begin("切片 v6.14 D · 补衣人在切片里只留做得到的交易（正式版原样）；审计查得出要不到的选项；看全图走改键表，切片地图教程写着现在的键")
	var weaver := ContentPaths.load_asset("events", "event_refugee_weaver") as EventDef
	var mine := ContentPaths.load_asset("events", "event_refugee_weaver_slice") as EventDef
	var needs := func(ev: EventDef) -> Array:
		var out: Array = []
		for o in ev.options:
			for c in (o as EventOption).requires:
				if "item" in c:
					out.append(String(c.get("item")))
		return out
	t.eq(needs.call(weaver), ["tanned_leather", "linen_bolt"], "正式版补衣人：皮子、布都收")
	t.eq(needs.call(mine), ["linen_bolt"], "切片补衣人：只收布")
	t.eq(mine.options.size(), 2, "交出布卷、保留材料")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/slice_ruins.json"))
	var evs: Array = []
	for n in d["nodes"]:
		if (n["content"] as Dictionary).has("event"):
			evs.append(String(n["content"]["event"]))
	t.check(evs.has("event_refugee_weaver_slice") and not evs.has("event_refugee_weaver"), "切片地图用切片那份")
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var m := SliceAudit.load_manifest("slice_ruins")
	var events := EventPlacer.load_all()
	events[&"event_refugee_weaver_slice"] = weaver
	var bad := SliceAudit.check_static(m, items, enemies, RecipeDef.load_all(), events)
	t.check(bad.any(func(l: String) -> bool: return l.contains("tanned_leather")), "换回正式版那份：审计报熟皮革拿不到（%s）" % [bad])
	InputKeys.apply(null)
	t.check(InputKeys.ACTIONS.has(InputKeys.MAP_FIT) and InputKeys.keys_of(InputKeys.MAP_FIT) == ([KEY_F] as Array[Key]), "看全图默认 F，能改键")
	var steps := CoachOverlay.load_steps(&"slice_map")
	var last := CoachOverlay.text_of(steps[steps.size() - 1]) if not steps.is_empty() else ""
	t.check(last.contains(OS.get_keycode_string(KEY_F)) and not last.contains("[key="), "地图教程写着现在的键（%s）" % last)
