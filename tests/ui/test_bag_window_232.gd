## 232（作者 19:23 选 2、6）：背包窗换成一只背包（四件皮料随窗宽摆、翻盖整块是把手、夹边算进凸出），腰带 1–6 格换弯皮带（圆心读表，超过 6 格退回直圆槽）
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func frame_satchel(t: TestCase, root: Window) -> void:
	t.begin("232 · 背包窗：包身 / 翻盖 / 提手徽 / 侧环按 W 摆；翻盖就是拖动把手；窗夹边时提手和侧环不出屏；收起钮在翻盖上")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var host := Control.new()
	host.size = Vector2(1600, 1000)
	root.add_child(host)
	var win := BagWindow.new()
	host.add_child(win)
	win.setup_bag(run, UiPalette.cjk_font(), func(): pass)
	t.check(win.skinned(), "换上了背包皮")
	var w := win.window_size()
	var body := win.get_node("Satchel/Body") as Control
	t.eq(body.position, Vector2(-30, -18), "包身左上 (-30, -18)")
	t.eq(body.size, w + Vector2(60, 50), "包身大小 W + 60, H + 50")
	var flap := win.get_node("Satchel/Flap") as Control
	t.eq(flap.position, Vector2(-40, -46), "翻盖左上 (-40, -46)")
	t.eq(flap.size.x, w.x + 80.0, "翻盖宽 W + 80")
	var crest := win.get_node("Satchel/Crest") as Control
	t.eq(crest.position, Vector2(w.x / 2.0 - 150.0, -100.0), "提手徽居中、拱到窗顶上")
	t.eq((win.get_node("Satchel/TabLeft") as Control).position, Vector2(-50, 92), "左侧环")
	var right := win.get_node("Satchel/TabRight") as TextureRect
	t.check(right.position == Vector2(w.x - 6.0, 92.0) and right.flip_h, "右侧环翻转、在 W - 6")
	t.eq(win.get_node("Satchel").get_index() < win._canvas.get_index(), true, "皮料在画布底下")
	t.eq(Rect2(win._header.position, win._header.size), Rect2(flap.position, flap.size), "拖动把手 = 整块翻盖")
	t.eq(win.close_button.position, Vector2(914, -6) + Vector2(w.x - 984.0, 0.0), "收起钮在翻盖上")
	# 窗变宽：皮料跟着
	win._layout_back(Vector2(1100, 700))
	t.eq(crest.position.x, 400.0, "窗宽 1100：提手徽 x 400")
	t.eq(right.position.x, 1094.0, "窗宽 1100：右侧环 x 1094")
	win._layout_back(w)
	# 夹边算凸出
	t.eq(win.outset, Rect2(50, 100, 50, 32), "凸出 左 50 上 100 右 50 下 32")
	win.move_to(Vector2(-500, -500))
	t.eq(win.position, Vector2(50, 100), "往左上拖出屏：提手、左侧环还在屏里")
	win.move_to(Vector2(5000, 5000))
	t.eq(win.position, host.size - win.size - Vector2(50, 32), "往右下拖出屏：右侧环、包底还在屏里")
	host.free()


static func frame_curved_belt(t: TestCase, root: Window) -> void:
	t.begin("232 · 腰带：1–6 格一整张弯皮带，圆心 = 表里的、半径 36 命中；7 格退回一排直圆槽")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	var belt := BeltModule.of(run) if run != null else null
	if belt == null:
		t.check(false, "这一局有腰带")
		return
	var slots := BeltSlots.new()
	root.add_child(slots)
	slots.bind(belt)
	for n in range(1, 7):
		belt.slots = n
		belt.sync_slots()
		var lay: Dictionary = BeltSlots.belt_layouts().get(str(n), {})
		t.check(slots.curved(), "%d 格：弯皮带" % n)
		t.eq(slots.custom_minimum_size, Vector2(lay["size"][0], lay["size"][1]), "%d 格：大小是图的" % n)
		for i in n:
			var want := Vector2(float(lay["centers"][i][0]), float(lay["centers"][i][1]))
			t.eq(slots.slot_center(i), want, "%d 格第 %d 个圆心" % [n, i])
			t.eq(slots.slot_at(want + Vector2(35, 0)), i, "%d 格第 %d 个：半径 36 内命中" % [n, i])
	belt.slots = 7
	belt.sync_slots()
	t.check(not slots.curved(), "7 格：退回直圆槽")
	t.eq(slots.slot_center(6), Vector2(BeltSlots.SLOT * 0.5 + 6 * (BeltSlots.SLOT + BeltSlots.GAP), BeltSlots.SLOT * 0.5), "7 格一排直的")
	slots.free()
