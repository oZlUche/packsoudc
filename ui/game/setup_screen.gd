## 开局（M6，架构文档 8 节；058 第 2 条，报告 067）：挑一章、挑角色、往初始包里拖仓库的东西、定个种子，出发。
##
## 161（作者定）：拆成三页，一次只看一页、状态都在屏的字段里（换页不丢）：
## **一 选角色**（角色列表、角色卡 —— 名牌 + 生命 / 耐力方块 + 体力爱心 + 技能、这个角色的棋盘预览只看不拖）→
## **二 配道具**（预设装备、可拖的棋盘、地上、仓库 —— 仓库只在这一页）→ **三 选地图与难度**（模式、规模、难度、种子、出发摘要）。
## 180（作者 2026-10-17）：第三页改成 左 地图（一级）与规模（二级，选中的图下面展开）| 中 化开的地图预览（[MapPreview]）|
## 右 出发摘要 + 当前难度（〇级收成「开启挑战」铜牌；大字数字、加减两颗键、每升一级红字列出这一级的挑战）。序章不进列表（只出现一次），种子玩家看不见
## （进第三页随机取；调试台能指定下一局的，[member GameFlow.next_run_seed]）；上次挑的图、规模、难度记在局外旗标里，下次默认它们
## 每页右下角两颗大按钮：继续 / 出发（Enter）、返回（Esc；第一页的返回 = 回基地，264 §五）。[method page] / [method next_page] / [method prev_page]。
##
## 第二页：中间是这个角色的棋盘（初始包已经摆好），右边是仓库的格子：从仓库往包里拖，**放得进的就是带的** ——
## 带入的真正限制是初始包的空间；件数 / 稀有度上限是角色的字段（默认不限），出发时查。
## 包不能带入：仓库里本来没有包（局外只收非包，`MetaState.keeps`），仓库的格子也不收包（同一条规则接在 `accept_filter` 上）。
## 拖上棋盘那一刻东西就离开了仓库；出发时存 meta，返回基地就放回去。
## 所有动作都是公开方法（[method choose_chapter]、[method choose_character]、[method carry_in]、[method store]、[method depart]、[method cancel]），按钮只是调它们；测试直接调。
##
## **地上**（090，作者定）：上一局带回来、还没置入的东西（`MetaState.board`）进这一屏时挪进中间的地上（记住各自原位）。
## 往包里拖 = 带上、往仓库拖 = 置入、留着的**出发就没了**；返回基地则原样放回带回来的棋盘（视为没发生过移动）。
## 仓库的东西进不了地上（会丢）。
##
## 没有角色定义时和没有章节一样：一条红字，开不了（140：作者数据里有三个角色，「按第一套开局装备开」的老路只留在 core 给测试）。
##
## **预设装备**（096，作者定）：角色之下一栏「预设装备」—— 不带 / 强攻（伤害高）/ 坚守（防御高）……（`LoadoutDef.preset`，数据里加一份就多一套）。
## 挑一套就把它的道具免费放进初始包：不从仓库拿、不算带入预算与件数上限、拖不进仓库 / 地上（只能在棋盘上挪），出发时带着走。
## 预设是底线（094）：仓库空也有一套能打的
extends GameScreen

## 地上容器的 id（局外的 100 / 101 之外）
const STASH_ID := 110
## 225：包架空、棋盘上也没包时军需官发的那只（最差的包）
const FALLBACK_BAG := &"sack"

var chapter_index: int = 0
var character_index: int = 0
var difficulty_index: int = 0
## 096：挑的预设套在 [method GameFlow.presets] 里的下标；-1 = 不带
var preset_index: int = -1
## 096：棋盘上预设套的实例 uid → true（不算带入、不能拖去仓库）
var _preset_uids: Dictionary = {}
var _preset_btns: Array[Button] = []
var _preset_box: BoxContainer = null
## 085：地图规模（随机一局可选）；空 = 章节默认
var scale_id: StringName = &""
var _scale_btns: Dictionary = {}
## 2026-10-22（作者定）：这一局带多少现金入局 —— 从仓库账上扣，死在局内就没了。默认 0（不带）
var carry_funds: int = 0
## 带入现金那张便条：右上「仓库 N」、步进件（读数 = 带多少）、三枚石签
var _cash_store: Label = null
## 作者 10-27：拖条按比例选（0 … 仓库余额）+ 能键盘输入的数字框（原来的 ±10 步进件换掉）
var _cash_slider: StoneSlider = null
var _cash_field: StoneField = null
var _cash_typing := false
var _cash_chips: Array[Button] = []
const CASH_ROW_W := 264.0
const CASH_CHIP_GAP := 8.0
## 作者 10-27：带入现金的输入框宽（七位数放得下）
const CASH_FIELD_W := 84.0
const CASH_PAD := 24
const CASH_PAD_TOP := 22
const CASH_PAD_BOTTOM := 18
var run_seed: int = 1
## 这个角色的棋盘，初始包摆好；从仓库拖进来的东西就在上面。出发时整块记成 layout 交给 RunState
var board: GridInventory = null
## 090：地上 —— 上一局带回来、还没置入的东西
var stash: ItemStash = null
## 090：地上那些东西的来处：uid → {"origin", "rot"}（返回基地按原位放回）
var _pending: Dictionary = {}
## 225：中栏顶上的包架（挂牌 + 一列）与它的视图
var _rack_box: Control = null
var _rack_view: BagRackView = null
## 225：状态行没别的话说时写这一句（「军需官发的」）；换角色、重摆棋盘时清掉
var _note := ""
var _stash_view: GroundLayer = null
## 255 补充二：仓库页签列里「地上」那一页的页签
var _stash_tab: Button = null

## 083：开局屏列的章节（按解锁过滤、按 order 排）与这一章能选的角色
var _chapters: Array[ChapterDef] = []
var _characters: Array[CharacterDef] = []
var _char_box: VBoxContainer = null
## 180 补二：第二页右边的仓库框（按自己的内容定大小）与框里的滚动区（格子多到放不下时滚，预留滚动条位）
var _warehouse_box: Control = null
var _warehouse_scroll: ScrollContainer = null
var _character_btns: Array[Button] = []
## 180：第三页 —— 左列的地图 / 规模、中间的预览、右边的难度块
var _map_list: VBoxContainer = null
var _preview: MapPreview = null
var _difficulty_num: Label = null
## 180 补二：难度的翻页计数器牌面（黑底白字、深黄铜框）；补三：翻页有方向（[FlipCounter]）
var _counter: PanelContainer = null
var _flipper: FlipCounter = null
## 上一次加减的方向（翻页往哪翻）
var _step_dir: int = 0
## 180 补四 / 补五：难度块（〇级收成「开启挑战」按钮、≥ Ⅰ 展开，卷轴走位的动画在 [DifficultyBlock] 里）；
## 下面几个是它里面的件（测试与旧代码直接看）
var _diff_block: DifficultyBlock = null
var _diff_plate: Button = null
var _minus_btn: Button = null
var _plus_btn: Button = null
## 180 补三：挑战说明 —— 卷轴羊皮纸（[ChallengeScroll]）
var _challenge: ChallengeScroll = null
## 180：预览的图按「章 | 规模 | 种子」记，同一档不重复生成（182：整张图都留着，入口位置也从它算）
var _graph_cache: Dictionary = {}
## 182（作者 2026-10-17 15:26）：第三页纸上挑的出生点（-1 = 还没挑，「出发」灰着）；预览现在铺的是哪一张（换了就清选择）
var spawn_id: int = -1
var _preview_key: String = ""
## 182：点入口时屏幕正中弹的提示窗
var _hint: NodeHintCard = null
## 180：上次挑的图 / 规模 / 难度记在局外旗标里（旗标只存整数：图记 order + 1、规模记下标 + 1、难度记档位）
const FLAG_LAST_MAP := &"last_map"
const FLAG_LAST_SCALE := &"last_scale"
const FLAG_LAST_DIFFICULTY := &"last_difficulty"
var _board_host: VBoxContainer
var _board_view: InventoryView = null
var _warehouse_view: InventoryView = null
## 163：仓库分页（[member _warehouse_view] 是它当前页的视图）
var _warehouse_pages: WarehousePages = null
## 作者 10-31：仓库下面的【整理】
var _tidy_btn: Button = null
const TIDY_SIZE := Vector2(120, 52)
var _readout: RichTextLabel = null
## 226 批一：「出发」上面那句常显的话（出发不了的原因、空手提示、军需官发的）—— 本地红字行删了：
## 变了才走一次告示卷轴，平时写在「出发」的悬浮窗里（[method status_text]）
var _status := ""
## 右下那一组（状态字 + 两颗大按钮）；第三页按地图纸的右沿往左挪（180 定稿）
var _nav_box: VBoxContainer = null
## 标题前面那段空（第三页 = [constant PAPER_INSET]，让开地图纸的毛边）
var _title_indent: Control = null
## 161：右下角「继续 / 出发」与「返回」
var _enter_btn: Button
var _back_btn: Button
## 161：三页（0 选角色、1 配道具、2 选地图与难度）与现在是哪页
## 221 F1：每页的标题（UiText 键，用时按当前语言取）
const PAGE_TITLES: Array[String] = ["setup.page_1", "setup.page_2", "setup.page_3"]
const PAGE_MAP := 2
## 180：难度数字的字号、规模那一列缩进多少
const DIFFICULTY_NUM_SIZE := UiTheme.FLIP_NUM_SIZE
const SCALE_INDENT := 20
## 180 补二：仓库框给滚动条留多宽；底下「返回」的字号（按钮按档放大，仍比「出发」小）
const SCROLL_GUTTER := 16
## 整屏内容区的边距、底下留给两颗大按钮的高、标题与页之间的空
const PAGE_MARGIN := 36
const NAV_ROOM := 140
const PAGE_SEP := 14
## 180 补三：羊皮纸下端离「出发」按钮上沿至少留多少
const PAPER_CLEARANCE := 24.0
## 180 定稿：第二页两块框的内边距、页签挂牌高、地图条目 / 规模条目高、右下两颗按钮高、第三页按钮组离地图纸右沿多远
const FRAME_INSET := 44
const TAB_TAG_H := 60.0
const MAP_ENTRY_H := 60.0
## 乙 石刻：第二页「不带 / 坚守 / 强攻」也是那种纸条，矮一点
const PRESET_ENTRY_H := 52.0
const MAP_SUB_H := 44.0
const NAV_BTN_H := 84.0
const NAV_PAPER_GAP := 60.0
## 第三页的左右两列离屏边再让多少（地图纸的毛边）
const PAPER_INSET := 36
var _pages: Array[Control] = []
var _page: int = 0
var _title: TitlePlate = null
## 161：第一页的角色卡与棋盘预览；第三页右上只写角色名（180 补二）
var _card: VBoxContainer = null
## 214：角色卡顶上的大头像
var _portrait: PortraitSlot = null
const CARD_PORTRAIT := 160
var _preview_host: VBoxContainer = null
var _preview_view: InventoryView = null
var _summary: Label = null
## 179：整屏的内容区（[method GameScreen._painted_screen]：场地背景上，不再是石板）
var _area: Control = null
## 179：第一页三栏的凹槽板（左、中、右）
var _grooves: Array[PanelContainer] = []
## 179：中栏的三块图标牌、技能名的标签（测试看）
var _cap_tiles: Array[CapTile] = []
var _skill_names: Array[Label] = []
## 258：卡里放不下时可以往回缩的字 —— [标签, 小档字号]
var _fit_labels: Array = []
## 选人页 B：头像右边的铭牌（名字 + 火漆属性）；255：技能 / 随身之物 / 短板那几行（[method _entry_row]）、右栏图例 / 首次赠包小签
var _stat_plate: StatSealPlate = null
var _entries: Array[HBoxContainer] = []
var _legend: Array[Control] = []
var _gift_tag: PanelContainer = null
## 255：预览那块只画形状（缺格 + 随身之物），不画包
var _preview_board: GridInventory = null
## 255：这一回进开局屏时，哪几个角色是第一次选（首次赠包刚送进包架）—— 小签只在这时显示
var _gifted: Dictionary = {}
## 179：右栏板的内边距（选人页 B：木框羊皮纸，棋盘离开木框）
const RIGHT_PAD := 26
## 选人页 B（作者 10-31 11:56）：左、中两栏木框羊皮纸板（[constant UiTheme.PANEL_HOME_PLAQUE]）的内边距
const HALL_INSET := 30
## 255（作者 2026-10-26 10:51）：三栏定宽，不随棋盘宽窄变 —— 左按角色名纸条（连皮框 312；稿子的 260 放不下「安德烈乌斯」）、右按最宽的九格棋盘、中栏是剩下的；不足九格的棋盘在右栏里居中
const LEFT_W := 308     # 选人页 B：名单换木键、字小了，让给右栏加宽的内边距（中栏宽差不多不变）
const COL_GAP := 24     # 作者 10-27「太窄了，向右拓宽一些」：左栏 312 → 336，让出的 24 来自两道栏距（中栏宽不变，英文最长的卡照样装得下）
const BOARD_MAX_W := CharacterDef.BOARD_MAX_W
## 255 补充二：第二页棋盘下的包架横排几格（九种以内一行）
const RACK_COLUMNS := 9
## 255 补充一：中栏（角色卡）定高 —— 英文最长的那张（游戏测试 v4.49：安德烈乌斯 / 布鲁图斯 814）放得下、底边不过页边；
## 内容再长栏会被顶高，`test_character_select_255` 中英文都比一遍会红
const CARD_H := 760     # 选人页 B：铭牌并进属性、那排蜡板删了
## 255 补充一：右栏（棋盘预览）定高 —— 六行棋盘、题字、图例、首次赠包签都在时那么高（七行以上的棋盘才再长）；258：按大档字号算（原 560）
const PREVIEW_H := 576
## 255：角色卡里的几样尺寸 —— 小牌间 10；小牌 ≤ 206 宽（选人页 B 木牌底，原 180）；条目行间 8
const STAT_GAP := 10
const TILE_MAX_W := 206.0
const ENTRY_GAP := 6
## 255：角色卡几行之间（原 14；卡多了两行，收一点才装得进三样全有的角色）
const CARD_SEP := 10
const ENTRY_TAIL_SIZE := 12
## 选人页 B：名单木键高（字号在 [constant UiTheme.BUTTON_SETUP_CHAR]）
const CHAR_KEY_H := 56.0
## 选人页 B：生命 / 耐力 / 耐力回复 / 体力的火漆
const STAT_SEALS: Array[String] = ["seal_hp", "seal_vigor", "seal_stamina", "seal_vitality"]
## 255：没解锁的角色在左栏压到 60%
const LOCKED_ALPHA := 0.6
## 三页各自的整屏画（作者 2026-10-17）：选角色 = 选人场地，带装备 = 木板拼接 / 仓库，选地图 = 桌上的军用地图
const PAGE_ART: Array[String] = [UiTheme.ART_SETUP_BG, UiTheme.ART_SETUP_KIT_BG, UiTheme.ART_SETUP_MAP_BG]


