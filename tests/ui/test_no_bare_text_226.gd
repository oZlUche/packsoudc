## 226 批四守门（作者 2026-10-21 16:32「所有字都要放在 UI 元素上」）：headless 把各屏开一遍，凡看得见、有字的
## [Label] / [RichTextLabel]，祖先链里得有一样「算控件」的东西 —— 按钮、标题牌 / 段头签 / 价签 / 告示卷轴等字件、
## [constant UiTheme.PLATE_VARIANTS] 里的底、叠层窗的标题条、书皮窗的书页、HUD；退路字用 `exempt_bare_text` 标记豁免（开发区、飘字等）
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Setup180 := preload("res://tests/ui/test_setup_180.gd")
const Drawer139 := preload("res://tests/ui/test_base_drawer_139.gd")
const PREFIX := "bare226"

## 自己就是一块字件的类（字画在它的底上）
const TEXT_WIDGETS := ["Button", "HeaderTag", "TitlePlate", "PriceTag", "NoticeScroll", "NoticeLayer", "StatsStrip",
	"HoverTip", "ItemTooltip", "CapTile", "HudHost", "DevDrawer", "LedgerView"]


static func _class_of(n: Node) -> String:
	var s: Script = n.get_script()
	while s != null:
		if s.get_global_name() != &"":
			return String(s.get_global_name())
		s = s.get_base_script()
	return n.get_class()


