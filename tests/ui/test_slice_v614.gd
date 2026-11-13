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
