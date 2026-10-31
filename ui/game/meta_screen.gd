## 局外 / 基地（M6，架构文档 8.2；058 第 4 / 7 条）：页签（088 作者定）—— **仓库**（格子、带回来还没清空的背包）与**图鉴**（带出过的道具点亮、
## 记累计件数，停上去看属性；特殊道具另列），后来又加了成就、出售、科技。
## 139（作者定）：开发开关、局外解锁、科技等级、最近几局收进「调试台」抽屉（[DevDrawer]，箭头在右上角）。
## 带回来的背包没清空之前「再来一局」是灰的（作者：提示玩家清空背包再配置）。
##
## 164（作者定）：三列 —— 左列（[constant LEFT_W]）：「基地」、四个页签竖排（图鉴、成就、出售、科技；再点一次选中的回「家」），
## 左下角「再来一局」（主档）与「回主菜单」；中列：当前页，默认「家」（这一局、战绩、带回来的背包与一键置入 / 整理）；
## 右半边：仓库（163 的 [WarehousePages]）常驻，10 × 8 整块可见（格子按宽高取小，40 ～ 80）。双击仓库一件按当前页：家 → 置入带回来的背包、
## 出售 → 卖、科技 → 上交、图鉴 / 成就 → 不做事。整屏一层拖拽，中列与右半边之间能拖。背景、按钮、文本框、仓库木架用「家」套件（`assets/ui/home/`）
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")
const TechPanelScript := preload("res://ui/game/tech_panel.gd")
const MarketPanelScript := preload("res://ui/game/market_panel.gd")     # 251
const SmithyPanelScript := preload("res://ui/game/smithy_panel.gd")     # 251
## 图鉴缩略图之间的空隙；一行几个按宽度算（139）
const CODEX_GAP := 8
## 左列宽、整屏外边距、三列之间的空
const LEFT_W := 220.0
const MARGIN := 24.0
const COL_GAP := 24.0
## 右半边标题行的高（「仓库　N 件」与调试台箭头）
const SHELF_HEAD := 44.0
## 仓库分页签（挂牌）多高，同开局屏第二页
const SHELF_TAB_H := 60.0
## 基地页签字左边的图标（`home/tabs/tab_<页签名>`，36 × 36 墨色剪影；没图就只有字）
const TAB_ICON_ART := "home/tabs/tab_"
## 左列五个页签（页签名、字）；「家」不在里面 —— 再点一次选中的页签回家。
## 178（作者 2026-10-16，待定 1 选 A）：加「仓库」，顺序 仓库 / 出售 / 科技 / 图鉴 / 成就 —— 右半边有仓库的三页挨着
## 262（作者 14:19）：集市、铁匠铺默认就有，和出售并成「后勤」一页；261 补充一（作者 16:37）：科技并进书架 —— 左列只剩 仓库 / 后勤 / 书架
## 264（作者 16:43「按推荐来」）：加「出征」放第一、默认选中（军功碑 + 上回出征 + 军需 + 【开始探索】），「家」页没了 —— 页签单选
const TABS := [["expedition", "meta.tab_expedition"], ["warehouse", "meta.tab_warehouse"], ["logistics", "meta.tab_logistics"], ["shelf", "meta.tab_shelf"]]
## 262（待定 1 选 A 左列折叠）：「后勤」选中时页签底下滑出缩进的小键（268：出售页删了，只剩集市 / 铁匠铺两颗）（分页名、字）；三页本身一个像素不动。
## 264 §四：「书架」也一样滑出五颗（书架格的顺序，油灯那格没有键）—— 点一颗 = 书架页 + 开那扇窗，窗开着那颗按下
const SUB_TABS := {
	"logistics": [["market", "market.title"], ["smithy", "smithy.title"]],
	"shelf": [["codex", "meta.sub_codex"], ["records", "meta.sub_records"], ["keepsakes", "meta.sub_keepsakes"], ["achievements", "meta.sub_achievements"], ["tech", "meta.sub_tech"]],
}
const SUB_TAB_SIZE := Vector2(170, 44)
const SUB_TAB_FONT := 17
const SUB_TAB_INDENT := 28
## 178：这几页不显示右半边的仓库，中列吃满。264：出征页也收起 —— 碑 + 560 宽的两块木牌要 1308 宽的中列（露着仓库中列只剩 508）
const NO_SHELF_TABS := ["shelf", "expedition"]
## 261（作者 14:13）：「图鉴」页签改「书架」—— 两层三格，点开各一扇窗；补充一（作者 16:37）：上 图鉴 / 对局记录 / 特殊道具，
## 下 成就 / 科技（科技页签并进来）/ 油灯静物（墨水瓶去掉）
const SHELF_CELLS := ["codex", "records", "keepsakes", "achievements", "tech", ""]
const SHELF_WIN := Vector2(1100, 820)
## 261 补充一：科技窗要宽一些 —— 科技页最窄约 1190 × 660（羊皮 MIN_SCALE 0.9 + 右边说明板），1100 × 820 装不下
const SHELF_WIN_WIDE := Vector2(1320, 900)
## 251 补充二 §12.1（作者 10-25 14:20「集市里不需要显示仓库，铁匠铺里也不需要」）：整页的两页 —— 右列（仓库木架 + 挂牌）收起、中列吃满。
## 只是藏：仓库视图照旧在，买下 / 打好的照样进仓库
const FULL_TABS := ["market", "smithy"]
## 264 §三（作者 17:01 定稿）：集市 / 铁匠铺两页换整屏背景（`market/scene`、`smithy/scene`，cover），别的页回基地底图；换时淡入淡出 [constant SCENE_FADE] 秒。
## 有场景图的这两页不垫粗布
const SCENES := {"market": "market/scene", "smithy": "smithy/scene"}
const SCENE_FADE := 0.25

