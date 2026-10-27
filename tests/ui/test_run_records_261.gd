## 261（作者 14:13）：「图鉴」页签改书架 —— 图鉴 / 对局记录 / 特殊道具 / 成就各占一格、各开一扇窗；
## 对局记录留最近 20 场，可收藏（收藏的不删，最多 19 场，永远给最新一局留一个位置）；详情只在调试模式写地图种子
extends RefCounted

const META := "user://test_261_meta.json"
const SETTINGS := "user://test_261_settings.json"
const MIDDLE := Vector2(1308, 952)


static func _flow() -> GameFlow:
	var db := ItemDatabase.new()
	db.load_dir()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	f.chapters = GameFlow.load_chapters()
	f.characters = GameFlow.load_characters()
	f.achievement_defs = GameFlow.load_achievements()
	return f


static func _screen(f: GameFlow, root: Window) -> Control:
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	return screen


static func _cleanup() -> void:
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _run(m: MetaState, value: int, extracted := true) -> void:
	var r := RunResult.new()
	r.outcome = &"extracted" if extracted else &"defeated"
	r.reason = &"extract" if extracted else &"vitality_depleted"
	r.chapter_id = &"free_mode"
	r.value = value
	r.steps = 10 + value % 7
	r.run_seed = 1000 + value
	r.ended_at = 1700000000 + value * 60
	r.scale_id = &"medium"
	m.absorb(r)


static func run_trim_and_pins(t: TestCase) -> void:
	t.begin("261 · 对局记录：留 20 场，超了删最旧的未收藏；收藏最多 19 场；存读往返")
	var m := MetaState.new(GameFlow.load_meta_rules())
	for i in 21:
		_run(m, i + 1)
	t.eq(m.history.size(), MetaState.HISTORY_MAX, "21 局只留 20 条")
	t.eq(int(m.history[0]["run_no"]), 21, "最新的在最前（第 21 局）")
	t.eq(int(m.history[-1]["run_no"]), 2, "最旧的第 1 局删了")
	t.check(not bool(m.history[0]["pinned"]), "新的一条没收藏")
	var p := MetaState.new(GameFlow.load_meta_rules())
	for i in 19:
		_run(p, i + 1)
	var pinned_ok := true
	for i in 19:
		pinned_ok = p.pin_run(i, true) and pinned_ok
	t.check(pinned_ok, "19 条都收藏得上")
	t.eq(p.pinned_count(), MetaState.PIN_MAX, "收藏了 19 场")
	_run(p, 20)
	_run(p, 21)
	t.eq(p.history.size(), MetaState.HISTORY_MAX, "收藏 19 + 未收藏 2 → 留 20")
	t.eq(int(p.history[0]["run_no"]), 21, "最新那局在")
	var nos := p.history.map(func(h): return int(h["run_no"]))
	t.check(not nos.has(20), "删的是最旧的未收藏那条（第 20 局）")
	t.eq(p.pinned_count(), 19, "收藏的一条没删")
	t.check(not p.pin_run(0, true), "收藏第 20 场：按不下去")
	t.check(p.pin_run(1, false) and p.pin_run(0, true), "取消一个再收藏就行")
	t.check(not p.pin_run(99, true), "下标不对：false")
	var db := ItemDatabase.new()
	db.load_dir()
	var back := MetaState.from_dict(p.to_dict(), db, GameFlow.load_meta_rules())
	t.eq(back.history, p.history, "存读往返（收藏、第几局都在）")
	# 游戏测试 v4.63：261 前记的局没有 run_no —— 按总局数倒推，不写「第 0 局」
	var old := p.to_dict()
	old["runs"] = 7
	var rows: Array = old["history"]
	old["history"] = rows.slice(0, 3)
	for row in old["history"]:
		(row as Dictionary).erase("run_no")
	var back2 := MetaState.from_dict(old, db, GameFlow.load_meta_rules())
	t.eq(back2.history.map(func(h): return int(h["run_no"])), [7, 6, 5], "老档：第 7 / 6 / 5 局")


