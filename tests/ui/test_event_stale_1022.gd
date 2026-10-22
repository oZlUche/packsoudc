## 作者 2026-10-22：序章第三次搜索遇敌，点【迎战】没反应 —— 事件屏和局里等着选的事件对不上时照局里的往下走；
## 本地日志里的「Lambda capture was freed」：滚动框的回调连在容器上，屏关了摘不掉
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "event_stale_1022"


static func frame_stale_event_moves_on(t: TestCase, root: Window) -> void:
	t.begin("作者 10-22 · 事件屏是死页（局里没有等着选的事件了）：点选项照局里的往下走，不卡在这一屏")
	var c := NodeScreens._content()
	var kit := NodeScreens._kit(c)
	var found := NodeScreens._seed_with(c, &"search", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是搜索点的种子")
		return
	var f := Support.flow(c, PREFIX)
	f.begin(c.chapter, kit, int(found["seed"]))
	f.pick_spawn(int(found["entry"]))
	t.check(f.step_to(int(found["next"])), "走上搜索点")
	t.eq(f.screen, GameFlow.Screen.EVENT, "事件屏")
	var screen = load("res://ui/game/event_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.EVENT
	root.add_child(screen)
	screen.open(f.last_payload)
	f.run.events.pending = {}     # 局里那一个已经没了，屏还开着
	t.check(not screen.choose(0), "选不了")
	t.eq(f.screen, GameFlow.Screen.MAP, "照局里的往下走：回地图")
	screen.free()
	Support.cleanup(PREFIX)


static func frame_scroll_box_lets_go(t: TestCase, root: Window) -> void:
	t.begin("本地日志 10-22 · 滚动框跟格子视图自己的尺寸走：容器长高照样跟，框关了容器上不留回调")
	var inv := GridInventory.new(Vector2i(4, 2), 1)
	var before := inv.changed.get_connections().size()
	var view := InventoryView.new()
	view.set_inventory(inv)
	var sc := ScrollBox.wrap(view, 10)
	root.add_child(sc)
	var h0 := sc.custom_minimum_size.y
	inv.grow_rows(3)
	t.eq(sc.custom_minimum_size.y, h0 / 2.0 * 5.0, "容器长高了 3 行：框跟着高")
	sc.free()
	t.eq(inv.changed.get_connections().size(), before, "框关了：容器上不留回调")
