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
	t.begin("216 · 数值栏：耐力档 / 耗 · 回、DPS 和战前屏同一个数、负重「当前 / 上限」与档名；三张总在（不算负重的章负重签照样在，小字空着）；字里没有「停上去」「按住」")
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
	t.eq(strip.shown(), StatsStrip.ORDER, "三张总在")
	if run.encumbrance_line() != "":
		t.eq(strip.texts(StatsStrip.LOAD), ["%d / %d" % [run.carry_weight(), run.carry_capacity()], run.encumbrance.name_of(run.encumbrance_level())] as Array[String], "负重：当前 / 上限 + 档名")
	for kind in strip.shown():
		var both := " ".join(strip.texts(kind)) + strip.tip_text(kind)
		t.check(not both.contains("停上去") and not both.contains("按住"), "%s 没有老说明字" % kind)
	var three := strip.tag_rect(StatsStrip.STAMINA).position.x
	t.check(absf(three - (480.0 - strip.tag_rect(StatsStrip.LOAD).end.x)) <= 1.0, "三张居中")
	# 作者 2026-10-20 16:20：负重签任何章节都显示
	run.encumbrance = null     # 这一章不算负重
	strip.refresh(spec, run)
	t.eq(strip.shown(), StatsStrip.ORDER, "不算负重：负重签照样在")
	var cap := run.carry_capacity()
	var want_main := "%d / %d" % [run.carry_weight(), cap] if cap > 0 else str(run.carry_weight())
	t.eq(strip.texts(StatsStrip.LOAD), [want_main, ""] as Array[String], "不算负重：大字「当前 / 上限」（没上限只写当前），小字空着")
	t.check(strip.tip_text(StatsStrip.LOAD).contains("不算负重"), "悬浮窗说这一章不算负重")
	var ch := run.character
	run.character = null     # 没角色 = 没上限
	strip.refresh(spec, run)
	t.eq(strip.texts(StatsStrip.LOAD), [str(run.carry_weight()), ""] as Array[String], "没上限：只写当前重量")
	run.character = ch
	strip.refresh(spec, null)
	t.eq(strip.shown(), [StatsStrip.STAMINA, StatsStrip.DPS] as Array[StringName], "没有这一局（run 为 null）：只排两张")
	var a := strip.tag_rect(StatsStrip.STAMINA)
	var b := strip.tag_rect(StatsStrip.DPS)
	t.check(absf(a.position.x - (480.0 - b.end.x)) <= 1.0, "两张居中（左 %.0f / 右 %.0f）" % [a.position.x, 480.0 - b.end.x])
	t.eq(String(strip.get_meta(&"tone")), "light", "浅纸墨字")
	strip.queue_free()


static func frame_bag_window(t: TestCase, root: Window) -> void:
	t.begin("216 补充 / 223 · 背包浮窗（作者选乙 一格 72）：不写字、右上圆钮（停上去写收起（B））按了收起；窗 984×620（右栏名牌 + 角色卡）、棋盘格子在窗 (42,82)、一格 72、皮带外框比格子外扩 24；棋盘下居中一条数值栏，没有老耐力行")
	var game = Setup._game(root, "strip216b")
	var setup = game.base()
	setup.show_page(2)
	var pv: MapPreview = setup.preview()
	pv.size = Vector2(640, 600)
	pv.finish()
	var ids: Array[int] = pv.entry_ids()
	t.check(not ids.is_empty() and setup.pick_spawn(ids[0]), "挑一个入口")
	setup.close_hint()
	t.check(Support.depart(setup), "出发")
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
		var mini: Array = (BagWindow.satchel().get("minimize", {}) as Dictionary).get("topleft_rel_window", spec["minimize"]["topleft_rel_window"]) if win.skinned() else spec["minimize"]["topleft_rel_window"]
		t.eq(win.close_button.position, BagWindow._vec(mini) + Vector2(extra.x, 0.0), "圆钮在右上（232：背包皮时在翻盖上）")
		t.check(not inv.board_view.seams.is_empty(), "格缝按棋盘美术画")
		# 223：窗加宽 984，竖线在原窗右沿 660，右栏名牌 + 角色卡（都跟着棋盘右移）
		t.eq(BagWindow._vec(spec["window_size"]), Vector2(984, 620), "223：窗 984×620")
		var dv := win.divider_v()
		t.eq([dv[0], dv[1].x], [Vector2(660.0 + extra.x, 66.0), 660.0 + extra.x], "竖分隔线在 x 660、从 y 66 起")
		t.eq(win.nameplate.position, Vector2(686.0 + extra.x, 78.0), "名牌在右栏 (686, 78)")
		t.check((win.nameplate.size * win.nameplate.scale - Vector2(272, 112)).length() < 0.5, "名牌画出来 272×112（%s）" % str(win.nameplate.size * win.nameplate.scale))
		t.eq(win.card.position, Vector2(686.0 + extra.x, 202.0), "角色卡在 (686, 202)")
		t.check(win.card.row(0).has("value") and win.card.passive_names().size() > 0, "角色卡有数、有被动")
		t.check(win.control_rect(&"character_card").has_area(), "教程能指角色卡")
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
		var right: float = screen.overlay_frame().global_position.x + screen.panel_size().x - CS.EDGE
		t.check(strip.get_global_rect().end.x <= right + 0.5, "复测 v3.79：签不伸出铜板右边（%.0f ≤ %.0f）" % [strip.get_global_rect().end.x, right])
		t.check(strip.texts(StatsStrip.DPS)[0] != "", "有读数")
	screen.queue_free()


