## 局内界面布局方案（handoff/2026-11-19-run-ui-layout-plan.md）U2：地图行动预览进浮窗、日晷读数、图例默认收起、
## 腰带全空淡下去、背包的普通 / 联动 / 风险三种查看方式
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "run_ui_layout"


static func _map(root: Window) -> Array:
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = String(p["run"])
	game.meta_path = String(p["meta"])
	game.settings_path = String(p["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	Support.depart(setup)
	var map = game.base()
	if flow.run != null and flow.run.phase == RunState.Phase.PICK_SPAWN:
		map.pick_spawn(flow.run.map.entry_ids[0])
	return [game, flow, map]


static func frame_map_parts(t: TestCase, root: Window) -> void:
	t.begin("U2 · 地图：浮窗写这一步实际扣几；日晷剩得少 / 设置始终显示才刻数；图例默认收起、点开记进设置；腰带全空淡下去")
	var got := _map(root)
	var game = got[0]
	var flow: GameFlow = got[1]
	var map = got[2]
	var run: RunState = flow.run
	if run == null or not map.has_method("preview_path"):
		t.check(false, "进了地图")
		game.queue_free()
		return
	# §4.2 行动预览
	var moves := run.travel.available_moves()
	t.check(not moves.is_empty(), "有能走的点")
	if not moves.is_empty():
		var to: int = moves[0]
		t.eq(map.preview_path(to), [to] as Array[int], "隔壁：按这一步算")
		t.eq(map.preview_path(run.travel.current_id), [] as Array[int], "脚下：不预览")
		map._update_tooltip(to)
		var p := ActionPreview.of(run, [to] as Array[int])
		var want := Glossary.strip_bbcode(UiText.t("preview.countdown") % int(p[ActionPreview.COUNTDOWN]))
		t.check(int(p[ActionPreview.COUNTDOWN]) < 0 or Glossary.strip_bbcode(map.tooltip_text()).contains(want), "浮窗里有「%s」：%s" % [want, Glossary.strip_bbcode(map.tooltip_text()).replace("\n", " / ")])
	# §4.1 日晷读数
	var host: HudHost = map.hud()
	var cd = host.widget(&"countdown") if host != null else null
	if cd != null and CountdownModule.of(run) != null and CountdownModule.of(run).has_countdown():
		t.eq(cd.stage(), &"calm", "开局：剩得多")
		t.check(not cd.shows_number(), "默认：剩得多时晷面不刻数（停上去看悬浮窗）")
		flow.settings.dial_number_always = true
		t.check(cd.shows_number(), "设置始终显示：刻数")
		flow.settings.dial_number_always = false
		var limit := CountdownModule.of(run).limit()
		run.travel.clock.total = maxi(0, limit - 3)
		t.eq(cd.stage(), &"low", "剩 3：危险")
		t.check(cd.shows_number(), "剩得少：不用设置也刻数")
		run.travel.clock.total = 0
	var back := GameSettings.from_dict({"version": GameSettings.SAVE_VERSION, "dial_number_always": true, "legend_open": true})
	t.check(back.dial_number_always and back.legend_open, "两个新设置读得回来")
	t.check(not GameSettings.new().dial_number_always and not GameSettings.new().legend_open, "默认：危险时才刻数、图例收起")
	t.eq(GameSettings.from_dict(back.to_dict()).to_dict(), back.to_dict(), "设置往返一致")
	# §4.3 图例
	var legend = host.widget(&"legend") if host != null else null
	if legend != null:
		legend.refresh()
		t.check(not legend.expanded(), "图例默认收起")
		var names_before: Array[String] = legend.row_names()
		t.check(not names_before.is_empty(), "行照样在（%d 行）" % names_before.size())
		t.check(legend.tooltip_text != "", "收起时停上去读得到名字")
		legend.toggle_expanded()
		t.check(legend.expanded() and flow.settings.legend_open, "点开：展开、记进设置")
		t.eq(legend.row_names(), names_before, "展开前后同一份行")
		legend.toggle_expanded()
		legend.set_expanded(true)
		t.check(legend.expanded() and not flow.settings.legend_open, "教程临时展开不写设置")
		legend.set_expanded(false)
		t.check(not legend.expanded(), "教程收起回到玩家选的样子")
	# §4.3 腰带
	var belt = host.widget(&"belt") if host != null else null
	if belt != null and belt.slots != null:
		var slots: BeltSlots = belt.slots
		t.eq(is_equal_approx(slots.modulate.a, BeltSlots.EMPTY_ALPHA), slots.all_empty(), "全空才淡（全空 = %s）" % str(slots.all_empty()))
	game.queue_free()
	Support.cleanup(PREFIX)


static func frame_bag_views(t: TestCase, root: Window) -> void:
	t.begin("U2 · 背包三种查看：风险只亮侵蚀 / 不参战的，写「侵蚀 n/满」；联动只画真正连上的格位；切换不动道具")
	var got := _map(root)
	var game = got[0]
	var flow: GameFlow = got[1]
	var map = got[2]
	var run: RunState = flow.run
	if run == null:
		t.check(false, "进了地图")
		game.queue_free()
		return
	map.toggle_bag()
	var win = map._bag.get_child(0) if map._bag != null and map._bag.get_child_count() > 0 else null
	t.check(win != null and win.has_method("set_view"), "背包窗开了、有查看方式")
	if win == null or not win.has_method("set_view"):
		game.queue_free()
		return
	var view: InventoryView = win.panel.board_view
	t.eq(win.view_mode(), InventoryView.VIEW_NORMAL, "默认：普通")
	var item: ItemInstance = null
	for inst in run.board.items():
		if ItemErosion.eligible(inst):
			item = inst
			break
	if item != null:
		t.eq(InventoryView.risk_note(item), "", "没侵蚀、参战：没有风险")
		ItemErosion.add(item)
		t.eq(InventoryView.risk_note(item), UiText.t("inv.risk_erosion") % [1, ItemErosion.limit(item)], "侵蚀一层：写「侵蚀1/满」")
		t.check(not InventoryView.risk_critical(item), "1/3 还不算快毁")
		ItemErosion.add(item)
		t.check(InventoryView.risk_critical(item), "2/3：再一次就毁 —— 红字")
	var before := run.board.to_dict() if run.board.has_method("to_dict") else {}
	win.set_view(InventoryView.VIEW_RISK)
	t.eq(view.view_mode, InventoryView.VIEW_RISK, "切到风险")
	win.set_view(InventoryView.VIEW_LINKS)
	var links: Dictionary = view.link_marks()
	for cell in links["marks"]:
		for m in links["marks"][cell]:
			t.check(bool(m[1]), "联动只画点亮了的（%s）" % str(cell))
	for uid in links["uids"]:
		t.check(run.board.has_item(int(uid)), "联动里的 %d 在棋盘上" % int(uid))
	win.set_view(InventoryView.VIEW_NORMAL)
	if not before.is_empty():
		t.eq(run.board.to_dict(), before, "切了三种查看，棋盘一格没动")
	game.queue_free()
	Support.cleanup(PREFIX)


static func run_recent_notices(t: TestCase) -> void:
	t.begin("U3 · 最近记录：告示按先后记、新的在前；紧挨着的同一句只记一次；最多 30 条；换一局清空")
	NoticeLayer.claim_history(-12345)
	NoticeLayer.claim_history(-54321)
	t.check(NoticeLayer.history().is_empty(), "换了主人：空")
	var layer := NoticeLayer.new()
	layer.push("A")
	layer.push("A")
	layer.push("B", true)
	var h := NoticeLayer.history()
	t.eq(h.size(), 2, "同一句挨着只记一次")
	t.eq([String(h[0]["text"]), bool(h[0]["urgent"])], ["B", true], "新的在前、记着要紧")
	for i in 40:
		NoticeLayer.remember("第 %d 句" % i)
	t.eq(NoticeLayer.history().size(), NoticeLayer.HISTORY_MAX, "最多 %d 条" % NoticeLayer.HISTORY_MAX)
	NoticeLayer.claim_history(-54321)
	t.eq(NoticeLayer.history().size(), NoticeLayer.HISTORY_MAX, "同一局：不清")
	NoticeLayer.claim_history(-1)
	t.check(NoticeLayer.history().is_empty(), "换一局：清空（读档不复播）")
	layer.free()
