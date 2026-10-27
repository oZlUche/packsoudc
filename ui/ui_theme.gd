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
## 235：石刻顶端栏里的读数格与按钮格 —— 浅色石面上的凹槽（`hud/topbar/well`）；栏外照旧 [constant PANEL_HUD]
const PANEL_HUD_WELL := &"PanelHudWell"
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
## 233：商店帐篷布招牌上的标题（红布上的浅字，居中；思源宋体粗 22）
const LABEL_TENT_SIGN := &"LabelTentSign"
const TENT_SIGN_SIZE := 22
const TENT_SIGN_INK := Color("f2e7cb")
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
## 255：选角色屏短板那一行的名字 —— 和技能名同字号、同描边，铁灰色（技能、随身之物是亮黄铜）
const LABEL_FLAW_NAME := &"LabelFlawName"
const LABEL_SCREEN_TITLE := &"LabelScreenTitle"
## 180 补二：开局屏第三页的难度翻页计数器 —— 黑底白字的牌面、压深的黄铜外框（美术给了 `setup/flip_counter` 九宫格就用图）
const PANEL_FLIP_COUNTER := &"PanelFlipCounter"
const LABEL_FLIP_NUM := &"LabelFlipNum"
const FLIP_NUM_SIZE := 72
const FLIP_BRASS := Color("6e5226")
const FLIP_FACE := Color("0b0b0d")
## 180 补三：难度块下面的挑战说明 —— 羊皮纸（浅底，竖向平铺九宫格 `setup/parchment_strip`）与上下两根卷轴；没图平色。纸上的挑战句是墨红
const PANEL_PARCHMENT := &"PanelParchment"
## 180 补四：难度的「−」「＋」（到头时真的灰：底压到板色、字暗一半、没有悬停）与「开启挑战」铜牌按钮（〇级时整块只剩它、背后两根卷好的卷轴就是羊皮纸的顶、底卷轴；美术图 `setup/difficulty_plate`）
const BUTTON_STEP := &"ButtonStep"
const BUTTON_DIFF_PLATE := &"ButtonDiffPlate"
## 180 补五：展开后顶上那枚「当前难度」铜牌（和「开启挑战」按钮面同一块铜，只是不能点）与它上面的字
const PANEL_DIFF_TITLE := &"PanelDiffTitle"
const LABEL_DIFF_TITLE := &"LabelDiffTitle"
const PARCHMENT := Color("e6dcc4")
const SCROLL_ROD := Color("5a4632")
## 180 定稿：挑战句血红、不描边
const PARCHMENT_RED := Color("c81018")
## 180 定稿美术（作者 2026-10-17 12:04「定稿」，`art/ui/setup/p180/`）：开局第二、三页的整套图。各变体没图时退回原来的平面样子
## - 第二页：背包皮框、仓库框（都是深底九宫格）、仓库挂牌页签（普通 / 选中 / 没解锁三张：按钮的常态 / 按下 / 灰态）
## - 第三页：地图条目、规模子条目（选中是 on 图）、摘要便条（浅底）、右下「返回」深色铜 /「出发」亮黄铜（按钮 A 套）
## - 难度组：「−」「＋」各四态（字画在图上）
const PANEL_PACK_LEATHER := &"PanelPackLeather"
const PANEL_STASH_FRAME := &"PanelStashFrame"
const PANEL_SUMMARY_NOTE := &"PanelSummaryNote"
## 10-24：便条（如开局「带入现金」）的抬头 —— 粗体；字号与墨色由造字的地方给
const LABEL_NOTE_TITLE := &"LabelNoteTitle"
## 第三页的东西直接摆在地图纸上（没有板）：一块透明的底，只管内边距；纸是浅底
const PANEL_BARE := &"PanelBare"
## 182：点节点时屏幕正中弹的提示窗（[NodeHintCard]）—— 浅底纸签
const PANEL_NODE_HINT := &"PanelNodeHint"
## 226 批四守门（tests/ui/test_no_bare_text_226.gd）：算「控件」的底 —— 字的祖先里有这些变体之一就算坐在控件上（牌、纸、签、板、提示框）
const PLATE_VARIANTS: Array[StringName] = [PANEL_NAMEPLATE, PANEL_PARCHMENT, PANEL_SUMMARY_NOTE, PANEL_NODE_HINT, PANEL_TOOLTIP,
	PANEL_DIFF_TITLE, PANEL_FLIP_COUNTER, PANEL_DARK, PANEL_GROOVE, PANEL_PACK_LEATHER, PANEL_STASH_FRAME, PANEL_HOME_BOX,
	PANEL_CAP_TILE, PANEL_HUD, PANEL_HUD_WELL, &"TooltipPanel"]
const BUTTON_SETUP_TAB := &"ButtonSetupTab"
## 开局挂牌页签锁着时的页名色
const SETUP_TAB_LOCKED_INK := Color("b8a98c")
const BUTTON_MAP_ENTRY := &"ButtonMapEntry"
const BUTTON_MAP_SUB := &"ButtonMapSub"
const BUTTON_SETUP_BACK := &"ButtonSetupBack"
const BUTTON_SETUP_GO := &"ButtonSetupGo"
const BUTTON_DIFF_MINUS := &"ButtonDiffMinus"
const BUTTON_DIFF_PLUS := &"ButtonDiffPlus"
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
## 168：大标题（寒蝉锦书宋 Heavy，子集改名 PackSDC Display；2026-10-27 起替换马善政，[method UiPalette.display_font]）—— 主菜单游戏名、开局屏与开场事件的章节名、宝箱屏的说明字
const LABEL_DISPLAY := &"LabelDisplay"
## 197 补充一 §6：主菜单 / 启动屏的游戏名 —— 思源宋体 Bold、暖纸色、6 px 深褐描边、下投影、字距 +6（[method make_hero_title]）
const LABEL_HERO_TITLE := &"LabelHeroTitle"
## 197 补充三 §14：主菜单左下角那几行字（思源宋体 Bold 描边字，悬停 / 焦点行前一枚铜菱形）与最底下一行小字链接（语言、开发工具、退出）
const BUTTON_MENU_LINE := &"ButtonMenuLine"
const BUTTON_MENU_FOOT := &"ButtonMenuFoot"
## 251 补充一：铁匠铺「打造」平键（烧亮的铁红，[constant UiPalette.HOT_IRON]）—— 四态图到之前用
const BUTTON_FORGE := &"ButtonForge"

