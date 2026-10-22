## UI替换美术 10-22：暂停窗打开时，地图那一屏留着的告示（「挑一个出生点」）收掉、不压在窗上；
## 设置页的标题牌固定在板顶刻线上，滚动框从它下面开始（滚过去的内容不压刻线）
extends RefCounted

const Pawn := preload("res://tests/ui/test_pawn_184.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_pause_clears_notices(t: TestCase, root: Window) -> void:
	t.begin("UI替换美术 10-22 · 暂停窗打开：地图的告示收掉；窗里再说的照常出来")
	var game = Pawn._map(root, "pause1022")
	var map = game.base()
	if map.screen != GameFlow.Screen.MAP:
		t.check(false, "进了地图屏")
		game.queue_free()
		return
	map.say("挑一个出生点")
	var layer: NoticeLayer = map.notice_layer()
	t.check(not layer.lines().is_empty(), "地图上有一卷告示")
	map.toggle_pause()
	t.check(map.pause_open(), "暂停窗开了")
	t.check(layer.lines().is_empty(), "打开暂停窗：地图的告示收掉")
	map.say("窗里的一句")
	t.eq(layer.lines().size(), 1, "窗开着时再说的照常出来")
	map.toggle_pause()
	game.queue_free()
	Support.cleanup("pause1022")


static func frame_settings_plate_outside_scroll(t: TestCase, root: Window) -> void:
	t.begin("UI替换美术 10-22 · 设置页：标题牌不在滚动框里，滚动框从标题牌下面开始")
	var c = NodeScreens._content()
	var f := Support.flow(c, "settings1022")
	f.settings = GameSettings.new()
	var screen = load("res://ui/game/settings_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({})
	var plate: Control = screen._plate
	t.not_null(plate, "有标题牌")
	var scrolls: Array = screen.find_children("*", "ScrollContainer", true, false)
	t.eq(scrolls.size(), 1, "一个滚动框")
	if plate != null and scrolls.size() == 1:
		var scroll := scrolls[0] as ScrollContainer
		t.check(not scroll.is_ancestor_of(plate), "标题牌在滚动框外面，不跟着滚")
		t.check(plate.get_parent() == scroll.get_parent() and plate.get_index() < scroll.get_index() and scroll.get_parent() is VBoxContainer,
			"标题牌与滚动框同在一列、标题牌在上：滚动框从标题牌下面开始")
	screen.free()
	Support.cleanup("settings1022")