func open(_payload: Dictionary) -> void:
	_backdrop()
	_reroll_seed()
	carry_funds = 0     # 2026-10-22：每次进开局屏都是「不带钱」，由玩家自己加
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, PAGE_MARGIN)
	margin.add_theme_constant_override("margin_bottom", NAV_ROOM)     # 161：底下留给右下角那两颗大按钮
	_area = _painted_screen(PAGE_ART[0])     # 179：整屏一幅画（157 补充三的整块石板不要了），各块内容坐凹槽板；翻页换画（[constant PAGE_ART]）
	_area.add_child(margin)
	var col := _vbox(PAGE_SEP)
	margin.add_child(col)
	_title = TitlePlate.new()     # 226 批二：页标题刻在标题牌上（页码去掉，翻页计数在右下角按钮上）
	_title.wood = true     # 选人页 B（作者 11:56「左上角跟着更新」）：三页的标题牌都是木框羊皮纸
	var title_row := _hbox(0)
	_title_indent = Control.new()     # 180 定稿：第三页让开地图纸的毛边
	title_row.add_child(_title_indent)
	title_row.add_child(_title)
	col.add_child(title_row)
	_chapters = map_chapters()
	_pages.clear()
	for build in [_build_character_page, _build_kit_page, _build_map_page]:
		var page: Control = build.call()
		page.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if page is PanelContainer else Control.SIZE_EXPAND_FILL     # 179：凹槽板按内容高，不压到右下角的按钮
		col.add_child(page)
		_pages.append(page)
	_build_nav()
	_restore_last()
	show_page(0)


## 179：一块凹槽板（深底白字），内边距 左 / 上 / 右 / 下
func _groove(l: int, t: int, r: int, b: int) -> PanelContainer:
	return UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_GROOVE, l, t, r, b)


## 180 定稿：一块有图的框（第二页的背包皮框、仓库框，内边距 [param inset]）；没图退回凹槽板
func _framed(variation: StringName, art_name: String, inset: int) -> PanelContainer:
	if UiTheme.art(art_name) == null:
		return _groove(16, 14, 16, 14)
	return UiTheme.panel_margins(PanelContainer.new(), variation, inset, inset, inset, inset)


## 180 定稿：第三页的东西直接摆在地图纸上（没有板，左右让开纸的毛边 [constant PAPER_INSET]）；没有地图纸那张背景退回凹槽板
func _on_paper(left: int, right: int) -> PanelContainer:
	if not _paper_art():
		return _groove(16, 14, 16, 14)
	return UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_BARE, left, 0, right, 0)


## 第三页有没有地图纸那张背景
static func _paper_art() -> bool:
	return UiTheme.art(UiTheme.ART_SETUP_MAP_BG) != null


## 255：右栏宽 = 九格棋盘 + 皮带框两边的缩进 + 凹槽内边距（作者 10:51：最宽九格定死，窄的棋盘居中）
static func right_width() -> float:
	return BOARD_MAX_W * InventoryView.CELL + 2.0 * (RIGHT_PAD + BoardFrame.box("player", false).content_margin_left)


## 255：中栏宽 = 设计宽减去页边、左右两栏与两道栏距（定死，不撑不缩）
static func mid_width() -> float:
	var w := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1600))
	return w - 2.0 * PAGE_MARGIN - LEFT_W - right_width() - 2.0 * COL_GAP


## 角色卡里面能用的宽（中栏减两边木框）
static func card_width() -> float:
	return mid_width() - 2.0 * HALL_INSET


## 选人页 B：第一页三栏的木框羊皮纸板（浅底墨字）
static func _hall_board(inset: int) -> PanelContainer:
	return UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_HOME_PLAQUE, inset, inset, inset, inset)


## 161 第一页：角色列表 | 角色卡 | 棋盘预览（只看不拖）。
## 179：三栏各坐一块凹槽板、间距 36；中栏撑满左右两栏之间，右栏（棋盘）贴右边
func _build_character_page() -> Control:
	var row := _hbox(COL_GAP)
	_grooves.clear()
	var left_board := _hall_board(HALL_INSET)     # 选人页 B（作者 10-31 11:56）：三栏都是基地木框羊皮纸，不再垫皮
	left_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(left_board)
	var left := _vbox(8)
	left.custom_minimum_size.x = LEFT_W - 2 * HALL_INSET     # 255 补充一：左栏连皮框共 260（原来里面就 232、整栏 320，三栏加起来顶出屏右沿）
	left_board.add_child(left)
	_char_box = _vbox(8)     # 226 批二：段头「角色」与缺数据那句删了
	left.add_child(_char_box)
	var mid_board := _hall_board(HALL_INSET)
	mid_board.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN     # 255：定宽，不再撑满
	mid_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mid_board.custom_minimum_size = Vector2(mid_width(), CARD_H)     # 255 补充一（游戏测试 v4.48）：高也不随角色 / 语言变
	row.add_child(mid_board)
	_card = _vbox(CARD_SEP)
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_board.add_child(_card)
	var right_board := _hall_board(RIGHT_PAD)     # 作者 10-31：黑底去掉；选人页 B：和左中两栏同一种木框羊皮纸
	right_board.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right_board.custom_minimum_size = Vector2(right_width(), PREVIEW_H)     # 255：按九格定宽；补充一：高按六行棋盘 + 题字 + 图例 + 赠包签定死
	row.add_child(right_board)
	_preview_host = _vbox(8)
	right_board.add_child(_preview_host)
	_grooves.append_array([left_board, mid_board, right_board])
	return row



## 161 第二页：预设装备一行 + 棋盘（可拖）/ 地上 / 仓库，拖拽层盖在下面那一块上
## 180 补二（作者 10:09）：左 行囊板（预设、棋盘、两行读数）| 中 地上 | 右 仓库框。仓库框按自己的内容定大小、不和左边棋盘对齐，
## 包住页签、格子和右边预留的滚动条位（格子多到一屏放不下时竖着滚）；两块板各按内容高、顶边对齐
func _build_kit_page() -> Control:
	# 拖拽层盖在整行上（两块板；255 补充二起地上是仓库的一页）
	var play := MarginContainer.new()
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := _hbox(36)
	play.add_child(row)

	var board_panel := _framed(UiTheme.PANEL_PACK_LEATHER, UiTheme.ART_PACK_LEATHER, FRAME_INSET)     # 180 定稿：背包皮框
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(board_panel)
	var left := _vbox(12)
	board_panel.add_child(left)
	if not flow.presets().is_empty():
		var presets := _hbox(8)     # 226 批二：段头「预设装备」删了
		_preset_box = presets
		left.add_child(presets)
		_rebuild_presets()
	_board_host = _vbox(6)
	left.add_child(_board_host)
	# 255 补充二：两栏 —— 中栏拆了。包架（225）挪进棋盘板、棋盘正下方横一行（九种以内一行），拖包上棋盘只隔一道缝
	_rack_box = BagRackView.boxed(flow.meta.rack, font, RACK_COLUMNS)
	_rack_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rack_view = BagRackView.view_in(_rack_box)
	left.add_child(_rack_box)

	# 作者 10-31「仓库的界面背景不该是纯黑色的，应该和基地里的仓库一样」：不再垫铁角黑框，格子套基地那副木架（PANEL_SHELF）、棕底；
	# 「右边的仓库棋盘应该右对齐」：整块贴页面右边
	var ware_panel := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_BARE)
	ware_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ware_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	row.add_child(ware_panel)
	_warehouse_box = ware_panel
	var right := _vbox(6)
	ware_panel.add_child(right)
	var w := flow.meta.warehouse

	_drag = DragLayer.new()
	_drag.label_font = font
	_drag.grab_refused.connect(func(uid: int): warn(DragLayer.refused_notice(board, uid)))     # 255：随身之物拿不下来
	# 163：仓库分页 —— 左边竖排页签，拖着东西停在页签上切页
	_warehouse_scroll = ScrollContainer.new()
	_warehouse_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_warehouse_scroll)
	_warehouse_pages = WarehousePages.new()
	if UiTheme.has_setup_art(UiTheme.ART_SETUP_TAB):     # 180 定稿：挂牌页签
		_warehouse_pages.tab_variation = UiTheme.BUTTON_SETUP_TAB
		_warehouse_pages.tab_height = TAB_TAG_H
	_warehouse_pages.frame_variation = UiTheme.PANEL_SHELF
	_warehouse_scroll.add_child(_warehouse_pages)
	_warehouse_pages.setup(w, font, _drag, TechWarehousePages.plan_of(flow.tech_defs))
	_warehouse_view = _warehouse_pages.view
	var tools := _hbox(12)
	right.add_child(tools)
	_tidy_btn = UiTheme.make_home_button(UiText.t("wh.tidy"), tidy_warehouse, false, TIDY_SIZE, 18)     # 作者 10-31「需要有整理按钮」：同基地仓库，只排当前页
	_tidy_btn.name = "TidyButton"
	_tidy_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tools.add_child(_tidy_btn)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(gap)
	_build_cash_box(tools)     # 2026-10-22：把仓库里的钱带进这一局；255 补充二：钱是仓库的，便条钉在仓库框底部靠右
	play.add_child(_drag)     # 容器把它铺到和整行一样大，盖在两块板上
	_drag.register_view(_warehouse_view)
	_warehouse_view.item_double_clicked.connect(quick_move)     # 109：双击 = 快速置入，和局内一样
	_drag.register_view(_rack_view)     # 225：包架 ⇄ 棋盘
	_rack_view.item_double_clicked.connect(quick_move)
	_warehouse_view.actions_for = item_actions.bind(_warehouse_view)     # 230
	_rack_view.actions_for = item_actions.bind(_rack_view)
	flow.meta.rack.changed.connect(_refresh)
	w.changed.connect(_refresh)
	_warehouse_pages.minimum_size_changed.connect(_fit_warehouse)
	if _warehouse_pages.frame != null:
		_warehouse_pages.frame.minimum_size_changed.connect(_fit_warehouse)     # 作者 10-31 木架：框的边距进了主题才算得出来
	_area.resized.connect(_fit_warehouse)
	_fit_warehouse()
	_build_stash()
	return play