## 全部变体（测试看齐全）
const VARIATIONS := [BUTTON_PRIMARY, BUTTON_SECONDARY, BUTTON_DIM, LABEL_TITLE, LABEL_DIM, LABEL_WARN,
	PANEL_DARK, PANEL_LINE, RICH_BODY, RICH_SMALL, PANEL_HUD, PANEL_HUD_WELL, LABEL_HUD, LABEL_HUD_LARGE, LABEL_HUD_DOUBLE,
	PANEL_OVERLAY, LABEL_OVERLAY_TITLE, LABEL_TENT_SIGN, PANEL_TOOLTIP, PANEL_NAMEPLATE, BUTTON_HOME, BUTTON_HOME_PRIMARY, PANEL_HOME_BOX, PANEL_SHELF,
	PANEL_HUD_BAR, BUTTON_ICON, LABEL_DISPLAY, BUTTON_ART, PANEL_WINDOW, PANEL_GROOVE, PANEL_CAP_TILE, LABEL_CAP_VALUE,
	LABEL_SKILL_NAME, LABEL_SKILL_TEXT, LABEL_SCREEN_TITLE, PANEL_FLIP_COUNTER, LABEL_FLIP_NUM, PANEL_PARCHMENT, BUTTON_STEP, BUTTON_DIFF_PLATE,
	PANEL_DIFF_TITLE, LABEL_DIFF_TITLE, PANEL_PACK_LEATHER, PANEL_STASH_FRAME, PANEL_SUMMARY_NOTE, BUTTON_SETUP_TAB,
	BUTTON_MAP_ENTRY, BUTTON_MAP_SUB, BUTTON_SETUP_BACK, BUTTON_SETUP_GO, BUTTON_DIFF_MINUS, BUTTON_DIFF_PLUS, PANEL_BARE, PANEL_NODE_HINT,
	LABEL_HERO_TITLE, BUTTON_MENU_LINE, BUTTON_MENU_FOOT, LABEL_NOTE_TITLE, BUTTON_FORGE, LABEL_FLAW_NAME]

const TITLE_SIZE := 18
## 168：大标题字号
const DISPLAY_SIZE := 40
## 197 补充一 §6：游戏名（1080 高时；屏幕按高等比缩放；补充三：居中上方、128 号）、颜色、描边、投影、字距
const HERO_TITLE_SIZE := 128
const HERO_TITLE_COLOR := Color("f0e2c4")
const HERO_OUTLINE_COLOR := Color("1a1410")
const HERO_OUTLINE := 6
const HERO_SHADOW := Color(0, 0, 0, 0.6)
const HERO_SHADOW_OFFSET := Vector2i(0, 4)
const HERO_SHADOW_SPREAD := 4
const HERO_SPACING := 6
## 197 补充三 §14：主菜单的字 —— 主档 44 / 次档 34 号，暖纸色、悬停提亮，7 px 深褐描边；行前菱形（≈ 0.4 字高、离字 14）画在固定的左缩进里；
## 最底下一行小字 18 号
const MENU_PRIMARY_SIZE := 44
const MENU_SECONDARY_SIZE := 34
const MENU_LINE_COLOR := Color("f0e2c4")
const MENU_LINE_HOVER := Color("fff6e0")
const MENU_LINE_OUTLINE := 7
const MENU_MARK_COLOR := Color("b08a4a")
const MENU_MARK_GAP := 14.0
const MENU_MARK_SHARE := 0.4
const MENU_LINE_INDENT := 32
const MENU_FOOT_SIZE := 18
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
## 235：石刻顶端栏的平铺段（在就是石刻皮，栏的底空着）
const ART_TOPBAR_TILE := "hud/topbar/bar_tile"
## 235：石刻顶端栏里那几格的浅色凹槽
const ART_HUD_WELL := "hud/topbar/well"
const ART_INSET := "inset"
## 石板顶边：标题条下沿到板边九宫格上边距之间留给刻线的那一段
const TITLE_LINE_GAP := 6.0
## 157 补充二：名牌底、肖像框（中间透明，画在肖像位外扩 json `inset` 处；徽记位同一张拉大）、没肖像时的占位
const ART_NAMEPLATE := "nameplate_bronze"
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
## 197 补充一 §5：主菜单轮换的三张整屏画（营地 → 军营 → 地图；2112 × 1320，四边留出血给镜头走）
const ART_MENU_BGS: Array[String] = ["menu/bg_camp", "menu/bg_legion", "menu/bg_map"]
## 179：开局三页的整屏背景「选人场地」（铺满裁边）与三栏的凹槽板；没图：纯色底、平面板
const ART_SETUP_BG := "setup/bg_hall"
## 作者 2026-10-17：选人场地只给第一页；第二页（带装备）木板拼接 / 仓库，第三页（选地图）桌上铺着的军用地图。没图：纯色底
const ART_SETUP_KIT_BG := "setup/bg_kit"
const ART_SETUP_MAP_BG := "setup/bg_map"
const ART_GROOVE := "setup/groove"
## 180 补二：难度翻页计数器的外框（深黄铜）；定稿：窗里一张翻页卡（下）+ 数字 + 中缝（上）
const ART_FLIP_COUNTER := "setup/diff_counter_frame"
const ART_FLIP_CARD := "setup/diff_flip_card"
const ART_FLIP_SPLIT := "setup/diff_flip_split"
## 180 补三：挑战说明的羊皮纸条（纵向平铺）与上下卷轴（同一张图）；补五：「开启挑战」铜牌（四态 `_normal/_hover/_pressed/_disabled`）
const ART_PARCHMENT_STRIP := "setup/diff_parch"
const ART_SCROLL_ROD_TOP := "setup/diff_roller"
const ART_SCROLL_ROD_BOTTOM := "setup/diff_roller"
const ART_DIFFICULTY_PLATE := "setup/diff_open_plate"
## 180 定稿：「当前难度」梯形标题牌、加减、第二页两块框与页签、第三页地图条目 / 规模 / 便条 / 按钮 A 套、预览圈的虚线参数
const ART_DIFF_TITLE := "setup/diff_title_tab"
const ART_DIFF_MINUS := "setup/diff_minus"
const ART_DIFF_PLUS := "setup/diff_plus"
const ART_PACK_LEATHER := "setup/pack_leather"
const ART_STASH_FRAME := "setup/stash_frame"
const ART_SETUP_TAB := "setup/tab"
const ART_MAP_ENTRY := "setup/map_entry"
const ART_MAP_SUB := "setup/map_sub"
const ART_SUMMARY_NOTE := "setup/summary_note"
const ART_SETUP_BACK := "setup/btn_back"
const ART_SETUP_GO := "setup/btn_go"
const ART_RINGS := "setup/rings"
## 182：第三页纸上的入口小旗（作者 15:32 定；`_normal` / `_hover` / `_sel` 三态，锚点在图中心），居中提示窗的纸签底与上沿正中的红蜡封（单独摆，不进九宫格）；
## 没图：小旗现画成纸底墨圈、纸签退回摘要便条
const ART_SPAWN_MARK := "setup/spawn_flag"
const ART_NODE_HINT := "setup/node_tip_paper"
const ART_NODE_SEAL := "setup/node_tip_seal"
## 184：地图上的玩家棋子（锚点 = 脚底中心，对准节点圆心）、离屏指示的小棋子、图例里的棋子与小旗、步数签的小纸签底
const ART_MAP_PAWN := "map/player_pawn"
const ART_MAP_PAWN_SMALL := "map/pawn_36"
const ART_LEGEND_PAWN := "map/pawn_24"
const ART_LEGEND_FLAG := "map/flag_24"
const ART_MAP_TAG := "map/tag_paper"
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
static var _font_hero: Font = null
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


