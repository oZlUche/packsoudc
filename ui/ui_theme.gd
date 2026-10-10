## 界面的 Godot [Theme]（121，作者定：现在的界面当灰盒原型，**表现层将来整套换**）—— 换皮只换这一处。
##
## 由代码按设置生成（底色是运行时设置、字体是系统 CJK 字体，写不成一份死的 `.tres`）：默认字体与字号、按钮三档、
## 标签 / 面板 / 富文本的几种 **type variation**。[method install] 把它并进引擎的默认主题（[method ThemeDB.get_default_theme]），
## 所有控件都继承到 —— 浮窗、叠层、换场景之后的编辑器也一样，节点离开树（退出时）也不会丢主题重排字；
## 设置里换了底色 [method refresh] 重填一遍再并进去，控件跟着变。
##
## 屏幕脚本不直接贴样式：选变体（`theme_type_variation = UiTheme.LABEL_DIM`），或用下面几个小工具
## （[method label]、[method panel]、[method rich]、[method mark]）—— 它们先选变体，只有变体给不了的（字号、面板内边距）才逐个覆写。
## 造控件走 [method make_label] / [method make_wrapped] / [method make_button] / [method rich_block]（各屏的 `_label / _button…` 都只是转发到这里）。
## 画布上画的颜色（血条、格子、邻接标记、稀有度、飘字）不归这里，继续读 [UiPalette]。
## 美术进场时把 [method _fill] 换成加载美术给的 `.tres` + 字体 + 贴图，屏幕脚本一行不动。
class_name UiTheme
extends RefCounted

## 默认字号（原来各处最常写的 14）
const FONT_SIZE := 14
## [method make_button] 的「不上样式」档：沙盒 / 编辑器的素按钮（引擎默认的样子，字号不是 14 才给）；真正的三档见 [enum UiPalette.Tier]
const TIER_PLAIN := -1

const BUTTON_PRIMARY := &"ButtonPrimary"
const BUTTON_SECONDARY := &"ButtonSecondary"
const BUTTON_DIM := &"ButtonDim"
const LABEL_TITLE := &"LabelTitle"
const LABEL_DIM := &"LabelDim"
const LABEL_WARN := &"LabelWarn"
const PANEL_DARK := &"PanelDark"
const PANEL_LINE := &"PanelLine"
## 150：地图屏读数组件（[HudWidget]）的底与字：无边窄底、14 号小档、34 号大档（倒计时那种一行大字）
const PANEL_HUD := &"PanelHud"
const LABEL_HUD := &"LabelHud"
const LABEL_HUD_LARGE := &"LabelHudLarge"
## 事件正文、百科正文：17 号、行距 6
const RICH_BODY := &"RichTextBody"
## 悬浮窗正文：13 号
const RICH_SMALL := &"RichTextSmall"

## 全部变体（测试看齐全）
const VARIATIONS := [BUTTON_PRIMARY, BUTTON_SECONDARY, BUTTON_DIM, LABEL_TITLE, LABEL_DIM, LABEL_WARN,
	PANEL_DARK, PANEL_LINE, RICH_BODY, RICH_SMALL, PANEL_HUD, LABEL_HUD, LABEL_HUD_LARGE]

const TITLE_SIZE := 18
const PANEL_MARGIN := 16
const PANEL_LINE_MARGIN := 8
const RICH_BODY_SIZE := 17
const RICH_SMALL_SIZE := 13
const HUD_MARGIN := 8
const HUD_LARGE_SIZE := 34
const RICH_FONT_SIZES := ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]

## 并进默认主题的那一份；[method refresh] 原地重填它
static var _current: Theme = null
static var _installed := false
## [member _current] 是按哪档底色填的
static var _current_bg := Color(0, 0, 0, 0)
static var _font: Font = null


## 按设置生成一份新主题（不挂）
static func build(settings: GameSettings = null) -> Theme:
	var t := Theme.new()
	_fill(t, _bg_of(settings))
	return t


