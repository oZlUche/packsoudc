## 271（作者 2026-11-03 11:10）：鼠标按下时手指下压 —— 箭头 / 按钮上的小手换按下帧，松开、失焦、离窗还原；出征页场景图位
extends RefCounted


static func run_press(t: TestCase) -> void:
	t.begin("271：按钮上的小手用箭头那张；三套都有按下帧；按下 / 松开切 UiCursor.pressed，重复按下不重复换")
	t.eq(UiCursor.SHAPES.get("pointing_hand"), Input.CURSOR_POINTING_HAND, "小手形状有图")
	t.eq(UiCursor.FILE_OF.get("pointing_hand"), "arrow", "用箭头那张（整局一只手套）")
	for skin in UiCursor.SKINS:
		var a := UiTheme.art("cursors/%s/cursor_arrow" % skin)
		var p := UiTheme.art("cursors/%s/cursor_arrow_pressed" % skin)
		t.check(p != null and a != null and p.get_size() == a.get_size(), "%s：按下帧在、和箭头同尺寸" % skin)
	UiCursor.apply()
	t.check(not UiCursor.pressed, "装上时是松开的")
	UiCursor.press(true)
	t.check(UiCursor.pressed, "按下")
	UiCursor.press(true)
	t.check(UiCursor.pressed, "再按下一次还是按下")
	UiCursor.press(false)
	t.check(not UiCursor.pressed, "松开")
	UiCursor.press(true)
	UiCursor.apply()
	t.check(not UiCursor.pressed, "换材质时还原")


static func frame_director(t: TestCase, _root: Window) -> void:
	t.begin("271：导演接鼠标键（按下 / 松开）、失焦 / 离窗还原")
	var d := GameDirector.new()
	UiCursor.apply()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	d._input(ev)
	t.check(UiCursor.pressed, "左键按下")
	d._notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	t.check(not UiCursor.pressed, "鼠标离窗：还原")
	d._input(ev)
	d._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.check(not UiCursor.pressed, "失焦：还原")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	d._input(wheel)
	t.check(not UiCursor.pressed, "滚轮不算按下")
	d.free()
	var meta: GDScript = load("res://ui/game/meta_screen.gd")
	t.eq(meta.SCENES.get("expedition"), "home/scene_expedition", "出征页场景图位")
	t.eq(meta.backdrop_of("expedition"), "home/scene_expedition" if UiTheme.art("home/scene_expedition") != null else UiTheme.ART_HOME_BG, "缺图回基地底图")