## 作者 10-31：整理仓库**当前页**（[GridTidy]，同基地仓库）；排不开就原样不动、说一句
func tidy_warehouse() -> bool:
	var page := _warehouse_pages.current_page() if _warehouse_pages != null else null
	if page == null:
		return false
	var ok := GridTidy.tidy(page)
	if page.item_count() > 1:
		warn(UiText.t("wh.page_tidied") if ok else UiText.t("wh.tidy_failed"))
	return ok


## 2026-10-22（作者定）：带入现金 —— 这一局带多少钱由玩家定，上限是仓库余额，不带就是 0。
## 带进去的钱从仓库账上扣，死在局内就没了；撤离时 [method MetaState.absorb] 会把局内余额 1:1 加回来
func _build_cash_box(parent: Container) -> void:
	var note := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_SUMMARY_NOTE, CASH_PAD, CASH_PAD_TOP, CASH_PAD, CASH_PAD_BOTTOM)
	note.name = "CashNote"
	note.size_flags_horizontal = Control.SIZE_SHRINK_END
	parent.add_child(note)
	var col := _vbox(10)
	col.custom_minimum_size.x = CASH_ROW_W
	note.add_child(col)
	var head := _hbox(8)
	col.add_child(head)
	var title := _label(UiText.t("setup.cash_title"), 17, UiTheme.INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_cash_store = _label("", 15, UiTheme.INK)
	_cash_store.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_cash_store)
	var slide_row := _hbox(6)
	col.add_child(slide_row)
	_cash_slider = StoneSlider.new()
	_cash_slider.name = "CashSlider"
	_cash_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cash_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cash_slider.value_changed.connect(func(v: float) -> void: set_carry_funds(roundi(v)))
	slide_row.add_child(_cash_slider)
	var coin := TextureRect.new()     # 作者 10-24：钱 = 金币 + 数字
	coin.texture = CoinLabel.coin_icon(20)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide_row.add_child(coin)
	_cash_field = StoneField.new("0", false)
	_cash_field.name = "CashField"
	_cash_field.custom_minimum_size.x = CASH_FIELD_W
	_cash_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cash_field.max_length = 7
	_cash_field.text_changed.connect(_on_cash_typed)
	_cash_field.text_submitted.connect(func(_t: String) -> void: _cash_field.release_focus())
	_cash_field.focus_exited.connect(_refresh_cash)
	slide_row.add_child(_cash_field)
	var row := _hbox(CASH_CHIP_GAP)
	col.add_child(row)
	_cash_chips.clear()
	for spec in [["setup.cash_none", func() -> void: set_carry_funds(0)],
			["setup.cash_half", func() -> void: set_carry_funds(int(floor(cash_cap() / 2.0)))],
			["setup.cash_all", func() -> void: set_carry_funds(cash_cap())]]:
		var chip := StoneChip.make(UiText.t(spec[0]), spec[1])
		chip.custom_minimum_size.x = (CASH_ROW_W - 2.0 * CASH_CHIP_GAP) / 3.0
		row.add_child(chip)
		_cash_chips.append(chip)
	_refresh_cash()


## 这一局最多能带多少：仓库账上的钱（没有局外就是 0）
func cash_cap() -> int:
	return flow.meta.funds if flow != null and flow.meta != null else 0


## 改带入的现金：夹在 0 和仓库余额之间，改完刷读数
func set_carry_funds(n: int) -> void:
	carry_funds = clampi(n, 0, cash_cap())
	_refresh_cash()


## 键盘输入：只留数字，超过仓库余额收到余额；打字时不回写框里的字（光标不跳）
func _on_cash_typed(t: String) -> void:
	var digits := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			digits += ch
	var n := mini(int(digits) if digits != "" else 0, cash_cap())
	if digits != t or (digits != "" and n != int(digits)):
		_cash_field.text = str(n) if digits != "" else ""
		_cash_field.caret_column = _cash_field.text.length()
	_cash_typing = true
	set_carry_funds(n)
	_cash_typing = false


func _refresh_cash() -> void:
	if _cash_slider == null:
		return
	carry_funds = clampi(carry_funds, 0, cash_cap())     # 仓库钱变少了（卖 / 花）跟着收
	var cap := cash_cap()
	_cash_store.text = UiText.t("setup.cash_store") % cap
	_cash_slider.max_value = cap
	_cash_slider.set_value_no_signal(carry_funds)
	_cash_slider.enabled = cap > 0
	_cash_slider.queue_redraw()
	_cash_field.editable = cap > 0
	if not _cash_typing:
		_cash_field.text = str(carry_funds)
	_cash_chips[0].disabled = carry_funds == 0
	_cash_chips[1].disabled = carry_funds == int(floor(cap / 2.0))
	_cash_chips[2].disabled = carry_funds == cap


## 180 补二：仓库框的大小 —— 宽 = 页签 + 格子 + 滚动条位；高 = 格子的高，但不超过这一页还剩的高（超出就滚）。
## 页还剩多高按整屏内容区算（不按页自己的尺寸：页的高又被框撑着）
func _fit_warehouse() -> void:
	var room := -1.0
	if _area != null and _area.size.y > 0.0 and _title != null:
		room = _area.size.y - PAGE_MARGIN - NAV_ROOM - _title.get_combined_minimum_size().y - PAGE_SEP
	fit_warehouse_to(room)


## [param page_h]：这一页能占多高（负 = 不知道，按格子全高）
func fit_warehouse_to(page_h: float) -> void:
	if _warehouse_scroll == null or _warehouse_pages == null:
		return
	var want := _warehouse_pages.get_combined_minimum_size()
	var room := want.y
	if page_h > 0.0:
		var chrome := _warehouse_box.get_combined_minimum_size().y - _warehouse_scroll.custom_minimum_size.y     # 框的边距与标题
		room = minf(want.y, page_h - chrome)
	_warehouse_scroll.custom_minimum_size = Vector2(want.x + SCROLL_GUTTER, maxf(UiTheme.FONT_SIZE * 4.0, room))


## 仓库框里的滚动区（测试看）
func warehouse_scroll() -> ScrollContainer:
	return _warehouse_scroll


## 180 第三页：左 地图（一级）与规模（选中的图下面展开）| 中 化开的地图预览 | 右 出发摘要 + 当前难度
func _build_map_page() -> Control:
	var row := _hbox(36)
	var left_board := _on_paper(PAPER_INSET, 0)
	left_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(left_board)
	var left := _vbox(8)
	left.custom_minimum_size.x = 300 - 32
	left_board.add_child(left)
	_map_list = _vbox(6)     # 226 批二：小标题「地图」与缺数据那句删了
	left.add_child(_map_list)

	_preview = MapPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_preview)
	_preview.entry_pressed.connect(pick_spawn)
	_preview.blank_pressed.connect(_on_preview_blank)
	_hint = NodeHintCard.new()
	add_child(_hint)

	var right_board := _on_paper(0, PAPER_INSET)
	right_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(right_board)
	var right := _vbox(18)
	right.custom_minimum_size.x = DifficultyBlock.WIDTH
	right_board.add_child(right)
	# 180 补二（作者 10:09）：右上只写角色名，没有标题，负重 / 地图 / 难度各行都不要（左列与难度块自己在显示）。
	# 定稿：写在一张钉着的便条上（浅底墨字、居中）
	_summary = _label("", 22, UiPalette.FG)
	if UiTheme.art(UiTheme.ART_SUMMARY_NOTE) != null:
		var note := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_SUMMARY_NOTE, 26, 20, 26, 20)
		note.custom_minimum_size.y = 88
		_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.add_child(_summary)
		right.add_child(note)
	else:
		right.add_child(_summary)
	# 180 补四 / 补五（作者 11:38 / 11:43 / 11:49）：〇级时整块（计数器、加减、羊皮纸）收成一颗居中写「开启挑战」的铜牌按钮，
	# 背后两根卷好的卷轴；点它拨到 Ⅰ —— 卷轴下移再拉开，按钮换成「当前难度」铜牌、计数器与加减。一个难度都没解锁时压灰
	_diff_block = DifficultyBlock.new()
	right.add_child(_diff_block)
	_diff_block.step_pressed.connect(step_difficulty)
	_diff_block.open_pressed.connect(_on_plate_pressed)
	_diff_plate = _diff_block.open_btn
	_counter = _diff_block.counter
	_flipper = _diff_block.flipper
	_difficulty_num = _flipper.label
	_minus_btn = _diff_block.minus_btn
	_plus_btn = _diff_block.plus_btn
	_challenge = _diff_block.scroll
	_area.resized.connect(_fit_challenge)
	return row


#region 161：翻页
func page() -> int:
	return _page


