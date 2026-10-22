## 235（作者 2026-10-22「按推荐来」）：顶端栏丙款皮 —— 两头是真按钮（左 = 本局菜单，右 = 背包，右槽小背包钮并进来），
## 栏里的组按两头石块外沿 + 间隙排、在石块上下沿之间居中；正中下半圆日晷（底座归栏，扇面 / 指针 / 轴心归倒计时那件）；
## 旧布局里的 `bag_button` 静默丢掉、不整份回默认
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const HudBarScript := preload("res://ui/hud/widgets/hud_bar.gd")
const HOST_SIZE := Vector2(1600, 1000)
const PROBE := "test_topbar235"


## 记下两头按了哪头（地图屏的 `hud_end`）
class FakeScreen:
	extends Control
	var _tip: HoverTip
	var ends: Array[StringName] = []

	func hud_end(side: StringName) -> void:
		ends.append(side)


static func _host(root: Window, screen: Control) -> Array:
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		return []
	var layout := HudLayout.default_for("map")
	for id in [&"encumbrance", &"buffs", &"erosion", &"distances"]:
		layout.entry_of(id)["visible"] = false
	var host := HudHost.new()
	host.size = HOST_SIZE
	root.add_child(host)
	host.setup(run, screen, layout)
	host.arrange()
	return [host, run]


static func frame_skin(t: TestCase, root: Window) -> void:
	t.begin("235 · 丙款栏皮：栏高 86；组左右各让 100（石块外沿 + 12）、在石块上下沿 8～78 之间居中；栏里的件带自己的凹槽；两头 104 宽贴屏边、热区是凸起的石块")
	t.check(HudBarScript.has_skin(), "丙款皮的图在")
	var screen := FakeScreen.new()
	screen.size = HOST_SIZE
	root.add_child(screen)
	var got := _host(root, screen)
	if got.is_empty():
		t.check(false, "开不了局")
		screen.queue_free()
		return
	var host: HudHost = got[0]
	var bar := host.widget(&"hud_bar")
	t.eq(host.bar_height(), 86.0, "栏高 = 石面 86（投影与日晷下凸不占布局）")
	t.eq(host.bar_side(), 100.0, "左右各让 100")
	t.eq(bar.get_theme_stylebox("panel").get_class(), "StyleBoxEmpty", "栏的底空着（皮由栏自己画）")
	var vit := host.widget(&"vitality")
	t.check(absf(vit.position.x - 100.0) < 0.5, "心格从 x 100 开始（%s）" % vit.position.x)
	t.check(absf(vit.position.y + vit.size.y * 0.5 - 43.0) <= 1.0, "左组在 8～78 之间居中（%s）" % (vit.position.y + vit.size.y * 0.5))
	t.eq(host._bar_frame(), Rect2(100, 8, HOST_SIZE.x - 200.0, 70), "栏里排组的那块：x 100 ～ 屏宽 − 100，y 8 ～ 78")
	var wallet := host.widget(&"wallet")
	t.eq(wallet.theme_type_variation, UiTheme.PANEL_HUD_WELL, "栏里的件坐在米色凹槽里（长槽退役）")
	t.eq(UiTheme.tone_at(wallet), UiTheme.TONE_LIGHT, "浅底墨字")
	t.eq(host.overhang(), 124.0, "栏往下伸到日晷下沿 124（告示卷排在它下面）")
	host.layout.entry_of(&"wallet")["anchor"] = "top_left"
	host.layout.entry_of(&"wallet")["offset"] = Vector2(0, 20)
	host.arrange()
	t.eq(wallet.theme_type_variation, UiTheme.PANEL_HUD, "拖出栏：回通用凹槽")
	host.layout.entry_of(&"wallet")["anchor"] = "bar_left"
	host.layout.entry_of(&"wallet")["offset"] = Vector2.ZERO
	host.arrange()
	t.eq(wallet.theme_type_variation, UiTheme.PANEL_HUD_WELL, "拖回栏：又是米色凹槽")
	var left: IconButton = bar.call("end_button", HudBarScript.LEFT)
	var right: IconButton = bar.call("end_button", HudBarScript.RIGHT)
	t.check(left != null and right != null and left.has_art() and right.has_art(), "两头是图按钮")
	if left == null or right == null:
		host.queue_free()
		screen.queue_free()
		return
	t.eq([left.global_position, right.global_position], [Vector2.ZERO, Vector2(HOST_SIZE.x - 104.0, 0.0)], "两头贴屏边")
	t.eq(bar.call("end_rect", HudBarScript.LEFT), Rect2(8, 8, 80, 70), "左头热区 [8, 8, 88, 78]")
	t.eq(bar.call("end_rect", HudBarScript.RIGHT), Rect2(HOST_SIZE.x - 104.0 + 16.0, 8, 80, 70), "右头热区 [16, 8, 96, 78]")
	t.check(not left._has_point(Vector2(4, 4)) and left._has_point(Vector2(50, 40)), "石块外的投影不算")
	var normal := left.icon
	left._set_hover(true)
	var hover := left.icon
	left._set_down(true)
	var pressed := left.icon
	left._set_down(false)
	left._set_hover(false)
	t.check(normal != null and hover != null and pressed != null and normal != hover and hover != pressed and left.icon == normal, "三态：常态 / 悬停 / 按下各一张")
	t.check(left.tooltip_text.begins_with("本局菜单（Esc）") and right.tooltip_text.begins_with("背包（B）"), "悬浮窗：本局菜单 / 背包")
	left.pressed.emit()
	right.pressed.emit()
	t.eq(screen.ends, [&"left", &"right"] as Array[StringName], "按下：交给所在屏的 hud_end")
	t.eq(host.rect_of(&"bag_end"), bar.call("end_rect", HudBarScript.RIGHT), "教程目标 bag_end = 右头的石块")
	t.eq(host.rect_of(&"menu_end"), bar.call("end_rect", HudBarScript.LEFT), "教程目标 menu_end = 左头的石块")
	t.eq(CoachOverlay.problems([{"target": "bag_end", "text": "x", "texts": {"en": "x"}}]), [] as Array[String], "教程认得栏两头")
	host.queue_free()
	screen.queue_free()


