## 227（作者 2026-10-21 17:25「所有的棋盘都要显示（包括格子）」）：全游戏每一块棋盘都有外框和格线 ——
## 运行时把有棋盘的屏开一遍，凡 [InventoryView]：外框（祖先里有 [BoardFrame]，或屏自己摆的框 [method BoardFrame.mark]）或仓库的棕底，
## 且格缝或棕底；源码里造 [InventoryView] 的文件都得接上框（沙盒、测试除外）
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Setup180 := preload("res://tests/ui/test_setup_180.gd")
const PREFIX := "boards227"

## 造了 [InventoryView] 却不在本文件里套框的：面板由用它的屏套（[method GameScreen._mount_bag]、背包窗、战前）；沙盒是开发工具
const STATIC_EXEMPT := {
	"res://ui/game/inventory_panel.gd": "棋盘由 _mount_bag / 背包窗 / 战前各自套框",
	"res://ui/inventory/inventory_sandbox.gd": "开发沙盒",
	"res://ui/battle/battle_sandbox.gd": "开发沙盒",
}


## 一个视图过不过：返回空串 = 过，否则是缺什么
static func problem(v: InventoryView) -> String:
	var grounded := not v.ground.is_empty()
	if not grounded and not BoardFrame.framed(v):
		return "没有外框"
	if not grounded and v.seams.is_empty():
		return "没有格缝"
	return ""


## [param n] 底下所有看得见的棋盘视图里不过的：["屏 · 路径：缺什么"]
static func audit(n: Node, label: String) -> Array[String]:
	var out: Array[String] = []
	for c in n.find_children("*", "InventoryView", true, false):
		var v := c as InventoryView
		if not v.is_visible_in_tree():
			continue
		var p := problem(v)
		if p != "":
			out.append("%s · %s：%s" % [label, n.get_path_to(v), p])
	return out


static func frame_node_screens(t: TestCase, root: Window) -> void:
	t.begin("227 · 节点屏的棋盘都有外框和格线：商店（货架、出售区、背包）、神坛祭品台、保险箱、铸炉三槽与出牌槽、搜刮 / 战利品")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var found := NodeScreens._seed_with(c, &"shop", kit.items)
	if found.is_empty():
		t.check(false, "找不到商店种子")
		return
	var f := Support.flow(c, PREFIX)
	f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	f.step_to(int(found["next"]))
	if f.screen == GameFlow.Screen.EVENT:
		f.choose_event(0)
	t.eq(f.screen, GameFlow.Screen.SHOP, "进了商店")
	var cases := [
		["shop", f.last_payload, 3],     # 背包、整排货架、出售区
		["altar", {}, 2],
		["forge", {}, 5],     # 三槽 + 出牌槽 + 背包
		["container", {"container": GridInventory.new(Vector2i(3, 3), 0, false)}, 2],
	]
	if SafeModule.of(f.run) != null:
		cases.append(["safe", {}, 2])
	var bad: Array[String] = []
	for row in cases:
		var screen = load("res://ui/game/%s_screen.gd" % row[0]).new()
		screen.flow = f
		screen.font = UiPalette.cjk_font()
		root.add_child(screen)
		screen.open(row[1])
		var views: Array = screen.find_children("*", "InventoryView", true, false)
		t.check(views.size() >= 2, "%s：有 %d 块棋盘" % [row[0], views.size()])
		bad.append_array(audit(screen, String(row[0])))
		var frames: Array = screen.find_children("*", "BoardFrame", true, false)
		t.check(frames.size() >= int(row[2]) or row[0] == "container", "%s：%d 块 BoardFrame" % [row[0], frames.size()])
		screen.free()
	t.eq(bad, [] as Array[String], "都有外框和格线")
	Support.cleanup(PREFIX)


