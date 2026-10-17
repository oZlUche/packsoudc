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
## 美术给了图就是石板（`slab_body` + `slab_edge`，157 补充三）/ 九宫格的纸（`tooltip_paper.png`），没给就是平面底
const PANEL_OVERLAY := &"PanelOverlay"
const LABEL_OVERLAY_TITLE := &"LabelOverlayTitle"
const PANEL_TOOLTIP := &"PanelTooltip"
## 157 补充二：名牌底（战前 / 回放两屏的名牌）
const PANEL_NAMEPLATE := &"PanelNameplate"
## 作者 2026-10-16（背包窗口没有底）：可拖的浮窗（[FloatingWindow]：地图 / 事件屏的背包）也是一整块石板，只是没有标题刻线
const PANEL_WINDOW := &"PanelWindow"
## 164：基地的「家」套件 —— 木牌按钮（左列页签与两颗大按钮；主档是「再来一局」）、粗布文本框（中列读数）、木架（右半边仓库的框）
const BUTTON_HOME := &"ButtonHome"
const BUTTON_HOME_PRIMARY := &"ButtonHomePrimary"
const PANEL_HOME_BOX := &"PanelHomeBox"
const PANEL_SHELF := &"PanelShelf"
## 179：开局屏坐在场地背景上的凹槽板（比背景更暗的板身、细黄铜边、内阴影；深底白字）；美术给了 `setup/groove` 就用图
const PANEL_GROOVE := &"PanelGroove"
## 179：选角色屏 —— 图标牌的底、牌上的数字（28 粗体）、技能名（22 粗体亮黄铜黑描边）、技能说明（17，行距半字）、开局屏标题（白字带阴影）
const PANEL_CAP_TILE := &"PanelCapTile"
const LABEL_CAP_VALUE := &"LabelCapValue"
const LABEL_SKILL_NAME := &"LabelSkillName"
const LABEL_SKILL_TEXT := &"LabelSkillText"
const LABEL_SCREEN_TITLE := &"LabelScreenTitle"
const CAP_VALUE_SIZE := 28
const SKILL_NAME_SIZE := 22
const SKILL_TEXT_SIZE := 17
const SCREEN_TITLE_SIZE := 26
## 166：地图屏的顶端栏（[code]hud_bar[/code] 部件的底：美术给 `hud/bar.png` 九宫格就贴，没给是读数那种半透明深底）、
## 栏里的图标按钮（[IconButton]：背包、放大镜、主动技能；按下态走这个变体）
const PANEL_HUD_BAR := &"PanelHudBar"
const BUTTON_ICON := &"ButtonIcon"
## 167：整颗按钮就是一张图（三态图自己画悬停与按下，[method IconButton.make_art]）—— 各态都没有底
const BUTTON_ART := &"ButtonArt"
## 168：大标题（马善政，[method UiPalette.display_font]）—— 主菜单游戏名、开局屏与开场事件的章节名、宝箱屏的说明字
const LABEL_DISPLAY := &"LabelDisplay"

## 全部变体（测试看齐全）
const VARIATIONS := [BUTTON_PRIMARY, BUTTON_SECONDARY, BUTTON_DIM, LABEL_TITLE, LABEL_DIM, LABEL_WARN,
	PANEL_DARK, PANEL_LINE, RICH_BODY, RICH_SMALL, PANEL_HUD, LABEL_HUD, LABEL_HUD_LARGE, LABEL_HUD_DOUBLE,
	PANEL_OVERLAY, LABEL_OVERLAY_TITLE, PANEL_TOOLTIP, PANEL_NAMEPLATE, BUTTON_HOME, BUTTON_HOME_PRIMARY, PANEL_HOME_BOX, PANEL_SHELF,
	PANEL_HUD_BAR, BUTTON_ICON, LABEL_DISPLAY, BUTTON_ART, PANEL_WINDOW, PANEL_GROOVE, PANEL_CAP_TILE, LABEL_CAP_VALUE,
	LABEL_SKILL_NAME, LABEL_SKILL_TEXT, LABEL_SCREEN_TITLE]

