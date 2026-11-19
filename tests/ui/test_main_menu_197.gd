## 197（作者 2026-10-19 定稿）：主菜单 —— 三张画轮换带慢镜头、描边粗体游戏名居中上方（补充三）、左下角几行字分三档（补充三）、启动屏同一张画压暗、存档目录钉死
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const Support := preload("res://tests/run/flow_support.gd")
const BOOT := "res://ui/boot.gd"


static func run(t: TestCase) -> void:
	t.begin("197 补充一 · 主菜单那几行字的样式、三张画（暗调）、启动屏的底画、存档目录不随改名走")
	var th := UiTheme.current()
	var line_font := th.get_font("font", UiTheme.BUTTON_MENU_LINE) as FontVariation
	t.check(line_font != null and line_font.base_font != null and line_font.base_font.resource_path.ends_with("serif_bold.otf"), "菜单那几行字：思源宋体 Bold")
	t.eq(th.get_font_size("font_size", UiTheme.BUTTON_MENU_LINE), 44, "主档 44 号")
	t.eq(th.get_color("font_color", UiTheme.BUTTON_MENU_LINE), Color("f0e2c4"), "暖纸色")
	t.eq(th.get_color("font_hover_color", UiTheme.BUTTON_MENU_LINE), Color("fff6e0"), "悬停提亮")
	t.eq(th.get_color("font_focus_color", UiTheme.BUTTON_MENU_LINE), Color("fff6e0"), "键盘焦点也提亮")
	t.eq(th.get_constant("outline_size", UiTheme.BUTTON_MENU_LINE), 7, "描边 7 px")
	t.eq(th.get_color("font_outline_color", UiTheme.BUTTON_MENU_LINE), Color("1a1410"), "深褐描边")
	var still := th.get_stylebox("normal", UiTheme.BUTTON_MENU_LINE)
	var sunk := th.get_stylebox("pressed", UiTheme.BUTTON_MENU_LINE)
	t.check(sunk.content_margin_top - still.content_margin_top == 1.0 and still.content_margin_left == UiTheme.MENU_LINE_INDENT, "按下下沉 1 px；左边留菱形的缩进")
	var second := UiTheme.make_menu_line("百科", 34, func(): pass)
	t.check(second.flat and second.alignment == HORIZONTAL_ALIGNMENT_LEFT and second.get_theme_font_size("font_size") == 34, "次档 34 号、左对齐")
	t.check(not UiTheme.menu_line_lit(second), "没悬停没焦点：不画菱形")
	second.free()
	t.eq(th.get_font_size("font_size", UiTheme.BUTTON_MENU_FOOT), 18, "末档小字 18 号")
	t.eq(th.get_color("font_color", UiTheme.BUTTON_MENU_FOOT), UiPalette.DIM, "末档暗色")
	t.eq(UiTheme.ART_MENU_BGS, ["menu/bg_camp", "menu/bg_legion", "menu/bg_map"] as Array[String], "顺序：营地 → 军营 → 地图")
	for n in UiTheme.ART_MENU_BGS:
		var tex := UiTheme.art(n)
		t.check(tex != null and tex.get_width() == 2112 and tex.get_height() == 1320, "%s：2112 × 1320（四边出血）" % n)
		t.eq(UiTheme.art_tone(n), UiTheme.TONE_DARK, "%s：暗调" % n)
	var boot: GDScript = load(BOOT)
	var consts := boot.get_script_constant_map()
	t.eq(consts["BACKDROP"], "res://assets/ui/menu/bg_camp.png", "启动屏底画 = 菜单第一张")
	t.eq(consts["BACKDROP_DIM"], MenuBackdrop.BOOT_DIM, "压暗那档和菜单亮起来的起点同值")
	var r: Rect2 = boot.cover_rect(Vector2(2112, 1320), Vector2(1600, 1000))
	t.check(r.position.x <= 0.0 and r.position.y <= 0.0 and r.end.x >= 1600.0 and r.end.y >= 1000.0, "启动屏的画铺满屏（%s）" % r)
	t.check(ProjectSettings.get_setting("application/config/use_custom_user_dir", false), "存档目录名钉死")
	t.check(OS.get_user_data_dir().replace("\\", "/").to_lower().ends_with("app_userdata/背包搜打撤"), "还是原来的目录（%s）" % OS.get_user_data_dir())