## 168：大标题（寒蝉锦书宋 Heavy，[constant LABEL_DISPLAY]）；字号不是 [constant DISPLAY_SIZE] 才覆写
static func make_display(text: String, font_size: int = DISPLAY_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = LABEL_DISPLAY
	if font_size != DISPLAY_SIZE:
		l.add_theme_font_size_override("font_size", font_size)
	return l


## 197 补充一 §6：游戏名（[constant LABEL_HERO_TITLE]）；字号不是 [constant HERO_TITLE_SIZE] 才覆写（主菜单按屏高缩放时改它）
static func make_hero_title(text: String, font_size: int = HERO_TITLE_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = LABEL_HERO_TITLE
	set_hero_size(l, font_size)
	return l


## 游戏名换字号（窗口改了高度）
static func set_hero_size(l: Label, font_size: int) -> void:
	if font_size == HERO_TITLE_SIZE:
		l.remove_theme_font_size_override("font_size")
	else:
		l.add_theme_font_size_override("font_size", font_size)


## 197 补充三 §14：主菜单的一行字（[constant BUTTON_MENU_LINE]）：左对齐、描边；悬停或键盘焦点时行前画一枚铜菱形，按下时菱形与字一起下沉 1 px。
## 字号不是主档 44 才覆写
static func make_menu_line(text: String, font_size: int, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.theme_type_variation = BUTTON_MENU_LINE
	if font_size != MENU_PRIMARY_SIZE:
		b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(handler)
	b.draw.connect(_draw_menu_mark.bind(b))
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	return b


## 这一行现在亮不亮（悬停或有焦点）—— 亮的才画菱形
static func menu_line_lit(b: Button) -> bool:
	return b.is_hovered() or b.has_focus()


static func _draw_menu_mark(b: Button) -> void:
	if not menu_line_lit(b):
		return
	var em := float(b.get_theme_font_size("font_size"))
	var half := em * MENU_MARK_SHARE * 0.5
	var sink := 1.0 if b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else 0.0
	var c := Vector2(MENU_LINE_INDENT - MENU_MARK_GAP - half, b.size.y * 0.5 + sink)
	b.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -half), c + Vector2(half, 0), c + Vector2(0, half), c + Vector2(-half, 0)]), MENU_MARK_COLOR)