## 换到第 [param i] 页（0..2）：只显示那一页，标题与右下角按钮跟着变
func show_page(i: int) -> void:
	var was := _page
	_page = clampi(i, 0, PAGE_TITLES.size() - 1)
	if _page == PAGE_MAP and was != PAGE_MAP:
		_reroll_seed()     # 180：种子玩家看不见，每次进这一页随机取（调试台指定了就用那个）
	if _page != PAGE_MAP:
		close_hint()
	for k in _pages.size():
		_pages[k].visible = k == _page
	if _page == 1:
		_fit_warehouse()     # 作者 10-31 木架：框的边距要等进了树、主题生效才算得出来，翻到这页再量一次
	var tone := _repaint(PAGE_ART[_page])
	if _title_indent != null:
		_title_indent.custom_minimum_size.x = PAPER_INSET if _page == PAGE_MAP and _paper_art() else 0.0
	if _title != null:
		_title.text = UiText.t(PAGE_TITLES[_page])
	if _enter_btn != null:
		_enter_btn.text = UiText.t("setup.depart") if _page == PAGE_TITLES.size() - 1 else UiText.t("menu.continue")
	if _back_btn != null:
		_back_btn.text = UiText.t("setup.back")     # 264 §五（作者 10-29 16:20）：三页都写「返回」，第一页回基地
	for b in [_enter_btn, _back_btn]:
		TextFit.shrink_button(b)     # 255 补充一：右下两颗定宽（英文缩字），不往左伸到角色卡上
	_sync_preview()
	_refresh()
	_fit_nav()
	_fit_challenge.call_deferred()     # 180 补三：排好版才知道纸能长多长


## 继续（最后一页 = 出发）。第一页没角色走不了
func next_page() -> bool:
	if _page >= PAGE_TITLES.size() - 1:
		return depart()
	if _page == 0 and character() == null:
		return false
	show_page(_page + 1)
	return true


## 返回（第一页 = 回基地）
func prev_page() -> void:
	if _page == 0:
		cancel()
	else:
		show_page(_page - 1)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		next_page()
		get_viewport().set_input_as_handled()
#endregion


## 090：地上。上一局带回来、还没置入的东西从带回来的棋盘挪进来，记住各自原位（返回基地原样放回）。
## 255 补充二：不再占一栏 —— 是仓库页签列末尾的一页「地上」，只在有东西时出现，大小 = 仓库格子那块；
## 刚进来地上有东西就先翻到这页（不然玩家看不见）；拖着东西停在页签上切页（163）照样能拖回地上
func _build_stash() -> void:
	stash = ItemStash.new(STASH_ID, 0)
	_pending = flow.meta.take_board_to_stash(stash)     # 101 第 4 刀：挪与记原位的账在 MetaState 里
	_stash_view = GroundLayer.new()     # 128：一块地，放手在哪就落在哪
	_stash_view.label_font = font
	_stash_view.stash = stash
	_stash_tab = _warehouse_pages.add_extra(_stash_view)
	_drag.register_view(_stash_view)
	_stash_view.item_double_clicked.connect(quick_move)
	_stash_view.actions_for = item_actions.bind(_stash_view)     # 230
	_drag.drop_filter = _allow_drop
	stash.changed.connect(_refresh)
	_sync_stash_tab()
	_warehouse_pages.show_extra()     # 225：只有包（进了包架）时地上那页不出来，这一下就是空操作


## 「地上」页签：有东西才出，第二行写几件
func _sync_stash_tab() -> void:
	if _warehouse_pages == null or stash == null:
		return
	var n := stash.item_count()
	_warehouse_pages.set_extra_tab(n > 0, "%s\n%s" % [UiText.t("wh.ground_tab"), UiText.t("wh.tab_count") % n], UiText.tn("setup.ground_count", n) % n)
	if _stash_tab != null:
		TextFit.shrink_button(_stash_tab, 9)     # 英文「Ground」在 52 宽的挂牌里


## 正看着仓库页签列里的「地上」那页（测试看）
func on_ground_page() -> bool:
	return _warehouse_pages != null and _warehouse_pages.on_extra()


## 090：落点规则。仓库的东西进不了地上（进去就等于出发时丢掉）；地上的东西上棋盘要这一章允许带入
func _allow_drop(inst: ItemInstance, target: ItemContainer) -> bool:
	if inst == null:
		return false
	if target == stash:
		return _pending.has(inst.uid)
	if target == flow.meta.rack:
		return BagRack.holds(inst.def) and not _preset_uids.has(inst.uid)     # 225：包架只收包，预设套的包留在棋盘上
	if target == board and _pending.has(inst.uid):
		var c := chapter()
		return c == null or c.allow_carry_in
	if _preset_uids.has(inst.uid) and target != board:
		return false     # 096：预设套的东西只能在棋盘上挪，进不了仓库 / 地上
	return true


## 一列单选按钮（章节 / 难度 / 角色 / 预设 / 规模各一列）：每个名字一个左对齐的按钮，按下调 `on_pick(序号)`；
## 选中的是哪个由 [method _mark_choice] 标。返回这一列的按钮，顺序同 [param names]
func _choice_column(box: Control, names: Array[String], on_pick: Callable, size: int = 14, entry_h: float = MAP_ENTRY_H) -> Array[Button]:
	var btns: Array[Button] = []
	for i in names.size():
		var idx := i
		var b := _button(names[i], func(): on_pick.call(idx), size)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_skin_entry(b, UiTheme.BUTTON_MAP_ENTRY, UiTheme.ART_MAP_ENTRY, entry_h)     # 乙 石刻：同第三页选地图的纸条，选中压蜡封
		btns.append(b)
		box.add_child(b)
	return btns


## 121：一列里第 [param index] 个是选中的（前景色），其余暗色（[method UiTheme.mark]）
func _mark_choice(btns: Array, index: int) -> void:
	for k in btns.size():
		_mark_entry(btns[k], k == index)


#region 公开动作
func choose_chapter(i: int) -> void:
	if _chapters.is_empty():
		return
	chapter_index = clampi(i, 0, _chapters.size() - 1)
	# 083：这一章能选的角色、能不能从仓库带东西，都跟着章节变。
	# 161：章节在第三页才挑 —— 已经挑好的角色这一章也能用就留着（棋盘上带的东西不动），不能用才换回第一个
	var keep := character()
	_rebuild_characters()
	_rebuild_scales()
	if _warehouse_box != null:
		_warehouse_box.visible = chapter().allow_carry_in
	var at := _characters.find(keep) if keep != null else -1
	if at < 0 or board == null:
		choose_character(0)
		return
	character_index = at
	_mark_choice(_character_btns, character_index)
	if not chapter().allow_carry_in:
		_return_carried()
	_refresh()


## 180：这一章能选的规模（环形生成器的 `scales`）；预设图没有 = 空。默认挑上次那档（同一张图时），否则第一档
func _rebuild_scales() -> void:
	_scale_btns.clear()
	scale_id = &""
	var ch := chapter()
	var options := scale_options_of(ch)
	if not options.is_empty():
		var last := flow.meta.flag(FLAG_LAST_SCALE) - 1
		var same_map := flow.meta.flag(FLAG_LAST_MAP) == ch.order + 1
		scale_id = options[last]["id"] if same_map and last >= 0 and last < options.size() else options[0]["id"]
	_rebuild_map_list()
	_sync_preview()


## 一章的规模选项（[method MapSource.scale_options]，没有 map_source = 空）
static func scale_options_of(c: ChapterDef) -> Array[Dictionary]:
	return c.map_source.scale_options() if c != null and c.map_source != null else [] as Array[Dictionary]


## 180：规模那一行右边的小字：「4~5 环　倒计时 36」（193 补充一）
static func scale_note(o: Dictionary) -> String:
	var parts: Array[String] = []
	var r: Vector2i = o.get("rings", Vector2i.ZERO)
	if r.x > 0:
		parts.append((UiText.t("setup.rings") % r.x) if r.y <= r.x else (UiText.t("setup.rings_range") % [r.x, r.y]))
	var limit := int(o.get("step_limit", 0))
	if limit > 0:
		parts.append(UiText.t("setup.scale_countdown") % limit)
	return UiText.t("setup.sep").join(parts)


