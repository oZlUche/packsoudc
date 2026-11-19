## 主菜单让出整张风景，标题居中，操作从左下向上排列。
## 存档、语言、开发工具和通知仍取自当前 GameFlow。
extends GameScreen

signal dev_tools_requested

## 设计稿按这个屏高写
const DESIGN_HEIGHT := 1080.0
## 菜单最小缩到这么多（1280 × 720）
const MIN_SCALE := 0.75
const ART_LOGO := "menu/title"
const LOGO_WIDTH := 1116.0
const LOGO_TOP := 90.0
const LEFT := 96.0
const BOTTOM := 72.0
const PRIMARY_SIZE := 51
const SECONDARY_SIZE := 32
const FOOT_SIZE := 20
const PRIMARY_GAP := 8
const SECONDARY_GAP := 4
const PRIMARY_TO_SECONDARY := 18
const SECONDARY_TO_FOOT := 22
## 右下提示离屏边、字号
const NOTICE_MARGIN := 48.0
const NOTICE_SIZE := 15

## 菜单第一次打开（刚从启动屏过来）：第一张画从启动屏那档暗亮起来；之后回菜单直接开镜头
static var _shown_once := false

var _scenery: MenuBackdrop = null
## 游戏名：字标图
var _title: Control = null
## 目录内的主操作、次操作与页脚。
var _column: VBoxContainer = null
var _primary: VBoxContainer = null
var _secondary: VBoxContainer = null
var _foot: HBoxContainer = null
var _notices: VBoxContainer = null
## 226 批四：垫在提示下面的便条
var _note_paper: PanelContainer = null


func open(_payload: Dictionary) -> void:
	UiText.apply(flow.settings)
	UiPalette.apply(flow.settings)
	_backdrop()
	_scenery = MenuBackdrop.new()
	add_child(_scenery)
	var brighten := not _shown_once
	_scenery.start(UiTheme.ART_MENU_BGS, brighten)
	if not UiMotion.enabled(flow.settings):
		_scenery.stop()
	_shown_once = true
	var area := Control.new()
	area.name = "MenuContent"
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.set_tone(area, UiTheme.TONE_DARK)
	add_child(area)

	var logo := UiTheme.art_cached(UiTheme.lang_art(ART_LOGO))
	if logo != null:
		_title = UiTheme.picture(logo, TextureRect.STRETCH_KEEP_ASPECT)
		if brighten and UiMotion.enabled(flow.settings):
			_title.modulate = Color(MenuBackdrop.BOOT_DIM, MenuBackdrop.BOOT_DIM, MenuBackdrop.BOOT_DIM)
			create_tween().tween_property(_title, "modulate", Color.WHITE, MenuBackdrop.BRIGHTEN)
	else:
		var label := UiTheme.make_display(UiText.t("game.title"), 90)
		label.add_theme_color_override("font_color", Color("ffe6b6"))
		label.add_theme_color_override("font_outline_color", Color("261b18"))
		label.add_theme_constant_override("outline_size", 8)
		_title = label
	_title.name = "MenuLogo"
	area.add_child(_title)

	# 089（作者定）：第一项「继续」（当前位有存档才显示）；「读取存档」（有任何一位有存档才显示）；「新的游戏」= 开一份新存档。只写这几个词，不写章名
	_column = _vbox(0)
	_column.name = "MenuColumn"
	area.add_child(_column)
	_primary = _vbox(PRIMARY_GAP)
	_column.add_child(_primary)
	# 089 补充二（作者 2026-10-27）：「继续」和「新的游戏」二选一 —— 有档只给「继续」（没有局就进基地），没档只给「新的游戏」；
	# 开第二份存档走「读取存档 → 在空位开新的游戏」
	if flow.profile_exists():
		_line(_primary, UiText.t("menu.continue"), func(): flow.continue_game())
	else:
		_line(_primary, UiText.t("menu.new_run"), func(): flow.start_new_game())
	_column.add_child(_spacer(PRIMARY_TO_SECONDARY))
	_secondary = _vbox(SECONDARY_GAP)
	_column.add_child(_secondary)
	if flow.slots != null and flow.slots.any():
		_line(_secondary, UiText.t("menu.load"), flow.show_slots)
	_line(_secondary, UiText.t("menu.encyclopedia"), func(): flow.show_encyclopedia())     # 114
	_line(_secondary, UiText.t("menu.settings"), flow.show_settings)
	_column.add_child(_spacer(SECONDARY_TO_FOOT))

	_foot = _hbox(14)     # 226 批二：链接之间的「·」删了，改成间距
	_foot.name = "MenuFoot"
	var indent := MarginContainer.new()
	UiTheme.margins(indent, UiTheme.MENU_LINE_INDENT - 2, 0, 0, 0)
	indent.add_child(_foot)
	_column.add_child(indent)
	var links: Array[Button] = [UiTheme.make_menu_link(UiText.t("menu.lang_short"), toggle_language)]
	if GameSettings.dev_build():     # 作者 2026-10-17：开发工具只在开发环境
		links.append(UiTheme.make_menu_link(UiText.t("menu.dev_tools"), func(): dev_tools_requested.emit()))
	links.append(UiTheme.make_menu_link(UiText.t("menu.quit"), func(): get_tree().quit()))
	for link in links:
		_style_link(link)
		_foot.add_child(link)

	# 098：这个存档位读不回来、已备份的那一句；173：读档时对账 / 挪位 / 打捞过 —— 右下角，没有不占位。
	# 存档消息写在单独的纸签上。
	_note_paper = UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_SUMMARY_NOTE)
	_note_paper.name = "MenuNoticePaper"
	_note_paper.add_theme_stylebox_override("panel", UiTheme.nine_box(UiTheme.art_cached("campaign/dossier"), [28, 23, 28, 23], [24, 15, 24, 15]))
	_note_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_note_paper)
	_note_paper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_notices = _vbox(4)
	_notices.name = "MenuNotices"
	_note_paper.add_child(_notices)
	for text in [flow.backup_notice(), flow.repair_notice()]:
		if text != "":
			var message := UiTheme.rich_line(text, NOTICE_SIZE, Color("633925"), 320.0)
			message.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_notices.add_child(message)
	_note_paper.visible = _notices.get_child_count() > 0
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()