## 197 补充一 §7：左下那一行的小字链接（暗色，悬停变亮）
static func make_menu_link(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.theme_type_variation = BUTTON_MENU_FOOT
	b.pressed.connect(handler)
	return b


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


## 164：家的木牌按钮（[constant BUTTON_HOME]；[param primary] = 「再来一局」那颗）。
## 228：[param min_size] / [param font_size] 给了就拉到那么大、字换那个号（结算第二页的「一键置入」「整理」180 × 67）
static func make_home_button(text: String, handler: Callable, primary: bool = false, min_size: Vector2 = Vector2.ZERO, font_size: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = BUTTON_HOME_PRIMARY if primary else BUTTON_HOME
	if min_size != Vector2.ZERO:
		b.custom_minimum_size = min_size
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if font_size > 0:
		b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(handler)
	return b


## 乙 石刻：基地出售页的下拉框 —— 框用家的木牌四态（[constant BUTTON_HOME]），箭头 `kit/drop_arrow`，字左对齐墨色；
## 弹出单 `kit/popup`（九宫格 16）、悬停行 `kit/popup_hover`（12 / 10 / 10 / 10）、墨字。缺图照旧
const WOOD_OPTION_INK := Color("3e2818")
static func dress_wood_option(ob: OptionButton, font_size: int = 16) -> void:
	if art_cached(ART_HOME_BTN) == null:
		return
	ob.theme_type_variation = BUTTON_HOME
	_dress_drop(ob, font_size, WOOD_OPTION_INK)


## 乙 石刻：神坛二选一的下拉 —— 框用 `kit/chip_*`（同 [StoneChip] 的九宫格，高 40），箭头、弹出单同 [method dress_wood_option]；缺图不动
static func dress_chip_option(ob: OptionButton, font_size: int = 16, disabled_ink: Color = INK_SOFT) -> void:
	if art_cached(StoneChip.ART + "normal") == null:
		return
	var spec: Dictionary = art_meta(StoneChip.LAYOUT).get("chip", {})
	var m: Array = spec.get("nine_slice_margin", [18, 18, 24, 18])
	var ink := Color(String(spec.get("label", {}).get("colors", {}).get("normal", "#2e2219")))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = art_cached(StoneChip.ART + state)
		if box.texture == null:
			box.texture = art_cached(StoneChip.ART + "normal")
		box.texture_margin_left = float(m[0])
		box.texture_margin_top = float(m[1])
		box.texture_margin_right = float(m[2])
		box.texture_margin_bottom = float(m[3])
		box.set_expand_margin_all(6.0)
		box.content_margin_left = StoneChip.PAD_X
		box.content_margin_right = StoneChip.PAD_X
		box.content_margin_top = 0.0
		box.content_margin_bottom = 0.0
		ob.add_theme_stylebox_override(state, box)
	ob.add_theme_stylebox_override("hover_pressed", ob.get_theme_stylebox("pressed"))
	ob.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	ob.add_theme_font_override("font", UiPalette.cjk_font())
	ob.custom_minimum_size.y = StoneChip.HEIGHT
	ob.focus_mode = Control.FOCUS_NONE
	_dress_drop(ob, font_size, ink)
	ob.add_theme_color_override("font_disabled_color", disabled_ink)


## 下拉共用：左对齐墨字、石刻箭头、浅纸弹出单（悬停一条 `kit/popup_hover`）
static func _dress_drop(ob: OptionButton, font_size: int, ink: Color) -> void:
	ob.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ob.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		ob.add_theme_color_override(c, ink)
	var arrow := art_cached("kit/drop_arrow")
	if arrow != null:
		ob.add_theme_icon_override("arrow", arrow)
	ob.add_theme_constant_override("arrow_margin", 8)
	var pop := ob.get_popup()
	var panel := art_cached("kit/popup")
	if panel != null:
		var box := StyleBoxTexture.new()
		box.texture = panel
		box.set_texture_margin_all(16.0)
		box.set_content_margin_all(12.0)
		pop.add_theme_stylebox_override("panel", box)
	var hover_tex := art_cached("kit/popup_hover")
	if hover_tex != null:
		var hb := StyleBoxTexture.new()
		hb.texture = hover_tex
		hb.texture_margin_left = 12.0
		hb.texture_margin_top = 10.0
		hb.texture_margin_right = 10.0
		hb.texture_margin_bottom = 10.0
		pop.add_theme_stylebox_override("hover", hb)
	pop.add_theme_font_override("font", UiPalette.cjk_font())
	pop.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_accelerator_color"]:
		pop.add_theme_color_override(c, ink)
	pop.add_theme_color_override("font_disabled_color", INK_SOFT)


## 224：结算屏的图按钮 —— `<art>_normal / _hover / _pressed / _disabled.png` 四态（图四周各比按钮大 [param bleed]，留给阴影），
## 字不在图上、由这里写（serif_bold，[param center] 是字在按钮里的中心；按下往下挪 1 px）。缺图退回平板按钮
const ART_BTN_INK := {"normal": Color("2e2219"), "hover": Color("16110d"), "pressed": Color("2e2219"), "disabled": Color("8d8a84")}
static func make_art_text_button(text: String, handler: Callable, art: String, btn_size: Vector2, center: Vector2,
		font_size: int, bleed: float = 6.0) -> Button:
	if art_cached(art + "_normal") == null:
		return make_button(text, handler, UiPalette.Tier.PRIMARY, 16)
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = btn_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiPalette.cjk_font_bold())
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var tex := art_cached(art + "_" + state)
		var box := StyleBoxTexture.new()
		box.texture = tex if tex != null else art_cached(art + "_normal")
		box.set_expand_margin_all(bleed)
		box.content_margin_left = maxf(0.0, center.x * 2.0 - btn_size.x)
		box.content_margin_right = maxf(0.0, btn_size.x - center.x * 2.0)
		box.content_margin_top = maxf(0.0, center.y * 2.0 - btn_size.y) + (2.0 if state == "pressed" else 0.0)
		box.content_margin_bottom = maxf(0.0, btn_size.y - center.y * 2.0)
		b.add_theme_stylebox_override(state, box)
		if state == "normal":
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if state == "pressed":
			b.add_theme_stylebox_override("hover_pressed", box)
	b.add_theme_color_override("font_color", ART_BTN_INK["normal"])
	b.add_theme_color_override("font_focus_color", ART_BTN_INK["normal"])
	b.add_theme_color_override("font_hover_color", ART_BTN_INK["hover"])
	b.add_theme_color_override("font_pressed_color", ART_BTN_INK["pressed"])
	b.add_theme_color_override("font_hover_pressed_color", ART_BTN_INK["pressed"])
	b.add_theme_color_override("font_disabled_color", ART_BTN_INK["disabled"])
	b.pressed.connect(handler)
	return b


## 224：标题牌上的字（[constant LABEL_TITLE] 变体 = 朱雀仿宋，字号另给；字色跟所在的底走）
static func make_title_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = LABEL_TITLE
	l.add_theme_font_size_override("font_size", font_size)
	return l


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
	PANEL_WINDOW: TONE_DARK, PANEL_GROOVE: TONE_DARK, PANEL_CAP_TILE: TONE_DARK, PANEL_FLIP_COUNTER: TONE_DARK,
	PANEL_PARCHMENT: TONE_LIGHT, PANEL_DIFF_TITLE: TONE_LIGHT, PANEL_PACK_LEATHER: TONE_DARK, PANEL_STASH_FRAME: TONE_DARK,
	PANEL_SUMMARY_NOTE: TONE_LIGHT, PANEL_BARE: TONE_LIGHT, PANEL_NODE_HINT: TONE_LIGHT, PANEL_HUD_WELL: TONE_LIGHT,
}
## 面板变体用哪张美术图（有图时深浅读它的 json）
## 157 补充三：叠层框与顶端栏是石板（深浅读板边的 json；顶端栏是自己那张长条板边），板里的分区都是凹槽
const PANEL_ART := {PANEL_DARK: ART_INSET, PANEL_LINE: ART_INSET, PANEL_HUD: ART_INSET, PANEL_OVERLAY: ART_SLAB_EDGE, PANEL_TOOLTIP: ART_TOOLTIP,
	PANEL_NAMEPLATE: ART_NAMEPLATE, PANEL_HOME_BOX: ART_HOME_BOX, PANEL_SHELF: ART_SHELF, PANEL_HUD_BAR: ART_SLAB_BAR,
	PANEL_WINDOW: ART_SLAB_EDGE, PANEL_GROOVE: ART_GROOVE, PANEL_FLIP_COUNTER: ART_FLIP_COUNTER,
	PANEL_PARCHMENT: ART_PARCHMENT_STRIP, PANEL_DIFF_TITLE: ART_DIFF_TITLE, PANEL_PACK_LEATHER: ART_PACK_LEATHER,
	PANEL_STASH_FRAME: ART_STASH_FRAME, PANEL_SUMMARY_NOTE: ART_SUMMARY_NOTE, PANEL_NODE_HINT: ART_NODE_HINT, PANEL_HUD_WELL: ART_HUD_WELL}
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
	if art_name != "" and has_art(art_name):
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
	for pair in [[LABEL_TITLE, INK], [LABEL_DIM, INK_SOFT], [LABEL_WARN, INK_WARN], [LABEL_OVERLAY_TITLE, INK], [LABEL_DISPLAY, INK], [LABEL_HUD, INK], [LABEL_HUD_LARGE, INK], [LABEL_HUD_DOUBLE, INK], [LABEL_TENT_SIGN, TENT_SIGN_INK]]:
		t.set_type_variation(pair[0], "Label")
		t.set_color("font_color", pair[0], pair[1])
	t.set_type_variation(LABEL_SCREEN_TITLE, "Label")     # 写在浅色背景画上的大标题：墨字，不要阴影（深底那圈黑影在浅底上发糊）
	t.set_color("font_color", LABEL_SCREEN_TITLE, INK)
	t.set_color("font_shadow_color", LABEL_SCREEN_TITLE, Color(PAPER, 0.0))
	t.set_color("default_color", "RichTextLabel", INK)
	for v in [RICH_BODY, RICH_SMALL]:
		t.set_type_variation(v, "RichTextLabel")
		t.set_color("default_color", v, INK)
	# 180 定稿：难度计数器的数字永远写在黑翻页卡上 —— 摆在浅色地图纸上也还是白字
	t.set_type_variation(LABEL_FLIP_NUM, "Label")
	t.set_color("font_color", LABEL_FLIP_NUM, Color.WHITE)
	# 控件自带的悬浮窗是深皮底：挂在浅底上的控件也写浅字
	t.set_type_variation("TooltipLabel", "Label")
	t.set_color("font_color", "TooltipLabel", UiPalette.FG)
	_tone_themes[tone] = t
	return t


## 深底嵌在浅底里（浅色石板框里的铜名牌）：外面挂的墨字小主题会一路继承进来 —— 这份小主题把同样那几种字色改回全局的浅色字
static func bright_text_theme() -> Theme:
	if _tone_themes.has(&"bright"):
		return _tone_themes[&"bright"]
	var ink := text_theme(TONE_LIGHT)
	var base := current()
	var t := Theme.new()
	for type in ink.get_color_type_list():
		var parent := ink.get_type_variation_base(type)
		if parent != &"":
			t.set_type_variation(type, parent)
		for key in ink.get_color_list(type):
			var at := _color_owner(base, key, type)
			if at != &"":     # 193：全局主题沿变体链都没写这一色 = 不写（让它照常继承），绝不写 Color() 的纯黑
				t.set_color(key, type, base.get_color(key, at))
	_tone_themes[&"bright"] = t
	return t