## [param n] 坐在控件上没有
static func covered(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if p is Button or p.has_meta(&"exempt_bare_text") or TEXT_WIDGETS.has(_class_of(p)):
			return true
		if p is Control and UiTheme.PLATE_VARIANTS.has((p as Control).theme_type_variation):
			return true
		if p is OverlayFrame:
			var fr := p as OverlayFrame
			if fr.book or (fr.title_bar != null and fr.title_bar.is_ancestor_of(n)):
				return true
		p = p.get_parent()
	return false


## [param n] 底下看得见的裸字：["屏 · 字（节点名）"]
static func audit(n: Node, label: String) -> Array[String]:
	var out: Array[String] = []
	for c in n.find_children("*", "Label", true, false) + n.find_children("*", "RichTextLabel", true, false):
		var cc := c as Control
		if not cc.is_visible_in_tree():
			continue
		var text: String = (c as Label).text if c is Label else (c as RichTextLabel).get_parsed_text()
		if text.strip_edges() == "" or covered(c):
			continue
		out.append("%s · %s（%s）" % [label, text.replace("\n", " ").left(30), c.name])
	return out


static func _open(script: String, f: GameFlow, root: Window, payload: Dictionary = {}) -> Control:
	var screen = load("res://ui/game/%s.gd" % script).new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open(payload)
	return screen


static func frame_covered_rules(t: TestCase, root: Window) -> void:
	t.begin("226 批四守门 · 认法：按钮、白名单底、叠层标题条、书页、豁免标记算；直接摆在屏上的字不算")
	var host := Control.new()
	root.add_child(host)
	var bare := Label.new()
	bare.text = "裸字"
	host.add_child(bare)
	t.check(not covered(bare), "直接摆的字：裸")
	t.eq(audit(host, "x").size(), 1, "报出来")
	for v in [UiTheme.PANEL_PARCHMENT, UiTheme.PANEL_SUMMARY_NOTE, UiTheme.PANEL_HOME_BOX]:
		var paper := UiTheme.panel(PanelContainer.new(), -1, v)
		host.add_child(paper)
		var l := Label.new()
		l.text = "纸上"
		paper.add_child(l)
		t.check(covered(l), "%s 上的字算" % v)
	var b := Button.new()
	host.add_child(b)
	var inner := Label.new()
	b.add_child(inner)
	t.check(covered(inner), "按钮里的字算")
	var exempt := Label.new()
	exempt.set_meta(&"exempt_bare_text", "dev")
	host.add_child(exempt)
	t.check(covered(exempt), "豁免标记算")
	var fr := OverlayFrame.new()
	host.add_child(fr)
	fr.set_title("标题")
	t.check(covered(fr.title_label), "叠层标题条上的字算")
	var body := Label.new()
	fr.content.add_child(body)
	t.check(not covered(body), "石板窗正文直接摆字：裸（得垫纸）")
	var book := OverlayFrame.new(-1, OverlayFrame.SKIN_BOOK)
	host.add_child(book)
	var page := Label.new()
	book.content.add_child(page)
	t.check(covered(page), "书页上的字算")
	host.free()


static func frame_out_of_run_screens(t: TestCase, root: Window) -> void:
	t.begin("226 批四守门 · 局外：开局三页、基地家与五个页签、设置、百科、读档、主菜单（带备份告示，便条字 15 号左对齐）都没有裸字")
	DevGate.force_player = true
	var bad: Array[String] = []
	var game = Setup180._game(root, PREFIX)
	var f: GameFlow = game.flow
	var setup = game.base()
	for page in 3:
		setup.show_page(page)
		bad.append_array(audit(setup, "开局第 %d 页" % (page + 1)))
	var settings := _open("settings_screen", f, root)
	bad.append_array(audit(settings, "设置"))
	settings.free()
	var ency := _open("encyclopedia_screen", f, root)
	t.check(ency.find_children("*", "RichTextLabel", true, false).size() > 0, "百科有正文")
	bad.append_array(audit(ency, "百科"))
	ency.free()
	f.meta_backup = "user://test_bare226_meta.json.bak"
	var slots := _open("slots_screen", f, root, {"full": true})
	bad.append_array(audit(slots, "读档"))
	slots.free()
	var menu := _open("main_menu", f, root)
	var paper := menu.find_child("MenuNoticePaper", true, false) as Control
	t.check(paper != null and paper.visible, "主菜单备份告示有纸条")
	var note_line := menu.notices().get_child(0) as Label if menu.notices().get_child_count() > 0 else null
	t.check(note_line != null and note_line.get_theme_font_size("font_size") == 15 and note_line.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "便条字 15 号、左对齐")
	bad.append_array(audit(menu, "主菜单"))
	menu.free()
	f.meta_backup = ""
	game.free()
	Support.cleanup(PREFIX)
	var mf := Drawer139._flow()
	mf.achievement_defs = GameFlow.load_achievements()
	for id in [&"knife", &"bandage"]:
		var def := mf.items.get_def(id)
		if def != null:
			mf.meta.warehouse.try_add(ItemInstance.create(def))
	var base = Drawer139._screen(mf, root)
	bad.append_array(audit(base, "基地家"))
	for tab in ["warehouse", "sell", "tech", "codex", "achievements"]:
		base.show_tab(tab)
		bad.append_array(audit(base, "基地 %s" % tab))
	base.free()
	Drawer139._cleanup()
	DevGate.force_player = false
	t.eq(bad, [] as Array[String], "没有裸字")


static func frame_node_screens(t: TestCase, root: Window) -> void:
	t.begin("226 批四守门 · 局内：地图（HUD）、事件书、商店、神坛、铸炉（便条）、搜刮、保险箱都没有裸字")
	DevGate.force_player = true
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found := NodeScreens._seed_with(c, &"shop", kit.items)
	if found.is_empty():
		t.check(false, "找不到商店种子")
		DevGate.force_player = false
		return
	var f := Support.flow(c, PREFIX + "n")
	f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	var bad: Array[String] = []
	var map := _open("map_screen", f, root)
	bad.append_array(audit(map, "地图"))
	map.free()
	f.step_to(int(found["next"]))
	if f.screen == GameFlow.Screen.EVENT:
		var ev := _open("event_screen", f, root, f.last_payload)
		bad.append_array(audit(ev, "事件"))
		ev.free()
		f.choose_event(0)
	t.eq(f.screen, GameFlow.Screen.SHOP, "进了商店")
	var cases := [["shop", f.last_payload], ["altar", {}], ["forge", {}],
		["container", {"container": GridInventory.new(Vector2i(3, 3), 0, false)}]]
	if SafeModule.of(f.run) != null:
		cases.append(["safe", {}])
	for row in cases:
		var screen := _open("%s_screen" % row[0], f, root, row[1])
		bad.append_array(audit(screen, String(row[0])))
		if row[0] == "forge":
			var note := screen.find_child("ForgeNote", true, false) as Control
			t.check(note != null and note.theme_type_variation == UiTheme.PANEL_SUMMARY_NOTE, "铸炉「将铸出」几行写在便条上")
			var slot_notes: Array = []
			for i in 3:
				var sn := screen.find_child("SlotNote%d" % i, true, false) as Control
				if sn != null and sn.theme_type_variation == UiTheme.PANEL_SUMMARY_NOTE and sn.find_children("*", "RichTextLabel", true, false).size() == 1:
					slot_notes.append(sn)
			t.eq(slot_notes.size(), 3, "铸炉三槽下的小字各写在一张便条上")
		screen.free()
	DevGate.force_player = false
	Support.cleanup(PREFIX + "n")
	t.eq(bad, [] as Array[String], "没有裸字")