var _wh = null
## 260：出征页（264 前是家页）的军功碑；264：碑右边那一列（上回出征、军需、【开始探索】）
var _stele: RecordsStele = null
var _expedition: ExpeditionBoard = null
var _new_run_btn: Button
## 264 §六：仓库页包架下面的筛选牌与账牌
var _wh_tools: WarehouseTools = null
## 268 补充一：快速出售的出售单
var _sell_sheet: SellSheet = null
var _wh_page: PanelContainer = null
## 264 §三：整屏背景那张图、现在铺的是哪张、淡入中的上层
var _home_bg: TextureRect = null
var _home_bg_name := ""
var _bg_fade: TextureRect = null
var _buff_btns: Dictionary = {}
var _unlock_btns: Dictionary = {}
## 119：开发区的科技等级数字框，科技 id → SpinBox（导出包里空）
var _tech_spins: Dictionary = {}
## 页签名 → 那一页的控件；`_tab_btns` 页签名 → 按钮
var _pages: Dictionary = {}
var _tab_btns: Dictionary = {}
var _tab: String = ""
## 262：「后勤」里翻着的分页（本次会话内记着，第一次是集市）；分页名 → 小键；三颗小键那一列
var _sub: String = "market"
var _sub_btns: Dictionary = {}
var _sub_box: VBoxContainer = null
## 264 §四：书架底下五颗小键（格名 → 键）与那一列
var _shelf_sub_btns: Dictionary = {}
var _shelf_sub_box: VBoxContainer = null
## 261：书架格 → 格上的小牌（按钮）；窗（压暗层）；开着的那扇
var _shelf_view: ShelfView = null
var _shelf_windows: Dictionary = {}
var _shelf_open: String = ""
var _records: RunRecordsWindow = null
## 图鉴页的缩略图与它的悬浮窗
var _codex_tiles: Array[CodexTile] = []
## 095：异体弹窗
var _variants_popup: Control = null
var _variant_tiles: Array[CodexTile] = []
var _codex_tip: HoverTip = null
## 091：成就页的筛选（"all" / "done" / "todo"）、列表与现在列着的行
var _ach_filter: String = "all"
## 265：图鉴「全部 / 收藏」
var _codex_filter: String = "all"
var _codex_filter_btns: Dictionary = {}
var _ach_filter_btns: Dictionary = {}
var _ach_list: VBoxContainer = null
var _ach_warn: HeaderTag = null
var _ach_rows: Array = []
## 139：调试台抽屉
var _drawer: DevDrawer = null
var _debug_btn: Button = null
var _codex_grids: Array[GridContainer] = []
## 164：三列与右半边的仓库（整屏的拖拽层是 [member GameScreen._drag]）
var _cols: HBoxContainer = null
var _margin: MarginContainer = null
var _middle: VBoxContainer = null
var _right: VBoxContainer = null
var _shelf: WarehousePages = null
var _shelf_frame: PanelContainer = null
var _shelf_title: HeaderTag = null
## 178：「仓库」页没有带回来的棋盘时那一行


func open(payload: Dictionary) -> void:
	var m := flow.meta
	flow.ensure_market()     # 251：有集市却没货（老档、开发区改了级数）先上一次
	_home_bg = UiTheme.dress_home_backdrop(_backdrop())
	_home_bg_name = UiTheme.ART_HOME_BG
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, int(MARGIN))
	add_child(_margin)
	_cols = _hbox(int(COL_GAP))
	_margin.add_child(_cols)
	_drag = DragLayer.new()
	_drag.label_font = font

	# 左列：标题、五个页签竖排；底下「再来一局」「回主菜单」
	var left := _vbox(12)
	left.custom_minimum_size.x = LEFT_W
	_cols.add_child(left)
	# 226 批二：「基地」二字删了（页签已说明在哪）
	for pair in TABS:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(UiText.t(pair[1]), func(): toggle_tab(key))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(LEFT_W * 0.8, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var icon := UiTheme.art_cached(TAB_ICON_ART + key)     # 作者 2026-10-24 选乙 平墨图标：字左边一枚墨色小图
		if icon == null and key == "shelf":
			icon = UiTheme.art_cached(TAB_ICON_ART + "codex")     # 261：书架剪影没到前先用图鉴那枚
		if icon != null:
			b.icon = icon
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_tab_btns[key] = b
		left.add_child(b)
		if SUB_TABS.has(key):
			_build_sub_tabs(left, key)
	var tab_w := LEFT_W * 0.8     # 英文页签加了图标放不下：几个页签一样宽，取最宽的那个
	for key in _tab_btns:
		tab_w = maxf(tab_w, (_tab_btns[key] as Button).get_combined_minimum_size().x)
	for key in _tab_btns:
		(_tab_btns[key] as Button).custom_minimum_size.x = tab_w
	# 作者 10-31：选中页签左上角那枚五角小木牌（164 tab_mark）删了 —— 「很难看而且没有意义」，选中只看按下态
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	# 226 批二：左下「带回来的背包还有 N 件……」那句删了（[method pending_text] 留给「仓库」页签的悬浮窗）
	# 264：左下「再来一局」搬进出征页改叫【开始探索】，左下只剩「回主菜单」
	var menu_btn := UiTheme.make_home_button(UiText.t("setup.main_menu"), flow.to_main_menu)
	menu_btn.custom_minimum_size = Vector2(LEFT_W * 0.8, 56)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(menu_btn)

	# 中列：当前页
	_middle = _vbox(10)
	_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cols.add_child(_middle)

	# 右半边：仓库（先建 —— 家页的带回来背包、科技页的上交区都要和它同一层拖拽）
	_right = _vbox(8)
	_cols.add_child(_right)
	var head := _hbox(8)
	head.custom_minimum_size.y = SHELF_HEAD
	_right.add_child(head)
	_shelf_title = HeaderTag.hanging(UiText.t("meta.tab_warehouse"))     # 226 批三：木架顶一块挂牌只写「仓库」，件数与页数进它的悬浮窗（每页件数页签上有）
	_shelf_title.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_shelf_title)
	if DevGate.on():     # 186：调试台只在开发包里有
		_drawer = DevDrawer.new()
		# 178：箭头钉在屏幕右上（原来在仓库标题行的右端，同一个位置）—— 图鉴 / 成就页收起右半边时它还在
		var arrow_w := _drawer.arrow.get_combined_minimum_size().x
		_drawer.arrow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_drawer.arrow.offset_left = -MARGIN - arrow_w
		_drawer.arrow.offset_right = -MARGIN
		_drawer.arrow.offset_top = MARGIN
		_drawer.arrow.offset_bottom = MARGIN + SHELF_HEAD
	_shelf_frame = UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_SHELF)
	_shelf_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_right.add_child(_shelf_frame)
	_shelf = WarehousePages.new()
	_shelf.tab_variation = UiTheme.BUTTON_SETUP_TAB     # 乙 石刻：分页签同开局、结算那款挂牌木签
	_shelf.tab_height = SHELF_TAB_H
	_shelf_frame.add_child(_shelf)
	_shelf.setup(m.warehouse, font, _drag, TechWarehousePages.plan_of(flow.tech_defs))
	_drag.register_view(_shelf.view)
	_shelf.view.item_double_clicked.connect(_on_shelf_double_clicked)
	_shelf.view.actions_for = func(uid: int) -> Array: return _wh.warehouse_actions(uid, _tab == "warehouse") if _wh != null else []     # 230
	m.warehouse.changed.connect(_refresh_shelf_title)

	# 264：出征页（原「家」页）—— 左边军功碑（260 原样，碑顶山墙上沿在设计坐标 y 52），右边上回出征 / 军需两块木牌与【开始探索】
	var home := _hbox(52)
	home.name = "ExpeditionPage"
	home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.add_child(home)
	_pages["expedition"] = home
	var stele_col := _vbox(0)
	home.add_child(stele_col)
	var stele_gap := Control.new()
	stele_gap.custom_minimum_size.y = 28.0     # 24 + 28 = 52
	stele_col.add_child(stele_gap)
	_stele = RecordsStele.new()
	stele_col.add_child(_stele)
	_stele.setup(flow)
	var board_col := _vbox(0)
	home.add_child(board_col)
	var board_gap := Control.new()
	board_gap.custom_minimum_size.y = 36.0     # 木牌顶在 y 60
	board_col.add_child(board_gap)
	_expedition = ExpeditionBoard.new()
	board_col.add_child(_expedition)
	_expedition.setup(flow)
	_new_run_btn = _expedition.start_btn
	# 178：「仓库」页 —— 带回来的背包（一键置入 / 整理 / 提示行）；没有带回来的就一行字（整理照旧管右边当前页）
	var wh_page := _cloth()
	_pages["warehouse"] = wh_page
	_wh_page = wh_page
	var wh_col := _vbox(10)
	wh_page.add_child(wh_col)
	# 226 批二：空态「没有带回来的东西」删了
	_wh = WarehousePanelScript.new()
	_wh.sell_one = sell
	_wh.setup(flow, font, _shelf, _drag)
	_wh.changed.connect(_refresh)
	wh_col.add_child(_wh)
	_wh_tools = WarehouseTools.new()     # 264 §六：包架下面筛选牌 + 账牌
	_wh.add_rack_tools(_wh_tools)
	_wh_tools.setup(flow, _shelf)     # 268：两块牌中间加【快速出售】
	_sell_sheet = SellSheet.new()     # 268 补充一：出售模式的出售单，挂在【快速出售】下面，模式里才露
	_sell_sheet.setup(flow, _shelf, say)
	_sell_sheet.visible = false
	_wh_tools.set_sell_mode(false, _sell_sheet)
	_wh_tools.sell_mode_toggled.connect(set_sell_mode)
	_sell_sheet.cancelled.connect(func(): set_sell_mode(false))
	_shelf.refused.connect(_on_pick_refused)
	m.changed.connect(_fit_wh_cloth)

	if _drawer != null:
		_build_dev_drawer(m)

	# 图鉴页、成就页（091）
	# 164：中列的页都垫一块粗布（浅底墨字）—— 直接写在背景上，炉火那块亮处看不清
	_pages["shelf"] = _build_shelf(_middle)     # 261 补充二：石砌壁龛直接立在墙上（透明处是墙），不垫粗布
	for pair in [["market", _build_market], ["smithy", _build_smithy]]:
		var cloth := _cloth()
		if backdrop_of(pair[0]) != UiTheme.ART_HOME_BG:
			cloth.add_theme_stylebox_override("panel", StyleBoxEmpty.new())     # 264 §三：场景图上不垫粗布
		(pair[1] as Callable).call(cloth)
		_pages[pair[0]] = cloth
	# 139：抽屉盖在右半边上（后加 = 画在上面），贴右缘、标题行下面
	if _drawer != null:
		_drawer.wrap_contents()
		add_child(_drawer)
		_drawer.dock(MARGIN + SHELF_HEAD + 8.0, MARGIN)
		add_child(_drawer.arrow)
	add_child(_drag)     # 164：整屏一层拖拽，盖在三列上（残影画在最上面）
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shelf_windows()     # 261：书架的五扇窗（科技在里面，110 的科技页整个搬进窗）盖在最上面，先藏着
	resized.connect(layout)
	show_tab(String(payload.get("tab", initial_tab(payload))))
	_refresh()
	_refresh_shelf_title()
	layout()