static func frame_menu_layout(t: TestCase, root: Window) -> void:
	t.begin("主菜单：营火与登记册，字标、主操作和页脚在目录内；键盘焦点与首次存档分支")
	var p := Support.paths("menu197")
	Support.cleanup("menu197")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var menu = game.base()
	t.check(menu != null and menu.has_method("scenery"), "底屏是主菜单")
	if menu == null or not menu.has_method("scenery"):
		game.queue_free()
		return
	t.is_null(menu.screen_slab(), "不上石板")
	var sc: MenuBackdrop = menu.scenery()
	t.eq(sc.current_name(), "menu/bg_camp", "第一张是营地（启动屏那张）")
	t.eq(sc.art_names.size(), 3, "三张画")
	t.eq(sc.live_tweens() > 0, UiMotion.enabled(game.flow.settings), "镜头跟随动效设置")
	var s: float = menu.ui_scale()
	var c: float = menu.column_scale()
	t.check(c >= 0.75 and is_equal_approx(s, menu.size.y / 1080.0), "按屏高缩放（%.3f），菜单不小于 0.75" % c)
	var title: Control = menu.title_node()
	var slab := menu.find_child("SurveyIndex", true, false) as TextureRect
	t.check(slab != null and slab.texture != null and slab.mouse_filter == Control.MOUSE_FILTER_IGNORE, "登记册有专属底纹，点击穿透")
	t.check(title is TextureRect and title.texture != null and title.texture.resource_path.contains("survey_title"), "使用独立的测绘字标")
	t.check(is_equal_approx(title.position.x + title.size.x * 0.5, slab.size.x * 0.5), "字标在书页水平居中")
	var col: VBoxContainer = menu.column()
	t.check(col.position.y >= title.get_rect().end.y and col.get_global_rect().end.x < slab.get_global_rect().end.x, "目录操作都在标题下、右边线内")
	t.check(col.get_global_rect().end.y < menu.size.y, "末行不出屏")
	var lines: Array[Button] = menu.lines()
	t.check(lines.size() >= 3, "几行字（%d）" % lines.size())
	if lines.size() >= 3:
		t.eq(lines[0].text, UiText.t("menu.new_run"), "没存档：第一行是「新的游戏」（不留「继续」的空行）")
		t.eq(lines[0].get_theme_font_size("font_size"), UiTheme.sz(UiTheme.MENU_PRIMARY_SIZE), "主档遵从当前字号")
		t.eq(lines[1].get_theme_font_size("font_size"), UiTheme.sz(UiTheme.MENU_SECONDARY_SIZE), "次档遵从当前字号")
		t.check(lines.all(func(b): return b.get_theme_constant("outline_size") == 0 and b.focus_mode != Control.FOCUS_NONE), "纸面墨字与键盘焦点")
		var tag := lines[0].get_theme_stylebox("normal") as StyleBoxTexture
		var index := lines[1].get_theme_stylebox("normal") as StyleBoxTexture
		t.check(tag != null and tag.texture != null and tag.texture.resource_path.ends_with("dispatch_tag.png"), "主要操作使用红皮签")
		t.check(index != null and index.texture != null and index.texture.resource_path.ends_with("archive_edge.png"), "次级操作使用索引纸边")
		t.check(lines[1].icon != null and lines[2].icon != null and lines[1].icon != lines[2].icon, "百科与设置各有可识别的图标")
		var over := lines[0].get_theme_stylebox("hover") as StyleBoxTexture
		var down := lines[0].get_theme_stylebox("pressed") as StyleBoxTexture
		t.check(tag != null and over != null and down != null and over.modulate_color != tag.modulate_color and down.content_margin_top > tag.content_margin_top, "悬停提亮，按下文字下移")
		var focus := lines[0].get_theme_stylebox("focus") as StyleBoxFlat
		t.check(focus != null and not focus.draw_center and focus.border_width_top >= 2, "键盘焦点有独立描边")
		var texts: Array = lines.map(func(b): return b.text)
		t.eq(texts.slice(1), [UiText.t("menu.encyclopedia"), UiText.t("menu.settings")], "240：「跳过序章」搬到开场一问；089 补充二：「仓库与战绩」去掉，次档：百科 / 设置")
		t.check(not UiText.t("menu.continue") in texts, "089 补充二：没存档只有「新的游戏」，没有「继续」")
		t.check(not UiTheme.menu_line_lit(lines[1]), "没焦点：不亮")
		lines[1].grab_focus()
		t.check(UiTheme.menu_line_lit(lines[1]), "键盘焦点：亮、画菱形")
		lines[1].release_focus()
	var links: Array = menu.foot().get_children().filter(func(n): return n is Button)
	var link_texts: Array = links.map(func(b): return (b as Button).text)
	t.eq(link_texts.front() if not link_texts.is_empty() else "", "中 / EN", "末行第一个：语言「中 / EN」")
	t.eq(link_texts.back() if not link_texts.is_empty() else "", UiText.t("menu.quit"), "末行最后：退出")
	t.check(links.all(func(b): return (b as Button).theme_type_variation == UiTheme.BUTTON_MENU_FOOT), "末行是小字链接")
	t.check(menu.find_child("FooterRule", true, false) != null and links.all(func(b): return (b as Button).get_theme_font_size("font_size") == UiTheme.sz(UiTheme.MENU_FOOT_SIZE)), "尾部横线和小字号区分辅助操作")
	t.eq(menu.find_children("MenuVeil", "", true, false).size(), 0, "没有暗纱")
	t.eq(menu.notices().get_child_count(), 0, "没有提示：右下不占位")
	var stats := false
	for l in menu.find_children("*", "Label", true, false):
		if (l as Label).text.contains("撤离") and (l as Label).text.contains("战败"):
			stats = true
	t.check(not stats, "战绩行从菜单拿掉")
	var flow: GameFlow = game.flow
	flow.slots = SaveSlots.new("user://test_menu197_slots")
	flow.slots.remove(1)
	flow.use_slot(1)
	t.check(flow.save_meta(), "建立可继续的存档")
	(links[0] as Button).grab_focus()
	(links[0] as Button).pressed.emit()
	t.check((menu.foot().get_child(0) as Button).has_focus(), "更换语言后键盘焦点回到语言入口")
	t.eq(menu.title_node().texture.resource_path.get_file(), "survey_title_en.png", "英文目录同步更换字标")
	lines = menu.lines()
	t.eq([lines[0].text, lines[1].text], ["Continue", "Load game"], "已有存档的英文入口")
	var last_link := menu.foot().get_child(-1) as Button
	var current_slab := menu.find_child("SurveyIndex", true, false) as TextureRect
	t.check(menu.column().get_global_rect().end.x <= current_slab.get_global_rect().end.x, "英文操作的最小宽度在目录内")
	t.check(last_link != null and last_link.text == "Quit" and last_link.focus_mode != Control.FOCUS_NONE, "英文退出保留键盘操作")
	menu.toggle_language()
	menu.lines()[0].pressed.emit()
	t.eq(flow.screen, GameFlow.Screen.META, "点继续回到该存档基地")
	flow.slots.remove(1)
	game.queue_free()
	Support.cleanup("menu197")


