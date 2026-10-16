## 作者第十六批（报告 092）里还没按模块归位的那一条：离开结算屏时一键出售地上。
## 倒计时搬去了 `test_countdown.gd`、保险箱搬去了 `test_safe.gd`（102 第 A-4 条）。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_stash_sale_and_result(t: TestCase, root: Window) -> void:
	t.begin("结算 · 地上一键出售（092）：地上没背出来的在结算屏上说清楚、离开时一键出售进局外、局外屏提示；保险箱那格画在结算屏上；只卖一次")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "stash_sale")
	var run := f.begin(c.chapter, kit, 5)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var def: ItemDef = null
	var board_item: ItemInstance = null
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			def = (inst as ItemInstance).def
			board_item = inst
			break
	t.check(def != null, "棋盘上有非包道具")
	if def == null:
		Support.cleanup("stash_sale")
		return
	t.check(InventoryService.transfer_auto(run.board, board_item.uid, SafeModule.of(run).inventory), "一件进保险箱")
	# 走到最近的撤离点（出生点旁没有撤离点：环形图的撤离点在外面几环）
	var near := MapNavigator.nearest_of_type(run.map, run.travel.current_id, &"extract")
	t.check(int(near["id"]) >= 0 and Support.walk_to(f, int(near["id"]), GameFlow.Screen.EVENT), "走到了最近的撤离点（%d 步；停在它的对话上）" % int(near["steps"]))
	if run.is_over() or run.travel.current_id != int(near["id"]):
		t.check(false, "没走到就结束了")
		Support.cleanup("stash_sale")
		return
	# 到了再往地上塞两件（路上事件给的也算，账按当时的地上数）
	run.storage.admit(ItemInstance.create(def))
	run.storage.admit(ItemInstance.create(def))
	var stash_n := run.storage.item_count()
	var stash_funds := 0
	for inst in run.storage.items():
		stash_funds += MetaState.sell_price((inst as ItemInstance).def, f.sell_ratio())
	var safe_n := SafeModule.of(run).inventory.item_count()
	t.check(f.extract(), "撤离")
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	var r: RunResult = f.result
	t.check(r != null and r.is_extracted() and r.left_behind == stash_n and r.left_items.size() == stash_n, "地上 %d 件记在账上" % stash_n)
	t.check(r != null and r.safe_items.size() == safe_n and safe_n >= 1, "保险箱 %d 件记在账上" % safe_n)
	var price := stash_funds
	var pre := f.stash_sale_preview()
	t.eq([int(pre["count"]), int(pre["funds"])], [stash_n, stash_funds], "预览：件数与卖价之和")
	var funds0 := f.meta.funds
	# 结算屏
	var screen = load("res://ui/game/result_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.RESULT
	root.add_child(screen)
	screen.open({"result": r})
	t.check(screen._stash_line != null and screen._stash_line.text.contains("一键出售") and screen._stash_line.text.contains("得 %d 币" % price), "结算屏说了离开时一键出售、得多少（%s）" % (screen._stash_line.text if screen._stash_line != null else "无"))
	t.eq(screen.safe_view(), null, "177：第 1 步只看账，保险箱格在第 2 步")
	screen.to_step(2)
	t.check(screen.safe_view() != null and screen.safe_view().inventory.item_count() == safe_n and screen.safe_view().inventory.size == Vector2i(3, 3), "保险箱那格画出来了：%d 件、3×3" % safe_n)
	t.check(f.meta.board != null and f.meta.board.item_count() >= safe_n, "带回来的棋盘里有保险箱那件")
	# 反馈：结算屏的继续按钮不能被仓库挤出窗口 —— 按钮在滚动区外，仓库区最小高度压在 4 行
	var cont: Button = null
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).text.begins_with("继续"):
			cont = n
		stack.append_array(n.get_children())
	t.not_null(cont, "有继续按钮")
	if cont != null:
		var inside_scroll := false
		var up: Node = cont.get_parent()
		while up != null and up != screen:
			inside_scroll = inside_scroll or up is ScrollContainer
			up = up.get_parent()
		t.check(not inside_scroll, "继续按钮钉在滚动区外")
	var wh_min := 0.0
	for sc: ScrollContainer in screen.find_children("*", "ScrollContainer", true, false):
		if sc.get_child_count() > 0 and sc.get_child(0) is InventoryView and (sc.get_child(0) as InventoryView).inventory == f.meta.warehouse:
			wh_min = maxf(wh_min, sc.custom_minimum_size.y)
	t.check(wh_min <= 4.0 * InventoryView.CELL, "仓库区最小高度不超过 4 行（%.0f）" % wh_min)
	screen.proceed()
	t.eq(f.screen, GameFlow.Screen.META, "→ 局外")
	t.eq(f.meta.funds, funds0 + price, "地上的卖了，钱进局外")
	t.eq(int((f.last_absorbed.get("stash_sold", {}) as Dictionary).get("count", 0)), stash_n, "记了卖掉几件")
	t.check(r.left_items.is_empty(), "清单清掉：只卖一次")
	f.finish_result()
	t.eq(f.meta.funds, funds0 + price, "再离开一次不重复卖")
	t.check(MetaSave.exists(String(Support.paths("stash_sale")["meta"])), "存了局外")
	# 局外屏的提示
	var meta_screen = load("res://ui/game/meta_screen.gd").new()
	meta_screen.flow = f
	meta_screen.font = UiPalette.cjk_font()
	meta_screen.screen = GameFlow.Screen.META
	root.add_child(meta_screen)
	meta_screen.open({"result": r, "stash_sold": {"count": stash_n, "funds": price}})
	var texts: Array[String] = []
	var walker := func(node: Node, fn: Callable) -> void:
		for ch in node.get_children():
			if ch is Label:
				texts.append((ch as Label).text)
			fn.call(ch, fn)
	walker.call(meta_screen, walker)
	var said := false
	for s in texts:
		if s.contains("已一键出售") and s.contains("%d 件" % stash_n):
			said = true
	t.check(said, "局外屏提示：地上 %d 件已一键出售" % stash_n)
	meta_screen.queue_free()
	screen.queue_free()
	Support.cleanup("stash_sale")