#region 三列与仓库的大小（164）
## 中列一页的底：一块粗布，占满中列
func _cloth() -> PanelContainer:
	var cloth := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_BOX)
	cloth.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cloth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle.add_child(cloth)
	return cloth



## 264 §六：仓库页没有带回来的棋盘时，粗布缩成一根窄布（包架 + 筛选牌 + 账牌那一列），有了再铺满中列
const WH_NARROW := 260.0


func _fit_wh_cloth() -> void:
	if _wh_page == null or _wh == null:
		return
	var wide: bool = _wh.has_board() or sell_mode()     # 268：出售单比窄布宽
	_wh_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_SHRINK_BEGIN
	_wh_page.custom_minimum_size.x = 0.0 if wide else WH_NARROW


func warehouse_tools() -> WarehouseTools:
	return _wh_tools


#region 268 补充一：快速出售模式
## 开 / 关：【快速出售】按下态、出售单露出（筛选牌收起、包架与带回来的背包板收起）、右边仓库进勾选模式；关了勾选全清、筛选牌的筛选还原
func set_sell_mode(on: bool) -> void:
	if _sell_sheet == null or on == sell_mode():
		_wh_tools.set_sell_mode(sell_mode(), _sell_sheet)
		return
	if on:
		_sell_sheet.open()
	else:
		_sell_sheet.close()
	_wh.set_sell_mode(on)
	_wh_tools.set_sell_mode(on, _sell_sheet)
	_fit_wh_cloth()
	layout.call_deferred()


func sell_mode() -> bool:
	return _shelf != null and _shelf.select_mode


func sell_sheet() -> SellSheet:
	return _sell_sheet


## 点了一件勾不上的：告示说为什么
func _on_pick_refused(item: ItemInstance) -> void:
	say(UiText.t("sell.no_locked" if item.is_locked_by_player() else "sell.no_fav") % Names.of(item.def))
#endregion


func expedition_board() -> ExpeditionBoard:
	return _expedition


## 按屏幕大小排：右半边占屏宽一半，仓库格子按右半边的宽高取小（40 ～ 80）；带回来的背包与右边同一个格子大小（中列放不下再缩）
func layout() -> void:
	if _right == null:
		return
	var screen := size if size.x > 0.0 and size.y > 0.0 else (get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080))
	# 229：科技页也收起右半边，中列的页都按中列宽自己排（图鉴按宽算列数），右半边只按半屏算
	var half := maxf(0.0, minf(screen.x * 0.5 - MARGIN, screen.x - 2.0 * MARGIN - LEFT_W - 2.0 * COL_GAP))
	var frame := _frame_margins()
	var c := _shelf.fit(half - frame.x, screen.y - 2.0 * MARGIN - SHELF_HEAD - 8.0 - frame.y)     # 收起时也按半屏算，切回来格子不变
	if not _right.visible:
		half = 0.0     # 178：图鉴 / 成就页（229：科技页）收起右半边，中列吃满
	_right.custom_minimum_size.x = half
	_margin.add_theme_constant_override("margin_right", int(MARGIN + right_gutter()))
	var mid_w := middle_width(screen)
	if _sell_sheet != null:
		_sell_sheet.fit_width(mid_w - 50.0)     # 268：粗布内边距 + 余量
	if _wh != null and flow.meta.board != null:
		_wh.set_board_cell(minf(c, maxf(WarehousePages.CELL_MIN, floorf((mid_w - 50.0 - _wh.rack_room() - 2.0 * _wh.BOARD_FRAME_PAD) / float(maxi(CharacterDef.BOARD_MAX_W, flow.meta.board.size.x))))))


## 178：右半边收起时，右边空出调试台箭头那一条（箭头钉在屏幕右上，别压在中列上）
func right_gutter() -> float:
	if _right.visible or _drawer == null:
		return 0.0
	return _drawer.arrow.get_combined_minimum_size().x + 8.0


## 178：中列的宽（右半边收起时 = 全宽减左列、减箭头那一条）
func middle_width(screen: Vector2) -> float:
	if not _right.visible:
		return screen.x - 2.0 * MARGIN - LEFT_W - COL_GAP - right_gutter()
	return screen.x - 2.0 * MARGIN - LEFT_W - _right.custom_minimum_size.x - 2.0 * COL_GAP