## 193：[param theme] 里 [param type] 的 [param key] 这一色实际写在哪一层（沿变体链往基类找）；都没有 = 空
static func _color_owner(theme: Theme, key: StringName, type: StringName) -> StringName:
	var at := type
	while at != &"":
		if theme.has_color(key, at):
			return at
		at = theme.get_type_variation_base(at)
	return &""


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
	if not has_art(name):
		return null
	return EventImage.load_texture(asset_root + name + ".png")


## 237：有没有这张图（只查文件，不加载）—— 只想知道「有图没图」的地方用它，别用 [method art]（每次都真加载一遍）
static func has_art(name: String) -> bool:
	var path := asset_root + name + ".png"
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


## 221：画着字的图按语言换 —— 非中文界面有 `<name>_en.png` 就用它（尺寸、原点、可点区域和中文版一样），没有就用原图
static func lang_art(name: String) -> String:
	if UiText.lang != "zh" and ResourceLoader.exists(asset_root + name + "_en.png"):
		return name + "_en"
	return name


## 184：每帧在 `_draw` 里画的小图走这个 —— [method art] 不缓存，画完没人拿着引用，贴图当帧就被释放、画出来是一块白；
## 这里按路径留一份（没有的不记，美术后到也能读到）
static func art_cached(name: String) -> Texture2D:
	var path := asset_root + name
	if _art_cache.has(path):
		return _art_cache[path]
	var tex := art(name)
	if tex != null:
		_art_cache[path] = tex
	return tex


static var _art_cache: Dictionary = {}


## 236 第五项：按路径前缀（相对 [member asset_root]）把 [method art_cached] 记住的图放掉，返回放了几张。
## 只给整屏底图用（1920 级一张 9 MB 显存）：各屏离开时放掉自己的，下次进屏再读（几十毫秒）；小件不放，重读不值
static func release_art(prefix: String) -> int:
	var root := asset_root + prefix
	var gone := 0
	for path in _art_cache.keys():
		if String(path).begins_with(root):
			_art_cache.erase(path)
			gone += 1
	return gone


## 236 第五项：缓存里有没有这张（测试与预热看）
static func art_is_cached(name: String) -> bool:
	return _art_cache.has(asset_root + name)


## 贴图旁边的 `<name>.json`（九宫格边距 `margin: [左, 上, 右, 下]`、石板框的 `title_height`）；没有或读不成字典是空字典
## 237：按路径记住读到的（没有的不记，美术后到也能读到）—— 地图屏、石碑叠层等在 `_draw` 里每次重绘都来读，以前每次开文件、解析
static func art_meta(name: String) -> Dictionary:
	var path := asset_root + name + ".json"
	if _art_meta_cache.has(path):
		return _art_meta_cache[path]
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		_art_meta_cache[path] = d
		return d
	return {}


static var _art_meta_cache: Dictionary = {}


## 石板顶上标题条的高（`slab_edge.json` 的 `title_height`，刻线在它下面）；没有石板图 0 = 按字高
static func frame_title_height() -> int:
	return int(art_meta(ART_SLAB_EDGE).get("title_height", 0)) if has_slab() else 0


## 157 补充三：板身、板边两张图都在才画石板；缺一张就是原来的平面底
static func has_slab() -> bool:
	return has_art(ART_SLAB_BODY) and has_art(ART_SLAB_EDGE)


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


## 157 补充三：把一块面板做成一整块石板（叠层框、底屏的大板）：石板变体 + 按石板的深浅挂字色。
## 224 补充二：[param edge_art] 给了 = 板边换这张（结算屏的 `slab_edge_plain`：没有顶上那道标题刻线）；缺图照旧
static func slab(c: PanelContainer, edge_art: String = "") -> PanelContainer:
	c.theme_type_variation = PANEL_OVERLAY
	apply_tone(c, PANEL_OVERLAY)
	var edge: StyleBox = slab_box(true, -1, edge_art) if edge_art != "" else null
	if edge != null:
		c.add_theme_stylebox_override("panel", edge)
	return c


## 一张九宫格图（边距读同名 json 的 `margin`），内边距跟图边一样；没图 null。贴图走 [method art_cached]（_draw 里画也不会白块）
static func art_box(name: String) -> StyleBoxTexture:
	var box := _art_box(name)
	if box != null:
		box.texture = art_cached(name)
	return box


