## 开局（M6，架构文档 8 节；058 第 2 条，报告 067）：挑一章、挑角色、往初始包里拖仓库的东西、定个种子，出发。
##
## 161（作者定）：拆成三页，一次只看一页、状态都在屏的字段里（换页不丢）：
## **一 选角色**（角色列表、角色卡 —— 名牌 + 生命 / 耐力方块 + 体力爱心 + 技能、这个角色的棋盘预览只看不拖）→
## **二 配道具**（预设装备、可拖的棋盘、地上、仓库 —— 仓库只在这一页）→ **三 选地图与难度**（模式、规模、难度、种子、出发摘要）。
## 180（作者 2026-10-17）：第三页改成 左 地图（一级）与规模（二级，选中的图下面展开）| 中 化开的地图预览（[MapPreview]）|
## 右 出发摘要 + 当前难度（〇级收成「开启挑战」铜牌；大字数字、加减两颗键、每升一级红字列出这一级的挑战）。序章不进列表（只出现一次），种子玩家看不见
## （进第三页随机取；调试台能指定下一局的，[member GameFlow.next_run_seed]）；上次挑的图、规模、难度记在局外旗标里，下次默认它们
## 每页右下角两颗大按钮：继续 / 出发（Enter）、返回（Esc；第一页的返回 = 回主菜单）。[method page] / [method next_page] / [method prev_page]。
##
## 第二页：中间是这个角色的棋盘（初始包已经摆好），右边是仓库的格子：从仓库往包里拖，**放得进的就是带的** ——
## 带入的真正限制是初始包的空间；件数 / 稀有度上限是角色的字段（默认不限），出发时查。
## 包不能带入：仓库里本来没有包（局外只收非包，`MetaState.keeps`），仓库的格子也不收包（同一条规则接在 `accept_filter` 上）。
## 拖上棋盘那一刻东西就离开了仓库；出发时存 meta，回主菜单就放回去。
## 所有动作都是公开方法（[method choose_chapter]、[method choose_character]、[method carry_in]、[method store]、[method depart]、[method cancel]），按钮只是调它们；测试直接调。
##
## **地上**（090，作者定）：上一局带回来、还没置入的东西（`MetaState.board`）进这一屏时挪进中间的地上（记住各自原位）。
## 往包里拖 = 带上、往仓库拖 = 置入、留着的**出发就没了**；回主菜单则原样放回带回来的棋盘（视为没发生过移动）。
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
var run_seed: int = 1
## 这个角色的棋盘，初始包摆好；从仓库拖进来的东西就在上面。出发时整块记成 layout 交给 RunState
var board: GridInventory = null
## 090：地上 —— 上一局带回来、还没置入的东西
var stash: ItemStash = null
## 090：地上那些东西的来处：uid → {"origin", "rot"}（回主菜单按原位放回）
var _pending: Dictionary = {}
var _stash_box: VBoxContainer = null
var _stash_view: GroundLayer = null
var _stash_title: Label = null

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
var _readout: RichTextLabel = null
var _status: Label
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
const BACK_FONT := 28
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
const MAP_SUB_H := 44.0
const NAV_BTN_H := 84.0
const NAV_PAPER_GAP := 60.0
## 第三页的左右两列离屏边再让多少（地图纸的毛边）
const PAPER_INSET := 36
var _pages: Array[Control] = []
var _page: int = 0
var _title: Label = null
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
## 179：右栏的凹槽板内边距（右栏宽 = 这个角色的棋盘宽 + 两边内边距，贴右边；中栏吃掉剩下的）
const RIGHT_PAD := 10
## 三页各自的整屏画（作者 2026-10-17）：选角色 = 选人场地，带装备 = 木板拼接 / 仓库，选地图 = 桌上的军用地图
const PAGE_ART: Array[String] = [UiTheme.ART_SETUP_BG, UiTheme.ART_SETUP_KIT_BG, UiTheme.ART_SETUP_MAP_BG]