static func frame_backdrop_camera(t: TestCase, root: Window) -> void:
	t.begin("197 补充一 · 慢镜头：换下一张交叉淡化，平移不超过屏宽 3 %、推拉交替、同一张再出现不走回头路；启动屏那档暗亮起来；失焦暂停、出树全停")
	var sc := MenuBackdrop.new()
	sc.size = Vector2(1600, 1000)
	root.add_child(sc)
	sc.start(UiTheme.ART_MENU_BGS, true)
	t.eq(sc.modulate, Color(0.4, 0.4, 0.4), "刚从启动屏过来：从 40 % 亮起来")
	sc.advance()
	t.eq(sc.current_name(), "menu/bg_legion", "营地 → 军营")
	var top: TextureRect = sc.get_child(sc.get_child_count() - 1)
	t.check(top.modulate.a < 1.0, "新的一张在上层、从透明淡进来")
	var first: Dictionary = sc.last_move
	t.check((first["to"] as Vector2).length() <= MenuBackdrop.DRIFT + 0.0001, "平移 ≤ 屏宽 3 %%（%s）" % first["to"])
	var grow: bool = first["zoom_to"] > first["zoom_from"]
	sc.advance()
	t.eq(sc.current_name(), "menu/bg_map", "军营 → 地图")
	var second: Dictionary = sc.last_move
	t.check((second["zoom_to"] > second["zoom_from"]) != grow, "推、拉交替")
	t.check(is_equal_approx(minf(second["zoom_from"], second["zoom_to"]), 1.0) and is_equal_approx(maxf(second["zoom_from"], second["zoom_to"]), 1.06), "缩放 1.00 ↔ 1.06")
	sc.advance()
	t.eq(sc.current_name(), "menu/bg_camp", "地图 → 营地（循环）")
	var camp1: Vector2 = sc.last_move["to"]
	for i in 3:
		sc.advance()
	var camp2: Vector2 = sc.last_move["to"]
	t.eq(sc.current_name(), "menu/bg_camp", "又到营地")
	t.check(camp1.dot(camp2) >= 0.0, "同一张再出现：不走回头路（%s → %s）" % [camp1, camp2])
	var m := sc.size.x * MenuBackdrop.BLEED
	t.check(m > sc.size.x * MenuBackdrop.DRIFT, "出血比平移大：不露边")
	t.check(sc.live_tweens() > 0, "在走")
	sc.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	t.eq(sc.live_tweens(), 0, "失焦：暂停")
	sc.notification(Control.NOTIFICATION_APPLICATION_FOCUS_IN)
	t.check(sc.live_tweens() > 0, "回来：接着走")
	root.remove_child(sc)
	t.eq(sc.live_tweens(), 0, "离开菜单：全停")
	sc.free()