static func frame_kinds(t: TestCase, root: Window) -> void:
	t.begin("227 · 框的种类：棋盘皮带、槽和出售区素框；铸炉夜里用深色；浅内垫浅缝、铜面板深内垫深缝；没写种类按棋盘 / 非棋盘自己挑")
	var board := InventoryView.new()
	board.inventory = GridInventory.new(Vector2i(4, 3), 0, true)
	var slot := InventoryView.new()
	slot.inventory = GridInventory.new(Vector2i(2, 2), 0, false)
	var host := VBoxContainer.new()
	root.add_child(host)
	host.add_child(board)
	host.add_child(slot)
	var fb := BoardFrame.wrap(board)
	var fs := BoardFrame.wrap(slot)
	t.eq([fb.kind, fs.kind], ["player", "plain"], "棋盘 → player，槽 → plain")
	t.eq([fb.get_index(), fs.get_index()], [0, 1], "框占原来的位置")
	t.check(board.get_parent() == fb and slot.get_parent() == fs, "视图进了框")
	t.eq(board.seams, BoardFrame.light_seams(), "浅框浅缝")
	var sb := fb.get_theme_stylebox("panel") as StyleBoxTexture
	t.check(sb != null and is_equal_approx(sb.content_margin_left, 24.0), "皮带框缩进 24（cells_offset）")
	t.eq(fs.inset(), 16.0, "素框缩进 16")
	var dark := InventoryView.new()
	dark.inventory = GridInventory.new(Vector2i(2, 2), 0, false)
	host.add_child(dark)
	var fd := BoardFrame.wrap(dark, "plain", true)
	t.check(fd.dark and (fd.get_theme_stylebox("panel") as StyleBoxTexture) != null, "深色素框有图（board 的 plain_dark）")
	t.eq(dark.seams, BoardFrame.light_seams(), "plain_dark 内垫是浅灰：浅缝")
	var bronze := InventoryView.new()
	bronze.inventory = GridInventory.new(Vector2i(2, 2), 0, true)
	host.add_child(bronze)
	BoardFrame.around(bronze, "player")
	t.eq(bronze.seams, BoardFrame.dark_seams(), "铜面板深框深缝")
	var own := InventoryView.new()
	own.inventory = GridInventory.new(Vector2i(2, 2), 0, false)
	host.add_child(own)
	t.check(not BoardFrame.framed(own), "没套框的不算")
	BoardFrame.mark(own, host)
	t.check(BoardFrame.framed(own) and own.seams == BoardFrame.light_seams(), "屏自己摆框的登记一下就算，格缝浅色")
	host.free()


static func frame_setup_pages(t: TestCase, root: Window) -> void:
	t.begin("227 · 开局第一页的棋盘预览、第二页的棋盘都套皮带框 + 格缝，仓库照旧棕底")
	var game = Setup180._game(root, PREFIX + "s")
	var setup = game.base()
	var bad: Array[String] = []
	for page in 2:
		setup.show_page(page)
		bad.append_array(audit(setup, "开局第 %d 页" % (page + 1)))
	t.check(setup._preview_view != null and BoardFrame.framed(setup._preview_view), "第一页预览有框")
	t.check(setup._board_view != null and BoardFrame.framed(setup._board_view), "第二页棋盘有框")
	t.eq(bad, [] as Array[String], "都有外框和格线")
	game.free()
	Support.cleanup(PREFIX + "s")


static func frame_notice_cap_tent(t: TestCase, root: Window) -> void:
	t.begin("233 复测：帐篷屏告示只留一卷（第二卷会压住窗顶布招牌），别的叠层照旧两卷")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, PREFIX + "n")
	f.begin(c.chapter, kit, 1)
	f.pick_spawn(f.run.map.entry_ids[0])
	for row in [["shop", 1], ["altar", NoticeLayer.MAX_LINES]]:
		var screen = load("res://ui/game/%s_screen.gd" % row[0]).new()
		screen.flow = f
		screen.font = UiPalette.cjk_font()
		root.add_child(screen)
		screen.open({})
		t.eq(screen.notice_cap(), int(row[1]), "%s：最多 %d 卷" % row)
		screen.say("一")
		screen.warn("二")
		NoticeLayer.post(screen.overlay_frame().content, "三")
		t.eq(screen.notice_layer().lines().size(), int(row[1]), "%s：连说三句挂着 %d 卷" % row)
		t.eq(screen.notice_layer().current_text(), "三", "最新的在")
		screen.free()
	Support.cleanup(PREFIX + "n")


static func frame_static_sources(t: TestCase, _root: Window) -> void:
	t.begin("227 · 源码守门：ui 下凡是造了 InventoryView / LootView 的文件，都接了 BoardFrame（wrap / around / mark）或仓库棕底（沙盒、面板除外）")
	var bad: Array[String] = []
	var files: Array[String] = []
	_collect("res://ui", files)
	for path in files:
		if STATIC_EXEMPT.has(path):
			continue
		var src := FileAccess.get_file_as_string(path)
		if not (src.contains("InventoryView.new()") or src.contains("LootView.new()")):
			continue
		if not (src.contains("BoardFrame.") or src.contains(".ground = ")):
			bad.append(path)
	t.eq(bad, [] as Array[String], "%d 个文件都接了框" % files.size())
	for path in STATIC_EXEMPT:
		t.check(FileAccess.file_exists(path), "豁免的文件还在：%s" % path)


static func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)