func open(_payload: Dictionary) -> void:
	_backdrop()
	_reroll_seed()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, PAGE_MARGIN)
	margin.add_theme_constant_override("margin_bottom", NAV_ROOM)     # 161：底下留给右下角那两颗大按钮
	_area = _painted_screen(PAGE_ART[0])     # 179：整屏一幅画（157 补充三的整块石板不要了），各块内容坐凹槽板；翻页换画（[constant PAGE_ART]）
	_area.add_child(margin)
	var col := _vbox(PAGE_SEP)
	margin.add_child(col)
	_title = UiTheme.make_variant_label("", UiTheme.LABEL_SCREEN_TITLE)     # 179：直接写在背景画上 —— 深底白字带阴影，浅底（白天的场地）墨字
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


## 161 第一页：角色列表 | 角色卡 | 棋盘预览（只看不拖）。
## 179：三栏各坐一块凹槽板、间距 36；中栏撑满左右两栏之间，右栏（棋盘）贴右边
func _build_character_page() -> Control:
	var row := _hbox(36)
	_grooves.clear()
	var left_board := _groove(14, 10, 14, 10)
	left_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(left_board)
	var left := _vbox(8)
	left.custom_minimum_size.x = 260 - 28
	left_board.add_child(left)
	left.add_child(_label(UiText.t("setup.characters"), 15, UiPalette.DIM))
	_char_box = _vbox(8)
	left.add_child(_char_box)
	if flow.characters.is_empty():
		left.add_child(_label(UiText.t("setup.no_characters"), 13, UiPalette.HP))
	var mid_board := _groove(30, 24, 30, 28)
	mid_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mid_board)
	_card = _vbox(14)
	_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_board.add_child(_card)
	var right_board := _groove(RIGHT_PAD, RIGHT_PAD, RIGHT_PAD, RIGHT_PAD)
	right_board.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(right_board)
	_preview_host = _vbox(6)
	right_board.add_child(_preview_host)
	_grooves.append_array([left_board, mid_board, right_board])
	return row



## 161 第二页：预设装备一行 + 棋盘（可拖）/ 地上 / 仓库，拖拽层盖在下面那一块上
## 180 补二（作者 10:09）：左 行囊板（预设、棋盘、两行读数）| 中 地上 | 右 仓库框。仓库框按自己的内容定大小、不和左边棋盘对齐，
## 包住页签、格子和右边预留的滚动条位（格子多到一屏放不下时竖着滚）；两块板各按内容高、顶边对齐
func _build_kit_page() -> Control:
	# 拖拽层盖在整行上（两块板和中间的地上）
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
		var presets := _hbox(8)
		presets.add_child(_label(UiText.t("setup.presets"), 15, UiPalette.DIM))
		_preset_box = presets
		left.add_child(presets)
		_rebuild_presets()
	_board_host = _vbox(6)
	left.add_child(_board_host)

	# 090：中间是地上（有上一局带回来的东西才显示）；没有也占着中间，把仓库框推到右边
	var middle := _vbox(0)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	_stash_box = _vbox(6)
	middle.add_child(_stash_box)

	var ware_panel := _framed(UiTheme.PANEL_STASH_FRAME, UiTheme.ART_STASH_FRAME, FRAME_INSET)     # 180 定稿：木框铁角的仓库框
	ware_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ware_panel)
	_warehouse_box = ware_panel
	var right := _vbox(6)
	ware_panel.add_child(right)
	var w := flow.meta.warehouse
	right.add_child(_label(UiText.t("setup.warehouse_pages") % w.page_count(), 15, UiPalette.DIM))     # 180：件数与那句「往左边的包里拖……」都不要

	_drag = DragLayer.new()
	_drag.label_font = font
	# 163：仓库分页 —— 左边竖排页签，拖着东西停在页签上切页
	_warehouse_scroll = ScrollContainer.new()
	_warehouse_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_warehouse_scroll)
	_warehouse_pages = WarehousePages.new()
	if UiTheme.has_setup_art(UiTheme.ART_SETUP_TAB):     # 180 定稿：挂牌页签
		_warehouse_pages.tab_variation = UiTheme.BUTTON_SETUP_TAB
		_warehouse_pages.tab_height = TAB_TAG_H
	_warehouse_scroll.add_child(_warehouse_pages)
	_warehouse_pages.setup(w, font, _drag, TechWarehousePages.plan_of(flow.tech_defs))
	_warehouse_view = _warehouse_pages.view
	play.add_child(_drag)     # 容器把它铺到和整行一样大，盖在两块板上
	_drag.register_view(_warehouse_view)
	_warehouse_view.item_double_clicked.connect(quick_move)     # 109：双击 = 快速置入，和局内一样
	w.changed.connect(_refresh)
	_warehouse_pages.minimum_size_changed.connect(_fit_warehouse)
	_area.resized.connect(_fit_warehouse)
	_fit_warehouse()
	_build_stash()
	return play


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
	if not _paper_art():     # 定稿：摆在纸上的地图条目自己带钉，不要小标题
		left.add_child(_label(UiText.t("setup.maps"), 15, UiPalette.DIM))
	_map_list = _vbox(6)
	left.add_child(_map_list)
	if _chapters.is_empty():
		left.add_child(_label(UiText.t("setup.no_chapters"), 13, UiPalette.HP))

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
	var tone := _repaint(PAGE_ART[_page])
	if _title_indent != null:
		_title_indent.custom_minimum_size.x = PAPER_INSET if _page == PAGE_MAP and _paper_art() else 0.0
	if _title != null:
		_title.text = UiText.t(PAGE_TITLES[_page])
		UiTheme.set_tone(_title, tone)
	if _enter_btn != null:
		_enter_btn.text = UiText.t("setup.depart") if _page == PAGE_TITLES.size() - 1 else UiText.t("menu.continue")
	if _back_btn != null:
		_back_btn.text = UiText.t("setup.main_menu") if _page == 0 else UiText.t("setup.back")
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


