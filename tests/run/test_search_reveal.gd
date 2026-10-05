## 搜索揭示重做（058 第 5 条，报告 068）：一件一件搜、耗时随稀有度、当前锁住、下一件随挪动变、没亮的只能在容器里挪。
## 期望从数据推：每件的秒数 = 规则表里它稀有度那一档。
extends RefCounted

const CELL := InventoryView.CELL


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _view(inv: GridInventory, at: Vector2) -> LootView:
	var v := LootView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


static func _plain_view(inv: GridInventory, at: Vector2) -> InventoryView:
	var v := InventoryView.new()
	v.inventory = inv
	v.position = at
	v.size = Vector2(inv.size) * CELL
	return v


static func _center(view: InventoryView, cell: Vector2i) -> Vector2:
	return view.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


static func _seconds(view: LootView, uid: int) -> float:
	var inst := view.inventory.get_item(uid)
	return view.reveal_seconds[clampi(inst.def.rarity, 0, view.reveal_seconds.size() - 1)]


static func run_rules(t: TestCase) -> void:
	t.begin("揭示耗时 · 是节点规则里的数：按稀有度取、超表按最后一档、导入器校验非递减且非负、作者文件是不动点")
	var rules := SearchRules.new()
	t.eq(rules.reveal_seconds, LootView.DEFAULT_SECONDS, "规则与视图的默认表一致")
	rules.reveal_seconds = [0.3, 0.5, 2.0] as Array[float]
	t.eq(rules.reveal_time(0), 0.3, "稀有度 0")
	t.eq(rules.reveal_time(2), 2.0, "稀有度 2")
	t.eq(rules.reveal_time(9), 2.0, "超出表长按最后一档")
	t.eq(rules.reveal_time(-1), 0.3, "负的按第一档")

	var raw = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file("node_rules", "standard")))
	t.check(raw is Dictionary, "读得到 standard 节点规则")
	var base := raw as Dictionary
	# 导出器对数组一律写出（遭遇曲线、权重表也是），作者文件里就是默认表；没写这个键的旧文件导进来也是默认
	t.eq((base.get("search", {}) as Dictionary).get("reveal_seconds", []), LootView.DEFAULT_SECONDS, "作者文件里是默认表（归一化写出来的）")
	var old: Dictionary = base.duplicate(true)
	(old["search"] as Dictionary).erase("reveal_seconds")
	var legacy := ContentImporter.import_node_rules(old, ContentImporter.Context.new(), ImportReport.new())
	t.eq(legacy.search.reveal_seconds, LootView.DEFAULT_SECONDS, "没写这个键的旧文件导进来是默认表")
	var ok := ImportReport.new()
	var imported := ContentImporter.import_node_rules(base, ContentImporter.Context.new(), ok)
	t.check(ok.ok(), "standard 导入没有错：%s" % ok.to_text())
	t.eq(imported.search.reveal_seconds, LootView.DEFAULT_SECONDS, "standard 的表 = 默认表")

	for bad_case in [[0.3, 0.2], [-1.0], []]:
		var d: Dictionary = base.duplicate(true)
		(d["search"] as Dictionary)["reveal_seconds"] = bad_case
		var r := ImportReport.new()
		ContentImporter.import_node_rules(d, ContentImporter.Context.new(), r)
		t.check(not r.ok(), "reveal_seconds = %s 报错" % str(bad_case))
	var good: Dictionary = base.duplicate(true)
	(good["search"] as Dictionary)["reveal_seconds"] = [0.1, 0.1, 0.9]
	var r2 := ImportReport.new()
	var res := ContentImporter.import_node_rules(good, ContentImporter.Context.new(), r2)
	t.check(r2.ok(), "非递减的表合法")
	var again := ContentExporter.export_node_rules(res)
	t.eq((again["search"] as Dictionary).get("reveal_seconds", []), [0.1, 0.1, 0.9], "非默认的表写进 JSON")