const TITLE_SIZE := 18
## 168：大标题字号
const DISPLAY_SIZE := 40
const PANEL_MARGIN := 16
const PANEL_LINE_MARGIN := 8
const RICH_BODY_SIZE := 20
const RICH_SMALL_SIZE := 13
const HUD_MARGIN := 8
const HUD_LARGE_SIZE := 34
const HUD_DOUBLE_SIZE := 28
const OVERLAY_TITLE_SIZE := 20
const TOOLTIP_MARGIN := 10
## 157：悬浮窗底的贴图文件名（不带扩展名；旁边同名 `.json` 写九宫格边距）。
## 170（作者定）：悬浮窗改深底白字；定稿（作者 2026-10-14「样式就这样吧」）是两层 —— 黄铜边框九宫格（`tip/tooltip_frame`，中心透明，json `tone: dark`）
## 叠在深皮革板身（`tip/tooltip_body`，平铺、边框底下也铺）上，同石板一样用 [SlabStyle] 画；原来的纸（`tooltip_paper`）、整张黑曜石（`tooltip_dark`）都退了
const ART_TOOLTIP := "tip/tooltip_frame"
const ART_TOOLTIP_BODY := "tip/tooltip_body"
## 170：悬浮窗里的行内图标（增益 / 受益 / 装载 / 金币 / 秤砣 / 钉子）与棋盘邻居格上的格位图标（`<id>_on` / `<id>_off`，32 px）
const TIP_ICON_DIR := "res://assets/ui/tip/"
## 170：带色的字描边（深底上提亮）：统一黑 75%（待定 4 A）
const OUTLINE_SIZE := 2
const OUTLINE_COLOR := Color(0, 0, 0, 0.75)
## 170：斜体（说明文字）—— 正文字体没有斜体字形，斜切这么多
const ITALIC_SLANT := 0.2
## 157 补充三（作者定：一屏一块完整石板，不要石砖墙）：石板的板身（平铺的纹）与板边（九宫格，中心透明；json 有 `title_height`），
## 板里的分区是刻进板里的凹槽（`PanelDark` / `PanelLine` / `PanelHud` 都用它）。原来的整屏砖墙底与三种小石板退了
const ART_SLAB_BODY := "slab_body"
const ART_SLAB_EDGE := "slab_edge"
## 顶端栏专用的长条板边（贴屏幕顶、没有标题刻线、底下一道投影；`margin` 的上下就是栏里的组居中的那一块）
const ART_SLAB_BAR := "slab_bar"
const ART_INSET := "inset"
## 石板顶边：标题条下沿到板边九宫格上边距之间留给刻线的那一段
const TITLE_LINE_GAP := 6.0
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
## 179：开局三页的整屏背景「选人场地」（铺满裁边）与三栏的凹槽板；没图：纯色底、平面板
const ART_SETUP_BG := "setup/bg_hall"
const ART_GROOVE := "setup/groove"
## 战斗界面的整屏背景（白天的沙地场子，铺满裁边；深浅读图旁 json 的 `tone`）；没图：照旧纯色底
const ART_BATTLE_BG := "battle/battle_bg"
## 179：凹槽板没图时的平面底（样稿第二版的色）
const GROOVE_BG := Color("14161c")
const GROOVE_EDGE := Color("5a4522")
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
static var _font_italic: Font = null
static var _font_bold_italic: Font = null
static var _font_title: Font = null
static var _font_display: Font = null
## 157：界面贴图的目录。测试指到 `res://tests/fixtures/ui/`（那里放一张小图），用完改回来
static var asset_root := "res://assets/ui/"


## 按设置生成一份新主题（不挂）
static func build(settings: GameSettings = null) -> Theme:
	UiPalette.text_colors()     # 169：浅底的墨色读字色模板，先读
	var t := Theme.new()
	_fill(t, _bg_of(settings))
	return t


## 当前那一份（没有就按现在的底色建）
static func current() -> Theme:
	if _current == null:
		UiPalette.text_colors()
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
		# 169：语义色（生命红、治疗绿……）是按深底配的 —— 进树后按所在的底取模板的版本（浅底暗字）
		l.set_meta(&"dark_color", color)
		if not l.tree_entered.is_connected(retone_label.bind(l)):
			l.tree_entered.connect(retone_label.bind(l))
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