## 返回（第一页 = 回主菜单）
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


## 090：地上那一栏。上一局带回来、还没置入的东西从带回来的棋盘挪进来，记住各自原位（回主菜单原样放回）
func _build_stash() -> void:
	stash = ItemStash.new(STASH_ID, 0)
	_pending = flow.meta.take_board_to_stash(stash)     # 101 第 4 刀：挪与记原位的账在 MetaState 里
	_stash_title = _label("", 15, UiPalette.DIM)
	_stash_box.add_child(_stash_title)
	_stash_view = GroundLayer.new()     # 128：一块地，放手在哪就落在哪
	_stash_view.label_font = font
	_stash_view.custom_minimum_size = Vector2(240, 320)
	_stash_view.stash = stash
	_stash_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stash_box.add_child(_stash_view)
	_drag.register_view(_stash_view)
	_stash_view.item_double_clicked.connect(quick_move)
	_drag.drop_filter = _allow_drop
	stash.changed.connect(_refresh)
	_stash_box.visible = not _pending.is_empty()


## 090：落点规则。仓库的东西进不了地上（进去就等于出发时丢掉）；地上的东西上棋盘要这一章允许带入
func _allow_drop(inst: ItemInstance, target: ItemContainer) -> bool:
	if inst == null:
		return false
	if target == stash:
		return _pending.has(inst.uid)
	if target == board and _pending.has(inst.uid):
		var c := chapter()
		return c == null or c.allow_carry_in
	if _preset_uids.has(inst.uid) and target != board:
		return false     # 096：预设套的东西只能在棋盘上挪，进不了仓库 / 地上
	return true


## 一列单选按钮（章节 / 难度 / 角色 / 预设 / 规模各一列）：每个名字一个左对齐的按钮，按下调 `on_pick(序号)`；
## 选中的是哪个由 [method _mark_choice] 标。返回这一列的按钮，顺序同 [param names]
func _choice_column(box: Control, names: Array[String], on_pick: Callable, size: int = 14) -> Array[Button]:
	var btns: Array[Button] = []
	for i in names.size():
		var idx := i
		var b := _button(names[i], func(): on_pick.call(idx), size)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btns.append(b)
		box.add_child(b)
	return btns


