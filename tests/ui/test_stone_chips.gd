## 乙 石刻小控件（UI替换美术 kit，作者 18:27 选乙）落在设置屏：选项签 `StoneChip`（选中 = chip_on，宽按粗体留，底色签带色样）、
## 开关行（chip_normal 拉满、左头印）、音量步进件 `StoneStepper`（[−][音效 80%][+]）；滚动条全局换 `kit/sb_*`
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")
const TechTree := preload("res://tests/meta/test_tech_tree.gd")
const PREFIX := "stone_chips"


static func frame_settings_stone(t: TestCase, root: Window) -> void:
	t.begin("乙 石刻：设置屏的选项签、开关行、音量步进件；滚动条用石槽")
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX)
	f.settings = GameSettings.new()
	var screen = load("res://ui/game/settings_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({})
	var chips: Array = screen._mode_btns.values() + screen._cursor_btns.values() + screen._bg_btns.values()
	t.check(chips.all(func(b: Button) -> bool: return b is StoneChip and b.toggle_mode), "窗口 / 光标 / 底色都是石签、可切换")
	var on: StoneChip = screen._mode_btns["windowed"]
	t.check(on.button_pressed and (on.get_theme_stylebox("pressed") as StyleBoxTexture).texture == UiTheme.art_cached("kit/chip_on"), "选中用 chip_on")
	t.eq(on.get_combined_minimum_size().y, StoneChip.HEIGHT, "签高 40")
	var bold_w := UiPalette.cjk_font_bold().get_string_size(on.text, HORIZONTAL_ALIGNMENT_LEFT, -1, StoneChip.FONT_SIZE).x
	t.check(absf(on.get_combined_minimum_size().x - (bold_w + 2.0 * StoneChip.PAD_X)) <= 1.0, "宽 = 粗体字宽 + 38")
	var bg: StoneChip = screen._bg_btns.values()[0]
	t.check(bg.swatch.a > 0.0, "底色签带色样")
	t.eq((bg.get_theme_stylebox("normal") as StyleBoxTexture).content_margin_left, StoneChip.PAD_X + StoneChip.SWATCH_ROOM, "字往右让出色样")
	var toggles: Array = [screen._auto_close_btn, screen._fades_btn, screen._unlock_all_btn]
	t.check(toggles.all(func(b: Button) -> bool: return b is StoneChip and b.check), "三个开关行是石签开关")
	t.eq((screen._fades_btn.get_theme_stylebox("pressed") as StyleBoxTexture).texture, UiTheme.art_cached("kit/chip_normal"), "开关行开着底也是平的（看左头印）")
	var sfx: StoneStepper = screen._sfx
	t.check(sfx != null and sfx.plate.text == UiText.t("settings.sfx_volume") % roundi(f.settings.sfx_volume * 100.0), "读数写在步进件石牌上（%s）" % (sfx.plate.text if sfx != null else ""))
	if sfx != null:
		var before := sfx.plate.text
		sfx.minus.pressed.emit()
		t.check(sfx.plate.text != before, "点「−」读数跟着变（%s）" % sfx.plate.text)
		t.eq(sfx.minus.custom_minimum_size, Vector2(36, 36), "钮 36 × 36")
	var sb := ThemeDB.get_default_theme().get_stylebox("grabber", "VScrollBar") as StyleBoxTexture
	t.check(sb != null and sb.texture == UiTheme.art_cached("kit/sb_grab_normal"), "竖滚动条把手是石刻")
	screen.free()
	Support.cleanup(PREFIX)


static func frame_base_stone(t: TestCase, root: Window) -> void:
	t.begin("乙 石刻：基地 —— 出售两个下拉是木牌框 + 箭头 + 浅纸弹出单、一键出售主档木牌、成就筛选木牌、科技节点木牌 + 选中圈、升级主档木牌、图鉴浅格")
	var c = NodeScreens._content()
	var f := Support.flow(c, PREFIX + "b", 10000.0)
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	for ob: OptionButton in [screen._sell_pick, screen._sell_tag_pick]:
		t.check(ob.theme_type_variation == UiTheme.BUTTON_HOME and ob.get_theme_icon("arrow") == UiTheme.art_cached("kit/drop_arrow"), "下拉：木牌框 + 石刻箭头")
		var panel := ob.get_popup().get_theme_stylebox("panel") as StyleBoxTexture
		t.check(panel != null and panel.texture == UiTheme.art_cached("kit/popup"), "弹出单是浅纸")
	t.eq(screen._sell_btn.theme_type_variation, UiTheme.BUTTON_HOME_PRIMARY, "一键出售 = 主档木牌")
	t.eq(screen._shelf.tab_variation, UiTheme.BUTTON_SETUP_TAB, "仓库分页签是开局那款挂牌木签")
	t.eq(screen._shelf._tabs[0].custom_minimum_size.y, 60.0, "挂牌高 60")
	t.eq(screen._shelf._tabs[0].get_theme_color("font_disabled_color"), UiTheme.SETUP_TAB_LOCKED_INK, "锁着的页名提亮")
	for b: Button in screen._ach_filter_btns.values():
		t.check(b.theme_type_variation == UiTheme.BUTTON_HOME and b.toggle_mode, "成就筛选「%s」是木牌、可切换" % b.text)
	var tree := TechTreeView.new()
	root.add_child(tree)
	var defs: Array[TechDef] = [TechTree._tech("a"), TechTree._tech("b", ["a"])]
	tree.setup(f.meta, defs, UiPalette.cjk_font())
	tree.select(&"a")
	var box := tree.node_button(&"a").get_theme_stylebox("normal") as StyleBoxTexture
	t.check(box != null and box.texture == UiTheme.art_cached("home/btn_wood"), "可点亮的节点是木牌")
	var locked := tree.node_button(&"b").get_theme_stylebox("normal") as StyleBoxTexture
	t.check(locked != null and locked.texture == UiTheme.art_cached("home/btn_wood_disabled"), "锁住的是灰木牌")
	t.check(tree.find_child("SelRing", false, false) != null, "选中圈那层在最上面")
	tree.free()
	t.eq(screen._tech._action.theme_type_variation, UiTheme.BUTTON_HOME_PRIMARY, "升级 = 主档木牌")
	screen.show_tab("codex")
	t.check(not screen._codex_tiles.is_empty() and CodexTile._box(CodexTile.CELL_ART, 16.0) != null, "图鉴格有浅亚麻格底")
	screen.free()
	Support.cleanup(PREFIX + "b")
