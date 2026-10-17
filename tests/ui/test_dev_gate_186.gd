## 186（作者 2026-10-17：内部说明不给玩家看）：调试台、基地调试段、设置里的调试节只在开发包里有（[DevGate]）；
## 玩家的回话走地图顶端栏下面的提示行 —— 拒绝原因用玩家用语、要紧的红字停得久、最多两行
extends RefCounted

const Pawn := preload("res://tests/ui/test_pawn_184.gd")
const Drawer139 := preload("res://tests/ui/test_base_drawer_139.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_gate(t: TestCase) -> void:
	t.begin("186 · DevGate：命令行跑的是开发包；打开 force_player 就是玩家包，调试模式与战斗日志默认跟着关")
	t.check(DevGate.on(), "测试是开发包")
	var gs := GameSettings.new()
	t.check(gs.debug_on(), "开发包：调试模式按存的值（默认开）")
	DevGate.force_player = true
	t.check(not DevGate.on(), "强制玩家包")
	t.check(not gs.debug_on() and gs.debug_mode, "玩家包：调试模式不生效，存的值不动")
	t.check(not BattleArchive.default_on(), "战斗日志默认关（同一个开关）")
	DevGate.force_player = false
	t.eq(HudLayout.VERSION, 7, "布局版本 7（默认布局加了提示行）")
	var d := HudLayout.default_for("map")
	t.eq(String(d.entry_of(&"notice")["anchor"]), "top", "提示行在顶端栏下面居中")
	t.check(HudWidgets.DEV_ONLY.has(&"dev_drawer"), "调试台箭头只在开发包里造")


static func frame_player_build(t: TestCase, root: Window) -> void:
	t.begin("186 · 玩家包：地图屏没有调试台箭头与抽屉、有提示行；基地屏没有调试台；设置屏没有调试模式")
	DevGate.force_player = true
	var game = Pawn._map(root, "gate186a")
	var map = game.base()
	if map.screen != GameFlow.Screen.MAP:
		t.check(false, "进了地图屏")
		DevGate.force_player = false
		game.queue_free()
		return
	t.check(map.dev_drawer() == null, "没有抽屉")
	t.check(map.hud().widget(&"dev_drawer") == null, "顶端栏右槽没有调试台箭头")
	t.not_null(map.notice_widget(), "有提示行")
	t.check(map.find_children("*", "DevDrawer", true, false).is_empty(), "整屏找不到 DevDrawer")
	game.queue_free()
	Support.cleanup("gate186a")

	var f := Drawer139._flow()
	var base = Drawer139._screen(f, root)
	t.check(base.dev_drawer() == null and not base.toggle_dev_drawer(), "基地屏没有调试台")
	t.check(base.find_children("*", "DevDrawer", true, false).is_empty(), "基地屏找不到 DevDrawer")
	base.queue_free()
	Drawer139._cleanup()

	var c = NodeScreens._content()
	var sf := Support.flow(c, "gate186s")
	sf.settings = GameSettings.new()
	var settings = load("res://ui/game/settings_screen.gd").new()
	settings.flow = sf
	settings.font = UiPalette.cjk_font()
	root.add_child(settings)
	settings.open({})
	var texts: Array[String] = []
	for n in settings.find_children("*", "Button", true, false):
		texts.append((n as Button).text)
	t.check(not texts.any(func(s: String) -> bool: return s.begins_with("调试模式") or s.begins_with("节点浮窗预览")), "设置屏没有调试模式、节点浮窗预览：%s" % [texts])
	settings.queue_free()
	Support.cleanup("gate186s")
	DevGate.force_player = false


static func frame_notice_line(t: TestCase, root: Window) -> void:
	t.begin("186 · 提示行：点不相邻的点写「那里走不过去」（不带数字），开发提示行还有原因；要紧的红、5 秒；第三句挤掉最老的")
	var game = Pawn._map(root, "gate186b")
	var map = game.base()
	if map.screen != GameFlow.Screen.MAP:
		t.check(false, "进了地图屏")
		game.queue_free()
		return
	t.not_null(map.dev_drawer(), "开发包：调试台照旧")
	var run: RunState = game.flow.run
	var here := run.travel.current_id
	var far := -1
	var moves := run.travel.available_moves()
	for id in run.map.node_ids():
		if id != here and not moves.has(id):
			far = id
			break
	var notice = map.notice_widget()
	t.not_null(notice, "有提示行")
	if notice != null:
		notice.step(10.0)     # 开局可能已经有一句（负重、倒计时……）：先等它们走完
	if far >= 0 and notice != null:
		map.step(far)
		t.eq(notice.current(), "那里走不过去", "玩家用语")
		t.check(RegEx.create_from_string("\\d").search(notice.current()) == null, "不带点号")
		t.check(map._status.text.begins_with("走不了：") and RegEx.create_from_string("\\d").search(map._status.text) != null, "开发提示行写原因（%s）" % map._status.text)
	if notice != null:
		map.extract()
		t.eq(notice.current(), "这里不是撤离点", "不在撤离点按撤离")
		t.eq(notice.lines().size(), 2, "两句叠着")
		map.warn("倒计时只剩 3 步")
		t.eq(notice.lines().size(), 2, "第三句来了：最老的走了")
		t.eq(notice.lines()[0], "这里不是撤离点", "留下的是第二句")
		t.check(notice.is_urgent(), "要紧")
		t.eq(notice.color_of(true), UiPalette.for_tone(UiPalette.HP, notice.paper_tone()), "要紧的用红（按纸的深浅）")
		notice.step(3.5)
		t.eq(notice.lines(), ["倒计时只剩 3 步"] as Array[String], "普通的 3 秒多一点淡掉，要紧的还在")
		notice.step(2.0)
		t.check(notice.lines().is_empty() and not notice.visible, "要紧的 5 秒多一点也走了，提示行收起")
		t.check(not notice.takes_space(), "不占地图的边")
	game.queue_free()
	Support.cleanup("gate186b")
