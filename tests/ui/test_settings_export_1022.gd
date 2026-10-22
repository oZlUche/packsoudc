## 游戏测试 10-22：设置页「导出平衡数据」的告示压住了标题牌（整条路径太长）—— 只写放到哪 + 文件名；v4.26 复测：卷压住「显示」段头签 —— 改排在导出石签右边
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "settings_export_1022"


static func frame_export_notice(t: TestCase, root: Window) -> void:
	t.begin("游戏测试 10-22 · 导出平衡数据：告示短；v4.26 卷排在导出石签右边，不压「显示」段头签")
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX)
	f.settings = GameSettings.new()
	var screen = load("res://ui/game/settings_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({})
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1600, 1000)     # 游戏的视口（project.godot）：列从标题牌下面紧接着起
	_lay_out(screen)     # 容器的排布是延迟的，同一帧里手动排一遍
	var plate: Control = screen._plate
	t.not_null(plate, "有标题牌")
	if plate != null:
		t.check(screen.notice_top() >= plate.get_global_rect().end.y, "告示卷顶在标题牌下沿以下（%s / %s）" % [screen.notice_top(), plate.get_global_rect()])
	var lang0 := UiText.lang
	UiText.lang = "zh"
	for p in ["C:/Users/me/Desktop/背包搜打撤-数据-2026-10-22.zip", "user://背包搜打撤-数据-2026-10-22.zip"]:
		_check_spot(t, screen, screen.export_notice(p))
	t.eq(screen.export_notice("C:/Users/me/Desktop/背包搜打撤-数据-2026-10-22.zip"), "已导出到桌面：背包搜打撤-数据-2026-10-22.zip", "桌面：只写文件名")
	t.eq(screen.export_notice("user://背包搜打撤-数据-2026-10-22.zip"), "已导出到存档文件夹：背包搜打撤-数据-2026-10-22.zip", "没有桌面：写存档文件夹")
	UiText.lang = "en"
	t.eq(screen.export_notice("user://x.zip"), "Exported to the save folder: x.zip", "英文")
	_check_spot(t, screen, screen.export_notice("user://背包搜打撤-数据-2026-10-22.zip"))
	UiText.lang = lang0
	screen.free()
	Support.cleanup(PREFIX)


## 游戏测试 v4.26：卷压住了标题牌下面「显示」段头签的右半边 —— 卷排到导出石签右边：在板面里，不压标题牌、段头签、任何按钮
static func _check_spot(t: TestCase, screen, text: String) -> void:
	t.check(screen.notice_spot(text).x != 0.0, "1600×1000 放得下：卷排在导出石签右边（%s）" % text)
	var layer: NoticeLayer = screen.notice_layer()
	layer.clear()
	screen._post(text)
	(layer.get_node("Scrolls") as Control).reset_size()     # 列的尺寸下一帧才跟着卷长，这里手动跟一遍
	_lay_out(layer)
	var s: NoticeScroll = layer.scrolls().back()
	var r := Rect2(s.global_position, s.custom_minimum_size)
	var board: Rect2 = (screen._plate.get_parent() as Control).get_global_rect()
	t.check(board.encloses(r), "告示卷在板面里（%s / %s）" % [r, board])
	t.check(r.position.x > screen._export_btn.get_global_rect().end.x, "卷在导出石签右边（%s）" % r)
	t.check(not r.intersects(screen._plate.get_global_rect()), "不压标题牌（%s）" % r)
	var hit: Array[String] = []
	for n in screen.find_children("*", "Control", true, false):
		if (n is HeaderTag or n is BaseButton) and (n as Control).is_visible_in_tree() and r.intersects((n as Control).get_global_rect()):
			hit.append("%s %s" % [n.get_class(), (n as Control).get_global_rect()])
	t.check(hit.is_empty(), "不压段头签、按钮（%s / %s）" % [r, hit])
	layer.clear()


static func _lay_out(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_lay_out(c)
