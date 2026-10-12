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
## 作者 2026-10-12：地图顶栏那一排放大到 200%（28 号）
const LABEL_HUD_DOUBLE := &"LabelHudDouble"
## 事件正文、百科正文：20 号、行距 8（作者 2026-10-12 嫌 17 号的粗体糊，加大并换真粗体）
const RICH_BODY := &"RichTextBody"
## 悬浮窗正文：13 号
const RICH_SMALL := &"RichTextSmall"
## 157：叠层共用的石板框（[OverlayFrame]）、框顶标题条的字、悬浮窗底（[HoverTip] 主面板与词条小窗）。
## 美术给了图（[member asset_root] 下的 `frame_stone.png` / `tooltip_paper.png`）就是九宫格，没给就是平面底
const PANEL_OVERLAY := &"PanelOverlay"
const LABEL_OVERLAY_TITLE := &"LabelOverlayTitle"
const PANEL_TOOLTIP := &"PanelTooltip"
## 157 补充二：名牌底（战前 / 回放两屏的名牌）
const PANEL_NAMEPLATE := &"PanelNameplate"
## 164：基地的「家」套件 —— 木牌按钮（左列页签与两颗大按钮；主档是「再来一局」）、粗布文本框（中列读数）、木架（右半边仓库的框）
const BUTTON_HOME := &"ButtonHome"
const BUTTON_HOME_PRIMARY := &"ButtonHomePrimary"
const PANEL_HOME_BOX := &"PanelHomeBox"
const PANEL_SHELF := &"PanelShelf"

## 全部变体（测试看齐全）
const VARIATIONS := [BUTTON_PRIMARY, BUTTON_SECONDARY, BUTTON_DIM, LABEL_TITLE, LABEL_DIM, LABEL_WARN,
	PANEL_DARK, PANEL_LINE, RICH_BODY, RICH_SMALL, PANEL_HUD, LABEL_HUD, LABEL_HUD_LARGE, LABEL_HUD_DOUBLE,
	PANEL_OVERLAY, LABEL_OVERLAY_TITLE, PANEL_TOOLTIP, PANEL_NAMEPLATE, BUTTON_HOME, BUTTON_HOME_PRIMARY, PANEL_HOME_BOX, PANEL_SHELF]

const TITLE_SIZE := 18
const PANEL_MARGIN := 16
const PANEL_LINE_MARGIN := 8
const RICH_BODY_SIZE := 20
const RICH_SMALL_SIZE := 13
const HUD_MARGIN := 8
const HUD_LARGE_SIZE := 34
const HUD_DOUBLE_SIZE := 28
const OVERLAY_TITLE_SIZE := 20
const TOOLTIP_MARGIN := 10
## 157：石板框 / 悬浮窗底的贴图文件名（不带扩展名；旁边同名 `.json` 写九宫格边距）
const ART_FRAME := "frame_stone"
const ART_TOOLTIP := "tooltip_paper"
## 157 补（作者定：整体纯色底换成石板）：整屏底（平铺）、通用面板、面板里的分区、地图读数组件
const ART_BG := "bg_stone"
const ART_PANEL := "panel_stone"
const ART_INSET := "panel_inset"
const ART_HUD := "panel_hud"
## 157 补充二：名牌底、肖像框（中间透明，画在肖像位外扩 json `inset` 处；徽记位同一张拉大）、没肖像时的占位
const ART_NAMEPLATE := "nameplate_stone"
const ART_PORTRAIT_FRAME := "portrait_frame"
const ART_PORTRAIT_EMPTY := "portrait_empty"
const NAMEPLATE_MARGIN := 12
## 164：家的套件（`assets/ui/home/`）：整屏背景（铺满裁边，json `stretch: cover`）、木牌按钮五态、粗布框、木架框、页签选中的挂牌
const ART_HOME_BG := "home/bg_home"
const ART_HOME_BTN := "home/btn_wood"
const ART_HOME_BTN_PRIMARY := "home/btn_wood_primary"
const ART_HOME_BOX := "home/panel_cloth"
const ART_SHELF := "home/shelf"
const ART_TAB_MARK := "home/tab_mark"
## 家的按钮字号：页签 / 回主菜单 20，「再来一局」28
const HOME_BUTTON_SIZE := 20
const HOME_PRIMARY_SIZE := 28
const RICH_FONT_SIZES := ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]

