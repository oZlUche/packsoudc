## 界面的 Godot [Theme]（121，作者定：现在的界面当灰盒原型，**表现层将来整套换**）—— 换皮只换这一处。
##
## 由代码按设置生成（底色是运行时设置、字体是系统 CJK 字体，写不成一份死的 `.tres`）：默认字体与字号、按钮三档、
## 标签 / 面板 / 富文本的几种 **type variation**。[method install] 把它并进引擎的默认主题（[method ThemeDB.get_default_theme]），
## 所有控件都继承到 —— 浮窗、叠层、换场景之后的编辑器也一样，节点离开树（退出时）也不会丢主题重排字；
## 设置里换了底色 [method refresh] 重填一遍再并进去，控件跟着变。
##
## 屏幕脚本不直接贴样式：选变体（`theme_type_variation = UiTheme.LABEL_DIM`），或用下面几个小工具
## （[method label]、[method panel]、[method rich]、[method mark]）—— 它们先选变体，只有变体给不了的（字号、面板内边距）才逐个覆写。
## 画布上画的颜色（血条、格子、邻接标记、稀有度、飘字）不归这里，继续读 [UiPalette]。
## 美术进场时把 [method _fill] 换成加载美术给的 `.tres` + 字体 + 贴图，屏幕脚本一行不动。
class_name UiTheme
extends RefCounted

## 默认字号（原来各处最常写的 14）
const FONT_SIZE := 14

const BUTTON_PRIMARY := &"ButtonPrimary"
const BUTTON_SECONDARY := &"ButtonSecondary"
const BUTTON_DIM := &"ButtonDim"
const LABEL_TITLE := &"LabelTitle"
const LABEL_DIM := &"LabelDim"
const LABEL_WARN := &"LabelWarn"
const PANEL_DARK := &"PanelDark"
const PANEL_LINE := &"PanelLine"
## 事件正文、百科正文：17 号、行距 6
const RICH_BODY := &"RichTextBody"
## 悬浮窗正文：13 号
const RICH_SMALL := &"RichTextSmall"

## 全部变体（测试看齐全）
const VARIATIONS := [BUTTON_PRIMARY, BUTTON_SECONDARY, BUTTON_DIM, LABEL_TITLE, LABEL_DIM, LABEL_WARN,
	PANEL_DARK, PANEL_LINE, RICH_BODY, RICH_SMALL]

const TITLE_SIZE := 18
const PANEL_MARGIN := 16
const PANEL_LINE_MARGIN := 8
const RICH_BODY_SIZE := 17
const RICH_SMALL_SIZE := 13
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


## 并进引擎的默认主题，从此每个控件都用它（根场景的 `_ready` 调；[param _node] 只是调用方，挂几次都一样）。
## 不挂在窗口上：窗口上的主题节点离开树时会丢，几千个控件退出时逐个换回引擎字体重排，系统里找不到中文字体时极慢
static func install(_node: Node = null) -> void:
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


#region 生成
static func _bg_of(settings: GameSettings) -> Color:
	var id := settings.bg_theme if settings != null and UiPalette.has_bg_theme(settings.bg_theme) else UiPalette.bg_theme
	for t in UiPalette.BG_THEMES:
		if String(t["id"]) == id:
			return t["color"]
	return UiPalette.bg()


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