## 179：同 [method panel]，四边内边距各给（左 / 上 / 右 / 下）
static func panel_margins(p: PanelContainer, variation: StringName, l: int, t: int, r: int, b: int) -> PanelContainer:
	panel(p, -1, variation)
	var box := current().get_stylebox("panel", variation).duplicate() as StyleBox
	box.content_margin_left = l
	box.content_margin_top = t
	box.content_margin_right = r
	box.content_margin_bottom = b
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


## 168：大标题（马善政，[constant LABEL_DISPLAY]）；字号不是 [constant DISPLAY_SIZE] 才覆写
static func make_display(text: String, font_size: int = DISPLAY_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = LABEL_DISPLAY
	if font_size != DISPLAY_SIZE:
		l.add_theme_font_size_override("font_size", font_size)
	return l


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


## 一段 BBCode 正文（169：颜色按所在的底取深版 / 浅版；之后换字走 [method set_rich]）：高度随内容、自己不滚（放进调用方的滚动区或面板里）、按 [param width] 折行；
## 字号走 [method rich]（17 / 13 号选变体，别的逐个给）
static func rich_block(width: float, font_size: int = FONT_SIZE, bbcode: String = "") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = width
	rich(r, font_size)
	set_rich(r, bbcode)
	r.tree_entered.connect(retone.bind(r))     # 169：进树才知道压在什么底上
	return r


## 170：斜切一份字体当斜体用（[constant ITALIC_SLANT]）
static func slanted(base: Font) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_transform = Transform2D(Vector2(1.0, ITALIC_SLANT), Vector2(0.0, 1.0), Vector2.ZERO)
	return v


## 170：一段字描边（[constant OUTLINE_SIZE] / [constant OUTLINE_COLOR]）—— 定稿只给悬浮窗里的名字和稀有度名用；正文里带色的字不描
static func outline(bbcode: String) -> String:
	return "[outline_size=%d][outline_color=#%s]%s[/outline_color][/outline_size]" % [OUTLINE_SIZE, OUTLINE_COLOR.to_html(true), bbcode]


## 170：行内图标 `[img=16x16]…[/img]`；图不在退回 [param fallback] 文字（「【增益】」「值」……）
static func tip_icon(id: String, fallback: String, px: int = 16) -> String:
	var path := TIP_ICON_DIR + id + ".png"
	# 作者 2026-10-16（脚注只剩数字、没有金币 / 秤砣）：只看 .import 在不在不够 —— 没导入成的图 [img] 画成空白；真读得出来才用图，读不出写字
	if not _tip_icons.has(path):
		_tip_icons[path] = ResourceLoader.exists(path) and load(path) is Texture2D
	if not bool(_tip_icons[path]):
		return fallback
	return "[img=%dx%d]%s[/img]" % [px, px, path]


## 170：棋盘邻居格上的格位图标（`grant_on` / `receive_off` / `load_on` ……，32 px）；不在返回 null（画回半透明方框）
static func slot_icon(kind: String, lit: bool) -> Texture2D:
	var path := TIP_ICON_DIR + "%s_%s.png" % [kind, "on" if lit else "off"]
	if not _slot_icons.has(path):
		_slot_icons[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _slot_icons[path]


static var _slot_icons := {}
## tip_icon 的图读不读得出来（路径 → bool）
static var _tip_icons := {}


## 170：在 `_draw` 之外先把格位图标读进来 —— 兼容渲染器下第一次在 `_draw` 里才读的贴图会画成白块（[InventoryView] 建出来时调）
static func warm_slot_icons() -> void:
	for kind in ["grant", "receive", "load"]:
		slot_icon(kind, true)
		slot_icon(kind, false)


## 清空一个节点的全部子节点：先摘下来再 free —— queue_free 到帧末才真的走，同一帧里数子节点会把旧的也数进去
static func clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## 根场景的前奏（启动器、沙盒、编辑器）：读设置让底色跟着走（091）、装主题、铺一块纯色底（铺满、不挡鼠标；157 补充三起不铺石砖墙）。
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


#region 深浅与字色（157 补，作者定：浅底黑字、深底白字 —— 每块底都要标深浅，字色按它选）
const TONE_DARK := &"dark"
const TONE_LIGHT := &"light"
## 每块底（面板变体）的深浅：没用美术图时按这张表；用了图按图旁 json 的 `tone`（美术交图时必须写，测试看）。
## **新加面板变体必须登记在这里**（测试看全）
const PANEL_TONES := {
	PANEL_DARK: TONE_DARK, PANEL_LINE: TONE_DARK, PANEL_HUD: TONE_DARK, PANEL_OVERLAY: TONE_DARK, PANEL_TOOLTIP: TONE_DARK,
	PANEL_NAMEPLATE: TONE_DARK, PANEL_HOME_BOX: TONE_LIGHT, PANEL_SHELF: TONE_DARK, PANEL_HUD_BAR: TONE_DARK,
	PANEL_WINDOW: TONE_DARK, PANEL_GROOVE: TONE_DARK, PANEL_CAP_TILE: TONE_DARK,
}
## 面板变体用哪张美术图（有图时深浅读它的 json）
## 157 补充三：叠层框与顶端栏是石板（深浅读板边的 json；顶端栏是自己那张长条板边），板里的分区都是凹槽
const PANEL_ART := {PANEL_DARK: ART_INSET, PANEL_LINE: ART_INSET, PANEL_HUD: ART_INSET, PANEL_OVERLAY: ART_SLAB_EDGE, PANEL_TOOLTIP: ART_TOOLTIP,
	PANEL_NAMEPLATE: ART_NAMEPLATE, PANEL_HOME_BOX: ART_HOME_BOX, PANEL_SHELF: ART_SHELF, PANEL_HUD_BAR: ART_SLAB_BAR,
	PANEL_WINDOW: ART_SLAB_EDGE, PANEL_GROOVE: ART_GROOVE}
## 浅底上的字色（美术规范的墨、褐墨，警示用压暗的铜褐）；浅底本身是亮纸。
## 169：读字色模板 `fg / dim / warn` 的浅版（[method text_colors_changed] 换），这几个常量是文件不在时的默认
const INK_DEFAULT := Color("2e2219")
const INK_SOFT_DEFAULT := Color("5a4433")
const INK_WARN_DEFAULT := Color("9a5a22")
static var INK := INK_DEFAULT
static var INK_SOFT := INK_SOFT_DEFAULT
static var INK_WARN := INK_WARN_DEFAULT
const PAPER := Color("f6eedb")
## 浅底上的字和底至少要这么大的对比（WCAG 正文 4.5）
const MIN_CONTRAST := 4.5

static var _tone_themes := {}


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
	for pair in [[LABEL_TITLE, INK], [LABEL_DIM, INK_SOFT], [LABEL_WARN, INK_WARN], [LABEL_OVERLAY_TITLE, INK], [LABEL_DISPLAY, INK], [LABEL_HUD, INK], [LABEL_HUD_LARGE, INK], [LABEL_HUD_DOUBLE, INK]]:
		t.set_type_variation(pair[0], "Label")
		t.set_color("font_color", pair[0], pair[1])
	t.set_type_variation(LABEL_SCREEN_TITLE, "Label")     # 写在浅色背景画上的大标题：墨字，不要阴影（深底那圈黑影在浅底上发糊）
	t.set_color("font_color", LABEL_SCREEN_TITLE, INK)
	t.set_color("font_shadow_color", LABEL_SCREEN_TITLE, Color(PAPER, 0.0))
	t.set_color("default_color", "RichTextLabel", INK)
	for v in [RICH_BODY, RICH_SMALL]:
		t.set_type_variation(v, "RichTextLabel")
		t.set_color("default_color", v, INK)
	_tone_themes[tone] = t
	return t


## 给一块底挂上它的字色（[method panel]、[OverlayFrame]、[HudWidget] 调）。深底不动别人挂的主题，只摘掉以前挂的字色。
## 169：同时把深浅记在这块底的 `tone` 元数据上 —— 里面的富文本往上找它（[method tone_at]），调用点不用自己传
static func apply_tone(c: Control, variation: StringName) -> void:
	set_tone(c, tone_of(variation))


## 按给定的深浅挂字色（不经面板变体：比如直接写在整屏背景图上的那几行字，深浅读 [method art_tone]）
static func set_tone(c: Control, tone: StringName) -> void:
	c.set_meta(&"tone", tone)
	var t := text_theme(tone)
	if t != null or _tone_themes.values().has(c.theme):
		c.theme = t


## 一张整屏背景图的深浅：有图读 json 的 `tone`（没写按深）；没图 = 纯色底，深
static func art_tone(art_name: String) -> StringName:
	if art(art_name) == null:
		return TONE_DARK
	var t := StringName(String(art_meta(art_name).get("tone", "")))
	return t if t == TONE_LIGHT else TONE_DARK


## 169：这个控件压在深底还是浅底上 —— 自己或往上第一个带 `tone` 元数据的祖先说了算；一路都没有 = 深
static func tone_at(n: Node) -> StringName:
	while n != null:
		if n.has_meta(&"tone"):
			return StringName(n.get_meta(&"tone"))
		n = n.get_parent()
	return TONE_DARK


## 169：给富文本块换字（原始 BBCode 记在 `raw` 元数据上，颜色按 [method tone_at] 取版；进树、换底时 [method retone] 重算）。
## 样式码颜色名（`[color=@hp]`）和写死的十六进制都行 —— 统一走 [method UiPalette.toned]
static func set_rich(r: RichTextLabel, bbcode: String) -> void:
	r.set_meta(&"raw", bbcode)
	r.text = UiPalette.toned(bbcode, tone_at(r))


## 按现在的底重算一块富文本（[method rich_block] 进树时自动调）
static func retone(r: RichTextLabel) -> void:
	if r.has_meta(&"raw"):
		r.text = UiPalette.toned(String(r.get_meta(&"raw")), tone_at(r))


## 169：[method label] 覆写过语义色的标签按现在的底换版本
static func retone_label(l: Label) -> void:
	if l.has_meta(&"dark_color"):
		l.add_theme_color_override("font_color", UiPalette.for_tone(l.get_meta(&"dark_color"), tone_at(l)))


## 换底之后（地图底图切换、设置换主题、配色页重读模板）：把 [param root] 下面所有富文本块与语义色标签按新的底重算一遍
static func refresh_tones(root: Node) -> void:
	if root is RichTextLabel:
		retone(root)
	elif root is Label:
		retone_label(root)
	for c in root.get_children():
		refresh_tones(c)


## 浅底上的 BBCode（169 起只是 [method UiPalette.toned] 的转发）：颜色名按模板、写死的亮色换浅版或墨水版；深底只换颜色名
static func ink_bbcode(text: String, tone: StringName) -> String:
	return UiPalette.toned(text, tone)


## 169：字色模板读完（或重读）—— 墨色跟着模板的浅版，浅底小主题重建，已建好的主题原地重填
static func text_colors_changed() -> void:
	var styles: Dictionary = UiPalette.text_colors()["styles"]
	INK = styles["fg"]["light"]
	INK_SOFT = styles["dim"]["light"]
	INK_WARN = styles["warn"]["light"]
	_tone_themes.clear()


## 回代码默认的墨色（读模板之前：缺文件时浅版按默认墨色压）
static func reset_ink() -> void:
	INK = INK_DEFAULT
	INK_SOFT = INK_SOFT_DEFAULT
	INK_WARN = INK_WARN_DEFAULT


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


## 石板顶上标题条的高（`slab_edge.json` 的 `title_height`，刻线在它下面）；没有石板图 0 = 按字高
static func frame_title_height() -> int:
	return int(art_meta(ART_SLAB_EDGE).get("title_height", 0)) if has_slab() else 0


## 157 补充三：板身、板边两张图都在才画石板；缺一张就是原来的平面底
static func has_slab() -> bool:
	return art(ART_SLAB_BODY) != null and art(ART_SLAB_EDGE) != null


## 一整块石板的底（[SlabStyle]：板身平铺 + 板边九宫格）；没图 null。参数同 [method _art_box]（内边距按板边）；
## [param edge_art] 板边用哪张：默认叠层的 `slab_edge`，顶端栏是 `slab_bar`（缺这张退回平面底）
static func slab_box(title_strip: bool = false, content: int = -1, edge_art: String = ART_SLAB_EDGE) -> SlabStyle:
	if not has_slab():
		return null
	return layered_box(edge_art, ART_SLAB_BODY, title_strip, content)


## 两层的底（[SlabStyle]）：[param body_art] 平铺做板身，[param edge_art] 九宫格叠在上面（内边距按它）；缺一张 null。
## 石板（[method slab_box]）和 170 定稿的悬浮窗（皮革 + 黄铜边框）都走这里
static func layered_box(edge_art: String, body_art: String, title_strip: bool = false, content: int = -1) -> SlabStyle:
	if art(edge_art) == null or art(body_art) == null:
		return null
	var s := SlabStyle.new()
	s.edge = _art_box(edge_art, title_strip, content)
	var body := StyleBoxTexture.new()
	body.texture = art(body_art)
	body.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	body.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.body = body
	s.body_inset = SlabStyle.inset_of(art_meta(edge_art).get("body_inset", 0))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_content_margin(side, s.edge.get_content_margin(side))
	return s


## 底是不是美术的图（九宫格或石板）：[OverlayFrame] 按它决定外框边距听图的还是听各屏的
static func is_art_box(box: StyleBox) -> bool:
	return box is StyleBoxTexture or box is SlabStyle


## 157 补充三：把一块面板做成一整块石板（叠层框、底屏的大板）：石板变体 + 按石板的深浅挂字色
static func slab(c: PanelContainer) -> PanelContainer:
	c.theme_type_variation = PANEL_OVERLAY
	apply_tone(c, PANEL_OVERLAY)
	return c


## 九宫格底：图 + json 的边距（没写边距按图边长的四分之一）。没图 null。
## [param title_strip] 真 = 石板框：顶边的内边距只留到标题条上沿（标题条 [OverlayFrame] 自己占住刻线上方那一条）；
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
	# 石板框：标题字刻在板顶那道刻线上方 —— 标题条（高 `title_height`）的下沿离内容区上沿留 [constant TITLE_LINE_GAP]（刻线所在）
	s.content_margin_top = maxf(0.0, float(m[1]) - float(art_meta(name).get("title_height", 0)) - TITLE_LINE_GAP) if title_strip else float(m[1])
	s.content_margin_right = float(m[2])
	s.content_margin_bottom = float(m[3])
	if content >= 0:
		s.set_content_margin_all(float(content))
	return s


## 164：基地整屏背景（`home/bg_home.png`，按比例铺满、多的裁掉）；没图什么也不加、返回 null
static func dress_home_backdrop(rect: ColorRect) -> TextureRect:
	return dress_backdrop(rect, ART_HOME_BG, "HomeBackdrop")


## 整屏背景图铺进 [param rect]（按比例铺满、多的裁掉）；没图什么也不加、返回 null（179：开局屏的场地也走这里）
static func dress_backdrop(rect: ColorRect, art_name: String, node_name: String) -> TextureRect:
	var tex := art(art_name)
	if tex == null:
		return null
	var pic := TextureRect.new()
	pic.name = node_name
	pic.texture = tex
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(pic)
	return pic


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
	if _font_title == null:
		_font_title = UiPalette.title_font()
	if _font_display == null:
		_font_display = UiPalette.display_font()
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
	# 168：标题（名牌也走 LabelTitle）与叠层标题条是朱雀仿宋；大标题是马善政
	t.set_font("font", LABEL_TITLE, _font_title)
	t.set_type_variation(LABEL_DISPLAY, "Label")
	t.set_font("font", LABEL_DISPLAY, _font_display)
	t.set_font_size("font_size", LABEL_DISPLAY, DISPLAY_SIZE)
	t.set_color("font_color", LABEL_DISPLAY, UiPalette.FG)
	# 面板
	# 157 补充三：板里的分区是刻进板里的凹槽（`inset.png` 九宫格，内边距照旧按变体的默认值，各屏排版不动），没图是原来的平面底
	t.set_type_variation(PANEL_DARK, "PanelContainer")
	var groove: StyleBox = _art_box(ART_INSET, false, PANEL_MARGIN)
	t.set_stylebox("panel", PANEL_DARK, groove if groove != null else _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	t.set_type_variation(PANEL_LINE, "PanelContainer")
	var inset: StyleBox = _art_box(ART_INSET, false, PANEL_LINE_MARGIN)
	t.set_stylebox("panel", PANEL_LINE, inset if inset != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), PANEL_LINE_MARGIN))
	# 157：叠层的石板框、悬浮窗底 —— 补充三：框是一整块石板（[SlabStyle] 两层），没图和原来一样（框 = PanelDark 的底、悬浮窗 = PanelLine 的底）
	t.set_type_variation(PANEL_OVERLAY, "PanelContainer")
	var frame: StyleBox = slab_box(true)
	t.set_stylebox("panel", PANEL_OVERLAY, frame if frame != null else _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	t.set_type_variation(PANEL_WINDOW, "PanelContainer")
	var window: StyleBox = slab_box(false, PANEL_MARGIN)
	t.set_stylebox("panel", PANEL_WINDOW, window if window != null else _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	t.set_type_variation(LABEL_OVERLAY_TITLE, "Label")
	t.set_font_size("font_size", LABEL_OVERLAY_TITLE, OVERLAY_TITLE_SIZE)
	t.set_font("font", LABEL_OVERLAY_TITLE, _font_title)
	t.set_color("font_color", LABEL_OVERLAY_TITLE, UiPalette.FG)
	t.set_type_variation(PANEL_TOOLTIP, "PanelContainer")
	var paper: StyleBox = layered_box(ART_TOOLTIP, ART_TOOLTIP_BODY)
	t.set_stylebox("panel", PANEL_TOOLTIP, paper if paper != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), TOOLTIP_MARGIN))
	# 157 补充二：名牌底 —— 有图是切角石碑九宫格（内边距按图边），没图是深底细边
	t.set_type_variation(PANEL_NAMEPLATE, "PanelContainer")
	# 作者 2026-10-16（战斗屏的名牌是透明的）：名牌图是凹刻的边、中间几乎透明（本来刻在石板上）—— 底下垫一层板身，放在哪都不透
	var plate: StyleBox = layered_box(ART_NAMEPLATE, ART_SLAB_BODY)
	if plate == null:
		plate = _art_box(ART_NAMEPLATE)
	t.set_stylebox("panel", PANEL_NAMEPLATE, plate if plate != null else _box(panel_bg.darkened(0.15), UiPalette.LINE.lightened(0.25), NAMEPLATE_MARGIN))
	# 164：家的粗布框（浅底墨字）、仓库木架（深底）；没图回落到面板的平面底
	t.set_type_variation(PANEL_HOME_BOX, "PanelContainer")
	var cloth: StyleBox = _art_box(ART_HOME_BOX)
	t.set_stylebox("panel", PANEL_HOME_BOX, cloth if cloth != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), PANEL_MARGIN))
	t.set_type_variation(PANEL_SHELF, "PanelContainer")
	var shelf: StyleBox = _art_box(ART_SHELF)
	t.set_stylebox("panel", PANEL_SHELF, shelf if shelf != null else _box(panel_bg, UiPalette.LINE, PANEL_MARGIN))
	# 179：开局屏的凹槽板
	t.set_type_variation(PANEL_GROOVE, "PanelContainer")
	var groove_box: StyleBox = _art_box(ART_GROOVE)
	t.set_stylebox("panel", PANEL_GROOVE, groove_box if groove_box != null else _groove_box())
	_setup_card(t)
	_home_buttons(t)
	# 150：读数组件（原来地图屏那条 HUD 的无边窄底，搬成变体）
	t.set_type_variation(PANEL_HUD, "PanelContainer")
	var hud_art: StyleBox = _art_box(ART_INSET, false, HUD_MARGIN)     # 157 补充三：读数是刻在板里的凹槽
	var hud_box := _box(panel_bg, UiPalette.LINE, HUD_MARGIN)
	hud_box.set_border_width_all(0)
	t.set_stylebox("panel", PANEL_HUD, hud_art if hud_art != null else hud_box)
	# 166：顶端栏（横贯顶部的一条，左右留 16）与栏里的图标按钮（平时透明，悬停 / 按下才露底）。
	# 157 补充三：栏是一条独立的长石板（同一套板身 + 自己的长条板边 `slab_bar`），没图是半透明深底 + 下边一条线。
	# 板边的上下内边距 = 栏里的组居中的那一块（[HudHost] 读），底下那道投影不算进去
	t.set_type_variation(PANEL_HUD_BAR, "PanelContainer")
	var bar_art: StyleBox = slab_box(false, -1, ART_SLAB_BAR)
	var bar_box := _box(Color(panel_bg, 0.86), UiPalette.LINE, HUD_MARGIN)
	bar_box.set_border_width_all(0)
	bar_box.border_width_bottom = 1
	bar_box.set_corner_radius_all(0)
	t.set_stylebox("panel", PANEL_HUD_BAR, bar_art if bar_art != null else bar_box)
	_button_variation(t, BUTTON_ICON, UiPalette.Tier.MINOR)
	var clear := StyleBoxEmpty.new()
	clear.set_content_margin_all(4)
	t.set_stylebox("normal", BUTTON_ICON, clear)
	t.set_stylebox("disabled", BUTTON_ICON, clear)
	t.set_type_variation(BUTTON_ART, "Button")
	var bare := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, BUTTON_ART, bare)
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
	# 富文本的 [b] 用真粗体（168：思源宋体 Bold），不让引擎拿常规体描粗
	t.set_font("bold_font", "RichTextLabel", _font_bold)
	# 170：[i] 是正文 / 粗体斜切 0.2（字体没有斜体字形）
	if _font_italic == null:
		_font_italic = slanted(_font)
		_font_bold_italic = slanted(_font_bold)
	t.set_font("italics_font", "RichTextLabel", _font_italic)
	t.set_font("bold_italics_font", "RichTextLabel", _font_bold_italic)
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