## 180：左列重排 —— 每张图一个按钮；选中的那张下面缩进一列规模（名字在左、环数与倒计时小字在右）
func _rebuild_map_list() -> void:
	if _map_list == null:
		return
	UiTheme.clear_children(_map_list)
	for i in _chapters.size():
		var c := _chapters[i]
		var idx := i
		var b := _button(Names.of(c) if c.display_name != "" else String(c.id), func(): choose_chapter(idx), 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_skin_entry(b, UiTheme.BUTTON_MAP_ENTRY, UiTheme.ART_MAP_ENTRY, MAP_ENTRY_H)
		_mark_entry(b, i == chapter_index)
		_map_list.add_child(b)
		if i != chapter_index:
			continue
		for o in scale_options_of(c):
			var sid: StringName = o["id"]
			var line := _hbox(0)
			var indent := Control.new()
			indent.custom_minimum_size.x = SCALE_INDENT
			line.add_child(indent)
			var sb := _button(String(o["display_name"]), func(): choose_scale(sid), 14)
			sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_skin_entry(sb, UiTheme.BUTTON_MAP_SUB, UiTheme.ART_MAP_SUB, MAP_SUB_H)
			_mark_entry(sb, sid == scale_id)
			var note := _label(scale_note(o), 12, UiPalette.DIM)
			note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			note.offset_right = -12
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			note.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sb.add_child(note)
			line.add_child(sb)
			_map_list.add_child(line)
			_scale_btns[sid] = sb


## 180 定稿：地图条目 / 规模换成图（钉位、连线红勾在图上，选中是 on 图 = 按下态）；没图照旧
func _skin_entry(b: Button, variation: StringName, art_name: String, height: float) -> void:
	if not UiTheme.has_setup_art(art_name):
		return
	b.theme_type_variation = variation
	b.toggle_mode = true
	b.custom_minimum_size.y = height


## 选中的那条：有图按下（on 图），没图前景色 / 暗色（[method UiTheme.mark]）
func _mark_entry(b: Button, on: bool) -> void:
	if b.toggle_mode:
		b.set_pressed_no_signal(on)
	else:
		UiTheme.mark(b, on)


## 挑一档规模。空 = 章节自己的默认配置（界面上不列；测试按章节默认配置找的种子用它）
func choose_scale(id: StringName) -> void:
	if id != &"" and not _scale_btns.has(id):
		return
	scale_id = id
	for k in _scale_btns:
		_mark_entry(_scale_btns[k], k == scale_id)
	_sync_preview()
	_refresh()


func scale_options() -> Array:
	return _scale_btns.keys()


## 180：第三页的图：开局屏能列的章里去掉教程章（序章只出现一次，不进列表）
func map_chapters() -> Array[ChapterDef]:
	var out: Array[ChapterDef] = []
	for c in flow.available_chapters():
		if c.hidden_by_unlock == &"":
			out.append(c)
	return out


## 180：这一章这一档按现在的种子真生成一次、数环（入局时 flow.begin 用同一个种子再生成，确定性生成两次一样）。
## 213：格阵数行；别的布局 0
func ring_levels(c: ChapterDef, sid: StringName) -> int:
	var g := preview_graph(c, sid)
	var lay := MapLayout.for_graph(g) if g != null else null
	if lay is RingLayoutBase:
		return (lay as RingLayoutBase).level_count(g)
	return LatticeMapLayout.rows_of(g) if lay is LatticeMapLayout else 0


## 182：这一章这一档按现在的种子生成的那张图（缓存；生成不出 null）。入口印记、环数都从它来
func preview_graph(c: ChapterDef, sid: StringName) -> MapGraph:
	if c == null or c.map_source == null:
		return null
	var key := _graph_key(c, sid)
	if not _graph_cache.has(key):
		_graph_cache[key] = c.map_source.resolve(run_seed, sid)
	return _graph_cache[key]


func _graph_key(c: ChapterDef, sid: StringName) -> String:
	return "%s|%s|%d" % [c.id, sid, run_seed]


## 180：预览跟着现在挑的图与规模（只在第三页算：别的页不生成）
func _sync_preview() -> void:
	if _preview == null or _page != PAGE_MAP:
		return
	var c := chapter()
	if c == null:
		_preview.clear()
		_forget_spawn()
		return
	var animate := _animations_on()
	var key := _graph_key(c, scale_id)
	if key == _preview_key and _preview.levels > 0:
		return     # 同一张图（换难度、回到这一页）：不重新化开，挑好的出生点留着
	_preview_key = key
	_preview.show_graph(c.map_skin, preview_graph(c, scale_id), scale_id, animate)     # 213：同心环、格阵都按图本身
	# 182：换了图（换图、换规模、重取种子）—— 入口换成新图的、挑的清掉（「出发」重新灰）；自己会站上出生点的章不画入口
	_forget_spawn()
	_preview.set_entries(preview_graph(c, scale_id) if not c.auto_spawn else null)


func preview() -> MapPreview:
	return _preview


## 180：种子进第三页随机取；调试台指定了下一局的种子就用它
func _reroll_seed() -> void:
	run_seed = flow.next_run_seed if flow != null and flow.next_run_seed >= 0 else randi() % 1000000
	_sync_preview()


## 180：进开局屏时默认上次的图、规模、难度（找不到回第一个 / 0 档）
func _restore_last() -> void:
	var at := 0
	var want := flow.meta.flag(FLAG_LAST_MAP) - 1
	for i in _chapters.size():
		if _chapters[i].order == want:
			at = i
	choose_chapter(at)
	var level := flow.meta.flag(FLAG_LAST_DIFFICULTY)
	var idx := 0
	var ladder := flow.available_difficulties()
	for i in ladder.size():
		if ladder[i].level <= level:
			idx = i
	choose_difficulty(idx)


func _rebuild_characters() -> void:
	_characters = flow.characters_for(chapter())
	_character_btns.clear()
	if _char_box == null:
		return
	UiTheme.clear_children(_char_box)
	var names: Array[String] = []
	for ch in _characters:
		var n := Names.of(ch) if ch.display_name != "" else String(ch.id)
		var why := lock_reason(ch)
		names.append(n + ("\n" + UiText.t("setup.locked_character") % why if why != "" else ""))
	_character_btns = _choice_column(_char_box, names, choose_character, 16)
	for b in _character_btns:     # 选人页 B：平头木键、字居中，选中 = 按下态（深色木），不压蜡封
		b.theme_type_variation = UiTheme.BUTTON_SETUP_CHAR
		b.remove_theme_font_size_override("font_size")     # 字号交给变体（20）
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size.y = CHAR_KEY_H
	for i in _characters.size():     # 255：没解锁的压灰、点不了（解锁条件写在名字下面一行）
		if lock_reason(_characters[i]) != "" and i < _character_btns.size():
			_character_btns[i].modulate.a = LOCKED_ALPHA
			_character_btns[i].disabled = true


## 255：这个角色没解锁的原因（解锁条件那一行）；空 = 能选。角色解锁（254 成就解锁）来之前一律能选，这里只是留好的口子
func lock_reason(_ch: CharacterDef) -> String:
	return ""


## 096：预设套那一栏：「不带」+ 每套一个按钮（悬停看说明）
func _rebuild_presets() -> void:
	_preset_btns.clear()
	if _preset_box == null:
		return
	UiTheme.clear_children(_preset_box)
	var names: Array[String] = [UiText.t("setup.no_preset")]
	var tips: Array[String] = [UiText.t("setup.no_preset_tip")]
	for def in flow.presets():
		names.append(Names.of(def))
		tips.append(Names.description_of(def))
	_preset_btns = _choice_column(_preset_box, names, func(i: int): choose_preset(i - 1), 14, PRESET_ENTRY_H)     # 第 0 个是「不带」
	for i in _preset_btns.size():
		_preset_btns[i].tooltip_text = tips[i]
	_color_presets()


func _color_presets() -> void:
	_mark_choice(_preset_btns, preset_index + 1)     # 第 0 个是「不带」


## 096：挑一套预设（-1 = 不带）：棋盘上原来那套拿掉，新的免费放进初始包（放不下的在状态栏说）。从仓库带上的不动
func choose_preset(i: int) -> void:
	var sets := flow.presets()
	preset_index = clampi(i, -1, sets.size() - 1)
	_clear_preset()
	_apply_preset()
	ensure_bag()     # 225：换回「不带」时棋盘上可能一只包都没了
	_color_presets()
	_refresh()


func preset() -> LoadoutDef:
	var sets := flow.presets()
	return sets[preset_index] if preset_index >= 0 and preset_index < sets.size() else null


func _clear_preset() -> void:
	if board != null:
		for uid in _preset_uids:
			if board.get_item(int(uid)) != null:
				board.remove(int(uid))
	_preset_uids.clear()


## 把预设套的道具放上棋盘（和拖进包里一样自动找位置）。放不下的记在状态栏
func _apply_preset() -> void:
	var def := preset()
	if def == null or board == null:
		return
	var missed: Array[String] = []
	for id in def.items:
		var idef := flow.items.get_def(id)
		if idef == null:
			continue
		var inst := ItemInstance.create(idef, 0)
		inst.uid = flow.meta.allocate_uid()
		if board.try_add(inst, true):
			_preset_uids[inst.uid] = true
		else:
			missed.append(Names.of(idef))
	if not missed.is_empty():
		warn(UiText.t("setup.preset_missed") % UiText.t("setup.list_sep").join(missed))


## 096：棋盘上预设套的实例
func preset_items() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if board == null:
		return out
	for inst in board.items():
		if _preset_uids.has((inst as ItemInstance).uid):
			out.append(inst)
	return out


## 换角色：带上的先放回仓库，按新角色的棋盘尺寸与初始包重摆
func choose_character(i: int) -> void:
	_return_bags()
	if not _characters.is_empty():
		character_index = clampi(i, 0, _characters.size() - 1)
	_mark_choice(_character_btns, character_index)
	_rebuild_board()
	_rebuild_card()
	_refresh()


## 挑难度（只在能选的里挑：没有解锁要求的和已解锁的）
func choose_difficulty(i: int) -> void:
	var avail := flow.available_difficulties()
	if avail.is_empty():
		return
	difficulty_index = clampi(i, 0, avail.size() - 1)
	_sync_difficulty()
	_refresh()


## 180：难度加减一级（只在能选的档里走：没解锁的上不去）
func step_difficulty(delta: int) -> void:
	_step_dir = signi(delta)
	choose_difficulty(difficulty_index + delta)
	_step_dir = 0


## 180：难度块 —— 数字、两颗键的灰亮、卷轴上的挑战（1..这一级各自新加的挑战，一级一行；〇级收起）
func _sync_difficulty() -> void:
	var avail := flow.available_difficulties()
	var d := difficulty()
	if _diff_block == null:
		return
	_minus_btn.disabled = difficulty_index <= 0
	_plus_btn.disabled = difficulty_index >= avail.size() - 1
	_diff_block.set_locked(avail.size() <= 1)
	# 只在玩家点了加减 / 按钮时播（读上次的难度直接是展开态）
	var animate := _animations_on() and _step_dir != 0
	_diff_block.show_state(difficulty_numeral(d.level if d != null else 0), challenge_lines(), difficulty_index > 0, _step_dir, animate)
	_fit_challenge.call_deferred()


## 难度块展开着（≥ Ⅰ；测试看）
func difficulty_open() -> bool:
	return _diff_block != null and _diff_block.is_open()


## 点「开启挑战」：〇级拨到 Ⅰ（展开）；已经展开就不动
func _on_plate_pressed() -> void:
	if difficulty_index == 0:
		step_difficulty(1)


## 180 补二：难度写成罗马数字（和回放倍速、仓库页签一套字形）。
## 0 级是空白卡（补四「全空更好」：收起时计数器翻成空白，点开从空白往上翻到 Ⅰ）
static func difficulty_numeral(level: int) -> String:
	return "" if level <= 0 else TextTemplate.roman(level)


## 翻页、纸伸缩这些小动画开不开（跟设置里的「换屏淡入」走）
func _animations_on() -> bool:
	return flow.settings == null or flow.settings.ui_fades


## 180 补三：挑战说明的几行 [[级, 文字], ...]，从〇级到现在这一级，没写挑战的级不列（〇级没有挑战，纸上没有它那行）
func challenge_lines() -> Array:
	var out: Array = []
	var avail := flow.available_difficulties()
	for i in range(0, mini(difficulty_index + 1, avail.size())):
		var c := Names.pick(avail[i].challenges, avail[i].challenge).strip_edges()
		if c != "":
			out.append([avail[i].level, c])
	return out


## 180：红字说明拼成一段（从低到高）
func challenge_text() -> String:
	return "\n".join(challenge_lines().map(func(l: Array) -> String: return String(l[1])))


## 180 补三：纸最长到「出发」按钮上沿再留 [constant PAPER_CLEARANCE]（排版好了才算得准，窗口变了重算；按展开时纸的位置算，收着也算得出）
func _fit_challenge() -> void:
	if _diff_block == null or _enter_btn == null or not _diff_block.is_inside_tree() or not _diff_block.is_visible_in_tree():
		return
	var top := _diff_block.get_global_rect().position.y + _diff_block.open_paper_top()
	var limit := _enter_btn.get_global_rect().position.y - PAPER_CLEARANCE - _challenge.bottom_rod.custom_minimum_size.y
	if limit > top:
		_challenge.max_paper = limit - top


func difficulty() -> DifficultyDef:
	var avail := flow.available_difficulties()
	return avail[difficulty_index] if difficulty_index < avail.size() else null


func chapter() -> ChapterDef:
	return _chapters[chapter_index] if chapter_index < _chapters.size() else null


## 129：出发前就看见负重（带太多直接显示级数，不拦）。这一章不算负重 / 角色没配上限 → 空
func encumbrance_text() -> String:
	var c := chapter()
	var ch := character()
	if c == null or ch == null or c.encumbrance_rules == &"" or ch.weight_capacity <= 0 or board == null:
		return ""
	var path := ContentPaths.asset_file("encumbrance_rules", String(c.encumbrance_rules))
	var rules := load(path) as EncumbranceRules if ResourceLoader.exists(path) else null
	if rules == null:
		return ""
	var defs: Array = []
	for id in flow.meta_buffs():
		if flow.buff_defs.has(id):
			defs.append(flow.buff_defs[id])
	var ctx := RunBuffs.context(defs)
	for e in ch.run_effects():     # 256：角色被动也算（马库斯「操练」武器减重）
		e.modify(ctx)
	var cap := ctx.carry_capacity_of(ch.weight_capacity)     # 149：科技按百分比
	var w := ItemWeight.total_scaled(board, ctx.weight_pct)
	var lv := rules.level_of(w, cap)
	return UiText.t("setup.load") % [w, cap, rules.name_of(lv), UiText.t("setup.sep") + rules.effect_text(lv) if lv > 0 else ""]


func character() -> CharacterDef:
	return _characters[character_index] if character_index < _characters.size() else null


## 把仓库（或 090 地上）里的一件带上（自动找位置，和拖进包里一样）。放不进返回 false
func carry_in(uid: int) -> bool:
	if board == null:
		return false
	var from: ItemContainer = flow.meta.warehouse if flow.meta.warehouse.get_item(uid) != null else stash
	if from == null or from.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(from, uid, board)
	_refresh()
	return ok


## 109（作者定）：开局屏的双击快速置入，和局内（084 [method InventoryPanel.quick_move]）同一个形状：
## 仓库 / 地上 → 初始包的棋盘；棋盘 → 仓库（初始包自己、预设套的不行）。放不下原地不动，状态行说一句。拖拽那套不动
func quick_move(view: ContainerView, uid: int) -> bool:
	var from := view.container() if view != null else null
	var inst := from.get_item(uid) if from != null else null
	if inst == null:
		return false
	var why := ""
	var ok := false
	if from == flow.meta.rack:     # 225：包架 → 棋盘
		ok = board != null and InventoryService.transfer_auto(from, uid, board)
		why = "" if ok else UiText.t("setup.no_room_bag") % Names.of(inst.def)
	elif flow.meta.warehouse.owns(from) or from == stash:
		if board == null:
			return false
		if not _allow_drop(inst, board):
			why = UiText.t("setup.no_brought_back")
		else:
			ok = carry_in(uid)
			why = "" if ok else UiText.t("setup.no_room_bag") % Names.of(inst.def)
	elif from == board:
		if _preset_uids.has(uid):
			why = UiText.t("setup.preset_stays")
		elif BagRack.holds(inst.def):     # 225：包 → 包架（空包才行）
			ok = rack_bag(uid)
			why = "" if ok else UiText.t("rack.has_contents") % Names.of(inst.def)
		else:
			ok = carry_out(uid)
			why = "" if ok else UiText.t("setup.no_room_warehouse") % Names.of(inst.def)
	if why != "":
		warn(why)
	return ok


## 230：悬浮窗按钮。第一颗 = 双击做的那件事（带上 / 摆上棋盘 / 放回仓库 / 收回包架），然后锁定、出售（仓库里的）、置入（地上的）、奉为主信仰（信物）
func item_actions(uid: int, view: ContainerView) -> Array:
	var from := view.container() if view != null else null
	var inst := from.get_item(uid) if from != null else null
	if inst == null:
		return []
	var save := func():
		flow.save_meta()
		view.queue_redraw()
	var quick := ItemActions.make(&"quick", "", func(): quick_move(view, uid))
	var out: Array = [quick]
	if from == flow.meta.rack:
		quick.label = UiText.t("act.to_board")
	elif flow.meta.warehouse.owns(from):
		quick.label = UiText.t("act.carry")
		if board != null and not _allow_drop(inst, board):
			ItemActions.disable(quick, UiText.t("setup.no_brought_back"))
		out.append(ItemActions.lock(inst, from, save))
		out.append(ItemActions.lock_same(inst, flow.meta.warehouse, save))
		out.append(ItemActions.sell(inst, MetaState.sell_price_of(inst, flow.sell_ratio()), _sell_one))
		out.append(ItemActions.sell_same(inst, flow.meta.warehouse, func(i: ItemInstance) -> int: return MetaState.sell_price_of(i, flow.sell_ratio()), _sell_one))
	elif from == stash:
		quick.label = UiText.t("act.to_board")
		if board != null and not _allow_drop(inst, board):
			ItemActions.disable(quick, UiText.t("setup.no_brought_back"))
		out.append(ItemActions.make(&"store", UiText.t("act.store"), func(): store(uid)))
		out.append(ItemActions.lock(inst, from, save))
	elif from == board:
		quick.label = UiText.t("act.to_rack" if BagRack.holds(inst.def) else "act.to_warehouse")
		if _preset_uids.has(uid):
			ItemActions.disable(quick, UiText.t("setup.preset_stays"))
		out.append(ItemActions.lock(inst, from, save))
		if inst.def.is_anchor():
			out.append(ItemActions.anchor(inst, board, reseat_anchor))
	if board == null and from != board:
		ItemActions.disable(quick, "")
	return out


## 230：仓库里卖一件（悬浮窗「出售」）
func _sell_one(uid: int) -> int:
	var got := flow.sell_item(uid)
	_refresh()
	return got


## 090：把地上的一件收进仓库（= 置入）。放不下返回 false
func store(uid: int) -> bool:
	if stash == null or stash.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(stash, uid, flow.meta.warehouse)
	if ok and _warehouse_pages != null:
		_warehouse_pages.show_item(uid)
	_refresh()
	return ok


## 225：棋盘上的一只包收回包架（上面还有东西的不行）
func rack_bag(uid: int) -> bool:
	if board == null or _preset_uids.has(uid):
		return false
	var inst := board.get_item(uid)
	if inst == null or not BagRack.holds(inst.def) or board.is_bag_with_contents(uid):
		return false
	board.remove(uid)
	var ok := flow.meta.put_bag(inst)
	if not ok:
		board.try_add(inst, true)
	_refresh()
	return ok


## 把棋盘上的一件放回仓库。包不行（225：包回包架，见 [method rack_bag]）
func carry_out(uid: int) -> bool:
	if board == null:
		return false
	var inst := board.get_item(uid)
	if inst == null or not MetaState.keeps(inst.def) or _preset_uids.has(uid):
		return false     # 096：预设套的不进仓库
	var ok := InventoryService.transfer_auto(board, uid, flow.meta.warehouse)
	if ok and _warehouse_pages != null:
		_warehouse_pages.show_item(uid)     # 163：放回落到哪页就翻到哪页
	_refresh()
	return ok


## 094：现在带上的东西的总价值（预算按它算）
func carry_value() -> int:
	var v := 0
	for inst in carried():
		v += ItemValue.of(inst.def)
	return v


## 094：预算那一行。180：「带入预算 420 / 600」/「带入预算 750 / 600　超出 150 → 倒计时 −3（36 → 33）」（不写「已带」）
static func carry_text(c: ChapterDef, sid: StringName, value: int) -> String:
	var budget := CountdownModule.budget_for(c, sid)
	if budget <= 0:
		return ""
	var over := CountdownModule.over_for(c, sid, value)
	if over <= 0:
		return "[color=#5cb85c]%s[/color]" % (UiText.t("setup.budget") % [value, budget])
	var penalty := CountdownModule.penalty_for(c, sid, value)
	var base := CountdownModule.base_limit_for(c, sid)
	if base > 0 and penalty > 0:
		return "[color=#f0ad4e]%s[/color]" % (UiText.t("setup.budget_over_countdown") % [value, budget, over, penalty, base, CountdownModule.limit_for(c, sid, value)])
	return "[color=#f0ad4e]%s[/color]" % (UiText.t("setup.budget_over") % [value, budget, over])


## 现在带上的（非包；096：预设套的不算 —— 它不占预算、不受件数上限）
func carried() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if board == null:
		return out
	for inst in board.items():
		if MetaState.keeps((inst as ItemInstance).def) and not _preset_uids.has((inst as ItemInstance).uid) and not (inst as ItemInstance).is_pinned():
			out.append(inst)
	return out


func set_run_seed(v: int) -> void:
	run_seed = v
	_sync_preview()


## 能不能出发；空串 = 能，否则是原因
func can_depart() -> String:
	if chapter() == null:
		return UiText.t("setup.no_chapter")
	if needs_spawn():
		return UiText.t("notice.pick_spawn")
	var ch := character()
	if ch == null:
		return UiText.t("setup.no_character")
	var defs: Array = []
	for inst in carried():
		defs.append(inst.def)
	return ch.carry_problem(defs)


## 反馈（紧急）：左边那一列比窗口还高，原来放在列尾的「出发」按钮被挤出了屏幕，开局没有入口。
## 按钮钉在屏幕右下角（不跟着列走），又大又醒目；开不了的原因（超上限、生成不出图）也写在它上面，窗口再矮都看得见。
## 161：两颗并排 —— 「返回」（次档）与「继续 / 出发」（主档），一样大
func _build_nav() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -36
	box.offset_bottom = -36
	var row := _hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_END
	_back_btn = UiTheme.make_button(UiText.t("setup.back"), prev_page, UiTheme.TIER_PLAIN)     # 选人页 B：字号在变体里（30，仍比「出发」小）
	_back_btn.custom_minimum_size = Vector2(240, 76)
	row.add_child(_back_btn)
	_enter_btn = UiTheme.make_button(UiText.t("menu.continue"), func(): next_page(), UiTheme.TIER_PLAIN)
	_enter_btn.custom_minimum_size = Vector2(280, 76)
	row.add_child(_enter_btn)
	# 选人页 B（作者 11:56「右下角跟着更新」）：三页都用基地木键 ——「返回」浅木、「继续 / 出发」橙色主键（同基地【开始探索】）
	_back_btn.theme_type_variation = UiTheme.BUTTON_SETUP_BACK
	_enter_btn.theme_type_variation = UiTheme.BUTTON_SETUP_GO
	_back_btn.custom_minimum_size.y = NAV_BTN_H
	_enter_btn.custom_minimum_size.y = NAV_BTN_H
	box.add_child(row)
	_area.add_child(box)
	_nav_box = box
	_area.resized.connect(_fit_nav)


## 180 定稿：右下那组在第三页离地图纸右沿往左挪 [constant NAV_PAPER_GAP]（纸的左右沿在 `bg_map.json` 的 `paper_x`，按铺满裁边换到屏上）；
## 别的页（或没有那张图）离屏边 36
func _fit_nav() -> void:
	if _nav_box == null:
		return
	var right := 36.0
	var meta := UiTheme.art_meta(UiTheme.ART_SETUP_MAP_BG)
	var tex := UiTheme.art(UiTheme.ART_SETUP_MAP_BG)
	if _page == PAGE_MAP and tex != null and meta.has("paper_x") and _area.size.x > 0.0:
		var src := tex.get_size()
		var k := maxf(_area.size.x / src.x, _area.size.y / src.y)     # 铺满裁边
		var paper_right := (_area.size.x - src.x * k) * 0.5 + float(meta["paper_x"][1]) * k
		right = maxf(36.0, _area.size.x - paper_right + NAV_PAPER_GAP)
	_nav_box.offset_right = -right


## 222（作者定「出发前有提示，空手也可以进战斗」）：棋盘上一件会出手的东西都没有 —— 「出发」上面常显一句接应者的话，不拦
func unarmed() -> bool:
	return board != null and BattleCompiler.compile_board(board).active_items().is_empty()


## 226 批一：「出发」上面那句（测试看）；空串 = 没话
func status_text() -> String:
	return _status


## 那句变了：新的不空就走一次告示卷轴（出发不了的原因是要紧的），并写进「出发」的悬浮窗
func _set_status(text: String) -> void:
	if text == _status:
		return
	_status = text
	if text != "":
		if can_depart() != "":
			warn(text)
		else:
			say(text)
	if _enter_btn != null:
		_enter_btn.tooltip_text = text


## 出发。开不了（生成不出图、超上限）返回 false，留在这一屏说明原因。
## 218 补充一（作者定）：这一章配了出发前的交代、这个存档没看过 —— 先叠一层事件屏弹它，「知道了」之后才真出发（返回 true：交代弹出来了）
func depart() -> bool:
	var why := can_depart()
	if why != "":
		warn(why)
		return false
	var brief := flow.departure_briefing(chapter())
	if brief != null:
		flow.show_briefing(brief, func(): _go_now())
		return true
	return _go_now()


## 真出发：按这一页的选择开局，交给地图屏的入局转场
func _go_now() -> bool:
	if not is_inside_tree():
		return false
	var c := chapter()
	var ch := character()
	flow.map_reveal = reveal_payload()
	var run := flow.begin(c, null, run_seed, [] as Array[int], ch, RunState.layout_of(board), difficulty(), scale_id, carry_value(), spawn_id, carry_funds)
	flow.map_reveal = {}
	if run == null:
		warn(UiText.t("setup.no_map") % (c.map_source.last_error if c.map_source != null else UiText.t("setup.no_map_source")))
		return false
	flow.next_run_seed = -1     # 180：调试台指定的种子只管一局
	_remember_last(c)
	# 090：进了游戏，留在地上的就没了（带回来的棋盘 begin 里已经清掉）
	if stash != null:
		stash.clear()
	_pending.clear()
	return true


## 180 §4：交给地图屏的入局转场 —— 预览此刻的圆心（全局像素）、化开半径、圈距、环数；第三页没开着 / 没圈 = 空（不转场）。
## 182：起点是第三页此刻的样子 —— 微放大了，圈的圆心（`center`）与圈距跟着放大；墨化那片没动（`mask_center`）；另带挑的出生点与它的印记在屏上哪
func reveal_payload() -> Dictionary:
	if _preview == null or not _preview.is_visible_in_tree() or _preview.levels <= 0 or _preview.ring_gap() <= 0.0:
		return {}
	var to_global := _preview.get_global_transform()
	var out := {"center": to_global * _preview.to_view(_preview.center()), "mask_center": to_global * _preview.center(),
		"radius": _preview.radius_frac * _preview.half_extent(), "ring_gap": _preview.ring_gap() * _preview.view_zoom, "levels": _preview.levels,
		"view_zoom": _preview.view_zoom, "view_center": to_global * (_preview.center() + _preview.view_shift), "spawn_id": spawn_id}
	if spawn_id >= 0:
		out["spawn_at"] = to_global * _preview.entry_point(spawn_id)
	return out


#region 182：在纸上挑出生点
## 还得先挑出生点才能出发：预览上画着入口（第三页铺开过这张图）而还没挑
func needs_spawn() -> bool:
	return _preview != null and not _preview.entries.is_empty() and spawn_id < 0


## 挑入口 [param id]（点印记 = 调它）：挑中、以它为中心微放大、屏幕正中弹提示窗；提示窗正说着它时再点 = 关窗（挑的留着）。
## 不是纸上的入口返回 false
func pick_spawn(id: int) -> bool:
	if _preview == null or not _preview.entry_ids().has(id):
		return false
	if _hint != null and _hint.is_open() and _hint.node_id == id:
		_hint.close(_animations_on())
		return true
	spawn_id = id
	_preview.selected = id
	_preview.zoom_to(id, _animations_on())
	_show_hint(id)
	_refresh()
	return true


## 点了预览上的空白：回到不放大、关窗（挑的留着）
func _on_preview_blank() -> void:
	_preview.zoom_reset(_animations_on())
	close_hint()


func close_hint() -> void:
	if _hint != null:
		_hint.close(_animations_on())


func hint_card() -> NodeHintCard:
	return _hint


func _show_hint(id: int) -> void:
	if _hint == null:
		return
	var g := preview_graph(chapter(), scale_id)
	var type: StringName = g.get_node(id).type if g != null and g.has_node(id) else &"spawn"
	var route := _route_text(g, id)
	var title := "%s·%s" % [NodeText.label_of(type), route["name"]] if not route.is_empty() else ""
	_hint.show_for(id, type, NodeHintCard.hint_for(chapter(), type), String(route.get("text", "")), UiText.t("setup.hint_elsewhere"), _animations_on(), title)


## 提示窗第三行：这个入口的路线。作者 2026-10-17 已把路线卡（风险 / 收益）对玩家藏起来（地图屏的 `SHOW_ROUTES`），跟着它藏
## 作者 10-19：这个出生点那条路线给玩家看的名字与特点（{name, text}）；风险 / 收益的数照旧不给玩家看
func _route_text(g: MapGraph, id: int) -> Dictionary:
	if g == null:
		return {}
	for route in g.routes:
		if int(route.get("entry_id", -1)) == id:
			return RouteStyle.player_text(StringName(String(route.get("style", ""))))
	return {}


func _forget_spawn() -> void:
	spawn_id = -1
	if _preview != null:
		_preview.selected = -1
	if _hint != null:
		_hint.close(false)


## 提示窗开着时点窗外任意处（预览上的点由预览自己管）= 关窗
func _input(event: InputEvent) -> void:
	if _hint == null or not _hint.is_open() or _page != PAGE_MAP:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if _hint.get_global_rect().has_point(mb.global_position):
		return
	if _preview != null and _preview.get_global_rect().has_point(mb.global_position):
		return
	close_hint()
#endregion


## 180：记下这一局挑的图、规模、难度（下次进开局屏默认它们）
func _remember_last(c: ChapterDef) -> void:
	flow.meta.set_flag(FLAG_LAST_MAP, c.order + 1)
	var ch := character()
	flow.meta.last_character = ch.id if ch != null else &""     # 264：出征页「上回出征」写这一位
	var opts := scale_options_of(c)
	var at := -1
	for i in opts.size():
		if opts[i]["id"] == scale_id:
			at = i
	flow.meta.set_flag(FLAG_LAST_SCALE, at + 1)
	var d := difficulty()
	flow.meta.set_flag(FLAG_LAST_DIFFICULTY, d.level if d != null else 0)


## 不开了：带上的放回仓库，回基地（264 §五，作者 10-29 16:20「【返回】用于回到基地页面，而不是主菜单」；从主菜单进来的也回基地）。
## 090：上一局带回来的原样放回带回来的棋盘（视为没发生过移动）
func cancel() -> void:
	_restore_pending()
	flow.show_meta()


## 090：Esc = 第一页回基地（同「返回」按钮）。161：第二、三页的 Esc = 回上一页
func escape() -> bool:
	prev_page()
	return true
#endregion


## 棋盘上带着的都下来：仓库来的回仓库；090 地上来的回地上
func _return_carried() -> void:
	if board == null:
		return
	for inst in carried():
		board.remove(inst.uid)
		if _pending.has(inst.uid) and stash != null:
			stash.insert(inst)
		elif not flow.meta.take_back(inst):
			push_warning("setup: %s 放不回仓库，丢弃" % inst.def.id)


## 225：这块棋盘不要了（换角色、返回基地）—— 带上的先下来（[method _return_carried]），预设套与发的袋子拿掉（重摆时再发），
## 剩下的包都回包架（包里这时已经空了）
func _return_bags() -> void:
	_return_carried()
	if board == null:
		return
	_clear_preset()
	for inst in board.items():
		var it := inst as ItemInstance
		if BagRack.holds(it.def) and not board.is_bag_with_contents(it.uid):
			board.remove(it.uid)
			flow.meta.put_bag(it)


## 090：返回基地 —— 上一局带回来的（不管还在地上还是已经拖上了棋盘）按原位放回带回来的棋盘；
## 原位放不下（不该发生）就找位置，再不行进仓库。玩家已经拖进仓库的留在仓库（那是他自己置入的）
func _restore_pending() -> void:
	_return_bags()
	if stash == null:
		return
	for id in flow.meta.return_stash(stash, _pending):     # 101 第 4 刀：放回的账在 MetaState 里
		push_warning("setup: %s 放不回带回来的棋盘也放不进仓库，丢弃" % id)
	_pending.clear()


## 按角色造棋盘：初始包摆好。包的 uid 走局外的号段，免得和从仓库拖来的撞号。
## 225（补充二 §11.2）：第一次选这个角色先把初始包发进包架；再从包架把初始包摆上来（包架里有几只摆几只，拖回包架即收起）；
## 棋盘上一只包都没有、包架也空、又没挑预设 → 军需官发一只粗麻袋（[method ensure_bag]）
func _rebuild_board() -> void:
	UiTheme.clear_children(_board_host)
	if _board_view != null and _drag != null:
		_drag.unregister_view(_board_view)
	_board_view = null
	_readout = null
	board = null
	_preset_uids.clear()
	var ch := character()
	if ch == null:     # 140：没有角色就没有棋盘（左栏那条红字说明了）
		return
	if flow.meta.grant_starting_bags(ch, flow.items) > 0:
		_gifted[ch.id] = true     # 255：这一回是第一次选他 —— 右栏的「首次赠包」小签亮着
	board = GridInventory.new(ch.board_size, RunState.BOARD_ID, true)
	ch.shape_board(board, flow.items, flow.meta.allocate_uid, false)     # 255：缺格挖掉、随身之物先钉上（包绕开它们）
	board.begin_batch()
	var rack := flow.meta.rack
	for id in ch.starting_bags:
		var inst := rack.first_of(id)
		if inst == null:
			continue
		rack.remove(inst.uid)
		if not board.try_add(inst, true):
			flow.meta.put_bag(inst)
	board.end_batch()
	_note = ""
	_board_view = InventoryView.new()
	_board_view.label_font = font
	_board_view.inventory = board
	_board_view.show_adjacency = true
	_board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_board_host.add_child(_board_view)
	var frame := BoardFrame.wrap(_board_view)     # 227：皮带框 + 格缝（同背包窗），外面那块皮面板照旧
	BoardFrame.brown(_board_view)     # 作者 10-31：开局的棋盘底统一成局内背包那块棕
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER     # 255（作者 10:51）：板按九格定宽，窄的棋盘居中
	var room := BOARD_MAX_W * InventoryView.CELL + 2.0 * frame.inset()
	_board_host.custom_minimum_size.x = room
	_readout = _log_box(13)
	_readout.custom_minimum_size = Vector2(room, 48)     # 180：只两行
	_readout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_board_host.add_child(_readout)
	_drag.register_view(_board_view)
	_board_view.actions_for = item_actions.bind(_board_view)     # 230：右键 = 钉住悬浮窗，信物奉为主信仰改成按钮
	_board_view.item_double_clicked.connect(quick_move)     # 109：每次重建棋盘视图都要重新接
	board.changed.connect(_refresh)
	_apply_preset()     # 096：挑着的预设套跟着角色换过来
	ensure_bag()


## 225（§9.4 第 2 条兜底）：棋盘上一只包都没有、包架也空、又没挑预设 → 发一只粗麻袋（最差那只），状态行说「军需官发的」。
## 发了返回 true。这只袋子和预设套一样算「发的」：只在棋盘上挪、进不了包架（免得返回基地再进来白拿一只去卖），出发了就跟着走
func ensure_bag() -> bool:
	if board == null or not board.bags().is_empty() or preset() != null or flow.meta.rack.item_count() > 0:
		return false
	var def := flow.items.get_def(FALLBACK_BAG)
	if def == null:
		return false
	var inst := ItemInstance.create(def, 0)
	inst.uid = flow.meta.allocate_uid()
	if not board.try_add(inst, true):
		return false
	_preset_uids[inst.uid] = true
	_note = UiText.t("rack.granted") % Names.of(def)
	_refresh()
	return true


## 161：第一页的角色卡与棋盘预览（只看不拖）。
## 255（作者 2026-10-26 定）：卡自上而下 —— 头像 160 + 名牌（名 24、「角色」、一句角色说明）→ 面板方块一行（生命 / 耐力 / 耐力回复 / 体力必有，
## 别的面板项角色改过才出）→ 小牌一行（负重 / 棋盘（缺几格）/ 带入上限）→ 同一种条目行：技能两条 → 随身之物（有才出）→ 短板（有才出、最后；补充三起选填）。
## 右栏：只画形状的棋盘（缺格 + 随身之物，不画包）居中 → 题字「棋盘 N × M 格　可用 K 格」→ 图例（有才出）→ 首次赠包小签（第一次选他才出）
func _rebuild_card() -> void:
	if _card == null:
		return
	UiTheme.clear_children(_card)
	UiTheme.clear_children(_preview_host)
	_preview_view = null
	_preview_board = null
	_legend.clear()
	_gift_tag = null
	_stat_plate = null
	_entries.clear()
	_cap_tiles.clear()
	_skill_names.clear()
	_fit_labels.clear()
	var ch := character()
	if ch == null:
		return
	var inner := card_width()
	# 214：开局是玩家唯一盯着角色看的地方 —— 一张大头像，放在名牌左边同一行；255：名牌里不再放小头像，放回角色说明那一句
	var head := _hbox(16)
	_card.add_child(head)
	_portrait = PortraitSlot.new(CARD_PORTRAIT, Nameplate.character_face(ch.id), true)
	head.add_child(_portrait)
	# 选人页 B（作者 11:29）：铭牌只写名字 + 火漆属性（「角色」与角色说明删了，那排蜡板也并进来）
	_stat_plate = StatSealPlate.new().setup(Names.of(ch), stat_plaques(ch))
	_stat_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_stat_plate)
	# 179：图标牌；255：带入上限也并成牌，每块 ≤ 180
	var tiles := _hbox(STAT_GAP)
	_card.add_child(tiles)
	var caps := cap_tiles(ch)
	var tw := minf(TILE_MAX_W, floorf((inner - STAT_GAP * (caps.size() - 1)) / maxf(1.0, caps.size())))
	for cap in caps:
		var tile := CapTile.new().setup(cap[0], cap[1], cap[2])
		UiTheme.panel_margins(tile, UiTheme.PANEL_HOME_PLAQUE_SMALL, 16, 12, 16, 16)     # 选人页 B：小木牌底
		tile.size_flags_horizontal = Control.SIZE_FILL
		tile.custom_minimum_size.x = tw
		tiles.add_child(tile)
		_cap_tiles.append(tile)
	# 255（作者 11:07 选甲）：技能 / 随身之物 / 短板同一种行；随身之物先写功效，「拿不下、丢不掉」只作末尾灰小字；短板永远最后
	var rows := _vbox(ENTRY_GAP)
	_card.add_child(rows)
	for e in ch.skill_entries():
		var row := _entry_row(EntryIcon.skill(e.get("skill", null) as RunSkill), String(e["name"]), String(e["text"]), "", false)
		rows.add_child(row)
		_skill_names.append(row.get_meta(&"name_label"))
	for f in ch.fixed_items:
		var def := flow.items.get_def(f.id) if f != null else null
		if def != null:
			rows.add_child(_entry_row(EntryIcon.pinned(def), Names.of(def), Names.description_of(def), UiText.t("setup.pin_moves_tail" if f.movable else "setup.pinned_tail"), false))
	var flaw := ch.flaw_entry()
	if not flaw.is_empty():
		rows.add_child(_entry_row(EntryIcon.flaw(), String(flaw["name"]), String(flaw["text"]), "", true))
	_fit_card()
	_build_preview(ch)


