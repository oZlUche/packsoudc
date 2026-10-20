## 216（作者 2026-10-20 选定丁 火漆签）：背包窗去字、收起换圆钮、棋盘下的数值栏（耐力 / DPS / 负重）；补充（选乙）：背包窗一格 72、定尺寸；
## 战利品 / 搜索屏右棋盘下同一条，和「全部拾取」同一行。没精修图先占位画
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Setup := preload("res://tests/ui/test_setup_180.gd")
const CS := preload("res://ui/game/container_screen.gd")
const InvPanel := preload("res://ui/game/inventory_panel.gd")


static func _flow(prefix: String) -> GameFlow:
	var c = NodeScreens._content()
	var f := Support.flow(c, prefix)
	f.begin(c.chapter, NodeScreens._kit(c), 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	return f


static func frame_refresh(t: TestCase, root: Window) -> void:
	t.begin("216 · 数值栏：耐力档 / 耗 · 回、DPS 和战前屏同一个数、负重「当前 / 上限」与档名；不算负重的章只排两张、居中；字里没有「停上去」「按住」")
	var f := _flow("strip216a")
	var run := f.run
	var strip := StatsStrip.new()
	root.add_child(strip)
	strip.set_width(480.0)
	var spec := run.compile_player()
	strip.refresh(spec, run)
	var e := StaminaEstimate.of(spec)
	t.eq(strip.texts(StatsStrip.STAMINA), [String(e["rating"]), "耗 %.1f · 回 %.1f" % [e["cost"], e["regen"]]] as Array[String], "耐力：档位 + 每秒耗 / 回")
	t.eq(strip.texts(StatsStrip.DPS), ["%.1f" % spec.rough_dps(), "DPS"] as Array[String], "DPS：和战前屏「约 x DPS」同一个数")
	t.eq(strip.tip_text(StatsStrip.STAMINA), StaminaEstimate.describe(spec), "耐力的悬浮窗沿用原来的细节")
	t.check(strip.tip_text(StatsStrip.DPS).contains("%.1f" % spec.rough_dps()), "DPS 的悬浮窗写总数、列出手件")
	if run.encumbrance_line() != "":
		t.eq(strip.shown(), StatsStrip.ORDER, "算负重：三张")
		t.eq(strip.texts(StatsStrip.LOAD), ["%d / %d" % [run.carry_weight(), run.carry_capacity()], run.encumbrance.name_of(run.encumbrance_level())] as Array[String], "负重：当前 / 上限 + 档名")
	for kind in strip.shown():
		var both := " ".join(strip.texts(kind)) + strip.tip_text(kind)
		t.check(not both.contains("停上去") and not both.contains("按住"), "%s 没有老说明字" % kind)
	var three := strip.tag_rect(StatsStrip.STAMINA).position.x
	var had_load := strip.shown().size() == 3
	run.encumbrance = null     # 这一章不算负重
	strip.refresh(spec, run)
	t.eq(strip.shown(), [StatsStrip.STAMINA, StatsStrip.DPS] as Array[StringName], "不算负重：只排两张")
	var a := strip.tag_rect(StatsStrip.STAMINA)
	var b := strip.tag_rect(StatsStrip.DPS)
	t.check(absf(a.position.x - (480.0 - b.end.x)) <= 1.0, "两张居中（左 %.0f / 右 %.0f）" % [a.position.x, 480.0 - b.end.x])
	if had_load:
		t.check(a.position.x > three, "比三张时往里收")
	t.eq(String(strip.get_meta(&"tone")), "light", "浅纸墨字")
	strip.queue_free()


static func frame_bag_window(t: TestCase, root: Window) -> void:
	t.begin("216 补充 · 背包浮窗（作者选乙 一格 72）：不写字、右上圆钮（停上去写收起（B））按了收起；窗 660×620、棋盘格子在窗 (42,82)、一格 72、皮带外框比格子外扩 24；棋盘下居中一条数值栏，没有老耐力行")
	var game = Setup._game(root, "strip216b")
	var setup = game.base()
	setup.show_page(2)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var ids: Array[int] = pv.entry_ids()
	t.check(not ids.is_empty() and setup.pick_spawn(ids[0]), "挑一个入口")
	setup.close_hint()
	t.check(setup.depart(), "出发")
	var map = game.base()
	if map.has_method("rules_open") and map.rules_open():
		map.close_rules()
	map.toggle_bag()
	t.check(map.bag_open(), "开背包")
	var wins: Array = map.find_children("*", "BagWindow", true, false)
	t.eq(wins.size(), 1, "一个背包浮窗")
	if wins.size() == 1:
		var win: BagWindow = wins[0]
		var spec := BagWindow.spec()
		var labels: Array = win.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text in ["背包", "按住标题拖动"])
		t.eq(labels.size(), 0, "标题行不写字")
		t.check(win.close_button is IconButton, "收起是圆钮")
		t.eq(win.close_button.tooltip_text, "收起（B）", "停上去写收起（B）")
		var side := 56.0 * float(spec["minimize"]["scale"])
		t.check(absf(win.close_button.custom_minimum_size.x - side) < 0.5, "按 %.2f 画" % float(spec["minimize"]["scale"]))
		var inv = map.bag_panel()
		var cell := float(spec["cell"])
		t.eq(inv.board_view.cell_px, cell, "一格 %d" % int(cell))
		var extra := (Vector2(inv.board_view.inventory.size) - BagWindow._vec(spec["board"])) * cell
		t.eq(win.window_size(), BagWindow._vec(spec["window_size"]) + extra, "窗按精修稿（棋盘 %s）" % str(inv.board_view.inventory.size))
		t.eq(inv.position, BagWindow._vec(spec["board_cells_topleft_rel_window"]), "棋盘格子左上在窗 (42,82)")
		var off := float(spec["board_frame"]["cells_offset"])
		t.eq(win.frame.position, inv.position - Vector2(off, off), "外框比格子外扩 %d" % int(off))
		t.eq(win.frame.size, Vector2(inv.board_view.inventory.size) * cell + Vector2(off, off) * 2.0, "外框包住整块棋盘")
		t.not_null(win.frame.texture, "外框切图在")
		t.eq(win.close_button.position, BagWindow._vec(spec["minimize"]["topleft_rel_window"]) + Vector2(extra.x, 0.0), "圆钮在右上")
		t.check(not inv.board_view.seams.is_empty(), "格缝按棋盘美术画")
		var strips: Array = win.find_children("*", "StatsStrip", true, false)
		t.eq(strips.size(), 1, "棋盘下一条数值栏")
		if strips.size() == 1:
			var s := strips[0] as StatsStrip
			var box := s.get_parent() as MarginContainer
			var col := box.get_parent() as VBoxContainer if box != null else null
			t.check(col != null and col == inv.board_view.get_parent() and box.get_index() == inv.board_view.get_index() + 1, "数值栏紧跟在棋盘下面")
			if col != null:
				t.eq(box.get_theme_constant("margin_top") + col.get_theme_constant("separation"), int(InvPanel.STRIP_GAP), "上沿离棋盘下沿 %d" % int(InvPanel.STRIP_GAP))
			var board_w: float = float(inv.board_view.inventory.size.x) * cell
			t.eq(s.custom_minimum_size.x, board_w, "和棋盘一样宽，签在里面居中")
		win.close_button.pressed.emit()
		t.check(not map.bag_open(), "按圆钮：收起")
	game.queue_free()
	Setup.Support.cleanup("strip216b")


