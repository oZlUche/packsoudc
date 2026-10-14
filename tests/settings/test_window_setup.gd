## 172（作者定）：固定分辨率档位（16:9 五档、16:10 三档）与窗口 / 全屏 —— 设置里存、启动和设置屏套到窗口上；
## 比屏幕大的档不列；首次启动按屏幕挑一档；全屏时分辨率灰掉；F11 切模式。headless 不碰窗口
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func run_settings_fields(t: TestCase) -> void:
	t.begin("172 · 设置：resolution 存成 [宽, 高]、读回 Vector2i；不在档位表里的回 ZERO；认不出的模式回窗口；旧文件没这两个键用默认")
	var s := GameSettings.new()
	t.eq(s.window_mode, "windowed", "默认窗口（待定 3 A）")
	t.eq(s.resolution, Vector2i.ZERO, "默认没定过")
	s.window_mode = "fullscreen"
	s.resolution = Vector2i(1920, 1080)
	var d := s.to_dict()
	t.eq(d["resolution"], [1920, 1080], "文件里写成 [1920, 1080]")
	var back := GameSettings.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(back.resolution, Vector2i(1920, 1080), "读回 Vector2i")
	t.eq(back.window_mode, "fullscreen", "模式读回")
	d["resolution"] = [1234, 567]
	d["window_mode"] = "exclusive"
	var odd := GameSettings.from_dict(d)
	t.eq(odd.resolution, Vector2i.ZERO, "怪尺寸回 ZERO（启动时重挑）")
	t.eq(odd.window_mode, "windowed", "认不出的模式回窗口")
	var old := GameSettings.from_dict({"version": GameSettings.SAVE_VERSION})
	t.check(old.window_mode == "windowed" and old.resolution == Vector2i.ZERO, "旧文件：默认")


static func run_presets(t: TestCase) -> void:
	t.begin("172 · 档位：16:9 五档、16:10 三档；首次启动挑屏幕九成里最大的一档（小屏放宽到整屏，再小随屏幕）；比屏幕大的不列")
	var nine := WindowSetup.PRESETS.filter(func(p: Vector2i) -> bool: return WindowSetup.aspect_name(p) == "16:9")
	var ten := WindowSetup.PRESETS.filter(func(p: Vector2i) -> bool: return WindowSetup.aspect_name(p) == "16:10")
	t.eq(nine.size(), 5, "16:9 五档")
	t.eq(ten.size(), 3, "16:10 三档")
	t.eq(WindowSetup.pick_default(Vector2i(1920, 1080)), Vector2i(1600, 900), "1920×1080 屏 → 1600×900")
	t.eq(WindowSetup.pick_default(Vector2i(2560, 1440)), Vector2i(1920, 1200), "2560×1440 屏 → 1920×1200")
	t.eq(WindowSetup.pick_default(Vector2i(1366, 768)), Vector2i(1280, 720), "1366×768 屏 → 1280×720")
	t.eq(WindowSetup.pick_default(Vector2i(1024, 600)), Vector2i(1024, 600), "1024×600 屏 → 随屏幕")
	var small := WindowSetup.available(Vector2i(1920, 1080))
	t.check(small.all(func(p: Vector2i) -> bool: return p.x <= 1920 and p.y <= 1080), "1920×1080 屏：不列 2560 以上（%s）" % str(small))
	t.eq(small, [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1280, 800)] as Array[Vector2i], "1920×1080 屏：16:9 三档 + 1280×800")
	t.eq(WindowSetup.available(Vector2i(3840, 2160)).size(), WindowSetup.PRESETS.size(), "4K 屏全列")
	t.eq(WindowSetup.label(Vector2i(1920, 1080)), "1920×1080", "按钮字")
	var s := GameSettings.new()
	t.check(not WindowSetup.apply(s, null), "没有窗口：不动")
	WindowSetup.toggle_mode(s)
	t.eq(s.window_mode, "fullscreen", "切到全屏")
	WindowSetup.toggle_mode(s)
	t.eq(s.window_mode, "windowed", "切回窗口")
	t.check(InputKeys.ACTIONS.has(InputKeys.TOGGLE_FULLSCREEN), "F11 动作能改键（154 补充一的改键表）")
	var f11 := InputMap.action_get_events(InputKeys.TOGGLE_FULLSCREEN)
	t.check(f11.size() == 1 and (f11[0] as InputEventKey).keycode == KEY_F11, "默认 F11")
	t.eq(bool(ProjectSettings.get_setting("display/window/size/resizable", true)), false, "窗口不可拖改")


static func frame_settings_screen(t: TestCase, root: Window) -> void:
	t.begin("172 · 设置屏「显示」一节：窗口 / 全屏两个按钮；分辨率按比例分行、每个按钮写「宽×高」；当前档按下；全屏时全灰并注一句，切回恢复；headless 下套用不报错")
	var c = NodeScreens._content()
	var f := Support.flow(c, "s172")
	f.settings = GameSettings.new()
	f.settings.resolution = Vector2i(1600, 900)
	var screen = load("res://ui/game/settings_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({})
	t.eq(screen._mode_btns.keys(), ["windowed", "fullscreen"], "窗口 / 全屏")
	t.check((screen._mode_btns["windowed"] as Button).button_pressed, "默认按下窗口")
	t.check(not screen._res_btns.is_empty(), "列了档位")
	var re := RegEx.create_from_string("^[0-9]+×[0-9]+$")
	t.check(screen._res_btns.values().all(func(b: Button) -> bool: return re.search(b.text) != null), "按钮写「宽×高」")
	t.check((screen._res_btns[Vector2i(1600, 900)] as Button).button_pressed, "当前档按下")
	screen.set_resolution(Vector2i(1920, 1080))
	t.eq(f.settings.resolution, Vector2i(1920, 1080), "换档写进设置")
	t.eq(GameSettings.load_from(String(Support.paths("s172")["settings"])).resolution, Vector2i(1920, 1080), "存盘了")
	t.check((screen._res_btns[Vector2i(1920, 1080)] as Button).button_pressed and not (screen._res_btns[Vector2i(1600, 900)] as Button).button_pressed, "按下的跟着换")
	screen.set_window_mode("fullscreen")
	t.eq(f.settings.window_mode, "fullscreen", "切全屏")
	t.check(screen._res_btns.values().all(func(b: Button) -> bool: return b.disabled), "全屏：分辨率全灰")
	t.check(screen._res_note.visible, "注「全屏按桌面分辨率」")
	screen.set_resolution(Vector2i(1280, 720))
	t.eq(f.settings.resolution, Vector2i(1920, 1080), "全屏时点分辨率不接")
	f.settings.window_mode = "windowed"     # F11 走导演：改设置后整组刷新
	root.get_tree().call_group(GameDirector.DISPLAY_GROUP, "refresh_display")
	t.check(not (screen._res_btns[Vector2i(1920, 1080)] as Button).disabled and (screen._res_btns[Vector2i(1920, 1080)] as Button).button_pressed, "切回窗口：恢复、上次那档按下")
	t.check(not screen._res_note.visible, "注藏起来")
	screen.queue_free()
	Support.cleanup("s172")