## 258：字号放大后英文最长的卡（马库斯）顶过定高 —— 说明句、功能句、末尾小字一起一号一号缩，最小缩回小档；中文放得下不动
func _fit_card() -> void:
	var board: Control = _grooves[1]
	var shrunk := true
	while shrunk and board.get_minimum_size().y > CARD_H:
		shrunk = false
		for pair in _fit_labels:
			shrunk = TextFit.step_down(pair[0], pair[1]) or shrunk


## 255：条目行 —— 左端 52 图标槽，右边名字（22，技能 / 随身之物亮黄铜、短板 [param iron] 铁灰）+ 一句功能句（17）+ 末尾灰小字 [param tail]（有才出）
func _entry_row(icon: EntryIcon, title: String, text: String, tail: String, iron: bool) -> HBoxContainer:
	var row := _hbox(12)
	row.add_child(icon)
	var col := _vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := UiTheme.make_variant_label(title, UiTheme.LABEL_FLAW_NAME if iron else UiTheme.LABEL_SKILL_NAME)
	col.add_child(name)
	row.set_meta(&"name_label", name)
	if text != "":
		var body := _wrapped(text, UiTheme.SKILL_TEXT_SIZE, UiPalette.FG, card_width() - EntryIcon.SIDE - 12)
		body.theme_type_variation = UiTheme.LABEL_SKILL_TEXT
		_fit_labels.append([body, UiTheme.SKILL_TEXT_SIZE])
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(body)
	if tail != "":
		var tail_label := _label(tail, ENTRY_TAIL_SIZE, UiPalette.DIM)
		col.add_child(tail_label)
		_fit_labels.append([tail_label, ENTRY_TAIL_SIZE])
	_entries.append(row)
	return row