## 121：一列里第 [param index] 个是选中的（前景色），其余暗色（[method UiTheme.mark]）
func _mark_choice(btns: Array, index: int) -> void:
	for k in btns.size():
		UiTheme.mark(btns[k], k == index)


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
		names.append(Names.of(ch) if ch.display_name != "" else String(ch.id))
	_character_btns = _choice_column(_char_box, names, choose_character)


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
	_preset_btns = _choice_column(_preset_box, names, func(i: int): choose_preset(i - 1))     # 第 0 个是「不带」
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
	if not missed.is_empty() and _status != null:
		_status.text = UiText.t("setup.preset_missed") % UiText.t("setup.list_sep").join(missed)


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
	_return_carried()
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
	var cap := RunBuffs.context(defs).carry_capacity_of(ch.weight_capacity)     # 149：科技按百分比
	var w := ItemWeight.total(board)
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
	if flow.meta.warehouse.owns(from) or from == stash:
		if board == null:
			return false
		if not _allow_drop(inst, board):
			why = UiText.t("setup.no_brought_back")
		else:
			ok = carry_in(uid)
			why = "" if ok else UiText.t("setup.no_room_bag") % Names.of(inst.def)
	elif from == board:
		if not MetaState.keeps(inst.def):
			why = UiText.t("setup.starting_bag") % Names.of(inst.def)
		elif _preset_uids.has(uid):
			why = UiText.t("setup.preset_stays")
		else:
			ok = carry_out(uid)
			why = "" if ok else UiText.t("setup.no_room_warehouse") % Names.of(inst.def)
	if why != "" and _status != null:
		_status.text = why
	return ok


## 090：把地上的一件收进仓库（= 置入）。放不下返回 false
func store(uid: int) -> bool:
	if stash == null or stash.get_item(uid) == null:
		return false
	var ok := InventoryService.transfer_auto(stash, uid, flow.meta.warehouse)
	if ok and _warehouse_pages != null:
		_warehouse_pages.show_item(uid)
	_refresh()
	return ok


## 把棋盘上的一件放回仓库。包不行（它是初始包，不是仓库的东西）
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
		if MetaState.keeps((inst as ItemInstance).def) and not _preset_uids.has((inst as ItemInstance).uid):
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
	_status = _wrapped("", 13, UiPalette.HP, 520)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_status)
	var row := _hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_END
	_back_btn = _button(UiText.t("setup.back"), prev_page, BACK_FONT, UiPalette.Tier.MINOR)     # 180 补二：大两号，仍比「出发」小
	_back_btn.custom_minimum_size = Vector2(240, 76)
	row.add_child(_back_btn)
	_enter_btn = _button(UiText.t("menu.continue"), func(): next_page(), 24, UiPalette.Tier.PRIMARY)
	_enter_btn.custom_minimum_size = Vector2(280, 76)
	row.add_child(_enter_btn)
	# 180 定稿：按钮 A 套 ——「返回」深色铜铸牌、「继续 / 出发」亮黄铜（各四态图）
	if UiTheme.has_setup_art(UiTheme.ART_SETUP_GO):
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


## 出发。开不了（生成不出图、超上限）返回 false，留在这一屏说明原因。
## 218 补充一（作者定）：这一章配了出发前的交代、这个存档没看过 —— 先叠一层事件屏弹它，「知道了」之后才真出发（返回 true：交代弹出来了）
func depart() -> bool:
	var why := can_depart()
	if why != "":
		_status.text = why
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
	var run := flow.begin(c, null, run_seed, [] as Array[int], ch, RunState.layout_of(board), difficulty(), scale_id, carry_value(), spawn_id)
	flow.map_reveal = {}
	if run == null:
		_status.text = UiText.t("setup.no_map") % (c.map_source.last_error if c.map_source != null else UiText.t("setup.no_map_source"))
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
	var opts := scale_options_of(c)
	var at := -1
	for i in opts.size():
		if opts[i]["id"] == scale_id:
			at = i
	flow.meta.set_flag(FLAG_LAST_SCALE, at + 1)
	var d := difficulty()
	flow.meta.set_flag(FLAG_LAST_DIFFICULTY, d.level if d != null else 0)


