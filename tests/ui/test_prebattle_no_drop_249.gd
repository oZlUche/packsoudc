## 249（作者 2026-10-24）：开战前不丢东西 —— 战前屏棋盘上的出不去（拖出去弹回 + 一句、右键「放到地上」灰着、双击不搬、顶替不往地上挤），
## 「不参战」照旧；地上的照样能拾进棋盘。别的屏（没设 [member InventoryPanel.ground_exit_notice]）照旧能丢
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const InvPanel := preload("res://ui/game/inventory_panel.gd")
const FAR := Vector2(5000, 5000)


static func _panel(run: RunState, notice: String) -> Control:
	var panel: Control = InvPanel.new()
	panel.setup(run, null)
	if notice != "":
		panel.ground_exit_notice = notice
	return panel


## 棋盘上一件能打的（有战斗定义、不是信物、能放上去）；没有就摆一把小刀
static func _armed(run: RunState) -> ItemInstance:
	for inst in run.board.items():
		var it := inst as ItemInstance
		if InvPanel.can_bench(it) and not it.def.is_bag and not run.board.is_locked(it.uid):
			return it
	var knife := ItemInstance.create(run.items.get_def(&"knife"))
	run.storage.insert(knife)
	return knife if InventoryService.transfer_auto(run.storage, knife.uid, run.board) else null


static func _grab(panel: Control, inst: ItemInstance) -> DragLayer:
	var view: InventoryView = panel.board_view
	var drag: DragLayer = panel._drag
	view.grab_requested.emit(view, inst.uid, Vector2(view.cell_px, view.cell_px) * (Vector2(inst.origin) + Vector2(0.5, 0.5)))
	return drag


static func run_no_drop(t: TestCase) -> void:
	t.begin("249 §二：战前屏 —— 拖出棋盘弹回、说「开战前不丢东西」；光标说不能放；右键第一项灰着（不参战还在）；双击不搬；地上的能拾进棋盘")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"brutus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var notice := UiText.t("pre.no_drop")
	t.eq(notice, "开战前不丢东西", "文案")
	var panel := _panel(run, notice)
	var inst := _armed(run)
	t.not_null(inst, "棋盘上有一件能打的")
	if inst == null:
		panel.free()
		return
	var at := inst.origin
	var ground0 := run.storage.item_count()
	var refused: Array = []
	var drag := _grab(panel, inst)
	drag.drop_refused.connect(func(uid: int): refused.append(uid))
	t.check(drag.is_dragging(), "拿起来了")
	t.check(not drag.drop_ok_at(FAR), "悬在棋盘外：光标说不能放")
	t.check(not drag.drop_at(FAR), "棋盘外松手：没放下")
	t.check(run.board.has_item(inst.uid) and run.board.get_item(inst.uid).origin == at, "弹回原格")
	t.eq(run.storage.item_count(), ground0, "地上没多")
	t.eq(refused, [inst.uid], "发了 drop_refused")
	t.eq(panel.last_hint, notice, "说了那一句")
	var acts: Array = panel.board_actions(inst.uid)
	var first := acts[0] as ItemActions.Action
	t.check(not first.enabled and first.reason == notice, "右键第一项「放到地上」灰着、原因同一句")
	t.check(acts.any(func(a: ItemActions.Action) -> bool: return a.id == &"bench" and a.enabled), "「不参战」还在、能点")
	panel.last_hint = ""
	t.check(not panel.quick_move(panel.board_view, inst.uid), "双击：不搬")
	t.check(run.board.has_item(inst.uid) and panel.last_hint == notice, "还在棋盘上、说了那一句")
	# 地上的照样能拾进棋盘
	var spare := ItemInstance.create(run.items.get_def(&"knife"))
	run.storage.insert(spare)
	var gv := GroundLayer.new()     # 地上的视图：双击走 quick_move 的「地上 → 棋盘」
	gv.stash = run.storage
	var picked: bool = panel.quick_move(gv, spare.uid)
	t.check(picked and run.board.has_item(spare.uid), "地上的双击拾进棋盘不拦")
	gv.free()
	panel.free()


static func run_other_screens(t: TestCase) -> void:
	t.begin("249 §二：别的屏没被连坐 —— 不设 ground_exit_notice 的面板，拖出棋盘照样落到地上、右键第一项亮着")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"brutus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var panel := _panel(run, "")
	var inst := _armed(run)
	if inst == null:
		t.check(false, "棋盘上有一件")
		panel.free()
		return
	t.check((panel.board_actions(inst.uid)[0] as ItemActions.Action).enabled, "右键第一项亮着")
	var drag := _grab(panel, inst)
	t.check(drag.drop_ok_at(FAR), "棋盘外：能放")
	t.check(drag.drop_at(FAR), "棋盘外松手：放到地上")
	t.check(run.storage.has_item(inst.uid) and not run.board.has_item(inst.uid), "到了地上")
	panel.free()