static func frame_dial(t: TestCase, root: Window) -> void:
	t.begin("235 · 下半圆日晷：底座在栏正中（轴心 800, 6），倒计时那件在栏里只画扇面 / 指针 / 轴心；180° 在左、90° 正下、0° 在右；晷面算停在这件上；拖出栏回小日规")
	var screen := FakeScreen.new()
	screen.size = HOST_SIZE
	root.add_child(screen)
	screen._tip = HoverTip.new()
	screen.add_child(screen._tip)
	var got := _host(root, screen)
	if got.is_empty():
		t.check(false, "开不了局")
		screen.queue_free()
		return
	var host: HudHost = got[0]
	var run: RunState = got[1]
	var bar := host.widget(&"hud_bar")
	var cd = host.widget(&"countdown")
	var cdm := CountdownModule.of(run)
	t.check(cdm != null and cdm.has_countdown() and cd.visible, "这一局有倒计时")
	if cdm == null or not cdm.has_countdown():
		host.queue_free()
		screen.queue_free()
		return
	t.eq(bar.call("dial_pivot"), Vector2(800, 6), "轴心在栏正中、y 6")
	t.eq(cd.theme_type_variation, UiTheme.PANEL_BARE, "栏里的日晷不带凹槽（画在栏皮的晷面上）")
	var lim := cdm.limit()
	var cases := [[0, Vector2(800 - 94, 6)], [lim / 2.0, Vector2(800, 100)], [lim, Vector2(800 + 94, 6)]]
	for cs in cases:
		run.travel.clock.total = int(cs[0])
		cd.refresh()
		var tip: Vector2 = cd.global_position + cd.hand_tip()
		if float(cs[0]) == lim / 2.0 and lim % 2 == 1:
			continue     # 奇数步数取不到正一半
		t.check(tip.distance_to(cs[1]) < 1.0, "用掉 %s / %d：指针尖在 %s（%s）" % [cs[0], lim, cs[1], tip])
	t.check(cd._has_point(Vector2(800, 90) - cd.global_position), "晷面下半圆算停在日晷上")
	t.check(not cd._has_point(Vector2(800, 140) - cd.global_position), "晷面外不算")
	t.eq(host.rect_of(&"countdown"), Rect2(800 - 102, 6, 204, 102), "教程指整块晷面")
	run.travel.clock.total = 0
	cd.refresh()
	cd.open_tip()
	t.check((screen._tip as HoverTip).is_showing(), "停上去：开悬浮窗")
	cd.close_tip()
	host.layout.entry_of(&"countdown")["anchor"] = "top_left"
	host.layout.entry_of(&"countdown")["offset"] = Vector2(0, 100)
	host.arrange()
	t.check(not cd.in_bar and cd.theme_type_variation == UiTheme.PANEL_HUD and cd.custom_minimum_size.y > 0.0, "拖出栏：回自带凹槽的小日规")
	t.eq(cd.hand_tip(), Vector2.INF, "不在栏里：不画栏上的指针")
	host.queue_free()
	screen.queue_free()