static func frame_run_timeline(t: TestCase, root: Window) -> void:
	t.begin("揭示 · 一件一件来：当前按稀有度计时，到点亮出来、换下一件；一次推进能跨好几件；快速搜索全亮")
	var db := _items()
	var box := LootPacker.board_of([&"pistol", &"knife", &"armor"] as Array[StringName], Vector2i(6, 4), db)
	var view := _view(box, Vector2.ZERO)
	root.add_child(view)
	view.reveal_seconds = [1.0, 2.0, 3.0, 4.0, 5.0] as Array[float]
	var revealed: Array = []
	view.item_revealed.connect(func(uid: int): revealed.append(uid))
	var finished: Array = []
	view.reveal_finished.connect(func(): finished.append(true))

	t.eq(view.current_uid(), GridInventory.EMPTY_UID, "没开始就没有当前")
	t.eq(view.progress(), 0.0, "进度 0")
	view.start_reveal()
	var order := view._unrevealed_in_slot_order()
	t.eq(view.current_uid(), order[0], "当前 = 栏位顺序第一件")
	t.eq(view.next_uid(), order[1], "下一件 = 第二件")
	var need := _seconds(view, order[0])
	t.eq(view.current_seconds(), need, "当前这件要的秒数 = 它稀有度那一档（%.1f）" % need)
	view.advance(need * 0.5)
	t.check(absf(view.progress() - 0.5) < 1e-6, "推进一半：进度 0.5")
	t.eq(revealed.size(), 0, "还没亮")
	t.eq(view.current_uid(), order[0], "当前没换")
	view.advance(need * 0.5)
	t.eq(revealed, [order[0]], "到点：第一件亮了")
	t.eq(view.current_uid(), order[1], "换到第二件")
	t.check(view.progress() < 1e-6, "新的一件从 0 开始")
	t.eq(view.next_uid(), order[2], "下一件 = 第三件")
	# 一次推进跨过两件：第二件的全部 + 第三件的全部 + 多余
	view.advance(_seconds(view, order[1]) + _seconds(view, order[2]) + 0.5)
	t.eq(revealed, order, "三件都亮了，顺序是栏位顺序")
	t.eq(finished.size(), 1, "发了一次 reveal_finished")
	t.check(not view.is_revealing(), "搜完了")
	t.eq(view.unrevealed_count(), 0, "没有没亮的")

	# 快速搜索
	var box2 := LootPacker.board_of([&"pistol", &"knife", &"armor"] as Array[StringName], Vector2i(6, 4), db)
	var view2 := _view(box2, Vector2.ZERO)
	root.add_child(view2)
	var fin2: Array = []
	view2.reveal_finished.connect(func(): fin2.append(true))
	view2.start_reveal()
	view2.advance(0.01)
	view2.skip()
	t.eq(view2.unrevealed_count(), 0, "快速搜索：全亮")
	t.eq(fin2.size(), 1, "发了一次 reveal_finished")
	t.check(not view2.is_revealing(), "不再在搜")
	view2.skip()
	t.eq(fin2.size(), 1, "全亮之后再按不重复发")

	# 耗时和体积无关：同稀有度的两件秒数相同（从数据里找两件同稀有度不同格数的）
	var by_rarity := {}
	for id in db.ids():
		var def := db.get_def(id)
		if def.is_bag or def.shape == null:
			continue
		if not by_rarity.has(def.rarity):
			by_rarity[def.rarity] = []
		(by_rarity[def.rarity] as Array).append(def)
	var checked := false
	for rarity in by_rarity:
		var defs: Array = by_rarity[rarity]
		for i in defs.size():
			for j in defs.size():
				if i < j and (defs[i] as ItemDef).shape.cell_count() != (defs[j] as ItemDef).shape.cell_count():
					var v3 := LootView.new()
					v3.reveal_seconds = view.reveal_seconds
					t.eq(v3._seconds_for(ItemInstance.create(defs[i], 0)), v3._seconds_for(ItemInstance.create(defs[j], 0)),
						"%s 与 %s 同稀有度、格数不同、秒数相同" % [(defs[i] as ItemDef).id, (defs[j] as ItemDef).id])
					checked = true
					break
			if checked:
				break
		if checked:
			break
	t.check(checked, "数据里找得到同稀有度不同格数的两件")
	view.queue_free()
	view2.queue_free()


static func frame_run_move_changes_next(t: TestCase, root: Window) -> void:
	t.begin("揭示 · 挪没亮的东西会换「下一件」；正在搜的不受影响")
	var db := _items()
	var box := LootPacker.board_of([&"pistol", &"knife", &"armor"] as Array[StringName], Vector2i(6, 4), db)
	var view := _view(box, Vector2.ZERO)
	root.add_child(view)
	view.start_reveal()
	var order := view._unrevealed_in_slot_order()
	var current := order[0]
	var second := order[1]
	var third := order[2]
	t.eq(view.next_uid(), second, "下一件是第二件")
	# 把第二件挪到最后一行的右下角：栏位顺序里它就排到第三件后面
	var inst := box.remove(second)
	t.not_null(inst, "第二件摘下来了")
	var placed := false
	for y in range(box.size.y - 1, -1, -1):
		for x in range(box.size.x - 1, -1, -1):
			if not placed and box.place(inst, Vector2i(x, y), 0):
				placed = true
	t.check(placed, "放到了靠后的格子")
	t.eq(view.next_uid(), third, "下一件换成了第三件")
	t.eq(view.current_uid(), current, "正在搜的没变")
	t.eq(view.progress(), 0.0, "进度也没变")
	view.advance(_seconds(view, current))
	t.eq(view.current_uid(), third, "搜完当前，接着搜的是挪动后排前面的那件")
	view.queue_free()