static func frame_inlay_bronze(t: TestCase, root: Window) -> void:
	t.begin("铜面板三屏 · 嵌槽签：战利品屏 152 宽；战前屏窄签按 prebattle_row 的签宽从左沿排；浅字 tone dark；生命 / 耐力 / 特殊能力三张新签（免疫归进特殊能力）")
	var f := _flow("stripbronze")
	var run := f.run
	var spec := run.compile_player()
	var wide := StatsStrip.new()
	root.add_child(wide)
	wide.refresh(spec, run)
	wide.use_inlay(false)
	t.eq(wide.inlay(), "wide", "战利品屏：宽嵌槽")
	t.eq(wide.shown(), StatsStrip.ORDER, "还是耐力 / DPS / 负重三张")
	t.eq(wide.tag_rect(StatsStrip.STAMINA).size.x, 152.0, "签宽 152")
	t.eq(String(wide.get_meta(&"tone")), "dark", "铜面板上浅字")
	t.eq(wide.span_for(100.0), 152.0 * 3 + 12.0 * 2, "复测 v3.79：棋盘比三张签窄，整条按签宽")
	t.eq(wide.span_for(600.0), 600.0, "棋盘更宽：跟棋盘一样宽")
	var bold := UiPalette.cjk_font_bold()
	t.check(StatsStrip.fit_size(bold, "37 / 40", 17, 40.0) < 17, "放不下：收字号")
	t.eq(StatsStrip.fit_size(bold, "37 / 40", 17, 400.0), 17, "放得下：原字号")
	t.eq(StatsStrip.fit_size(bold, "37 / 40", 17, 1.0), StatsStrip.MIN_TEXT_SIZE, "最小收到 MIN_TEXT_SIZE")
	var strip := StatsStrip.new()
	root.add_child(strip)
	strip.use_inlay(true, StatsStrip.ORDER_PLAYER)
	strip.refresh(spec, run)
	t.eq([strip.inlay(), strip.shown()], ["narrow", StatsStrip.ORDER_PLAYER], "战前屏自己那排：生命 / 耐力 / 耗气 / DPS / 负重")
	t.eq(strip.texts(StatsStrip.HP), [str(spec.max_hp_int()), "生命"] as Array[String], "生命签 = 生命上限")
	t.eq(strip.texts(StatsStrip.VIGOR), [str(StatsStrip.vigor_of(spec)), "耐力"] as Array[String], "耐力签 = 耐力上限")
	t.check(StatsStrip.vigor_of(spec) > 0, "耐力上限有数")
	var row: Dictionary = UiTheme.art_meta(StatsStrip.BATTLE_LAYOUT).get("prebattle_row", {})
	var widths: Dictionary = row.get("tag_w", {})
	t.eq(strip.tag_rect(StatsStrip.HP).position.x, 0.0, "从左沿排起")
	t.eq(strip.tag_rect(StatsStrip.STAMINA).size.x, float(widths.get("stamina", 0)), "耗气签宽照 prebattle_row")
	t.eq(strip.tag_rect(StatsStrip.VIGOR).position.x, float(widths.get("hp", 0)) + float(row.get("gap", 0)), "签间隔照 prebattle_row")
	var foe := run.compile_player()
	foe.immune_buffs.assign([&"bleed"])
	var es := StatsStrip.new()
	root.add_child(es)
	es.use_inlay(true, StatsStrip.ORDER_ENEMY)
	es.refresh(foe, null)
	t.eq(es.shown(), StatsStrip.ORDER_ENEMY, "敌人那排：生命 / 耐力 / 耗气 / DPS / 特殊能力")
	t.eq(es.texts(StatsStrip.SPECIAL), [str(StatsStrip.specials_of(foe).size()), "特殊能力"] as Array[String], "特殊能力：条数")
	t.check(es.tip_text(StatsStrip.SPECIAL).contains("免疫流血"), "悬浮窗写免疫：%s" % es.tip_text(StatsStrip.SPECIAL))
	t.eq(StatsStrip.specials_of(CombatantSpec.new()), [] as Array[String], "什么都没有：空")
	UiText.lang = "en"
	es.refresh(CombatantSpec.new(), null)
	strip.refresh(spec, run)
	var sub: Dictionary = (row.get("text", {}) as Dictionary).get("sub", {})
	var sub_x := float((sub.get("pos_in_tag", [36, 37]) as Array)[0])
	var regular := UiPalette.cjk_font()
	for pair in [[es, StatsStrip.ORDER_ENEMY], [strip, StatsStrip.ORDER_PLAYER]]:
		for k in (pair[1] as Array):
			var s := String((pair[0] as StatsStrip).texts(k)[1])
			var room := (pair[0] as StatsStrip).tag_rect(k).size.x - sub_x - StatsStrip.TEXT_RIGHT_PAD
			var w := regular.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, StatsStrip.fit_size(regular, s, int(sub.get("size", 11)), room)).x
			t.check(w <= room + 0.5, "游戏测试 v3.81：英文小字「%s」不伸出签（%.0f ≤ %.0f）" % [s, w, room])
	UiText.lang = "zh"
	for s in [wide, strip, es]:
		(s as Node).queue_free()
	Support.cleanup("stripbronze")