func _line(box: VBoxContainer, text: String, handler: Callable) -> Button:
	var primary := box == _primary
	var em := UiTheme.sz(PRIMARY_SIZE if primary else SECONDARY_SIZE)
	var b := UiTheme.make_menu_line(text, em, handler)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", em)
	var font := UiPalette.cjk_font()
	if primary:
		font = UiPalette.display_font() if UiText.lang == "zh" else UiPalette.cjk_font_bold()
	b.add_theme_font_override("font", font)
	_style_text(b, Color("ffe6b6") if primary else Color("f2e7d4"), 6 if primary else 4)
	box.add_child(b)
	return b


func _style_link(b: Button) -> void:
	b.add_theme_font_size_override("font_size", UiTheme.sz(FOOT_SIZE))
	b.add_theme_font_override("font", UiPalette.cjk_font())
	_style_text(b, Color("dccdb7"), 3)


## 文字带暗描边；键盘焦点用金色底线，按住时变成铜色。
func _style_text(b: Button, ink: Color, outline: int) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.add_theme_color_override("font_focus_color", Color("fff1cd"))
	b.add_theme_color_override("font_pressed_color", Color("e7af70"))
	b.add_theme_color_override("font_hover_pressed_color", Color("e7af70"))
	b.add_theme_color_override("font_outline_color", Color("261b18"))
	b.add_theme_constant_override("outline_size", outline)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("ffe3a5")
	focus.border_width_bottom = 3
	b.add_theme_stylebox_override("focus", focus)


## 档与档之间的空（VBox 两侧的间距是 0，空多高就隔多远）
static func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 这一屏比设计稿的缩放（游戏名按它）
func ui_scale() -> float:
	return (size.y if size.y > 0.0 else DESIGN_HEIGHT) / DESIGN_HEIGHT


## 菜单的缩放：同 [method ui_scale]，但不小于 [constant MIN_SCALE]
func column_scale() -> float:
	return maxf(ui_scale(), MIN_SCALE)


func _layout() -> void:
	if _column == null:
		return
	var s := ui_scale()
	var c := column_scale()
	var h := size.y if size.y > 0.0 else DESIGN_HEIGHT
	var w := size.x if size.x > 0.0 else DESIGN_HEIGHT * 1.6
	if _title is TextureRect:
		var tex := (_title as TextureRect).texture
		var wide := minf(LOGO_WIDTH * s, w * 0.9)
		_title.size = Vector2(wide, wide * tex.get_height() / maxf(tex.get_width(), 1.0))
		_title.position = Vector2((w - wide) * 0.5, LOGO_TOP * s)
	else:
		var title_label := _title as Label
		title_label.add_theme_font_size_override("font_size", roundi(90.0 * s))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.size = Vector2(w, 0)
		title_label.position = Vector2(0, LOGO_TOP * s)
	_column.scale = Vector2.ONE * c
	_column.reset_size()
	_column.position = Vector2((LEFT - UiTheme.MENU_LINE_INDENT) * c, h - (BOTTOM + _column.size.y) * c)
	if _note_paper.visible:
		var margin := roundi(NOTICE_MARGIN * c)
		var message_width := clampf(w - _column.get_rect().end.x - 2 * margin - 48, 120.0, 460.0 * c)
		for message: RichTextLabel in _notices.get_children():
			message.custom_minimum_size.x = message_width
		_note_paper.set_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, margin)


## 切到下一种界面语言：写进设置并存盘，然后把菜单原地重建（按钮文字立刻换）
func toggle_language() -> void:
	var restore_focus := _foot.get_child(0) == get_viewport().gui_get_focus_owner()
	if flow.settings == null:
		flow.settings = GameSettings.new()
	flow.settings.language = UiText.next_lang(flow.settings.language)
	flow.save_settings()
	_reopen()
	if restore_focus:
		(_foot.get_child(0) as Button).grab_focus()


#region 测试看
func scenery() -> MenuBackdrop:
	return _scenery


func title_node() -> Control:
	return _title


func column() -> VBoxContainer:
	return _column


## 主档 / 次档那几行（测试看）
func lines() -> Array[Button]:
	var out: Array[Button] = []
	for box in [_primary, _secondary]:
		for n in box.get_children():
			if n is Button:
				out.append(n)
	return out


func foot() -> HBoxContainer:
	return _foot


func notices() -> VBoxContainer:
	return _notices
#endregion