## 当前那一份（没有就按现在的底色建）
static func current() -> Theme:
	if _current == null:
		_current = Theme.new()
		_current_bg = UiPalette.bg()
		_fill(_current, _current_bg)
	return _current


## 并进引擎的默认主题，从此每个控件都用它（根场景的 `_ready` 调；调几次都一样）。
## 不挂在窗口上：窗口上的主题节点离开树时会丢，几千个控件退出时逐个换回引擎字体重排，系统里找不到中文字体时极慢
static func install() -> void:
	if _installed:
		return     # 并一次就够：再并会让树里每个控件都收到主题变更、重排一遍字
	ThemeDB.get_default_theme().merge_with(current())
	_installed = true


## 装过没有（测试看）
static func installed() -> bool:
	return _installed


## 设置里换了底色：原地重填当前那一份，挂着的控件跟着变（[method UiPalette.apply] 调）
static func refresh(settings: GameSettings = null) -> void:
	if _current == null:
		return
	var bg := _bg_of(settings)
	if bg == _current_bg:
		return     # 底色没变（各根场景读档时都会调一次）：不重填，免得全树重排字
	_current_bg = bg
	var fresh := build(settings)
	_current.clear()
	_current.merge_with(fresh)
	if _installed:
		ThemeDB.get_default_theme().merge_with(_current)


## 面板的底色：跟着设置里的底色走（默认的石墨底正好是原来的 [constant UiPalette.PANEL]）；最深的那档底往亮里提一点，不然面板看不出来
static func panel_color(bg: Color) -> Color:
	return bg.darkened(0.4) if bg.get_luminance() > 0.08 else bg.lightened(0.05)


#region 小工具（屏幕脚本用它们，不直接 add_theme_*）
## 标签：按颜色选变体（前景色 = 默认、暗色 = [constant LABEL_DIM]、警示 = [constant LABEL_WARN]），
## 字号不是变体的默认值才覆写；别的颜色（生命红、治疗绿……是语义色）才覆写颜色
static func label(l: Label, font_size: int = FONT_SIZE, color: Color = UiPalette.FG) -> Label:
	var variation := label_variation(color)
	l.theme_type_variation = variation
	if variation == &"" and color != UiPalette.FG:
		l.add_theme_color_override("font_color", color)
	if font_size != (TITLE_SIZE if variation == LABEL_TITLE else FONT_SIZE):
		l.add_theme_font_size_override("font_size", font_size)
	return l


## 这个颜色对应哪个标签变体；没有对应的返回空（= 默认前景色或语义色）
static func label_variation(color: Color) -> StringName:
	if color == UiPalette.DIM:
		return LABEL_DIM
	if color == UiPalette.STAMINA:
		return LABEL_WARN
	return &""


## 面板：选变体；内边距不是变体的默认值时，用变体那份底复制一份改内边距（面板大小各屏不一，这一项只能逐个给）
static func panel(p: PanelContainer, margin: int = -1, variation: StringName = PANEL_DARK) -> PanelContainer:
	p.theme_type_variation = variation
	var default_margin := PANEL_LINE_MARGIN if variation == PANEL_LINE else PANEL_MARGIN
	if margin >= 0 and margin != default_margin:
		var box := current().get_stylebox("panel", variation).duplicate() as StyleBox
		box.set_content_margin_all(margin)
		p.add_theme_stylebox_override("panel", box)
	return p


## 富文本：17 号正文 / 13 号小字选变体，别的字号逐个给（几种字重一起）
static func rich(r: RichTextLabel, font_size: int = FONT_SIZE) -> RichTextLabel:
	match font_size:
		RICH_BODY_SIZE:
			r.theme_type_variation = RICH_BODY
		RICH_SMALL_SIZE:
			r.theme_type_variation = RICH_SMALL
		FONT_SIZE:
			pass
		_:
			for k in RICH_FONT_SIZES:
				r.add_theme_font_size_override(k, font_size)
	return r