## 九宫格底：图 + json 的边距（没写边距按图边长的四分之一）。没图 null。
## [param title_strip] 真 = 石板框：顶边的内边距只留到标题条上沿（标题条 [OverlayFrame] 自己占住刻线上方那一条）；
## [param content] ≥ 0 = 内边距用它（换皮不改排版），否则跟图边一样
static func _art_box(name: String, title_strip: bool = false, content: int = -1) -> StyleBoxTexture:
	var tex := art_cached(name)     # 237：StyleBox 反正会一直拿着这张图，留在缓存里不多占；以前每建一块面板都重新加载
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
	# 168：标题（名牌也走 LabelTitle）与叠层标题条是朱雀仿宋；大标题是寒蝉锦书宋 Heavy
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
	t.set_type_variation(LABEL_TENT_SIGN, "Label")     # 233：布招牌是红布，不管窗是深是浅都写浅字
	t.set_font_size("font_size", LABEL_TENT_SIGN, TENT_SIGN_SIZE)
	t.set_font("font", LABEL_TENT_SIGN, UiPalette.cjk_font_bold())
	t.set_color("font_color", LABEL_TENT_SIGN, TENT_SIGN_INK)
	t.set_type_variation(PANEL_TOOLTIP, "PanelContainer")
	var paper: StyleBox = layered_box(ART_TOOLTIP, ART_TOOLTIP_BODY)
	t.set_stylebox("panel", PANEL_TOOLTIP, paper if paper != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), TOOLTIP_MARGIN))
	# 226 批三补：控件自带的 tooltip_text（挂牌、段头签、按钮）也用这块深皮浅字，不再是引擎的小黑框
	var tip_box: StyleBox = paper.duplicate() if paper != null else _box(Color(panel_bg, 0.96), UiPalette.LINE.lightened(0.15), TOOLTIP_MARGIN)
	tip_box.set_content_margin_all(12.0)
	t.set_stylebox("panel", "TooltipPanel", tip_box)
	t.set_color("font_color", "TooltipLabel", UiPalette.FG)
	t.set_font("font", "TooltipLabel", _font)
	t.set_font_size("font_size", "TooltipLabel", 15)
	# 157 补充二：名牌底 —— 有图是九宫格（内边距按图边），没图是深底细边。
	# 作者 2026-10-17：改铜质名牌（士兵牌样式，深铜底亮字；铜板本身不透明，不再垫板身；左上的穿链孔在边距里，内容不压它）
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
	# 179：开局屏的凹槽板
	t.set_type_variation(PANEL_GROOVE, "PanelContainer")
	var groove_box: StyleBox = _art_box(ART_GROOVE)
	t.set_stylebox("panel", PANEL_GROOVE, groove_box if groove_box != null else _groove_box())
	_setup_card(t)
	# 180 补二：难度翻页计数器（没图是平色黑牌 + 压深的黄铜边）
	t.set_type_variation(PANEL_FLIP_COUNTER, "PanelContainer")
	var flip_art: StyleBox = _art_box(ART_FLIP_COUNTER)
	var flip := _box(FLIP_FACE, FLIP_BRASS, 6)
	flip.set_border_width_all(3)
	flip.set_corner_radius_all(6)
	flip.content_margin_left = 28
	flip.content_margin_right = 28
	t.set_stylebox("panel", PANEL_FLIP_COUNTER, flip_art if flip_art != null else flip)
	t.set_type_variation(LABEL_FLIP_NUM, "Label")
	t.set_font_size("font_size", LABEL_FLIP_NUM, FLIP_NUM_SIZE)
	t.set_color("font_color", LABEL_FLIP_NUM, Color.WHITE)
	# 180 补三：羊皮纸（没图是平色纸、不描边）；定稿图 264 宽、纵向平铺，左右是毛边不切九宫格
	t.set_type_variation(PANEL_PARCHMENT, "PanelContainer")
	var parchment_art := _tex_box(ART_PARCHMENT_STRIP, [0, 0, 0, 0])
	if parchment_art != null:
		parchment_art.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE     # 竖着平铺，纸多长都不拉花
	var parchment := _box(PARCHMENT, PARCHMENT, 0)
	parchment.set_border_width_all(0)
	t.set_stylebox("panel", PANEL_PARCHMENT, parchment_art if parchment_art != null else parchment)
	_difficulty_buttons(t)
	_forge_button(t)
	_home_buttons(t)
	_menu_styles(t)
	# 150：读数组件（原来地图屏那条 HUD 的无边窄底，搬成变体）
	t.set_type_variation(PANEL_HUD, "PanelContainer")
	var hud_art: StyleBox = _art_box(ART_INSET, false, HUD_MARGIN)     # 157 补充三：读数是刻在板里的凹槽
	var hud_box := _box(panel_bg, UiPalette.LINE, HUD_MARGIN)
	hud_box.set_border_width_all(0)
	t.set_stylebox("panel", PANEL_HUD, hud_art if hud_art != null else hud_box)
	t.set_type_variation(PANEL_HUD_WELL, "PanelContainer")
	var well_art: StyleBox = _art_box(ART_HUD_WELL, false, HUD_MARGIN)
	t.set_stylebox("panel", PANEL_HUD_WELL, well_art if well_art != null else t.get_stylebox("panel", PANEL_HUD))
	# 166：顶端栏（横贯顶部的一条，左右留 16）与栏里的图标按钮（平时透明，悬停 / 按下才露底）。
	# 157 补充三：栏是一条独立的长石板（同一套板身 + 自己的长条板边 `slab_bar`），没图是半透明深底 + 下边一条线。
	# 板边的上下内边距 = 栏里的组居中的那一块（[HudHost] 读），底下那道投影不算进去
	t.set_type_variation(PANEL_HUD_BAR, "PanelContainer")
	var bar_art: StyleBox = slab_box(false, -1, ART_SLAB_BAR)
	var bar_box := _box(Color(panel_bg, 0.86), UiPalette.LINE, HUD_MARGIN)
	bar_box.set_border_width_all(0)
	bar_box.border_width_bottom = 1
	bar_box.set_corner_radius_all(0)
	# 235：石刻栏皮（`hud/topbar/`）由栏自己画（平铺段 + 日晷底座 + 两头），底空着
	t.set_stylebox("panel", PANEL_HUD_BAR, StyleBoxEmpty.new() if art(ART_TOPBAR_TILE) != null else (bar_art if bar_art != null else bar_box))
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
	for v in [LABEL_HUD, LABEL_HUD_LARGE, LABEL_HUD_DOUBLE]:
		t.set_color("font_color", v, UiPalette.FG)     # 193：变体自己写上默认字色（缺了别人取色会拿到纯黑）
	# 富文本
	for pair in [[RICH_BODY, RICH_BODY_SIZE], [RICH_SMALL, RICH_SMALL_SIZE]]:
		t.set_type_variation(pair[0], "RichTextLabel")
		t.set_color("default_color", pair[0], UiPalette.FG)     # 193：同上
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
	_kit_scrollbars(t)


## 乙 石刻滚动条（kit `sb_groove(_h)` + `sb_grab_<态>(_h)`）：宽 14，图四周多 6；槽沿长向两头各 14 不拉、把手各 16。缺图用引擎默认
static func _kit_scrollbars(t: Theme) -> void:
	for horizontal in [false, true]:
		var suffix := "_h" if horizontal else ""
		var type := "HScrollBar" if horizontal else "VScrollBar"
		var groove := _kit_bar_box("kit/sb_groove" + suffix, horizontal, 14.0)
		if groove == null:
			continue
		t.set_stylebox("scroll", type, groove)
		t.set_stylebox("scroll_focus", type, groove)
		for pair in [["grabber", "normal"], ["grabber_highlight", "hover"], ["grabber_pressed", "pressed"]]:
			var g := _kit_bar_box("kit/sb_grab_%s%s" % [pair[1], suffix], horizontal, 16.0)
			if g != null:
				t.set_stylebox(String(pair[0]), type, g)


static func _kit_bar_box(name: String, horizontal: bool, along: float) -> StyleBoxTexture:
	var tex := art_cached(name)
	if tex == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = tex
	var across := 12.0
	s.texture_margin_left = along if horizontal else across
	s.texture_margin_right = along if horizontal else across
	s.texture_margin_top = across if horizontal else along
	s.texture_margin_bottom = across if horizontal else along
	s.set_expand_margin_all(6.0)
	# 横着量宽 14（竖条左右各 7）；沿长向的内边距给把手留最短
	s.content_margin_left = 10.0 if horizontal else 7.0
	s.content_margin_right = 10.0 if horizontal else 7.0
	s.content_margin_top = 7.0 if horizontal else 10.0
	s.content_margin_bottom = 7.0 if horizontal else 10.0
	return s


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
		t.set_constant("h_separation", name, 6)     # 基地页签字左边的图标与字隔 6