static func frame_logo(t: TestCase, root: Window) -> void:
	t.begin("主菜单：测绘字标缺图时回退到原字标，保持比例并在目录居中；启动屏仍读其专属字标")
	var consts := (load(BOOT) as GDScript).get_script_constant_map()
	t.eq(consts["LOGO"], "res://assets/ui/menu/title_boot.png", "启动屏的字标是 1× 那张")
	var saved := UiTheme.asset_root
	UiTheme.asset_root = "res://tests/fixtures/ui/"     # 夹具里有一张 menu/title.png（144 × 40）
	var p := Support.paths("menu197l")
	Support.cleanup("menu197l")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var menu = game.base()
	var logo = menu.title_node() if menu != null and menu.has_method("title_node") else null
	t.check(logo is TextureRect, "有图：标题是图")
	if logo is TextureRect:
		var slab := menu.find_child("SurveyIndex", true, false) as TextureRect
		t.check(is_equal_approx(logo.size.y, logo.size.x * 40.0 / 144.0), "回退图仍按原比例（%s）" % logo.size)
		t.check(is_equal_approx(logo.position.x + logo.size.x * 0.5, slab.size.x * 0.5), "回退图也在登记册居中")
		t.eq(logo.mouse_filter, Control.MOUSE_FILTER_IGNORE, "不接鼠标")
	game.queue_free()
	UiTheme.asset_root = saved
	Support.cleanup("menu197l")
	var real := UiTheme.art_cached("menu/title")
	t.check(real != null and real.get_size() == Vector2(2232, 620), "仓库里是定稿字标：2232 × 620（720 × 200 画布 × 3.1）")
	var boot_logo := load(consts["LOGO"]) as Texture2D
	t.check(boot_logo != null and boot_logo.get_size() == Vector2(1116, 310), "启动屏那张 1116 × 310（× 1.55）")