## 一排互斥按钮里「选中的那个」：字是前景色，其余暗色（开局屏的章节 / 角色 / 难度……）
static func mark(b: Control, on: bool) -> void:
	b.add_theme_color_override("font_color", UiPalette.FG if on else UiPalette.DIM)
#endregion


#region 造控件与场景前奏（屏、面板、沙盒、编辑器共用）
## 一个标签：字体在主题里，颜色先选变体（[method label]）
static func make_label(text: String, font_size: int = FONT_SIZE, color: Color = UiPalette.FG) -> Label:
	var l := Label.new()
	l.text = text
	return label(l, font_size, color)


## 会折行的说明文字。必须给最小宽度：中文没有词边界，容器算出的最小宽度是一个字
static func make_wrapped(text: String, font_size: int, color: Color, width: float) -> Label:
	var l := make_label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 一个按钮。090（作者定）：按重要性分三档（[enum UiPalette.Tier]），字号是 [param font_size] 的 300% / 200% / 150%，颜色也各不同，
## 不写档就是次要（200%）；[constant TIER_PLAIN] = 不上样式（字号不是默认的 14 才覆写）
static func make_button(text: String, handler: Callable, tier: int = UiPalette.Tier.SECONDARY, font_size: int = FONT_SIZE) -> Button:
	var b := Button.new()
	b.text = text
	if tier == TIER_PLAIN:
		if font_size != FONT_SIZE:
			b.add_theme_font_size_override("font_size", font_size)
	else:
		UiPalette.style_button(b, tier, UiPalette.button_font_size(font_size, tier))
	b.pressed.connect(handler)
	return b


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


## 一段 BBCode 正文：高度随内容、自己不滚（放进调用方的滚动区或面板里）、按 [param width] 折行；
## 字号走 [method rich]（17 / 13 号选变体，别的逐个给）
static func rich_block(width: float, font_size: int = FONT_SIZE, bbcode: String = "") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = width
	rich(r, font_size)
	r.text = bbcode
	return r


## 清空一个节点的全部子节点：先摘下来再 free —— queue_free 到帧末才真的走，同一帧里数子节点会把旧的也数进去
static func clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## 根场景的前奏（启动器、沙盒、编辑器）：读设置让底色跟着走（091）、装主题、铺一块底色（铺满、不挡鼠标）。
## [param read_settings] 假 = 宿主已经读过设置、apply 过（嵌在别人里的 [BattleView]，或自己还要拿设置做别的事）。返回那块底色
static func prepare_root(root: Control, read_settings: bool = true) -> ColorRect:
	if read_settings:
		UiPalette.apply(GameSettings.load_from())
	install()
	var bg := ColorRect.new()
	bg.color = UiPalette.bg()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	return bg
#endregion


#region 生成
static func _bg_of(settings: GameSettings) -> Color:
	var id := settings.bg_theme if settings != null and UiPalette.has_bg_theme(settings.bg_theme) else UiPalette.bg_theme
	return UiPalette.theme_of(id).get("color", UiPalette.BG_THEMES[0]["color"])