## 255：右栏 —— 只画形状的棋盘（缺格 + 随身之物，不画包），居中；下面题字、图例、首次赠包小签
func _build_preview(ch: CharacterDef) -> void:
	_grooves[2].custom_minimum_size.x = right_width()
	_preview_board = GridInventory.new(ch.board_size, RunState.BOARD_ID, true)
	ch.shape_board(_preview_board, flow.items, Callable(), false)
	_preview_view = InventoryView.new()
	_preview_view.label_font = font
	_preview_view.inventory = _preview_board
	_preview_view.show_adjacency = false
	_preview_host.add_child(_preview_view)     # 179：底下不再列有哪些背包
	var frame := BoardFrame.wrap(_preview_view)     # 227：皮带框 + 格缝；255：有缺格时框沿轮廓走
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER     # 255：不足九格居中，差额是左右内距
	var counts := ch.board_counts(flow.items)
	# 作者 10-31（奥卡姆剃刀）：棋盘画出来了，「棋盘 N × M 格」那行字删了
	var legend := _hbox(10)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	if int(counts["missing"]) > 0:
		legend.add_child(_legend_tag(UiText.t("setup.legend_missing"), Color(0, 0, 0, 0)))
	if int(counts["pinned"]) > 0:
		legend.add_child(_legend_tag(UiText.t("setup.legend_pinned"), Color("c9a24e")))
	if legend.get_child_count() > 0:
		_preview_host.add_child(legend)
	else:
		legend.free()
	var gift := first_gift_text(ch)
	if gift != "" and _gifted.has(ch.id):
		_gift_tag = GiftTag.make(gift, right_width() - 2.0 * RIGHT_PAD)
		_gift_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_preview_host.add_child(_gift_tag)