## 197 补充一 / 三：游戏名与主菜单的几行字、小字链接
static func _menu_styles(t: Theme) -> void:
	if _font_hero == null:
		var hero := FontVariation.new()
		hero.base_font = UiPalette.cjk_font_bold()
		hero.spacing_glyph = HERO_SPACING
		_font_hero = hero
	t.set_type_variation(LABEL_HERO_TITLE, "Label")
	t.set_font("font", LABEL_HERO_TITLE, _font_hero)
	t.set_font_size("font_size", LABEL_HERO_TITLE, HERO_TITLE_SIZE)
	t.set_color("font_color", LABEL_HERO_TITLE, HERO_TITLE_COLOR)
	t.set_color("font_outline_color", LABEL_HERO_TITLE, HERO_OUTLINE_COLOR)
	t.set_constant("outline_size", LABEL_HERO_TITLE, HERO_OUTLINE)
	t.set_color("font_shadow_color", LABEL_HERO_TITLE, HERO_SHADOW)
	t.set_constant("shadow_offset_x", LABEL_HERO_TITLE, HERO_SHADOW_OFFSET.x)
	t.set_constant("shadow_offset_y", LABEL_HERO_TITLE, HERO_SHADOW_OFFSET.y)
	t.set_constant("shadow_outline_size", LABEL_HERO_TITLE, HERO_SHADOW_SPREAD)
	t.set_type_variation(BUTTON_MENU_LINE, "Button")
	var still := StyleBoxEmpty.new()     # 左缩进留给菱形；下边多 1 px，按下时挪到上边 = 字下沉 1 px
	still.content_margin_left = MENU_LINE_INDENT
	still.content_margin_top = 0
	still.content_margin_bottom = 1
	var sunk := still.duplicate() as StyleBoxEmpty
	sunk.content_margin_top = 1
	sunk.content_margin_bottom = 0
	for state in ["normal", "hover", "disabled", "focus"]:
		t.set_stylebox(state, BUTTON_MENU_LINE, still)
	for state in ["pressed", "hover_pressed"]:
		t.set_stylebox(state, BUTTON_MENU_LINE, sunk)
	t.set_font("font", BUTTON_MENU_LINE, _font_bold)
	t.set_font_size("font_size", BUTTON_MENU_LINE, MENU_PRIMARY_SIZE)
	t.set_color("font_color", BUTTON_MENU_LINE, MENU_LINE_COLOR)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, BUTTON_MENU_LINE, MENU_LINE_HOVER)
	t.set_color("font_outline_color", BUTTON_MENU_LINE, HERO_OUTLINE_COLOR)
	t.set_constant("outline_size", BUTTON_MENU_LINE, MENU_LINE_OUTLINE)
	t.set_type_variation(BUTTON_MENU_FOOT, "Button")
	var bare := StyleBoxEmpty.new()
	bare.set_content_margin_all(2)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, BUTTON_MENU_FOOT, bare)
	t.set_font_size("font_size", BUTTON_MENU_FOOT, MENU_FOOT_SIZE)
	t.set_color("font_color", BUTTON_MENU_FOOT, UiPalette.DIM)
	t.set_color("font_focus_color", BUTTON_MENU_FOOT, UiPalette.DIM)
	for state in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, BUTTON_MENU_FOOT, UiPalette.FG)


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


## 251 补充一 §10.2：「打造」平键 —— 烧亮的铁红底、亮字，平的（230：小功能键不要斜面 / 渐变 / 投影）；灰态压成暗铁色
static func _forge_button(t: Theme) -> void:
	t.set_type_variation(BUTTON_FORGE, "Button")
	var pad := Vector2i(24, 8)
	for pair in [["normal", UiPalette.HOT_IRON], ["hover", UiPalette.HOT_IRON_HOVER], ["pressed", UiPalette.HOT_IRON_PRESSED],
			["hover_pressed", UiPalette.HOT_IRON_PRESSED], ["disabled", UiPalette.HOT_IRON_OFF]]:
		t.set_stylebox(pair[0], BUTTON_FORGE, _button_box(pair[1], pair[1], pad))
	t.set_stylebox("focus", BUTTON_FORGE, StyleBoxEmpty.new())
	t.set_font("font", BUTTON_FORGE, _font_bold)
	t.set_font_size("font_size", BUTTON_FORGE, 20)
	_button_ink(t, BUTTON_FORGE, UiPalette.HOT_IRON_TEXT)


## 180 补四：难度的加减键（次档的样子，到头的灰态单独做：底压到板色、字暗一半、悬停不亮）与〇级的「开启挑战」铜牌按钮；
## 定稿：加减、铜牌、「当前难度」标题牌都换成图（字在加减图上、铜牌墨字），没图照旧平色
static func _difficulty_buttons(t: Theme) -> void:
	t.set_type_variation(BUTTON_STEP, BUTTON_DIM)
	var size := UiPalette.button_font_size(FONT_SIZE, UiPalette.Tier.MINOR)
	var pad := Vector2i(int(round(size * 0.6)), int(round(size * 0.3)))
	var off := _button_box(GROOVE_BG, GROOVE_BG.lightened(0.06), pad)
	t.set_stylebox("disabled", BUTTON_STEP, off)
	t.set_color("font_disabled_color", BUTTON_STEP, Color(UiPalette.DIM, 0.5))
	for pair in [[BUTTON_DIFF_MINUS, ART_DIFF_MINUS], [BUTTON_DIFF_PLUS, ART_DIFF_PLUS]]:
		t.set_type_variation(pair[0], BUTTON_STEP)
		_art_button(t, pair[0], pair[1], [14, 14, 14, 14])
	t.set_type_variation(BUTTON_DIFF_PLATE, "Button")
	if _art_button(t, BUTTON_DIFF_PLATE, ART_DIFFICULTY_PLATE, [0, 0, 0, 0]):
		t.set_font("font", BUTTON_DIFF_PLATE, _font_bold)
		t.set_font_size("font_size", BUTTON_DIFF_PLATE, 28)
		_button_ink(t, BUTTON_DIFF_PLATE, INK)
	else:
		var plate := _button_box(FLIP_BRASS.darkened(0.25), FLIP_BRASS.lightened(0.25), Vector2i(22, 6))
		var lit := _button_box(FLIP_BRASS, FLIP_BRASS.lightened(0.4), Vector2i(22, 6))
		t.set_stylebox("normal", BUTTON_DIFF_PLATE, plate)
		t.set_stylebox("hover", BUTTON_DIFF_PLATE, lit)
		t.set_stylebox("pressed", BUTTON_DIFF_PLATE, lit)
		t.set_stylebox("hover_pressed", BUTTON_DIFF_PLATE, lit)
		t.set_stylebox("disabled", BUTTON_DIFF_PLATE, _button_box(GROOVE_BG.lightened(0.04), GROOVE_BG.lightened(0.1), Vector2i(22, 6)))
		t.set_stylebox("focus", BUTTON_DIFF_PLATE, StyleBoxEmpty.new())
		t.set_font_size("font_size", BUTTON_DIFF_PLATE, 26)
		_button_ink(t, BUTTON_DIFF_PLATE, Color("f3e3c0"))
	t.set_color("font_disabled_color", BUTTON_DIFF_PLATE, Color(UiPalette.DIM, 0.5))
	t.set_type_variation(PANEL_DIFF_TITLE, "PanelContainer")
	var title_art: StyleBox = _art_box(ART_DIFF_TITLE)
	t.set_stylebox("panel", PANEL_DIFF_TITLE, title_art if title_art != null else _button_box(FLIP_BRASS.darkened(0.25), FLIP_BRASS.lightened(0.25), Vector2i(22, 6)))
	t.set_type_variation(LABEL_DIFF_TITLE, "Label")
	t.set_font_size("font_size", LABEL_DIFF_TITLE, 20 if title_art != null else 26)
	t.set_color("font_color", LABEL_DIFF_TITLE, INK if title_art != null else Color("f3e3c0"))
	if title_art != null:
		t.set_font("font", LABEL_DIFF_TITLE, _font_bold)
	_setup_art(t)