## 178（待定 2 选 A）：进基地落哪一页 —— 从结算屏回来、带回来的背包还没清空 → 「仓库」页；否则家
func initial_tab(payload: Dictionary) -> String:
	return "warehouse" if payload.has("result") and flow.meta.has_pending_board() else "expedition"


## 木架框的左右、上下内边距之和
func _frame_margins() -> Vector2:
	var box := _shelf_frame.get_theme_stylebox("panel") if _shelf_frame != null else null
	if box == null:
		return Vector2.ZERO
	return Vector2(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT), box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))


## 右半边的仓库（测试看）
func shelf() -> WarehousePages:
	return _shelf


func drag_layer() -> DragLayer:
	return _drag


func _refresh_shelf_title() -> void:
	if _shelf_title != null:
		_shelf_title.tooltip_text = UiText.t("meta.shelf_title") % [UiText.count(flow.meta.warehouse.item_count(), "unit.item"), UiText.count(flow.meta.warehouse.page_count(), "unit.page")]


## 双击右边仓库的一件：仓库页 → 置入带回来的背包（178：原来在家页）；别的页不做事（268：出售页删了，卖走悬浮窗或工具列一键出售）
func _on_shelf_double_clicked(view: ContainerView, uid: int) -> void:
	if page() == "warehouse":
		_wh.quick_move(view, uid)
#endregion


#region 调试台（139）
## 139：调试台（原来仓库页的右列）。186：整个是开发物 —— 只在开发包里造（[DevGate]）
func _build_dev_drawer(m: MetaState) -> void:
	var right := _drawer.content
	# 150 补 2：头部写着现在的调试模式，点一下切（和设置页那个勾选是同一个开关）
	_debug_btn = _button("", toggle_debug_mode, 13, UiPalette.Tier.MINOR)
	_debug_btn.text = _debug_text()
	right.add_child(_debug_btn)
	# 开发开关：只在开发包显示（200：DevGate，开发版导出也有）。科技给的局外 buff 由「科技」页的等级决定（写进 tech_buffs），不在这里重复开关
	if DevGate.on():
		right.add_child(_label("开发：局外 buff 开关（科技给的在下面「科技等级」里改）", 15, UiPalette.DIM))
		var ids_b: Array = flow.buff_defs.keys()
		ids_b.sort()
		var from_tech := {}
		for t in flow.tech_defs:
			if t.effect is TechRunBuff:
				for tid in (t.effect as TechRunBuff).buffs:
					from_tech[tid] = true
		var any_meta := false
		for id in ids_b:
			var def: RunBuffDef = flow.buff_defs[id]
			if not def.is_meta() or from_tech.has(id):
				continue
			any_meta = true
			var bid: StringName = id
			var b := _button("%s　%s" % [def.display_name, def.summary()], func(): toggle_buff(bid), 13, UiPalette.Tier.MINOR)
			b.toggle_mode = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.set_pressed_no_signal(m.active_buffs.has(bid))
			_buff_btns[bid] = b
			right.add_child(b)
		if not any_meta:
			right.add_child(_label("（没有局外 buff 的内容）", 12, UiPalette.DIM))
	# 局外解锁（069，占位开关）：难度定义里要求的解锁 id 各一个开关；085：章节通关给的解锁也列（关掉 = 教程重新顶上）
	var unlock_ids: Array[StringName] = []
	for d in flow.difficulties:
		if d.requires_unlock != &"" and not unlock_ids.has(d.requires_unlock):
			unlock_ids.append(d.requires_unlock)
	for c in flow.chapters:
		if c.grants_unlock != &"" and not unlock_ids.has(c.grants_unlock):
			unlock_ids.append(c.grants_unlock)
	if not unlock_ids.is_empty():
		right.add_child(_label("开发：局外解锁开关", 15, UiPalette.DIM))
		for uid in unlock_ids:
			var names: Array[String] = []
			for d in flow.difficulties:
				if d.requires_unlock == uid:
					names.append("难度：" + d.display_name)
			for c in flow.chapters:
				if c.grants_unlock == uid:
					names.append("通关：" + c.display_name)
				elif c.requires_unlock == uid:
					names.append("开放：" + c.display_name)
			var key: StringName = uid
			var ub := _button("%s　%s" % [uid, "、".join(names)], func(): toggle_unlock(key), 13, UiPalette.Tier.MINOR)
			ub.toggle_mode = true
			ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ub.set_pressed_no_signal(m.has_unlock(key))
			_unlock_btns[key] = ub
			right.add_child(ub)
	# 119：开发区手改进度表（存档的 tech_levels）—— 每个科技一个数字框，玩家版里没有
	if DevGate.on() and not flow.tech_defs.is_empty():
		right.add_child(_label("科技等级　开发：直接改存档里点到几级（0 = 没点亮），效果跟着重算", 15, UiPalette.DIM))
		var grid := GridContainer.new()
		grid.columns = 2     # 139：抽屉窄，一行一个科技
		grid.add_theme_constant_override("h_separation", 12)
		right.add_child(grid)
		for t in flow.tech_defs:
			var tid: StringName = t.id
			grid.add_child(_label(Names.of(t), 13, UiPalette.FG))
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = t.max_level()
			spin.step = 1
			spin.rounded = true
			spin.set_value_no_signal(TechService.level(m, tid))
			spin.value_changed.connect(func(v: float): set_tech_level(tid, int(v)))
			_tech_spins[tid] = spin
			grid.add_child(spin)
	right.add_child(_label("最近几局", 15, UiPalette.DIM))
	var log := _log_box(13)
	for h in m.history:
		var extracted := String(h.get("outcome", "")) == "extracted"
		log.append_text("[color=#%s]%s[/color]　走了 %d 步　打赢 %d　%s\n" % [
			(UiPalette.HEAL if extracted else UiPalette.HP).to_html(false), "撤离" if extracted else "战败",
			int(h.get("steps", 0)), int(h.get("battles_won", 0)),
			"%d 件、值 %d 币、带出 %d 币" % [(h.get("items", []) as Array).size(), int(h.get("value", 0)), int(h.get("balance", 0))] if extracted else ""])
	if m.history.is_empty():
		log.append_text("[color=#8b93a1]还没有打过[/color]")
	log.fit_content = true     # 抽屉自己滚，日志按内容撑高
	right.add_child(log)


## 150 补 2：调试模式开关（存盘）
func toggle_debug_mode() -> bool:
	flow.settings.debug_mode = not flow.settings.debug_mode
	flow.save_settings()
	if _debug_btn != null:
		_debug_btn.text = _debug_text()
	return flow.settings.debug_mode


func _debug_text() -> String:
	return "调试模式：%s（地图上的事件日志）" % ("开" if flow.settings.debug_mode else "关")


func dev_drawer() -> DevDrawer:
	return _drawer


## 点箭头：开 / 关。返回开着没
func toggle_dev_drawer() -> bool:
	return _drawer.toggle() if _drawer != null else false
#endregion