## 不开了：带上的放回仓库，回主菜单。090：上一局带回来的原样放回带回来的棋盘（视为没发生过移动）
func cancel() -> void:
	_restore_pending()
	flow.to_main_menu()


## 090：Esc = 回主菜单（同「回主菜单」按钮）。161：第二、三页的 Esc = 回上一页
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


## 090：回主菜单 —— 上一局带回来的（不管还在地上还是已经拖上了棋盘）按原位放回带回来的棋盘；
## 原位放不下（不该发生）就找位置，再不行进仓库。玩家已经拖进仓库的留在仓库（那是他自己置入的）
func _restore_pending() -> void:
	_return_carried()
	if stash == null:
		return
	for id in flow.meta.return_stash(stash, _pending):     # 101 第 4 刀：放回的账在 MetaState 里
		push_warning("setup: %s 放不回带回来的棋盘也放不进仓库，丢弃" % id)
	_pending.clear()


## 按角色造棋盘：初始包摆好。包的 uid 走局外的号段，免得和从仓库拖来的撞号
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
	board = GridInventory.new(ch.board_size, RunState.BOARD_ID, true)
	board.begin_batch()
	for id in ch.starting_bags:
		var def := flow.items.get_def(id)
		if def == null:
			continue
		var inst := ItemInstance.create(def, 0)
		inst.uid = flow.meta.allocate_uid()
		board.try_add(inst, true)
	board.end_batch()
	_board_host.add_child(_label(UiText.t("setup.pack_title") % [Names.of(ch), ch.board_size.x, ch.board_size.y], 15, UiPalette.DIM))     # 180
	_board_view = InventoryView.new()
	_board_view.label_font = font
	_board_view.inventory = board
	_board_view.show_adjacency = true
	_board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_board_host.add_child(_board_view)
	_readout = _log_box(13)
	_readout.custom_minimum_size = Vector2(ch.board_size.x * InventoryView.CELL, 48)     # 180：只两行
	_readout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_board_host.add_child(_readout)
	_drag.register_view(_board_view)
	_board_view.item_context.connect(func(_v: ContainerView, uid: int): reseat_anchor(uid))     # 099：开局屏的棋盘同一套
	_board_view.item_double_clicked.connect(quick_move)     # 109：每次重建棋盘视图都要重新接
	board.changed.connect(_refresh)
	_apply_preset()     # 096：挑着的预设套跟着角色换过来