## 180 定稿：开局第二、三页的框、页签、地图条目、便条、按钮 A 套（没图的变体照旧：框是凹槽板、按钮是平面档）
static func _setup_art(t: Theme) -> void:
	t.set_type_variation(PANEL_BARE, "PanelContainer")
	t.set_stylebox("panel", PANEL_BARE, StyleBoxEmpty.new())
	for spec in [[PANEL_PACK_LEATHER, ART_PACK_LEATHER], [PANEL_STASH_FRAME, ART_STASH_FRAME], [PANEL_SUMMARY_NOTE, ART_SUMMARY_NOTE]]:
		t.set_type_variation(spec[0], "PanelContainer")
		var box: StyleBox = _art_box(spec[1])
		t.set_stylebox("panel", spec[0], box if box != null else (_groove_box() if spec[0] != PANEL_SUMMARY_NOTE else StyleBoxEmpty.new()))
	t.set_type_variation(LABEL_NOTE_TITLE, "Label")
	t.set_font("font", LABEL_NOTE_TITLE, UiPalette.cjk_font_bold())
	# 182：提示窗的纸签 —— 自己的图 → 摘要便条那张 → 平色纸
	t.set_type_variation(PANEL_NODE_HINT, "PanelContainer")
	var hint: StyleBox = _art_box(ART_NODE_HINT)
	if hint != null:     # 纸签的边是毛边：字再往里收一点
		hint.content_margin_left += 12.0
		hint.content_margin_right += 12.0
		hint.content_margin_top += 6.0
		hint.content_margin_bottom += 8.0
	if hint == null:
		hint = _art_box(ART_SUMMARY_NOTE)
	if hint == null:
		hint = _box(PARCHMENT, INK_DEFAULT, 20)
	t.set_stylebox("panel", PANEL_NODE_HINT, hint)
	# 页签：52 × 60 的挂牌，字写在牌面（json 的 text_area），整张拉伸不切九宫格
	var tab: Dictionary = art_meta(ART_SETUP_TAB)
	var area: Array = tab.get("text_area", [6, 18, 40, 38])
	var sz: Array = tab.get("size", [52, 60])
	var content := [area[0], area[1], int(sz[0]) - int(area[0]) - int(area[2]), int(sz[1]) - int(area[1]) - int(area[3])]
	t.set_type_variation(BUTTON_SETUP_TAB, BUTTON_DIM)
	if _art_button(t, BUTTON_SETUP_TAB, ART_SETUP_TAB, [0, 0, 0, 0], {"normal": "normal", "hover": "normal", "pressed": "on", "hover_pressed": "on", "disabled": "locked"}, content):
		_button_ink(t, BUTTON_SETUP_TAB, INK)
		t.set_color("font_disabled_color", BUTTON_SETUP_TAB, SETUP_TAB_LOCKED_INK)     # 锁着的深木牌上页名提亮（UI替换美术 10-22），锁照旧
	# 地图条目 / 规模：选中是 on 图（按钮按下态），墨字
	for spec in [[BUTTON_MAP_ENTRY, ART_MAP_ENTRY], [BUTTON_MAP_SUB, ART_MAP_SUB]]:
		t.set_type_variation(spec[0], BUTTON_DIM)
		var m: Array = art_meta(spec[1]).get("margin", [16, 8, 16, 8])
		if _art_button(t, spec[0], spec[1], m, {"normal": "normal", "hover": "hover", "pressed": "on", "hover_pressed": "on", "disabled": "normal"}):
			_button_ink(t, spec[0], INK)
	# 按钮 A 套：「返回」深色铜铸牌（浅字），「出发 / 继续」亮黄铜（墨字）
	var btn: Dictionary = art_meta("setup/btn")
	for spec in [[BUTTON_SETUP_BACK, ART_SETUP_BACK, "back", BUTTON_SECONDARY, Color("f3e3c0")], [BUTTON_SETUP_GO, ART_SETUP_GO, "go", BUTTON_PRIMARY, INK]]:
		t.set_type_variation(spec[0], spec[3])
		var m: Array = (btn.get(spec[2], {}) as Dictionary).get("margin", [26, 22, 26, 26])
		if _art_button(t, spec[0], spec[1], m):
			_button_ink(t, spec[0], spec[4])


## 一套按钮状态图挂到变体上：[param states] 是 状态 → 文件后缀（`<base>_<后缀>.png`，缺的那张退回 normal）；
## [param margin] 九宫格边距 [左, 上, 右, 下]，[param content] 字区内边距（不给 = 同 margin）。没有 normal 图什么也不挂、返回 false
static func _art_button(t: Theme, variation: StringName, base: String, margin: Array, states: Dictionary = {}, content: Array = []) -> bool:
	if states.is_empty():
		states = {"normal": "normal", "hover": "hover", "pressed": "pressed", "hover_pressed": "pressed", "disabled": "disabled"}
	var normal := _tex_box(base + "_" + String(states["normal"]), margin, content)
	if normal == null:
		return false
	for state in states:
		var box := _tex_box(base + "_" + String(states[state]), margin, content)
		t.set_stylebox(state, variation, box if box != null else normal)
	t.set_stylebox("focus", variation, StyleBoxEmpty.new())
	return true


## 一张图的九宫格底（边距照给的，不读 json）；没图 null
static func _tex_box(name: String, margin: Array, content: Array = []) -> StyleBoxTexture:
	var tex := art(name)
	if tex == null:
		return null
	var c := content if content.size() == 4 else margin
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = float(margin[0])
	s.texture_margin_top = float(margin[1])
	s.texture_margin_right = float(margin[2])
	s.texture_margin_bottom = float(margin[3])
	s.content_margin_left = float(c[0])
	s.content_margin_top = float(c[1])
	s.content_margin_right = float(c[2])
	s.content_margin_bottom = float(c[3])
	return s


## 按钮各态的字色一样（灰态另给）
static func _button_ink(t: Theme, variation: StringName, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, variation, color)
	t.set_color("font_disabled_color", variation, Color(color, 0.5))
	t.set_constant("outline_size", variation, 0)


## 180 补四：「开启挑战」铜牌按钮（字居中）
static func make_difficulty_plate(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = BUTTON_DIFF_PLATE
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(handler)
	return b


## 180 定稿：这几样有没有图（开局屏按它决定用图的尺寸、去不去掉凹槽板）
static func has_setup_art(art_name: String) -> bool:
	return art(art_name) != null or art(art_name + "_normal") != null


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
	t.set_type_variation(LABEL_FLAW_NAME, LABEL_SKILL_NAME)
	t.set_color("font_color", LABEL_FLAW_NAME, UiPalette.FLAW_IRON)
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