#region 科技（110）
var _tech = null


func _build_tech(root: Control) -> Control:
	_tech = TechPanelScript.new()
	_tech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tech.setup(flow, font)
	_tech.changed.connect(_refresh)
	root.add_child(_tech)
	return _tech


## 科技页（测试看）
func tech_panel():
	return _tech
#endregion


#region 集市、铁匠铺（251）
var _market = null
var _smithy = null


func _build_market(root: Control) -> Control:
	_market = MarketPanelScript.new()
	_market.setup(flow, font, say)
	_market.changed.connect(_refresh)
	root.add_child(_market)
	return _market


func _build_smithy(root: Control) -> Control:
	_smithy = SmithyPanelScript.new()
	_smithy.setup(flow, font, say)
	_smithy.changed.connect(_refresh)
	root.add_child(_smithy)
	return _smithy


## 测试看
func market_panel():
	return _market


func smithy_panel():
	return _smithy


## 262：「后勤」底下三颗缩进的小键（木牌键皮小号字，选中的按下）；只在「后勤」选中时露出来。
## 264 §四：「书架」底下五颗（点 = [method show_tab] 那一格的别名：书架页 + 开窗）
func _build_sub_tabs(left: VBoxContainer, tab_key: String) -> void:
	var row := _hbox(0)
	left.add_child(row)
	var indent := Control.new()
	indent.custom_minimum_size.x = SUB_TAB_INDENT
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(indent)
	var box := _vbox(6)
	row.add_child(box)
	var btns := _sub_btns if tab_key == "logistics" else _shelf_sub_btns
	for pair in SUB_TABS[tab_key]:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(UiText.t(pair[1]), func(): show_tab(key), false, SUB_TAB_SIZE, SUB_TAB_FONT)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btns[key] = b
		box.add_child(b)
	row.visible = false
	if tab_key == "logistics":
		_sub_box = box
	else:
		_shelf_sub_box = box


## 测试看：后勤（264：或书架）的分页小键
func sub_tab_buttons(tab_key: String = "logistics") -> Dictionary:
	return _sub_btns if tab_key == "logistics" else _shelf_sub_btns


## 264 §四：书架小键按下态跟着开着的窗
func _sync_shelf_sub() -> void:
	for key in _shelf_sub_btns:
		(_shelf_sub_btns[key] as Button).set_pressed_no_signal(key == _shelf_open)
#endregion


#region 出售（091；268：出售页删了，一键出售在仓库页工具列 [WarehouseTools]，卖包在包架悬浮窗 [method WarehousePanel.sell_bag]）
## 成就筛选木牌的字号
const ACH_FILTER_FONT := 16


## 卖掉仓库里的一件；返回得了多少（没这件 -1）
func sell(uid: int) -> int:
	var inst := flow.meta.warehouse.get_item(uid)
	var name := Names.of(inst.def) if inst != null else ""
	var got := flow.sell_item(uid)
	if got >= 0:
		say(UiText.t("meta.sold_one") % [name, got, flow.meta.funds])     # 226 批一：卖出回话走告示卷轴
	return got
#endregion


#region 成就页（091，作者定）
## 成就页：每枚一行 —— 名字、解锁途径、进度、完成给什么；「全部 / 已解锁 / 未解锁」切
func _build_achievements(root: Control) -> Control:
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var head := _hbox(8)
	page.add_child(head)
	for pair in [["all", "meta.all"], ["done", "meta.ach_filter_done"], ["todo", "meta.ach_filter_todo"]]:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(UiText.t(pair[1]), func(): show_achievement_filter(key), false, Vector2.ZERO, ACH_FILTER_FONT)     # 乙 石刻：木牌，选中 = 按下的那块
		b.toggle_mode = true
		_ach_filter_btns[key] = b
		head.add_child(b)
	_ach_warn = HeaderTag.new(UiText.t("meta.ach_unlock_all_on"))     # 226 批三：「全部解锁开着」改一枚警示签；「完成 N / N」进「全部」钮
	_ach_warn.visible = false
	head.add_child(_ach_warn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 300
	page.add_child(scroll)
	_ach_list = _vbox(8)
	_ach_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ach_list)
	show_achievement_filter("all")
	return page


## 切「全部 / 已解锁 / 未解锁」（"all" / "done" / "todo"）并重列
func show_achievement_filter(key: String) -> void:
	if not _ach_filter_btns.has(key):
		key = "all"
	_ach_filter = key
	for k in _ach_filter_btns:
		(_ach_filter_btns[k] as Button).set_pressed_no_signal(k == key)
	_fill_achievements()


func achievement_filter() -> String:
	return _ach_filter


## 现在列着的：[{id, done}]（测试看）
func achievement_rows() -> Array:
	return _ach_rows.duplicate()


func _fill_achievements() -> void:
	if _ach_list == null:
		return
	UiTheme.clear_children(_ach_list)
	_ach_rows.clear()
	var m := flow.meta
	var total := flow.achievement_defs.size()
	var done_n := 0
	for def in flow.achievement_defs:
		if m.has_achievement(def.id):
			done_n += 1
	if _ach_warn != null:
		_ach_warn.visible = flow.settings != null and flow.settings.unlock_all
	if _ach_filter_btns.has("all"):
		(_ach_filter_btns["all"] as Button).text = UiText.t("meta.ach_all_count") % [done_n, total]
	if total == 0:
		return     # 226 批二：空态的字删了
	for def in flow.achievement_defs:
		var done := m.has_achievement(def.id)
		if _ach_filter == "done" and not done or _ach_filter == "todo" and done:
			continue
		_ach_rows.append({"id": def.id, "done": done})
		_ach_list.add_child(_achievement_row(def, done))


func _achievement_row(def: AchievementDef, done: bool) -> Control:
	var m := flow.meta
	var panel := _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _vbox(4)
	panel.add_child(col)
	var secret := def.hidden and not done
	var head := _hbox(12)
	col.add_child(head)
	head.add_child(_label((UiText.t("meta.secret") if secret else Names.of(def)), 16, UiPalette.HEAL if done else UiPalette.FG))
	var status := ""
	if done:
		var t := m.achievement_time(def.id)
		status = UiText.t("meta.ach_done") + (UiText.t("meta.ach_done_date") % Time.get_date_string_from_unix_time(t) if t > 0 else "")
	elif secret:
		status = UiText.t("meta.ach_not_done")
	else:
		status = UiText.t("meta.ach_progress") % def.progress_text(m)
	head.add_child(_label(status, 13, UiPalette.HEAL if done else UiPalette.DIM))
	col.add_child(_wrapped(UiText.t("meta.ach_how") % (UiText.t("meta.secret") if secret else Names.description_of(def)), 13, UiPalette.FG, 700))
	var opens: Array[String] = []
	for g in def.grants:
		opens.append_array(flow.unlock_names(g))
		if flow.unlock_names(g).is_empty():
			opens.append(UiText.t("meta.unlock_id") % g)
	col.add_child(_wrapped(UiText.t("meta.ach_grants") % (UiText.t("hud.buff_sep").join(opens) if not opens.is_empty() else UiText.t("meta.ach_badge_only")), 12, UiPalette.DIM, 700))
	return panel
