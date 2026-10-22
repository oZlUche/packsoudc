## 228（作者 2026-10-21 17:33 选第三案）：结算第二页是回到基地的木头库间 —— 整屏一幅画（tone dark）、标题刻在挂着的浅木牌上（墨字）、
## 「继续」琥珀木牌、「一键置入」「整理」木牌 180 × 67、仓库分页签同开局的木签；第一页照旧石板石键；基地「仓库」页的两颗小钮也是木牌
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Steps177 := preload("res://tests/ui/test_result_steps_177.gd")
const PREFIX := "result228"


static func _home(b: Button) -> bool:
	return b != null and b.theme_type_variation == UiTheme.BUTTON_HOME


static func _art_of(b: Button) -> Texture2D:
	var box := b.get_theme_stylebox("normal") as StyleBoxTexture
	return box.texture if box != null else null


static func frame_storeroom_page(t: TestCase, root: Window) -> void:
	t.begin("228 · 结算第二页：整屏库间画、tone dark；标题木牌「置入仓库」浅木墨字；继续换琥珀木牌；一键置入 / 整理木牌 180 × 67；分页签木签；第一页不变")
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX, 10000.0)
	var r := Steps177._extracted_result(Steps177._defs(c)[0])
	f.last_absorbed = {"lit": 0}
	var screen = load("res://ui/game/result_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.RESULT
	screen.size = Vector2(1600, 1000)
	root.add_child(screen)
	screen.open({"result": r})
	t.check(screen.find_child("ScreenSlab", true, false) != null, "第一页照旧石板")
	t.eq(_art_of(screen.continue_button()), UiTheme.art_cached("result/btn_stone_normal"), "第一页「继续」石键")
	t.eq(screen.find_child("TitlePlank", true, false), null, "第一页没有木牌")
	screen.ledger().reveal_all()
	screen.to_step(2)
	t.eq(screen.step(), 2, "第二页")
	t.eq(screen.find_child("ScreenSlab", true, false), null, "第二页不是石板")
	var painted: Control = screen.find_child("PaintedContent", true, false)
	t.check(painted != null and UiTheme.tone_at(painted) == UiTheme.TONE_DARK, "整屏一幅画，tone dark")
	var pic := screen.find_child("PaintedBackdrop", true, false) as TextureRect
	t.check(pic != null and pic.texture != null and pic.texture.get_size() == Vector2(1920, 1080), "背景是 1920 × 1080 的库间画")
	var plank: Control = screen.find_child("TitlePlank", true, false)
	t.check(plank != null, "有标题木牌")
	if plank != null:
		t.eq(UiTheme.tone_at(plank), UiTheme.TONE_LIGHT, "木牌是浅木（tone light）")
		var labels: Array = plank.find_children("*", "Label", true, false)
		var title: Label = labels[0] if not labels.is_empty() else null
		t.check(title != null and title.text == "置入仓库", "牌上写「置入仓库」")
		if title != null:
			t.check(title.get_theme_color("font_color").get_luminance() < 0.3, "墨字（深色）")
			t.eq(title.size, Vector2(384, 72), "字落在牌面 384 × 72 上")
			t.eq(title.position, Vector2(6, 36), "牌面在图内 (6, 36)（上面是两根麻绳）")
		var nine := plank.find_children("*", "NinePatchRect", true, false)
		t.check(nine.size() == 1 and (nine[0] as NinePatchRect).patch_margin_left == 60 and (nine[0] as NinePatchRect).patch_margin_bottom == 20, "九宫格两头 60 不拉伸")
	t.eq(_art_of(screen.continue_button()), UiTheme.art_cached("result/btn_wood_continue_normal"), "继续换琥珀木牌")
	t.eq(screen.continue_button().custom_minimum_size, Vector2(252, 77), "继续 252 × 77")
	var wh = screen.get("_wh")
	for b: Button in [wh._store_btn, wh._tidy_btn]:
		t.check(_home(b) and b.custom_minimum_size == Vector2(180, 67), "「%s」木牌 180 × 67" % b.text)
	var shelf: WarehousePages = wh.shelf()
	t.eq(shelf.tab_variation, UiTheme.BUTTON_SETUP_TAB, "分页签同开局的木签")
	t.check(shelf.tab_count() > 0 and shelf.tab(0).custom_minimum_size.y == WarehousePanel.RESULT_TAB_H, "木签高 60")
	# 美术设计 10-22 01:09：仓库格子套基地那副木架框，页签在框外左边；离右沿、挂钉板各让出一截
	t.check(shelf.frame != null and shelf.frame.theme_type_variation == UiTheme.PANEL_SHELF and shelf.view.get_parent() == shelf.frame, "格子套木架框（PANEL_SHELF）")
	t.check(shelf.tab_box.get_parent() == shelf, "页签在框外")
	t.eq(shelf.frame_pad(), Vector2(44, 44), "框四边各 22")
	# 仓库右对齐那根空位两边的行距都算上：整排不顶出右沿
	var used: float = screen._area.size.x - 2.0 * screen.PAGE_MARGIN
	t.check(wh.get_combined_minimum_size().x <= used + 0.5, "仓库一行（%.0f）不超出内容区（%.0f）" % [wh.get_combined_minimum_size().x, used])
	var row_end: Control = shelf.get_parent().get_parent().get_child(-1)
	t.eq(row_end.custom_minimum_size.x, WarehousePanel.RESULT_SHELF_RIGHT, "框右边再空 24（那一排最后一件是空位）")
	screen.free()
	Support.cleanup(PREFIX)


static func frame_base_warehouse_wood(t: TestCase, root: Window) -> void:
	t.begin("228 · 基地「仓库」页的「一键置入」「整理」也是木牌（home 原尺寸），不再是平按钮")
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX + "b", 10000.0)
	var wh = WarehousePanel.new()
	root.add_child(wh)
	wh.setup(f, UiPalette.cjk_font())
	for b: Button in [wh._store_btn, wh._tidy_btn]:
		t.check(_home(b) and b.custom_minimum_size == Vector2.ZERO, "「%s」木牌、原尺寸" % b.text)
	t.eq(wh.shelf().tab_variation, &"", "面板自带的分页签照旧（基地那副由基地屏换成挂牌木签）")
	wh.free()
	Support.cleanup(PREFIX + "b")


const WarehousePanel := preload("res://ui/game/warehouse_panel.gd")