static func _fill(t: Theme, bg: Color) -> void:
	if _font == null:
		_font = UiPalette.cjk_font()
	t.default_font = _font
	t.default_font_size = FONT_SIZE
	var panel_bg := panel_color(bg)
	# 默认的字色
	t.set_color("font_color", "Label", UiPalette.FG)
	t.set_color("default_color", "RichTextLabel", UiPalette.FG)
	# 按钮三档（090）：字号是原 14 号的 300% / 200% / 150%，内边距跟字号走
	for pair in [[BUTTON_PRIMARY, UiPalette.Tier.PRIMARY], [BUTTON_SECONDARY, UiPalette.Tier.SECONDARY], [BUTTON_DIM, UiPalette.Tier.MINOR]]:
		_button_variation(t, pair[0], pair[1])
	# 标签
	for pair in [[LABEL_TITLE, UiPalette.FG], [LABEL_DIM, UiPalette.DIM], [LABEL_WARN, UiPalette.STAMINA]]:
		t.set_type_variation(pair[0], "Label")
		t.set_color("font_color", pair[0], pair[1])
	t.set_font_size("font_size", LABEL_TITLE, TITLE_SIZE)
	# 面板
	t.set_type_variation(PANEL_DARK, "PanelContainer")
	t.set_stylebox("panel", PANEL_DARK, _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	t.set_type_variation(PANEL_LINE, "PanelContainer")
	t.set_stylebox("panel", PANEL_LINE, _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), PANEL_LINE_MARGIN))
	# 150：读数组件（原来地图屏那条 HUD 的无边窄底，搬成变体）
	t.set_type_variation(PANEL_HUD, "PanelContainer")
	var hud_box := _box(panel_bg, UiPalette.LINE, HUD_MARGIN)
	hud_box.set_border_width_all(0)
	t.set_stylebox("panel", PANEL_HUD, hud_box)
	t.set_type_variation(LABEL_HUD, "Label")
	t.set_type_variation(LABEL_HUD_LARGE, "Label")
	t.set_font_size("font_size", LABEL_HUD_LARGE, HUD_LARGE_SIZE)
	# 富文本
	for pair in [[RICH_BODY, RICH_BODY_SIZE], [RICH_SMALL, RICH_SMALL_SIZE]]:
		t.set_type_variation(pair[0], "RichTextLabel")
		for k in RICH_FONT_SIZES:
			t.set_font_size(k, pair[0], pair[1])
	t.set_constant("line_separation", RICH_BODY, 6)
	# 输入框、数字框、树（编辑器里反复贴的那几组）
	for type in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, _box(panel_bg.darkened(0.2), UiPalette.LINE, 6))
		t.set_stylebox("focus", type, _box(panel_bg.darkened(0.2), UiPalette.BTN_SECONDARY_EDGE, 6))
		t.set_color("font_color", type, UiPalette.FG)
	t.set_stylebox("panel", "Tree", _box(panel_bg, UiPalette.LINE, 4))
	t.set_color("font_color", "Tree", UiPalette.FG)


static func _button_variation(t: Theme, name: StringName, tier: int) -> void:
	var bg: Color
	var hover: Color
	var edge: Color
	var text: Color
	match tier:
		UiPalette.Tier.PRIMARY:
			bg = UiPalette.BTN_PRIMARY
			hover = UiPalette.BTN_PRIMARY_HOVER
			edge = UiPalette.BTN_PRIMARY_HOVER
			text = UiPalette.BTN_PRIMARY_TEXT
		UiPalette.Tier.MINOR:
			bg = UiPalette.BTN_MINOR
			hover = UiPalette.BTN_MINOR_HOVER
			edge = UiPalette.BTN_MINOR_EDGE
			text = UiPalette.FG
		_:
			bg = UiPalette.BTN_SECONDARY
			hover = UiPalette.BTN_SECONDARY_HOVER
			edge = UiPalette.BTN_SECONDARY_EDGE
			text = UiPalette.FG
	var size := UiPalette.button_font_size(FONT_SIZE, tier)
	var pad := Vector2i(int(round(size * 0.6)), int(round(size * 0.3)))
	t.set_type_variation(name, "Button")
	t.set_font_size("font_size", name, size)
	t.set_stylebox("normal", name, _button_box(bg, edge, pad))
	t.set_stylebox("hover", name, _button_box(hover, edge.lightened(0.2), pad))
	t.set_stylebox("pressed", name, _button_box(hover, Color.WHITE.lerp(edge, 0.3), pad))
	t.set_stylebox("hover_pressed", name, _button_box(hover, Color.WHITE.lerp(edge, 0.2), pad))
	t.set_stylebox("disabled", name, _button_box(UiPalette.BTN_DISABLED, UiPalette.LINE, pad))
	t.set_stylebox("focus", name, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, name, text)
	t.set_color("font_disabled_color", name, UiPalette.DIM)


static func _button_box(bg: Color, edge: Color, pad: Vector2i) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s


static func _box(bg: Color, edge: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_content_margin_all(margin)
	return s
#endregion