## 并进默认主题的那一份；[method refresh] 原地重填它
static var _current: Theme = null
static var _installed := false
## [member _current] 是按哪档底色填的
static var _current_bg := Color(0, 0, 0, 0)
static var _font: Font = null
static var _font_bold: Font = null
## 157：界面贴图的目录。测试指到 `res://tests/fixtures/ui/`（那里放一张小图），用完改回来
static var asset_root := "res://assets/ui/"


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


## 面板：选变体；内边距不是变体的默认值时，用变体那份底复制一份改内边距（面板大小各屏不一，这一项只能逐个给）。
## 157 补：按这块底的深浅挂字色（[method apply_tone]）
static func panel(p: PanelContainer, margin: int = -1, variation: StringName = PANEL_DARK) -> PanelContainer:
	p.theme_type_variation = variation
	apply_tone(p, variation)
	var default_margin := PANEL_LINE_MARGIN if variation == PANEL_LINE else (TOOLTIP_MARGIN if variation == PANEL_TOOLTIP else PANEL_MARGIN)
	if margin >= 0 and margin != default_margin:
		var box := current().get_stylebox("panel", variation).duplicate() as StyleBox
		box.set_content_margin_all(margin)
		p.add_theme_stylebox_override("panel", box)
	return p


## 富文本：20 号正文 / 13 号小字选变体，别的字号逐个给（几种字重一起）
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