## 255：图例一枚小签（色块 + 字），坐在小牌底上
func _legend_tag(text: String, swatch: Color) -> PanelContainer:
	var tag := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_HOME_CHIP, 10, 4, 10, 4)
	var row := _hbox(6)
	tag.add_child(row)
	var box := ColorRect.new()
	box.color = swatch
	box.custom_minimum_size = Vector2(14, 14)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.draw.connect(func(): box.draw_rect(Rect2(Vector2.ZERO, box.size).grow(-0.5), UiPalette.DIM, false, 1.0))
	row.add_child(box)
	row.add_child(_label(text, 13, UiPalette.FG))
	_legend.append(tag)
	return tag


## 255：首次赠包那一句（「首次选他：皮革包 ×1、小包 ×1 进包架」）；没有初始包空串
func first_gift_text(ch: CharacterDef) -> String:
	var counts := {}
	var order: Array[StringName] = []
	for id in ch.starting_bags:
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	var parts: Array[String] = []
	for id in order:
		var def := flow.items.get_def(id)
		if def != null:
			parts.append(UiText.t("setup.gift_item") % [Names.of(def), int(counts[id])])
	return UiText.t("setup.first_gift") % UiText.t("setup.list_sep").join(parts) if not parts.is_empty() else ""


## 255：面板项 [名, 数, 火漆图名]：生命 / 耐力 / 耐力回复 / 体力必有（各有火漆，[constant STAT_SEALS]）；别的面板项角色在 base_stats 里改过才出，没有专属火漆
static func stat_plaques(ch: CharacterDef) -> Array:
	var base := ch.baseline()
	var out: Array = [
		[UiText.t("setup.stat_hp"), _num(base.value_of(&"max_hp")), STAT_SEALS[0]],
		[UiText.t("setup.stat_stamina"), _num(base.value_of(&"max_stamina")), STAT_SEALS[1]],
		[UiText.t("setup.stat_regen"), UiText.t("setup.per_sec") % _num(base.value_of(&"regen_stamina")), STAT_SEALS[2]],
		[UiText.t("setup.stat_vitality"), str(ch.vitality_max), STAT_SEALS[3]],
	]
	for key in ch.base_stats:
		var k := StringName(String(key))
		if k in [&"max_hp", &"max_stamina", &"regen_stamina"]:
			continue
		out.append([Glossary.stat_name(k), _num(base.value_of(k)), ""])
	return out


## 179：图标牌 [id, 数字, 说明]：负重上限（有才有）、棋盘；255：缺格写进棋盘那块的说明，带入件数 / 稀有度上限有才有
## 2026-10-22（作者定）：**开局金币那块不再显示** —— 钱改成玩家自己从仓库带了，角色身上这个数不再有任何作用
static func cap_tiles(ch: CharacterDef) -> Array:
	var out: Array = []
	if ch.weight_capacity > 0:
		out.append([&"weight", str(ch.weight_capacity), UiText.t("setup.cap_load")])
	out.append([&"board", "%d × %d" % [ch.board_size.x, ch.board_size.y],
		UiText.t("setup.cap_board_missing") % ch.board_mask.size() if not ch.board_mask.is_empty() else UiText.t("setup.cap_board")])
	if ch.carry_max_items >= 0:
		out.append([&"carry", str(ch.carry_max_items), UiText.t("setup.cap_carry")])
	if ch.carry_rarity_cap >= 0:
		out.append([&"rarity", str(ch.carry_rarity_cap), UiText.t("setup.cap_rarity")])
	return out


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## 161：第三页右上那一块。180 补二（作者 10:09）：只写角色名
func summary_text() -> String:
	var ch := character()
	return Names.of(ch) if ch != null else ""


## 099（作者定）：右键棋盘上的信物 = 奉它为主信仰（出发带走的就是这个顺序）。不是信物什么也不做
func reseat_anchor(uid: int) -> bool:
	var inst := board.get_item(uid) if board != null else null
	if inst == null or inst.def == null or not inst.def.is_anchor():
		return false
	return board.reseat(uid)


func _refresh() -> void:
	var c := chapter()
	var ch := character()
	if _readout != null and board != null:
		# 180（作者定）：棋盘下只留两行 —— 负重、带入预算
		_readout.clear()
		var lines: Array[String] = []
		var enc_line := encumbrance_text()
		if enc_line != "":
			lines.append(enc_line)
		if c != null and CountdownModule.budget_for(c, scale_id) > 0:
			lines.append(carry_text(c, scale_id, carry_value()))
		_readout.append_text("\n".join(lines))
	_sync_stash_tab()
	if _summary != null:
		_summary.text = summary_text()
	if _enter_btn != null:
		_enter_btn.disabled = (_page == 0 and ch == null) or (_page == PAGE_MAP and needs_spawn())     # 182：没挑出生点「出发」灰着
	var why := can_depart()
	var hint := UiText.t("setup.unarmed") if _page > 0 and unarmed() else ""
	_set_status(why if why != "" and not carried().is_empty() else _note + hint)     # 225：「军需官发的」在前
	_refresh_cash()     # 2026-10-22：仓库的钱可能刚变过（卖了东西 / 换了角色）
