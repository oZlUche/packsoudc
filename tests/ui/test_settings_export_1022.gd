## 游戏测试 10-22：设置页「导出平衡数据」的告示压住了标题牌（整条路径太长）—— 只写放到哪 + 文件名，卷排在标题牌下面
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "settings_export_1022"


static func frame_export_notice(t: TestCase, root: Window) -> void:
	t.begin("游戏测试 10-22 · 导出平衡数据：告示短、排在标题牌下面")
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX)
	f.settings = GameSettings.new()
	var screen = load("res://ui/game/settings_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({})
	var plate: Control = screen._plate
	t.not_null(plate, "有标题牌")
	if plate != null:
		t.check(screen.notice_top() >= plate.get_global_rect().end.y, "告示卷顶在标题牌下沿以下（%s / %s）" % [screen.notice_top(), plate.get_global_rect()])
	var lang0 := UiText.lang
	UiText.lang = "zh"
	t.eq(screen.export_notice("C:/Users/me/Desktop/背包搜打撤-数据-2026-10-22.zip"), "已导出到桌面：背包搜打撤-数据-2026-10-22.zip", "桌面：只写文件名")
	t.eq(screen.export_notice("user://背包搜打撤-数据-2026-10-22.zip"), "已导出到存档文件夹：背包搜打撤-数据-2026-10-22.zip", "没有桌面：写存档文件夹")
	UiText.lang = "en"
	t.eq(screen.export_notice("user://x.zip"), "Exported to the save folder: x.zip", "英文")
	UiText.lang = lang0
	screen.free()
	Support.cleanup(PREFIX)