## 164：家的木牌按钮（[constant BUTTON_HOME]；[param primary] = 「再来一局」那颗）
static func make_home_button(text: String, handler: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = BUTTON_HOME_PRIMARY if primary else BUTTON_HOME
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


## 外边距容器的四边（布局常量，和 [method vbox] 的间距一样不算样式）
static func margins(m: MarginContainer, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


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
	dress_backdrop(bg)     # 157 补：有石板图铺石板
	root.add_child(bg)
	return bg
#endregion


#region 深浅与字色（157 补，作者定：浅底黑字、深底白字 —— 每块底都要标深浅，字色按它选）
const TONE_DARK := &"dark"
const TONE_LIGHT := &"light"
## 每块底（面板变体）的深浅：没用美术图时按这张表；用了图按图旁 json 的 `tone`（美术交图时必须写，测试看）。
## **新加面板变体必须登记在这里**（测试看全）
const PANEL_TONES := {
	PANEL_DARK: TONE_DARK, PANEL_LINE: TONE_DARK, PANEL_HUD: TONE_DARK, PANEL_OVERLAY: TONE_DARK, PANEL_TOOLTIP: TONE_DARK,
	PANEL_NAMEPLATE: TONE_DARK, PANEL_HOME_BOX: TONE_LIGHT, PANEL_SHELF: TONE_DARK,
}
## 面板变体用哪张美术图（有图时深浅读它的 json）
const PANEL_ART := {PANEL_DARK: ART_PANEL, PANEL_LINE: ART_INSET, PANEL_HUD: ART_HUD, PANEL_OVERLAY: ART_FRAME, PANEL_TOOLTIP: ART_TOOLTIP,
	PANEL_NAMEPLATE: ART_NAMEPLATE, PANEL_HOME_BOX: ART_HOME_BOX, PANEL_SHELF: ART_SHELF}
## 浅底上的字色（美术规范的墨、褐墨，警示用压暗的铜褐）；浅底本身是亮纸
const INK := Color("2e2219")
const INK_SOFT := Color("5a4433")
const INK_WARN := Color("9a5a22")
const PAPER := Color("f6eedb")
## 浅底上的字和底至少要这么大的对比（WCAG 正文 4.5）
const MIN_CONTRAST := 4.5

static var _tone_themes := {}
static var _color_tag: RegEx = null


## 一块底现在是深是浅：用着美术图就看图的 json，否则查 [constant PANEL_TONES]（没登记的按深）
static func tone_of(variation: StringName) -> StringName:
	var art_name := String(PANEL_ART.get(variation, ""))
	if art_name != "" and art(art_name) != null:
		var t := StringName(String(art_meta(art_name).get("tone", "")))
		if t == TONE_LIGHT or t == TONE_DARK:
			return t
	return PANEL_TONES.get(variation, TONE_DARK)


## 深浅对应的字色：深底 null（就是全局主题的浅色字）；浅底是一份只填字色的小主题 —— 挂在那块底上，里面的字都继承
static func text_theme(tone: StringName) -> Theme:
	if tone != TONE_LIGHT:
		return null
	if _tone_themes.has(tone):
		return _tone_themes[tone]
	var t := Theme.new()
	t.set_color("font_color", "Label", INK)
	for pair in [[LABEL_TITLE, INK], [LABEL_DIM, INK_SOFT], [LABEL_WARN, INK_WARN], [LABEL_OVERLAY_TITLE, INK], [LABEL_HUD, INK], [LABEL_HUD_LARGE, INK], [LABEL_HUD_DOUBLE, INK]]:
		t.set_type_variation(pair[0], "Label")
		t.set_color("font_color", pair[0], pair[1])
	t.set_color("default_color", "RichTextLabel", INK)
	for v in [RICH_BODY, RICH_SMALL]:
		t.set_type_variation(v, "RichTextLabel")
		t.set_color("default_color", v, INK)
	_tone_themes[tone] = t
	return t


## 给一块底挂上它的字色（[method panel]、[OverlayFrame]、[HudWidget] 调）。深底不动别人挂的主题，只摘掉以前挂的字色
static func apply_tone(c: Control, variation: StringName) -> void:
	var t := text_theme(tone_of(variation))
	if t != null or _tone_themes.values().has(c.theme):
		c.theme = t


## 浅底上的 BBCode：里面写死的 `[color=…]`（都是按深底配的亮色）换成够深的墨水版；深底原样
static func ink_bbcode(text: String, tone: StringName) -> String:
	if tone != TONE_LIGHT or not text.contains("[color="):
		return text
	if _color_tag == null:
		_color_tag = RegEx.create_from_string("\\[color=#?([0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)\\]")
	var out := ""
	var at := 0
	for m in _color_tag.search_all(text):
		out += text.substr(at, m.get_start() - at)
		out += "[color=#%s]" % ink_color(Color(m.get_string(1))).to_html(false)
		at = m.get_end()
	return out + text.substr(at)


## 一个按深底配的颜色在亮纸上的版本：灰色系（前景 / 暗色字）换成墨 / 褐墨；有色的按原色相压暗到对比够
static func ink_color(c: Color) -> Color:
	if c.s < 0.18:
		return INK if c.get_luminance() > 0.7 else INK_SOFT
	var out := Color(c, 1.0)
	var guard := 0
	while contrast(out, PAPER) < MIN_CONTRAST and guard < 30:
		out = out.darkened(0.08)
		guard += 1
	return out


## 两个颜色的对比度（WCAG：亮的相对亮度 + 0.05 比暗的 + 0.05；相对亮度按线性值算）
static func contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
#endregion


#region 美术贴图（157：有图用图、没图照旧）
## [member asset_root] 下的 `<name>.png`；没有这张图返回 null
static func art(name: String) -> Texture2D:
	var path := asset_root + name + ".png"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	return EventImage.load_texture(path)


## 贴图旁边的 `<name>.json`（九宫格边距 `margin: [左, 上, 右, 下]`、石板框的 `title_height`）；没有或读不成字典是空字典
static func art_meta(name: String) -> Dictionary:
	var path := asset_root + name + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## 石板框顶上标题条的高（`frame_stone.json` 的 `title_height`）；没图 0 = 按字高
static func frame_title_height() -> int:
	return int(art_meta(ART_FRAME).get("title_height", 0)) if art(ART_FRAME) != null else 0


## 九宫格底：图 + json 的边距（没写边距按图边长的四分之一）。没图 null。
## [param title_strip] 真 = 石板框：顶边的内边距是 0，标题条（[OverlayFrame]）自己占住图上那一条；
## [param content] ≥ 0 = 内边距用它（换皮不改排版），否则跟图边一样
static func _art_box(name: String, title_strip: bool = false, content: int = -1) -> StyleBoxTexture:
	var tex := art(name)
	if tex == null:
		return null
	var quarter := int(mini(tex.get_width(), tex.get_height()) / 4.0)
	var m: Array = art_meta(name).get("margin", [quarter, quarter, quarter, quarter])
	if m.size() != 4:
		m = [quarter, quarter, quarter, quarter]
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = float(m[0])
	s.texture_margin_top = float(m[1])
	s.texture_margin_right = float(m[2])
	s.texture_margin_bottom = float(m[3])
	s.content_margin_left = float(m[0])
	s.content_margin_top = 0.0 if title_strip else float(m[1])
	s.content_margin_right = float(m[2])
	s.content_margin_bottom = float(m[3])
	if content >= 0:
		s.set_content_margin_all(float(content))
	return s


## 整屏底的石板（`bg_stone.png`，平铺）；没图 null = 照旧纯色
static func backdrop_art() -> Texture2D:
	return art(ART_BG)


## 石板底按设置里挑的底色染一点（091 的底色设置照旧有用）：默认那档是原色，别的档按和默认的比例乘上去
static func backdrop_tint() -> Color:
	var base: Color = UiPalette.theme_of(UiPalette.BG_DEFAULT).get("color", UiPalette.BG_THEMES[0]["color"])
	var c := UiPalette.bg()
	return Color(c.r / maxf(base.r, 0.01), c.g / maxf(base.g, 0.01), c.b / maxf(base.b, 0.01), 1.0)


## 给一块纯色整屏底铺上石板（子节点，平铺、不挡鼠标）；没图什么也不加、返回 null。底色设置变了调 [method tint_backdrop]
static func dress_backdrop(rect: ColorRect) -> TextureRect:
	var tex := backdrop_art()
	if tex == null:
		return null
	var tile := TextureRect.new()
	tile.name = "StoneBackdrop"
	tile.texture = tex
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.self_modulate = backdrop_tint()
	rect.add_child(tile)
	return tile


## 164：基地整屏背景（`home/bg_home.png`，按比例铺满、多的裁掉）；没图什么也不加、返回 null
static func dress_home_backdrop(rect: ColorRect) -> TextureRect:
	var tex := art(ART_HOME_BG)
	if tex == null:
		return null
	var pic := TextureRect.new()
	pic.name = "HomeBackdrop"
	pic.texture = tex
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stone := rect.get_node_or_null(^"StoneBackdrop")
	if stone != null:
		stone.visible = false     # 家有自己的背景，石板不铺
	rect.add_child(pic)
	return pic


## 设置里换了底色：铺着的石板跟着染
static func tint_backdrop(rect: ColorRect) -> void:
	var tile := rect.get_node_or_null(^"StoneBackdrop") as TextureRect
	if tile != null:
		tile.self_modulate = backdrop_tint()
#endregion


#region 生成
static func _bg_of(settings: GameSettings) -> Color:
	var id := settings.bg_theme if settings != null and UiPalette.has_bg_theme(settings.bg_theme) else UiPalette.bg_theme
	return UiPalette.theme_of(id).get("color", UiPalette.BG_THEMES[0]["color"])


static func _fill(t: Theme, bg: Color) -> void:
	if _font == null:
		_font = UiPalette.cjk_font()
	if _font_bold == null:
		_font_bold = UiPalette.cjk_font_bold()
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
	# 157 补：美术给了石板图就是九宫格（内边距照旧按变体的默认值，各屏排版不动），没给是原来的平面底
	t.set_type_variation(PANEL_DARK, "PanelContainer")
	var stone: StyleBox = _art_box(ART_PANEL, false, PANEL_MARGIN)
	t.set_stylebox("panel", PANEL_DARK, stone if stone != null else _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	t.set_type_variation(PANEL_LINE, "PanelContainer")
	var inset: StyleBox = _art_box(ART_INSET, false, PANEL_LINE_MARGIN)
	t.set_stylebox("panel", PANEL_LINE, inset if inset != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), PANEL_LINE_MARGIN))
	# 157：叠层的石板框、悬浮窗底 —— 美术给了图是九宫格，没给和原来一样（框 = PanelDark 的底、悬浮窗 = PanelLine 的底）
	t.set_type_variation(PANEL_OVERLAY, "PanelContainer")
	var frame: StyleBox = _art_box(ART_FRAME, true)
	t.set_stylebox("panel", PANEL_OVERLAY, frame if frame != null else _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	t.set_type_variation(LABEL_OVERLAY_TITLE, "Label")
	t.set_font_size("font_size", LABEL_OVERLAY_TITLE, OVERLAY_TITLE_SIZE)
	t.set_color("font_color", LABEL_OVERLAY_TITLE, UiPalette.FG)
	t.set_type_variation(PANEL_TOOLTIP, "PanelContainer")
	var paper: StyleBox = _art_box(ART_TOOLTIP)
	t.set_stylebox("panel", PANEL_TOOLTIP, paper if paper != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), TOOLTIP_MARGIN))
	# 157 补充二：名牌底 —— 有图是切角石碑九宫格（内边距按图边），没图是深底细边
	t.set_type_variation(PANEL_NAMEPLATE, "PanelContainer")
	var plate: StyleBox = _art_box(ART_NAMEPLATE)
	t.set_stylebox("panel", PANEL_NAMEPLATE, plate if plate != null else _box(panel_bg.darkened(0.15), UiPalette.LINE.lightened(0.25), NAMEPLATE_MARGIN))
	# 164：家的粗布框（浅底墨字）、仓库木架（深底）；没图回落到面板的平面底
	t.set_type_variation(PANEL_HOME_BOX, "PanelContainer")
	var cloth: StyleBox = _art_box(ART_HOME_BOX)
	t.set_stylebox("panel", PANEL_HOME_BOX, cloth if cloth != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), PANEL_MARGIN))
	t.set_type_variation(PANEL_SHELF, "PanelContainer")
	var shelf: StyleBox = _art_box(ART_SHELF)
	t.set_stylebox("panel", PANEL_SHELF, shelf if shelf != null else _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	_home_buttons(t)
	# 150：读数组件（原来地图屏那条 HUD 的无边窄底，搬成变体）
	t.set_type_variation(PANEL_HUD, "PanelContainer")
	var hud_art: StyleBox = _art_box(ART_HUD, false, HUD_MARGIN)
	var hud_box := _box(panel_bg, UiPalette.LINE, HUD_MARGIN)
	hud_box.set_border_width_all(0)
	t.set_stylebox("panel", PANEL_HUD, hud_art if hud_art != null else hud_box)
	t.set_type_variation(LABEL_HUD, "Label")
	t.set_type_variation(LABEL_HUD_LARGE, "Label")
	t.set_font_size("font_size", LABEL_HUD_LARGE, HUD_LARGE_SIZE)
	t.set_type_variation(LABEL_HUD_DOUBLE, "Label")
	t.set_font_size("font_size", LABEL_HUD_DOUBLE, HUD_DOUBLE_SIZE)
	# 富文本
	for pair in [[RICH_BODY, RICH_BODY_SIZE], [RICH_SMALL, RICH_SMALL_SIZE]]:
		t.set_type_variation(pair[0], "RichTextLabel")
		for k in RICH_FONT_SIZES:
			t.set_font_size(k, pair[0], pair[1])
	t.set_constant("line_separation", RICH_BODY, 8)
	# 富文本的 [b] 用真粗体（字重 700），不让引擎拿常规体描粗
	for k in ["bold_font", "bold_italics_font"]:
		t.set_font(k, "RichTextLabel", _font_bold)
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


## 164：家的木牌按钮。有图：五态九宫格（常态 / 悬停 / 按下 / 禁用 + 主档一张），浅木墨字；没图：回落到次档 / 主档的样子
static func _home_buttons(t: Theme) -> void:
	for pair in [[BUTTON_HOME, UiPalette.Tier.SECONDARY, HOME_BUTTON_SIZE], [BUTTON_HOME_PRIMARY, UiPalette.Tier.PRIMARY, HOME_PRIMARY_SIZE]]:
		var name: StringName = pair[0]
		_button_variation(t, name, pair[1])
		t.set_font_size("font_size", name, pair[2])
		var normal := _art_box(ART_HOME_BTN_PRIMARY if name == BUTTON_HOME_PRIMARY else ART_HOME_BTN)
		if normal == null:
			continue
		var pad := Vector2i(int(round(pair[2] * 0.9)), int(round(pair[2] * 0.4)))
		var states := {"normal": normal, "hover": _art_box(ART_HOME_BTN + "_hover"), "pressed": _art_box(ART_HOME_BTN + "_pressed"),
			"hover_pressed": _art_box(ART_HOME_BTN + "_pressed"), "disabled": _art_box(ART_HOME_BTN + "_disabled")}
		for state in states:
			var box: StyleBoxTexture = states[state] if states[state] != null else normal
			if name == BUTTON_HOME_PRIMARY and state == "hover":
				box = _art_box(ART_HOME_BTN_PRIMARY)
				box.modulate_color = Color(1.08, 1.08, 1.08)
			box.content_margin_left = pad.x
			box.content_margin_right = pad.x
			box.content_margin_top = pad.y
			box.content_margin_bottom = pad.y
			t.set_stylebox(state, name, box)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(state, name, INK)
		t.set_color("font_disabled_color", name, INK_SOFT)


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
