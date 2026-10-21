## 作者第十六批（报告 092）里还没按模块归位的那一条：撤离时地上的东西。092 定的「离开结算屏时一键出售」224 撤了（作者：「地上的怎么可能出售」）——
## 地上的撤离时就没了：不进仓库、不进钱、不提示。保险箱那格照旧画在结算屏第 2 步。
## 倒计时搬去了 `test_countdown.gd`、保险箱搬去了 `test_safe.gd`（102 第 A-4 条）。
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_stash_sale_and_result(t: TestCase, root: Window) -> void:
	t.begin("结算 · 地上的不进仓库也不进钱（224 撤销 092 的一键出售）；保险箱那格画在结算屏第 2 步")
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
	t.check(stash_n >= 2, "地上有 %d 件" % stash_n)
	var safe_n := SafeModule.of(run).inventory.item_count()
	t.check(f.extract(), "撤离")
	t.eq(f.screen, GameFlow.Screen.RESULT, "→ 结算")
	var r: RunResult = f.result
	t.check(r != null and r.is_extracted() and not ("left_behind" in r), "地上的不记账")
	t.check(r != null and r.safe_items.size() == safe_n and safe_n >= 1, "保险箱 %d 件记在账上" % safe_n)
	t.check(not f.has_method("stash_sale_preview"), "没有出售预览")
	var funds0 := f.meta.funds
	var wh0 := f.meta.warehouse.item_count()
	# 结算屏
	var screen = load("res://ui/game/result_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.RESULT
	root.add_child(screen)
	screen.open({"result": r})
	var said := false
	for l: Label in screen.find_children("*", "Label", true, false):
		said = said or l.text.contains("出售") or l.text.contains("地上")
	t.check(not said, "结算屏不提地上的")
	t.check(screen.safe_view() != null and screen.safe_view().inventory.item_count() == safe_n and screen.safe_view().inventory.size == Vector2i(3, 3), "224 补充二：保险箱在第 1 步账单右边：%d 件、3×3" % safe_n)
	screen.to_step(2)
	t.eq(screen.safe_view(), null, "第 2 步不再画保险箱")
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
	t.eq(f.meta.funds, funds0, "地上的不进钱")
	t.check(not f.last_absorbed.has("stash_sold"), "不记卖掉几件")
	t.check(f.meta.warehouse.item_count() <= wh0 + f.meta.board.item_count() if f.meta.board != null else true, "地上的不进仓库")
	t.check(MetaSave.exists(String(Support.paths("stash_sale")["meta"])), "存了局外")
	screen.queue_free()
	Support.cleanup("stash_sale")