#endregion


## 088 / 089：图鉴页 —— 跟棋盘的格子无关：所有能获得的道具按稀有度排成**缩略图网格**（一行几个按宽度算，139；能上下滚），
## 带出过的亮着（右上角写累计件数），没获得的灰的；停在一格上开悬浮窗看属性。特殊道具另起一段
func _build_codex(root: Control) -> Control:
	var m := flow.meta
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var ids: Array = flow.items.ids(true)     # 091：锁着的也列（灰的，写着怎么解锁）
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da := flow.items.get_def(a)
		var db := flow.items.get_def(b)
		return da.rarity < db.rarity if da.rarity != db.rarity else String(a) < String(b))
	# 095（作者定）：派生的赐福版并进原件那一格（ids() 本来就不列赐福版），格子叠影 + 角标，点开弹异体列表
	# 226 批二：说明行（「图鉴　带出过的点亮 N / N……」）删了
	# 265：「全部 / 收藏」两块木牌（同成就页那一排）
	var head := _hbox(8)
	page.add_child(head)
	for pair in [["all", "meta.all"], ["fav", "meta.codex_fav"]]:
		var key: String = pair[0]
		var b := UiTheme.make_home_button(UiText.t(pair[1]), func(): show_codex_filter(key), false, Vector2.ZERO, ACH_FILTER_FONT)
		b.toggle_mode = true
		_codex_filter_btns[key] = b
		head.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED     # 139：按宽度定列数，不横向滚
	scroll.custom_minimum_size.y = 300
	page.add_child(scroll)
	var inner := _vbox(10)
	scroll.add_child(inner)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", CODEX_GAP)
	grid.add_theme_constant_override("v_separation", CODEX_GAP)
	inner.add_child(grid)
	_codex_grids.clear()
	_codex_grids.append(grid)
	_codex_tiles.clear()
	for id in ids:
		var def := flow.items.get_def(id)
		var tile := _codex_tile_for(def)
		grid.add_child(tile)
		_codex_tiles.append(tile)
	_codex_tip = HoverTip.new()
	add_child(_codex_tip)
	show_codex_filter("all")
	if not m.changed.is_connected(_refilter_codex):
		m.changed.connect(_refilter_codex)     # 收藏变了：「收藏」档跟着增减
	fit_codex_to_width(SHELF_WIN.x)     # 进树之前先给个列数，布局好了按真宽度重算
	scroll.resized.connect(func(): fit_codex_to_width(scroll.size.x))
	return page


## 265：图鉴切「全部 / 收藏」（"all" / "fav"）：收藏档只露收藏了的种类（异体并在原件格里，任一收藏就露）
func show_codex_filter(key: String) -> void:
	if not _codex_filter_btns.has(key):
		key = "all"
	_codex_filter = key
	for k in _codex_filter_btns:
		(_codex_filter_btns[k] as Button).set_pressed_no_signal(k == key)
	_refilter_codex()


func codex_filter() -> String:
	return _codex_filter


func _refilter_codex() -> void:
	if _codex_grids.is_empty():
		return
	for tile in (_codex_grids[0] as GridContainer).get_children():
		var t := tile as CodexTile
		t.visible = _codex_filter != "fav" or t.variants.any(func(v): return v != null and ItemFavorites.has((v as ItemDef).id)) or (t.def != null and ItemFavorites.has(t.def.id))


## 特殊道具（088）：不进背包、不能生成，拿到过的点亮。261：原来在图鉴页底下一段，搬进书架上自己那一格的窗
func _build_keepsakes(root: Control) -> Control:
	var m := flow.meta
	var page := _vbox(8)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(page)
	var keeps: Array = flow.items.keepsake_ids()
	keeps.sort()
	var kgrid := UiTheme.grid(codex_columns_for(SHELF_WIN.x), CODEX_GAP)
	page.add_child(kgrid)
	_codex_grids.append(kgrid)
	for id in keeps:
		var def := flow.items.get_def(id)
		var tile := CodexTile.new(def, m.has_keepsake(id), 0, font)
		_wire_tile(tile)
		kgrid.add_child(tile)
		_codex_tiles.append(tile)
	return page


## 139：图鉴一行放几个 —— 让缩略图占满 [param width]（扣掉竖滚动条），至少一个
static func codex_columns_for(width: float) -> int:
	return maxi(1, floori((width - 14.0 + CODEX_GAP) / (CodexTile.SIZE.x + CODEX_GAP)))


func fit_codex_to_width(width: float) -> void:
	var cols := codex_columns_for(width)
	for g in _codex_grids:
		g.columns = cols


func codex_columns() -> int:
	return _codex_grids[0].columns if not _codex_grids.is_empty() else 0


## 095：一件（含它的异体）的格子：原件在前、各神的赐福版按 id 排；任一点亮格子就亮
func _codex_tile_for(def: ItemDef) -> CodexTile:
	var m := flow.meta
	var variants: Array[ItemDef] = [def]
	for vid in flow.items.variants_of(def.id):
		if vid != def.id:
			variants.append(flow.items.get_def(vid))
	var any_lit := false
	var tile := CodexTile.new(def, m.codex_lit(def.id), m.codex_count(def.id), font)
	for v in variants:
		var on := m.codex_lit(v.id)
		any_lit = any_lit or on
		tile.variant_lit.append(on)
		tile.variant_counts.append(m.codex_count(v.id))
	tile.variants = variants
	tile.lit = any_lit
	tile.mask_name = not flow.names_revealed()     # 作者 10-26：没点亮的写「？」，悬浮窗同样
	_wire_tile(tile)
	tile.pressed.connect(func(t: CodexTile): show_variants(t))
	return tile


## 图鉴格的悬浮接线：停上去显示说明、离开就藏
func _wire_tile(tile: CodexTile) -> void:
	tile.hovered.connect(_on_tile_hovered)
	tile.unhovered.connect(func(_t: CodexTile): _codex_tip.release())


## 095：点开一格：有异体就弹出列表（原件、蛮神版、日神版……各一小格，点亮的亮着），再点关闭 / 别处关掉
func show_variants(tile: CodexTile) -> void:
	close_variants()
	if tile == null or tile.variant_count() == 0:
		return
	var box := _panel(10)
	box.name = "VariantsPopup"
	var col := _vbox(6)
	box.add_child(col)
	col.add_child(_label(UiText.t("meta.variants_title") % [tile.shown_name(), tile.variants_lit(), tile.variants.size()], 14, UiPalette.FG))
	var row := _hbox(8)
	col.add_child(row)
	_variant_tiles.clear()
	for i in tile.variants.size():
		var v: ItemDef = tile.variants[i]
		var vt := CodexTile.new(v, tile.variant_lit[i] if i < tile.variant_lit.size() else false, tile.variant_counts[i] if i < tile.variant_counts.size() else 0, font)
		vt.mask_name = tile.mask_name
		_wire_tile(vt)
		var cell := _vbox(2)
		cell.add_child(_label(_variant_kind(v), 11, UiPalette.DIM))
		cell.add_child(vt)
		row.add_child(cell)
		_variant_tiles.append(vt)
	col.add_child(_button(UiText.t("meta.close"), close_variants, 12, UiPalette.Tier.MINOR))
	add_child(box)
	box.position = (tile.global_position + Vector2(0, tile.size.y + 6)).clamp(Vector2.ZERO, get_viewport_rect().size - Vector2(400, 200))
	_variants_popup = box


