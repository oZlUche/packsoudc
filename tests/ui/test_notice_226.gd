## 226 批一：告示层 —— 一句一卷（[NoticeScroll]，作者 17:25「告示签做成横向打开的卷轴」），全游戏的回话都走它
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_scroll_geometry(t: TestCase, root: Window) -> void:
	t.begin("226 批一 · 告示卷轴：纸宽 = 字宽 + 52、整卷宽 + 28、高 54；字在卷上居中；开卷从零展到全宽、轴贴着纸边；收卷完了回调")
	var s := NoticeScroll.make("那里走不过去")
	root.add_child(s)
	var tw := UiPalette.cjk_font().get_string_size("那里走不过去", HORIZONTAL_ALIGNMENT_LEFT, -1, NoticeScroll.FONT_SIZE).x
	t.eq(s.paper_rect().size.x, ceilf(tw) + 2.0 * NoticeScroll.PAD, "纸宽 = 字宽 + 2 × 26")
	t.eq(s.custom_minimum_size, Vector2(s.paper_rect().size.x + 28.0, 54.0), "整卷宽 = 纸宽 + 28、高 54")
	t.eq(s.paper_rect().position.y, 10.0, "纸在轴里垂直居中（上沿 10）")
	t.check(s.label().get_parent().clip_contents, "字用纸的矩形裁切")
	t.eq(s.label().label_settings.font_color, NoticeScroll.INK, "墨字（纸是浅色）")
	var center := s.label().get_global_rect().get_center().x
	s.amount = 0.3
	t.check(is_equal_approx(s.label().get_global_rect().get_center().x, center), "展到一半：字仍在原处（不跟着纸挪）")
	t.check(is_equal_approx(s.roller_x().x, s.paper_rect().position.x - NoticeScroll.ROLLER_OUT), "左轴贴着纸边外 4")
	t.check(s.paper_rect().size.x < ceilf(tw), "展到一半：纸还没全开")
	s.open(false)
	t.eq(s.amount, 1.0, "动效关着：直接全开")
	var tw_open := s.open(true)
	t.check(tw_open != null and s.amount == 0.0, "动效开着：从合着开始展")
	tw_open.kill()
	var done := [false]
	s.close(false, func(): done[0] = true)
	t.check(done[0] and s.amount == 0.0 and s.modulate.a == 0.0, "收卷：合上、淡掉、回调")
	var u := NoticeScroll.make("倒计时只剩 3 步", true)
	t.check(u.urgent, "要紧的一卷")
	u.free()
	s.queue_free()


static func frame_layer(t: TestCase, root: Window) -> void:
	t.begin("226 批一 · 告示层：一句一卷往下叠、最多两卷、同一句只重置时间；3 秒（要紧 5 秒）收卷；没有导演时屏自己挂一层；节点屏的回话都上卷")
	var layer := NoticeLayer.new()
	root.add_child(layer)
	layer.push("一")
	layer.push("二", true)
	t.eq(layer.lines(), ["一", "二"] as Array[String], "两卷叠着")
	t.check(layer.is_urgent() and layer.current_text() == "二", "最新的是要紧的那句")
	layer.push("一")
	t.eq(layer.lines().size(), 2, "同一句不再加一卷")
	layer.push("三")
	t.eq(layer.lines(), ["二", "三"] as Array[String], "第三句挤掉最老的")
	layer.step(3.5)
	t.eq(layer.lines(), ["二"] as Array[String], "普通的 3 秒收卷，要紧的还在")
	layer.step(2.0)
	t.check(layer.lines().is_empty(), "要紧的 5 秒也收了")
	layer.queue_free()

	var c = NodeScreens._content()
	var f := Support.flow(c, "n226")
	var screen := GameScreen.new()
	screen.flow = f
	root.add_child(screen)
	t.check(NoticeLayer.current() == null, "单测里没有导演那一层")
	screen.say("你好")
	t.check(screen.notice_layer().get_parent() == screen and screen.notice_layer().current_text() == "你好", "屏自己挂一层，字写在卷上")
	var host := Control.new()
	screen.add_child(host)
	NoticeLayer.post(host, "从子节点喊", true)
	t.eq(screen.notice_layer().current_text(), "从子节点喊", "子节点（面板、腰带）往上找到屏的那层")
	screen.queue_free()
	Support.cleanup("n226")


static func frame_no_local_lines(t: TestCase, root: Window) -> void:
	t.begin("226 批一 · 十一处本地回话行删了：商店、神坛、保险箱、铸炉、仓库面板、科技、出售、开局、读档没有 _line / _status / _hint 那一行字")
	for path in ["res://ui/game/shop_screen.gd", "res://ui/game/altar_screen.gd", "res://ui/game/safe_screen.gd", "res://ui/game/forge_screen.gd",
			"res://ui/game/warehouse_panel.gd", "res://ui/game/tech_panel.gd", "res://ui/game/slots_screen.gd"]:
		var names: Array = []
		for p in (load(path) as GDScript).get_script_property_list():
			names.append(String(p["name"]))
		t.check(not names.has("_line") and not names.has("_hint"), "%s 没有本地回话行" % path.get_file())
	var meta_props: Array = []
	for p in (load("res://ui/game/meta_screen.gd") as GDScript).get_script_property_list():
		meta_props.append(String(p["name"]))
	t.check(not meta_props.has("_sell_line"), "出售页没有回话行")
	var belt := BeltSlots.new()
	t.check(belt.find_children("*", "Label", true, false).is_empty(), "腰带不再飘字")
	belt.free()
	t.check(not HudWidgets.KINDS.has(&"notice"), "顶端栏下面的提示行组件删了")