## 161：第一页的角色卡（名牌、生命 / 耐力方块、体力爱心、技能）与棋盘预览（只看不拖）
func _rebuild_card() -> void:
	if _card == null:
		return
	UiTheme.clear_children(_card)
	UiTheme.clear_children(_preview_host)
	_preview_view = null
	var ch := character()
	if ch == null:
		return
	# 179：角色说明不放在这一屏（字段留着给图鉴 / 帮助）
	# 214：开局是玩家唯一盯着角色看的地方 —— 一张大头像（同一张源图缩放），换角色跟着换。
	# 放在铭牌左边同一行（放铭牌上方整张卡要高 170，1600×1000 下卡底压到「回主菜单」）
	var head := _hbox(16)
	_card.add_child(head)
	_portrait = PortraitSlot.new(CARD_PORTRAIT, Nameplate.character_face(ch.id), true)
	head.add_child(_portrait)
	var plate := Nameplate.new().setup(Names.of(ch), UiText.t("setup.character"), Nameplate.character_face(ch.id))
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(plate)
	var base := ch.baseline()
	_card.add_child(_stat_row(UiText.t("setup.stat_hp"), StatBlocks.new().setup(StatBlocks.HP, base.value_of(&"max_hp"))))
	var stamina := _stat_row(UiText.t("setup.stat_stamina"), StatBlocks.new().setup(StatBlocks.STAMINA, base.value_of(&"max_stamina")))
	stamina.add_child(_label(UiText.t("setup.stamina_regen") % _num(base.value_of(&"regen_stamina")), 14, UiPalette.DIM))     # 161 待定 1：三人唯一不同的第三个数
	_card.add_child(stamina)
	_card.add_child(_stat_row(UiText.t("setup.stat_vitality"), StatBlocks.new().setup(StatBlocks.VITALITY, ch.vitality_max)))
	_card.add_child(_label(UiText.t("setup.block_note"), 12, UiPalette.DIM))
	# 179：负重上限 / 棋盘 / 开局金币换成三块图标牌；带入上限（有才有）仍是牌下一行字
	_cap_tiles.clear()
	var tiles := _hbox(14)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.add_child(tiles)
	for cap in cap_tiles(ch):
		var tile := CapTile.new().setup(cap[0], cap[1], cap[2])
		tiles.add_child(tile)
		_cap_tiles.append(tile)
	var extra := carry_caps_text(ch)
	if extra != "":
		_card.add_child(_label(extra, 13, UiPalette.DIM))
	# 179：技能两行 —— 名字（22 粗体、亮黄铜、黑描边；不写「被动」）；说明 17 正文色
	_skill_names.clear()
	var skills := _vbox(12)
	_card.add_child(skills)
	for e in ch.skill_entries():
		var one := _vbox(4)
		skills.add_child(one)
		var name := UiTheme.make_variant_label(String(e["name"]), UiTheme.LABEL_SKILL_NAME)
		one.add_child(name)
		_skill_names.append(name)
		var text := _wrapped(String(e["text"]), UiTheme.SKILL_TEXT_SIZE, UiPalette.FG, 300)
		text.theme_type_variation = UiTheme.LABEL_SKILL_TEXT
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		one.add_child(text)
	if board == null:
		return
	_grooves[2].custom_minimum_size.x = ch.board_size.x * InventoryView.CELL + 2 * RIGHT_PAD
	_preview_host.add_child(_label(UiText.t("setup.board_title") % [ch.board_size.x, ch.board_size.y], 15, UiPalette.DIM))
	_preview_view = InventoryView.new()
	_preview_view.label_font = font
	_preview_view.inventory = board
	_preview_view.show_adjacency = false
	_preview_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_preview_host.add_child(_preview_view)     # 179：底下不再列有哪些背包


## 179：三块图标牌 [id, 数字, 说明]：负重上限（有才有）、棋盘、开局金币（有才有）
static func cap_tiles(ch: CharacterDef) -> Array:
	var out: Array = []
	if ch.weight_capacity > 0:
		out.append([&"weight", str(ch.weight_capacity), UiText.t("setup.cap_load")])
	out.append([&"board", "%d × %d" % [ch.board_size.x, ch.board_size.y], UiText.t("setup.cap_board")])
	if ch.starting_funds >= 0:
		out.append([&"coin", str(ch.starting_funds), UiText.t("setup.cap_coins")])
	return out


## 179：图标牌之外的带入上限（最多带 N 件、稀有度不超过 N），有才写
static func carry_caps_text(ch: CharacterDef) -> String:
	var caps: Array[String] = []
	if ch.carry_max_items >= 0:
		caps.append(UiText.t("setup.carry_max") % ch.carry_max_items)
	if ch.carry_rarity_cap >= 0:
		caps.append(UiText.t("setup.carry_rarity") % ch.carry_rarity_cap)
	return UiText.t("setup.sep").join(caps)


func _stat_row(title: String, blocks: StatBlocks) -> HBoxContainer:
	var row := _hbox(10)
	var l := _label(title, 17, UiPalette.FG)
	l.custom_minimum_size.x = 48
	row.add_child(l)
	row.add_child(blocks)
	return row


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
	if _stash_title != null and stash != null:
		_stash_title.text = UiText.t("setup.ground_count") % stash.item_count()
	if _summary != null:
		_summary.text = summary_text()
	if _enter_btn != null:
		_enter_btn.disabled = (_page == 0 and ch == null) or (_page == PAGE_MAP and needs_spawn())     # 182：没挑出生点「出发」灰着
	if _status != null:
		var why := can_depart()
		_status.text = why if why != "" and not carried().is_empty() else (UiText.t("setup.unarmed") if _page > 0 and unarmed() else "")