static func frame_notice_top(t: TestCase, root: Window) -> void:
	t.begin("235 · 告示卷：地图屏说的话让到日晷下面（top），别的屏照旧 y 78；set_top 让挂着的卷跟着挪（开局屏留下的那卷）")
	var layer := NoticeLayer.new()
	root.add_child(layer)
	layer.push("一", false, NoticeLayer.MAX_LINES, 0.0, 130.0)
	var col := layer.get_node("Scrolls") as Control
	t.eq(col.offset_top, 130.0, "带 top：卷顶 130")
	layer.push("二")
	t.eq(col.offset_top, NoticeLayer.TOP, "不带：回 78")
	layer.set_top(130.0)
	t.eq(col.offset_top, 130.0, "set_top：挂着的卷跟着挪")
	layer.set_top(10.0)
	t.eq(col.offset_top, NoticeLayer.TOP, "不到 78 按 78")
	layer.queue_free()


static func run_layout(t: TestCase) -> void:
	t.begin("235 · 右槽小背包钮退役：登记表与默认布局都没有；旧布局文件里的 bag_button 静默丢掉，别的摆法照用（不整份回默认）")
	t.check(not HudWidgets.has(&"bag_button") and HudLayout.default_for("map").entry_of(&"bag_button").is_empty(), "没有 bag_button")
	t.eq(HudLayout.BAR_RIGHT, [&"reopen_button", &"skills", &"dev_drawer"] as Array[StringName], "右槽：放大镜、技能、调试台箭头")
	var problems: Array[String] = []
	var old := HudLayout.from_dict({"widgets": [{"id": "wallet", "anchor": "top_left", "offset": [40, 120]}, {"id": "bag_button", "anchor": "bar_right"}]}, problems)
	t.check(old != null and problems.is_empty() and old.entry_of(&"bag_button").is_empty(), "读得进来、不报错、没有 bag_button（%s）" % "；".join(problems))
	var path := HudLayout.user_path(PROBE)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"screen": PROBE, "version": HudLayout.VERSION, "widgets": [
		{"id": "wallet", "anchor": "top_left", "offset": [40, 120], "tier": "double"},
		{"id": "bag_button", "anchor": "bar_right", "offset": [0, 0], "tier": "small"}]}))
	f.close()
	var loaded := HudLayout.load_for(PROBE)
	t.eq(String(loaded.entry_of(&"wallet").get("anchor", "")), "top_left", "存的摆法照用（货币还在左上角）")
	HudLayout.reset(PROBE)
	var coach := CoachOverlay.load_steps(&"prologue_map")
	t.check(coach.any(func(s: Dictionary) -> bool: return String(s["target"]) == "bag_end"), "序章教程的背包那步指栏的右头")