static func frame_shelf(t: TestCase, root: Window) -> void:
	t.begin("261 · 书架：两层三格在中列里（补充一：上 图鉴 / 对局记录 / 特殊道具，下 成就 / 科技 / 静物），前五格各开一扇窗（1100 × 820，科技 1320 × 900），小牌写数；老名字 codex / achievements / tech 也开书架上的窗")
	var f := _flow()
	_run(f.meta, 300)
	var screen = _screen(f, root)
	screen.show_tab("shelf")
	t.eq(screen.tab(), "shelf", "书架页")
	var btns: Dictionary = screen.shelf_buttons()
	t.eq(screen.SHELF_CELLS, ["codex", "records", "keepsakes", "achievements", "tech", ""], "六格顺序")
	t.eq(btns.keys(), ["codex", "records", "keepsakes", "achievements", "tech"], "五格有小牌")
	t.eq((btns["tech"] as Button).text, UiText.t("shelf.tech") % [0, f.tech_defs.size()], "科技的小牌：点过的节点 / 全部")
	var page: Control = screen._pages["shelf"]
	var need: Vector2 = page.get_combined_minimum_size()
	t.check(need.x <= MIDDLE.x and need.y <= MIDDLE.y, "书架 %s 放得进中列 %s" % [need, MIDDLE])
	t.eq((btns["records"] as Button).text, UiText.t("shelf.records") % 1, "对局记录的小牌写场数")
	for key in btns:
		(btns[key] as Button).pressed.emit()
		t.eq(screen.shelf_open(), key, "点 %s：开那扇窗" % key)
		var win: Control = screen.shelf_window(key)
		t.check(win != null and win.is_visible_in_tree(), "%s 窗看得见" % key)
		var frame := win.find_children("*", "OverlayFrame", true, false)
		var want: Vector2 = screen.SHELF_WIN_WIDE if key == "tech" else screen.SHELF_WIN
		t.check(not frame.is_empty() and (frame[0] as Control).custom_minimum_size == want, "%s 窗 %s" % [key, want])
		if key == "tech" and not frame.is_empty():
			var fr := frame[0] as Control
			t.check(fr.get_combined_minimum_size().x <= want.x + 0.5 and fr.get_combined_minimum_size().y <= want.y + 0.5,
				"科技窗 %s 装得下科技页（窗不被撑大）" % fr.get_combined_minimum_size())
			t.check(screen.tech_panel() != null and screen.tech_panel().is_visible_in_tree(), "科技窗里就是科技页")
	t.check(screen.escape() and screen.shelf_open() == "" and screen.tab() == "shelf", "Esc 先关窗")
	screen.show_tab("achievements")
	t.check(screen.tab() == "shelf" and screen.shelf_open() == "achievements", "老名字 achievements → 书架 + 成就窗")
	screen.show_tab("tech")
	t.check(screen.tab() == "shelf" and screen.shelf_open() == "tech", "老名字 tech → 书架 + 科技窗")
	screen.show_tab("home")
	t.eq(screen.shelf_open(), "", "换页签关窗")
	screen.free()
	_cleanup()


static func frame_records_window(t: TestCase, root: Window) -> void:
	t.begin("261 · 对局记录窗：从新到旧一行一局、星 = 收藏；点一行看详情，「← 记录」回列表；种子只在调试模式写")
	var f := _flow()
	for i in 3:
		_run(f.meta, 100 * (i + 1), i != 1)
	var screen = _screen(f, root)
	screen.open_shelf("records")
	var win: RunRecordsWindow = screen.records_window()
	t.eq(win.row_count(), 3, "三局三行")
	var cols: Array = win.row_columns(0)
	t.eq(cols[0], UiText.t("records.run_no") % 3, "第一行是最新的第 3 局")
	t.check(String(cols[4]).begins_with(UiText.t("records.outcome_extracted")), "结局：撤离")
	t.check(String(win.row_columns(1)[4]).contains(UiText.t("records.reason_vitality_depleted")), "战败写原因")
	t.check(win.toggle_pin(1) and bool(f.meta.history[1]["pinned"]), "点星：收藏")
	t.eq(win.head_text(), UiText.t("records.count") % [3, MetaState.HISTORY_MAX, 1, MetaState.PIN_MAX], "表头：场数与收藏数")
	t.check(win.toggle_pin(1) and not bool(f.meta.history[1]["pinned"]), "再点：取消")
	f.settings.debug_mode = false
	win.show_detail(0)
	t.eq(win.detail_index(), 0, "开详情")
	t.check(win.detail_text().contains(UiText.t("records.detail_out")), "详情有带出那行")
	t.check(not win.detail_text().contains(UiText.t("records.seed")), "非调试：没有种子")
	win.show_list()
	t.eq(win.detail_index(), -1, "回列表")
	if DevGate.on():
		f.settings.debug_mode = true
		win.show_detail(0)
		t.check(win.detail_text().contains(UiText.t("records.seed")) and win.detail_text().contains(str(1300)), "调试模式：写种子（%s）" % win.detail_text())
		t.not_null(win._copy_btn, "旁边有复制键")
		f.meta.history[0].erase("scale")
		win.show_detail(0)
		t.check(not win.detail_text().strip_edges().ends_with("/"), "老记录没规模：种子行不留半截「/」（%s）" % win.detail_text())
		f.settings.debug_mode = false
	screen.free()
	_cleanup()



static func run_shelf_tiers(t: TestCase) -> void:
	t.begin("261 补充一 · 书架物件五档：tier = clampi(floori(done × 5 / total), 0, 4)；total 0 → t0")
	t.eq(ShelfCell.tier_of(0, 100), 0, "0 → t0")
	t.eq(ShelfCell.tier_of(19, 100), 0, "19% → t0")
	t.eq(ShelfCell.tier_of(20, 100), 1, "20% → t1")
	t.eq(ShelfCell.tier_of(79, 100), 3, "79% → t3")
	t.eq(ShelfCell.tier_of(80, 100), 4, "80% → t4")
	t.eq(ShelfCell.tier_of(100, 100), 4, "100% → t4")
	t.eq(ShelfCell.tier_of(3, 0), 0, "分母 0 → t0")
	t.eq(ShelfCell.tier_of(20, 20), 4, "对局记录满 20 场 → t4")