func close_variants() -> void:
	if _variants_popup != null:
		_variants_popup.queue_free()
		_variants_popup = null
	_variant_tiles.clear()


func variants_open() -> bool:
	return _variants_popup != null


func variant_tiles() -> Array[CodexTile]:
	return _variant_tiles


## 「原件」/「蛮神版」……
func _variant_kind(def: ItemDef) -> String:
	if def == null or not def.is_blessed():
		return UiText.t("meta.variant_base")
	var fid := FaithTags.id_of_tag(def.faith_tag())
	var fd: FaithDef = flow.faith_defs.get(fid, null) if flow.faith_defs != null else null
	return UiText.t("meta.variant_blessed") % (Names.of(fd) if fd != null else String(fid))


## 停在一格上：点亮的开完整的道具说明；没获得的只写名字与「未获得」
func _on_tile_hovered(tile: CodexTile) -> void:
	if _codex_tip == null or tile.def == null:
		return
	var at := tile.global_position + Vector2(tile.size.x, 0)
	if tile.lit:
		_codex_tip.show_kind(tile.def, at, tile.get_global_rect())     # 作者 10-26：贴着格子摆；265：右上角收藏丝带
	elif tile.def.requires_unlock != &"" and not flow.unlocked(tile.def.requires_unlock):
		# 091：锁着的写怎么解锁（哪一枚成就）
		var ach := flow.achievement_granting(tile.def.requires_unlock)
		var how := UiText.t("meta.codex_how_ach") % [Names.of(ach), Names.description_of(ach)] if ach != null else UiText.t("meta.unlock_id") % tile.def.requires_unlock
		_codex_tip.show_text(UiText.t("meta.codex_locked_tip") % [tile.shown_name(), how], at)
	else:
		_codex_tip.show_text(UiText.t("meta.codex_unseen_tip") % tile.shown_name(), at)


func codex_tiles() -> Array[CodexTile]:
	return _codex_tiles


#region 书架（261）
## 书架页：261 补充二 C 石砌壁龛整座（[ShelfView]，件和摆位读 layout.json）；前五格各开一扇窗，最后一格是静物油灯
func _build_shelf(root: Control) -> Control:
	var holder := Control.new()     # 1308 × 952 是 1600 宽时中列的整块；左列变宽（英文、大字号）中列窄了就整座等比缩，居中
	holder.name = "ShelfHolder"
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	_shelf_view = ShelfView.new()
	_shelf_view.open_requested.connect(open_shelf)
	holder.add_child(_shelf_view)
	holder.resized.connect(_fit_shelf_view)
	_refresh_shelf_labels()
	return holder


func _fit_shelf_view() -> void:
	var holder := _shelf_view.get_parent() as Control
	var body := _shelf_view.custom_minimum_size
	var k := minf(1.0, minf(holder.size.x / body.x, holder.size.y / body.y))
	_shelf_view.size = body
	_shelf_view.scale = Vector2.ONE * k
	_shelf_view.position = ((holder.size - body * k) * 0.5).floor()


## 格上小牌写什么：图鉴 40 / 153、对局记录 N 场、特殊道具 N / N、成就 N / N、科技 N / N
func shelf_label(key: String) -> String:
	var p := shelf_progress(key)
	match key:
		"records":
			return UiText.t("shelf.records") % p[0]
		"codex", "keepsakes", "achievements", "tech":
			return UiText.t("shelf." + key) % p
	return ""


## 261 补充一：这一格的进度 [分子, 分母] —— 图鉴 已点亮 / 全部道具；对局记录 场数 / 20；特殊道具 拿到过 / 全部；
## 成就 完成 / 全部；科技 点过至少 1 级的节点 / 全部节点
func shelf_progress(key: String) -> Array:
	var m := flow.meta
	match key:
		"codex":
			return [m.codex.size(), flow.items.ids(true).size()]
		"records":
			return [m.history.size(), MetaState.HISTORY_MAX]
		"keepsakes":
			var keeps: Array = flow.items.keepsake_ids()
			return [keeps.filter(func(id): return m.has_keepsake(id)).size(), keeps.size()]
		"achievements":
			var done := 0
			for def in flow.achievement_defs:
				if m.has_achievement(def.id):
					done += 1
			return [done, flow.achievement_defs.size()]
		"tech":
			var lit := 0
			for def in flow.tech_defs:
				if TechService.level(m, def.id) >= 1:
					lit += 1
			return [lit, flow.tech_defs.size()]
	return [0, 0]


## 格上纸签与物件档跟着进度改（科技窗里刚点亮一个、对局记录多一局 …）
func _refresh_shelf_labels() -> void:
	if _shelf_view == null:
		return
	for key in SHELF_CELLS:
		if key != "":
			_shelf_view.set_cell(key, shelf_progress(key), shelf_label(key))
	_shelf_view.set_keepsakes(flow.items.keepsake_ids().map(func(id) -> Array: return [flow.items.get_def(StringName(String(id))), flow.meta.has_keepsake(id)]))


## 书架前五格的按钮（透明，盖在格上）
func shelf_buttons() -> Dictionary:
	return _shelf_view.buttons() if _shelf_view != null else {}


func shelf_view() -> ShelfView:
	return _shelf_view


## 五扇窗：压暗的底 + 居中一块石板（1100 × 820；科技 1320 × 900），标题 + 右上「关」；内容照原来那几页
func _build_shelf_windows() -> void:
	_shelf_windows.clear()
	for pair in [["codex", _build_codex], ["records", _build_records], ["keepsakes", _build_keepsakes], ["achievements", _build_achievements], ["tech", _build_tech]]:
		var key: String = pair[0]
		var shade := ColorRect.new()
		shade.name = "ShelfWindow_" + key
		shade.color = Color(0.04, 0.05, 0.07, OVERLAY_SHADE)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.gui_input.connect(func(e: InputEvent):     # 点窗外 = 关
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				close_shelf())
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var frame := OverlayFrame.new(16)
		frame.custom_minimum_size = SHELF_WIN_WIDE if key == "tech" else SHELF_WIN
		frame.set_title(UiText.t("shelf.title_" + key))
		frame.add_slot(UiTheme.make_home_button(UiText.t("meta.close"), close_shelf))
		center.add_child(frame)
		var cloth := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_BOX)     # 窗里垫原来那块粗布（浅底墨字），内容照旧
		cloth.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cloth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.content.add_child(cloth)
		(pair[1] as Callable).call(cloth)
		shade.visible = false
		_shelf_windows[key] = shade
	if _codex_tip != null:
		move_child(_codex_tip, -1)     # 悬浮窗压在窗上面


func _build_records(root: Control) -> Control:
	_records = RunRecordsWindow.new()
	_records.setup(flow, font)
	root.add_child(_records)
	return _records