static func frame_container_screen(t: TestCase, root: Window) -> void:
	t.begin("216 · 战利品屏：玩家棋盘下一条数值栏，和「全部拾取」同一行（中线 ±2）、上沿让开棋盘；面板加高放得下")
	var f := _flow("strip216c")
	var box := LootPacker.board_of([&"knife"] as Array[StringName], Vector2i(6, 4), f.run.items)
	var screen = load("res://ui/game/container_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.LOOT
	root.add_child(screen)
	screen.open({"container": box})
	var strip: StatsStrip = screen._strip
	t.not_null(strip, "有数值栏")
	if strip != null:
		t.check(strip.get_parent() == screen._stage, "摆在屏上（不在背包面板的竖排里）")
		var take: Rect2 = screen._take_btn.get_global_rect()
		var take_mid := take.position.y + CS.TAKE_INSET + CS.TAKE_VISIBLE * 0.5
		var strip_mid := strip.global_position.y + strip.strip_height() * 0.5
		t.check(absf(take_mid - strip_mid) <= 2.0, "和「全部拾取」同一行（%.0f / %.0f）" % [take_mid, strip_mid])
		var board: Rect2 = screen._inv.board_view.get_global_rect()
		t.check(strip.global_position.y >= board.end.y + CS.STRIP_GAP - 1.0, "上沿让开棋盘")
		t.check(absf(strip.global_position.x - board.position.x) <= 1.0 and absf(strip.size.x - board.size.x) <= 1.0, "和玩家棋盘左对齐、一样宽")
		var bottom: float = screen.overlay_frame().global_position.y + screen.panel_size().y
		t.check(strip.get_global_rect().end.y <= bottom, "面板放得下（%.0f ≤ %.0f）" % [strip.get_global_rect().end.y, bottom])
		t.check(strip.texts(StatsStrip.DPS)[0] != "", "有读数")
	screen.queue_free()