## 179：选角色屏的几种字与图标牌的底
static func _setup_card(t: Theme) -> void:
	t.set_type_variation(PANEL_CAP_TILE, "PanelContainer")
	var tile := _box(Color("1c1f27"), Color("2c3140"), 10)
	tile.content_margin_left = 14
	tile.content_margin_right = 14
	t.set_stylebox("panel", PANEL_CAP_TILE, tile)
	t.set_type_variation(LABEL_CAP_VALUE, "Label")
	t.set_font("font", LABEL_CAP_VALUE, _font_bold)
	t.set_font_size("font_size", LABEL_CAP_VALUE, CAP_VALUE_SIZE)
	t.set_color("font_color", LABEL_CAP_VALUE, UiPalette.FG)
	t.set_type_variation(LABEL_SKILL_NAME, "Label")
	t.set_font("font", LABEL_SKILL_NAME, _font_bold)
	t.set_font_size("font_size", LABEL_SKILL_NAME, SKILL_NAME_SIZE)
	t.set_color("font_color", LABEL_SKILL_NAME, UiPalette.BTN_PRIMARY_HOVER)
	t.set_color("font_outline_color", LABEL_SKILL_NAME, Color.BLACK)
	t.set_constant("outline_size", LABEL_SKILL_NAME, OUTLINE_SIZE * 2)     # 22 号字上 2 太细
	t.set_type_variation(LABEL_SKILL_TEXT, "Label")
	t.set_font_size("font_size", LABEL_SKILL_TEXT, SKILL_TEXT_SIZE)
	t.set_color("font_color", LABEL_SKILL_TEXT, UiPalette.FG)
	t.set_constant("line_spacing", LABEL_SKILL_TEXT, SKILL_TEXT_SIZE / 2)
	t.set_type_variation(LABEL_SCREEN_TITLE, "Label")
	t.set_font_size("font_size", LABEL_SCREEN_TITLE, SCREEN_TITLE_SIZE)
	t.set_color("font_color", LABEL_SCREEN_TITLE, UiPalette.FG)
	t.set_color("font_shadow_color", LABEL_SCREEN_TITLE, Color(0, 0, 0, 0.85))
	t.set_constant("shadow_offset_x", LABEL_SCREEN_TITLE, 0)
	t.set_constant("shadow_offset_y", LABEL_SCREEN_TITLE, 2)
	t.set_constant("shadow_outline_size", LABEL_SCREEN_TITLE, 6)


## 只挂变体的标签（字号、颜色、字体都在变体里）
static func make_variant_label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	return l


## 179：凹槽板的平面底 —— 暗板身、细黄铜边、往下一点投影
static func _groove_box() -> StyleBoxFlat:
	var s := _box(Color(GROOVE_BG, 0.94), GROOVE_EDGE, PANEL_MARGIN)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 6)
	return s


static func _box(bg: Color, edge: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_content_margin_all(margin)
	return s
#endregion