func records_window() -> RunRecordsWindow:
	return _records


## 开书架上一格的窗（"codex" / "records" / "keepsakes" / "achievements" / "tech"）；不在书架页就先切过去
func open_shelf(key: String) -> void:
	if not _shelf_windows.has(key):
		return
	if _tab != "shelf":
		show_tab("shelf")
	close_shelf()
	_shelf_open = key
	(_shelf_windows[key] as Control).visible = true
	if key == "records" and _records != null:
		_records.show_list()
	_sync_shelf_sub()


func close_shelf() -> void:
	close_variants()
	if _codex_tip != null:
		_codex_tip.release()
	for k in _shelf_windows:
		(_shelf_windows[k] as Control).visible = false
	_shelf_open = ""
	_sync_shelf_sub()


func shelf_open() -> String:
	return _shelf_open


func shelf_window(key: String) -> Control:
	return _shelf_windows.get(key, null)
#endregion


## 切页："expedition"（出征，默认；264 前叫家，"home" 留作别名）/ "warehouse" / "logistics" / "shelf"；261：老名字 "codex" / "achievements" / "tech" = 书架 + 开那扇窗。
## 262：分页名 "market" / "smithy" = 后勤 + 那个分页；"logistics" 落上次看的分页。268："sell"（出售页删了）落仓库页。
## 178：图鉴 / 成就页收起右半边的仓库（翻到的那页不变）
## 264 §三：中列这一页该铺哪张整屏背景（集市 / 铁匠铺有场景图用场景图，否则基地底图）
static func backdrop_of(page_name: String) -> String:
	if SCENES.has(page_name) and UiTheme.art(String(SCENES[page_name])) != null:
		return String(SCENES[page_name])
	return UiTheme.ART_HOME_BG


## 整屏背景换成 [param art_name]：淡入淡出（上面叠一张新图从透明到不透明，满了换给底图）；不淡（测试）当场换
func _swap_backdrop(art_name: String) -> void:
	if _home_bg == null or _home_bg_name == art_name:
		return
	_home_bg_name = art_name
	var tex := UiTheme.art(art_name)
	if _bg_fade != null and is_instance_valid(_bg_fade):
		_bg_fade.queue_free()
	if not GameDirector.fades_allowed or not is_inside_tree():
		_home_bg.texture = tex
		return
	var top := _home_bg.duplicate() as TextureRect
	top.texture = tex
	top.modulate.a = 0.0
	_home_bg.get_parent().add_child(top)
	_bg_fade = top
	var tw := create_tween()
	tw.tween_property(top, "modulate:a", 1.0, SCENE_FADE)
	tw.tween_callback(func():
		_home_bg.texture = tex
		top.queue_free())


## 现在铺的整屏背景（测试看）
func backdrop_name() -> String:
	return _home_bg_name


func show_tab(name: String) -> void:
	if _shelf_windows.has(name):
		show_tab("shelf")
		open_shelf(name)
		return
	close_shelf()
	var was := page()
	if name == "sell":
		name = "warehouse"
	if name != "warehouse" and sell_mode():
		set_sell_mode(false)     # 268：离开仓库页就退出售模式
	if _sub_btns.has(name):
		_sub = name
		name = "logistics"
	if not (_pages.has(name) or name == "logistics"):
		name = "expedition"
	var shown := _sub if name == "logistics" else name
	if _tab != "" and shown != was:
		notice_layer().clear()     # 游戏测试 v4.34：上一页的告示（「买不了：钱不够」）不跟到下一页
	_tab = name
	_swap_backdrop(backdrop_of(shown))
	for key in _pages:
		(_pages[key] as Control).visible = key == shown
	if _right != null:
		_right.visible = not (NO_SHELF_TABS.has(shown) or FULL_TABS.has(shown))     # 262：后勤的集市 / 铁匠铺收起
	for key in _tab_btns:
		var b := _tab_btns[key] as Button
		b.set_pressed_no_signal(key == name)
	if _sub_box != null:
		_sub_box.get_parent().visible = name == "logistics"
		for key in _sub_btns:
			(_sub_btns[key] as Button).set_pressed_no_signal(key == _sub)
	if _shelf_sub_box != null:
		_shelf_sub_box.get_parent().visible = name == "shelf"
	layout.call_deferred()     # 中列换了页，最窄宽度可能变了


## 164：点左列一个页签。264：页签单选 —— 再点选中的不动（没有「家」了），只把按下态补回来
func toggle_tab(key: String) -> void:
	if _tab == key:
		(_tab_btns[key] as Button).set_pressed_no_signal(true)
		return
	show_tab(key)


func tab() -> String:
	return _tab


## 262：后勤里翻着的分页（不在后勤 = 空串）
func sub_tab() -> String:
	return _sub if _tab == "logistics" else ""


## 中列现在是哪一页（后勤 = 它的分页）
func page() -> String:
	return _sub if _tab == "logistics" else _tab


## 090：Esc = 返回上一级 —— 在别的页先回出征页（264 前是家），出征页再回主菜单
func escape() -> bool:
	if sell_mode():     # 268：先退出售模式
		set_sell_mode(false)
		return true
	if _shelf_open != "":
		close_shelf()
		return true
	if _tab != "expedition":
		show_tab("expedition")
		return true
	flow.to_main_menu()
	return true


## 178：「再来一局」上面那句 —— 带回来的背包还没清空就指向「仓库」页（点一下过去）
func pending_text() -> String:
	if not flow.meta.has_pending_board():
		return ""
	return UiText.t("meta.pending") % flow.meta.board.item_count()


func toggle_buff(id: StringName) -> bool:
	var on := flow.toggle_meta_buff(id)
	if _buff_btns.has(id):
		(_buff_btns[id] as Button).set_pressed_no_signal(on)
	return on


## 119 开发区：改某个科技的级数（数字框与测试都走它）。返回实际的级数（夹在 0 ～ 满级）
func set_tech_level(id: StringName, level: int) -> int:
	var lv := flow.dev_set_tech_level(id, level)
	if _tech_spins.has(id):
		(_tech_spins[id] as SpinBox).set_value_no_signal(lv)
	return lv


## 开发区的科技等级数字框（测试看）；导出包里没有，返回 null
func tech_level_spin(id: StringName) -> SpinBox:
	return _tech_spins.get(id, null)


func toggle_unlock(id: StringName) -> bool:
	var on := flow.toggle_unlock(id)
	if _unlock_btns.has(id):
		(_unlock_btns[id] as Button).set_pressed_no_signal(on)
	return on


func _refresh() -> void:
	_refresh_shelf_labels()
	_fit_wh_cloth()
	# 090：带回来的没清不再拦，只提示（开局屏里到地上，出发就没了）
	if _tab_btns.has("warehouse"):
		(_tab_btns["warehouse"] as Button).tooltip_text = pending_text()     # 226 批二：那句提示挪进页签的悬浮窗
	for id in _tech_spins:     # 119：科技页点亮 / 升级了，开发区的数字框跟上
		(_tech_spins[id] as SpinBox).set_value_no_signal(TechService.level(flow.meta, id))