static func frame_run_drop_filter(t: TestCase, root: Window) -> void:
	t.begin("揭示 · 没亮的能抓、只能放回容器；亮了才能拖出去；拖拽层的第二道门")
	var db := _items()
	var box := LootPacker.board_of([&"pistol", &"knife", &"armor"] as Array[StringName], Vector2i(6, 4), db)
	var board := GridInventory.new(Vector2i(6, 4), 77, false)
	var view := _view(box, Vector2.ZERO)
	var board_view := _plain_view(board, Vector2(600, 0))
	root.add_child(view)
	root.add_child(board_view)
	var drag := DragLayer.new()
	root.add_child(drag)
	drag.register_view(view)
	drag.register_view(board_view)
	drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		return view.is_revealed(inst.uid) or target == box

	view.start_reveal()
	var order := view._unrevealed_in_slot_order()
	var second := order[1]
	var inst := box.get_item(second)
	var grab_at := view.cell_origin_px(inst.origin) + Vector2(CELL, CELL) * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = grab_at
	view._gui_input(press)
	t.check(drag.is_dragging(), "没亮的（不是正在搜的）抓起来了")
	t.eq(box.item_count(), 2, "抓起来就离开了容器")
	# 放到棋盘：不许
	drag.update_preview(_center(board_view, Vector2i(0, 0)))
	t.check(not board_view._preview_on, "预览：那儿不许放，不画落点")
	t.check(not drag.drop_at(_center(board_view, Vector2i(0, 0))), "放到棋盘上放不下去")
	t.eq(board.item_count(), 0, "棋盘上没有它")
	t.check(box.has_item(second), "退回了容器")
	t.eq(box.item_count(), 3, "容器还是三件")
	# 放回容器别的地方：许
	view._gui_input(press)
	t.check(drag.is_dragging(), "再抓")
	var target := Vector2i(-1, -1)
	for y in box.size.y:
		for x in box.size.x:
			if target.x < 0 and box.can_place_item(inst, Vector2i(x, y), inst.rotation) and Vector2i(x, y) != inst.origin:
				target = Vector2i(x, y)
	t.check(target.x >= 0, "容器里有别的空位")
	var drop_pos := _center(view, target) + Vector2.ZERO
	t.check(drag.drop_at(drop_pos - Vector2(0.5, 0.5) * CELL + Vector2(0.5, 0.5) * CELL), "放回容器里的空位放得下")
	t.check(box.has_item(second), "还在容器里")
	# 正在搜的抓不起来
	var current := view.current_uid()
	var cur := box.get_item(current)
	var press2 := InputEventMouseButton.new()
	press2.button_index = MOUSE_BUTTON_LEFT
	press2.pressed = true
	press2.position = view.cell_origin_px(cur.origin) + Vector2(CELL, CELL) * 0.5
	view._gui_input(press2)
	t.check(not drag.is_dragging(), "正在搜的那件锁住")
	# 亮了就能拖出去
	view.skip()
	view._gui_input(press2)
	t.check(drag.is_dragging(), "亮了能抓")
	t.check(drag.drop_at(_center(board_view, Vector2i(0, 0))), "亮了能放到棋盘上")
	t.eq(board.item_count(), 1, "棋盘上有它了")
	view.queue_free()
	board_view.queue_free()
	drag.queue_free()


static func frame_run_container_screen(t: TestCase, root: Window) -> void:
	t.begin("容器屏 · 耗时表从节点规则来、拖拽层装了第二道门、读数写着正在搜")
	var db := _items()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var f := GameFlow.new(db, enemies, sets, MetaState.new())
	f.chapters = [chapter] as Array[ChapterDef]
	var run: RunState = null
	var seed := 1
	while run == null and seed < 30:
		run = RunState.start(chapter, seed, db, enemies, sets, [&"bag_leather", &"pistol"] as Array[StringName])
		seed += 1
	t.not_null(run, "开得了局")
	if run == null:
		return
	f.run = run
	var box := LootPacker.board_of([&"pistol", &"knife", &"armor"] as Array[StringName], Vector2i(6, 4), db)
	var screen = load("res://ui/game/container_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.LOOT
	root.add_child(screen)
	screen.open({"container": box})
	var view: LootView = screen.loot_view()
	t.eq(view.reveal_seconds, run.node_rules.search.reveal_seconds, "耗时表 = 这一局节点规则里的")
	t.check(screen._drag.drop_filter.is_valid(), "拖拽层装了第二道门")
	t.check(view.is_revealing(), "打开就开始搜")
	t.check(screen._line.text.contains("正在搜"), "读数写着正在搜：%s" % screen._line.text)
	var unrevealed := box.get_item(view.next_uid())
	t.check(not bool(screen._drag.drop_filter.call(unrevealed, run.board)), "没亮的不许放到棋盘")
	t.check(bool(screen._drag.drop_filter.call(unrevealed, box)), "没亮的许放回容器")
	view.skip()
	t.check(not screen._line.text.contains("正在搜"), "搜完读数不再写正在搜")
	t.check(bool(screen._drag.drop_filter.call(unrevealed, run.board)), "亮了许放到棋盘")
	t.check(view.get_parent() is ScrollContainer, "格子包在竖向滚动容器里（容器太高不撑出窗口）")
	screen.take_all()
	t.eq(box.item_count(), 0, "滚动容器里全部拾取照样拿完")
	screen.queue_free()
