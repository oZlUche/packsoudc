## 帝国测绘册的首页：右侧轮换夜营、军营与地图桌，左侧行军登记册承载全部操作。
## 存档、语言、开发工具和通知仍取自当前 GameFlow。
extends GameScreen

signal dev_tools_requested

## 设计稿按这个屏高写
const DESIGN_HEIGHT := 1080.0
## 菜单最小缩到这么多（1280 × 720）
const MIN_SCALE := 0.75
const ART_LOGO := "menu/survey_title"
const SLAB_WIDTH := 620.0
const LOGO_WIDTH := 496.0
const LOGO_TOP := 181.0
const LEFT := 61.0
const PRIMARY_GAP := 8
const SECONDARY_GAP := 4
const PRIMARY_TO_SECONDARY := 18
const SECONDARY_TO_FOOT := 22
const DISPATCH_ART := "menu/dispatch/"
## 右下提示离屏边、字号
const NOTICE_MARGIN := 48.0
const NOTICE_SIZE := 15

## 菜单第一次打开（刚从启动屏过来）：第一张画从启动屏那档暗亮起来；之后回菜单直接开镜头
static var _shown_once := false

var _scenery: MenuBackdrop = null
var _slab: TextureRect
## 游戏名：字标图
var _title: TextureRect = null
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
	UiTheme.set_tone(area, UiTheme.TONE_LIGHT)
	add_child(area)

	_slab = UiTheme.picture(load("res://assets/ui/menu/survey_slab.jpg"), TextureRect.STRETCH_SCALE)
	_slab.name = "SurveyIndex"
	area.add_child(_slab)
	var logo := UiTheme.art_cached(UiTheme.lang_art(ART_LOGO))
	if logo == null:
		logo = UiTheme.art_cached(UiTheme.lang_art("menu/title"))
	_title = UiTheme.picture(logo, TextureRect.STRETCH_KEEP_ASPECT)
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
		_line(_secondary, UiText.t("menu.load"), flow.show_slots, "load")
	_line(_secondary, UiText.t("menu.encyclopedia"), func(): flow.show_encyclopedia(), "codex")     # 114
	_line(_secondary, UiText.t("menu.settings"), flow.show_settings, "settings")
	_column.add_child(_spacer(SECONDARY_TO_FOOT))

	var foot_rule := Control.new()
	foot_rule.name = "FooterRule"
	foot_rule.custom_minimum_size.y = 9
	foot_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot_rule.draw.connect(_draw_footer_rule.bind(foot_rule))
	_column.add_child(foot_rule)
	_foot = _hbox(14)     # 226 批二：链接之间的「·」删了，改成间距
	_foot.name = "MenuFoot"
	var indent := MarginContainer.new()
	UiTheme.margins(indent, 2, 0, 0, 0)
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


## 主操作是行军皮签；次级页签用各自的档案图标和共用的纸边。
func _line(box: VBoxContainer, text: String, handler: Callable, icon_name: String = "") -> Button:
	var primary := box == _primary
	var b := Button.new()
	b.text = text
	b.theme_type_variation = UiTheme.BUTTON_MENU_LINE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(handler)
	b.add_theme_font_size_override("font_size", UiTheme.sz(UiTheme.MENU_PRIMARY_SIZE if primary else UiTheme.MENU_SECONDARY_SIZE))
	b.add_theme_constant_override("outline_size", 0)
	b.custom_minimum_size.y = 80.0 if primary else 56.0
	var art := "dispatch_tag" if primary else "archive_edge"
	var edges: Array = [48, 13, 64, 13] if primary else [12, 7, 14, 7]
	var pad: Array = [50, 8, 50, 8] if primary else [16, 3, 17, 3]
	var base := UiTheme.nine_box(UiTheme.art_cached(DISPATCH_ART + art), edges, pad)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var skin := base.duplicate() as StyleBoxTexture
		if state == "normal":
			skin.modulate_color = Color("ead6c1") if primary else Color.WHITE
		elif state == "hover":
			skin.modulate_color = Color.WHITE if primary else Color("f0d7ad")
		else:
			skin.modulate_color = Color("b79c86") if primary else Color("d8c8aa")
			skin.content_margin_top += 2
			skin.content_margin_bottom -= 2
		b.add_theme_stylebox_override(state, skin)
	b.add_theme_stylebox_override("focus", _focus_frame(Color("ffe19b") if primary else Color("743f2d")))
	var ink := Color("fff0cb") if primary else Color("3f342b")
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ink if primary or state == "font_color" else Color("753d2a"))
	if not icon_name.is_empty():
		b.icon = UiTheme.art_cached(DISPATCH_ART + icon_name)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 15)
	box.add_child(b)
	return b


## 一道独立焦点线，叠于按钮本身，鼠标按下时仍可辨认。
static func _focus_frame(ink: Color) -> StyleBoxFlat:
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = ink
	focus.set_expand_margin_all(2)
	return focus


func _draw_footer_rule(rule: Control) -> void:
	var ink := Color("9b8766")
	rule.draw_line(Vector2(0, 2), Vector2(rule.size.x, 2), Color(ink, 0.6), 1)
	rule.draw_line(Vector2(0, 2), Vector2(25, 2), ink, 2)


func _style_link(b: Button) -> void:
	b.flat = false
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", UiTheme.sz(UiTheme.MENU_FOOT_SIZE))
	b.add_theme_constant_override("outline_size", 0)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.bg_color = Color.TRANSPARENT
		if state != "normal":
			style.bg_color = Color("8a654423") if state == "hover" else Color("77523241")
			style.border_color = Color("846440")
			style.border_width_bottom = 1
		b.add_theme_stylebox_override(state, style)
	b.add_theme_stylebox_override("focus", _focus_frame(Color("805e42")))
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color("51483c") if state == "font_color" else Color("723d2c"))


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
	var panel_width := minf(w, maxf(SLAB_WIDTH * c, _foot.get_combined_minimum_size().x * c + 2.0 * LEFT * c))
	_slab.size = Vector2(panel_width, h)
	var tex := _title.texture
	if tex != null:
		var wide := minf(LOGO_WIDTH * c, panel_width - 2.0 * LEFT * c)
		_title.size = Vector2(wide, wide * tex.get_height() / maxf(tex.get_width(), 1.0))
		_title.position = Vector2((panel_width - wide) * 0.5, LOGO_TOP * s)
	_column.scale = Vector2.ONE * c
	_column.custom_minimum_size.x = maxf(0.0, panel_width / c - 2.0 * LEFT)
	_column.reset_size()
	var latest_top := h - (94.0 + _column.size.y) * c
	_column.position = Vector2(LEFT * c, minf(0.445 * h, latest_top))
	if _note_paper.visible:
		var margin := roundi(NOTICE_MARGIN * c)
		var message_width := clampf(w - panel_width - 2 * margin - 48, 120.0, 460.0 * c)
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
