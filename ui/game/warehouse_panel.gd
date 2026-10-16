## 仓库面板（058 第 7 条）：左边是撤离带回来的棋盘（有的话），右边是仓库（163：分页，[WarehousePages]），同一套拖拽；「一键置入」按栏位顺序逐件放，
## 放不下就停在那一件提示；（按钮已去掉，[method discard_board] 留给代码调用）清掉带回来的棋盘。
##
## 109（作者定）：「整理」把仓库**当前页**重排（163；先大后小，占用的聚左上，见 [GridTidy]）；两块格子都能双击快速置入（和局内一样），
## 置入落到哪页仓库就翻到哪页。
##
## 两种用法：
## - 结算屏：[method setup] 只给 flow 与字体 —— 面板自己建仓库分页、自己的拖拽层，格子 60；
## - 基地「家」页（164）：[method setup] 再给基地右半边常驻的 [param shelf] 与整屏的拖拽层 —— 面板只剩带回来的背包和下面两颗按钮，
##   仓库在右半边，跨列拖拽走那一层。
##
## 带回来的棋盘是一块不要求包的格子：包已经不在（只计图鉴），东西位置照旧 —— 作者说的「包统一替换成最大的默认背景包」。
extends MarginContainer

signal changed()

## 两块格子之间的空隙
const ROW_GAP := 20.0
## 带回来的棋盘最少显示几行（再高就滚）
const BOARD_MIN_ROWS := 6
## 177 补 1.1：一键置入的提示行最多列几个放不下的名字
const STUCK_SHOWN := 3

var _meta: MetaState = null
var _flow: GameFlow = null
var _font: Font
var _drag: DragLayer
## 163：仓库分页（结算屏自己建；基地是右半边那一块）
var _shelf: WarehousePages = null
var _own_shelf := true
var _board_box: VBoxContainer
var _board_view: InventoryView
var _board_label: Label = null
var _board_scroll: ScrollContainer = null
var _line: Label
var _store_btn: Button
var _tidy_btn: Button
var _size_label: Label = null


## [param shelf] / [param drag] 给了 = 基地「家」页（仓库在别处、拖拽层是整屏那一层）
func setup(flow: GameFlow, font: Font, shelf: WarehousePages = null, drag: DragLayer = null) -> void:
	_flow = flow
	_meta = flow.meta
	_font = font
	_shelf = shelf
	_own_shelf = shelf == null
	_drag = drag
	_build()
	_meta.changed.connect(_refresh)
	_meta.warehouse.changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var col := UiTheme.vbox(8)
	add_child(col)
	var row := UiTheme.hbox(int(ROW_GAP))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	_board_box = UiTheme.vbox(6)
	row.add_child(_board_box)

	if _own_shelf:
		var right := UiTheme.vbox(6)
		row.add_child(right)
		_size_label = UiTheme.make_label("", 13, UiPalette.DIM)
		right.add_child(_size_label)
		_shelf = WarehousePages.new()
		right.add_child(_shelf)

	_line = UiTheme.make_label("", 13, UiPalette.FG)
	col.add_child(_line)
	var buttons := UiTheme.hbox(8)
	col.add_child(buttons)
	_store_btn = UiTheme.make_button("一键置入", store_all, UiPalette.Tier.SECONDARY, 13)
	buttons.add_child(_store_btn)
	_tidy_btn = UiTheme.make_button("整理", tidy, UiPalette.Tier.SECONDARY, 13)
	buttons.add_child(_tidy_btn)

	if _drag == null:
		_drag = DragLayer.new()
		_drag.label_font = _font
		add_child(_drag)     # 容器把它铺满，盖在两块格子上
	if _own_shelf:
		_shelf.setup(_meta.warehouse, _font, _drag, TechWarehousePages.plan_of(_flow.tech_defs))
		_drag.register_view(_shelf.view)
		_shelf.view.item_double_clicked.connect(quick_move)
	_shelf.page_changed.connect(func(_i: int): _refresh())     # 「整理」只管当前页：翻页了按钮跟着亮灭
	_rebuild_board_view()


## 带回来的棋盘换了（置入完了、丢了、新的一局带回来）就重画那一块
func _rebuild_board_view() -> void:
	# 审查 A3：旧视图先从拖拽层撤登记 —— 只 queue_free 的话拖拽层还拿着它，之后拖仓库里的东西会碰到已释放的视图、卡在「正在拖」
	if _board_view != null and _drag != null:
		_drag.unregister_view(_board_view)
	UiTheme.clear_children(_board_box)
	_board_view = null
	_board_label = null
	_board_scroll = null
	if _meta.board == null:
		_board_box.visible = false
		return
	_board_box.visible = true
	_board_label = UiTheme.make_label("", 13, UiPalette.DIM)
	_board_box.add_child(_board_label)
	_sync_board_label()
	_board_view = InventoryView.new()
	_board_view.label_font = _font
	_board_view.inventory = _meta.board
	_board_view.show_adjacency = false
	_board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_board_view.cell_px = _shelf.view.cell_px if _shelf != null and _shelf.view != null else InventoryView.CELL     # 139：和仓库一样大
	_board_scroll = ScrollBox.wrap(_board_view, BOARD_MIN_ROWS)     # 带回来的棋盘也可能很高：竖向滚动
	_board_box.add_child(_board_scroll)
	_drag.register_view(_board_view)
	_board_view.item_double_clicked.connect(quick_move)     # 视图每次新建，信号跟着重接


## 164：带回来的背包的格子边长（基地按中列宽和右边仓库一起算）
func set_board_cell(c: float) -> void:
	if _board_view != null:
		_board_view.cell_px = c
		ScrollBox.set_rows(_board_scroll, _board_view, maxi(BOARD_MIN_ROWS, _meta.board.size.y if _meta.board != null else 0))


func board_view() -> InventoryView:
	return _board_view


## 仓库分页（结算屏自己的，基地是右半边那块）
func shelf() -> WarehousePages:
	return _shelf


## 仓库当前页的视图
func warehouse_view() -> InventoryView:
	return _shelf.view if _shelf != null else null


## 一键置入的提示行。177 补 1.1：放不下的跳过了，列出卡住的名字（最多三个，多的写「等」）
static func store_text(got: Dictionary) -> String:
	var line := "放进 %d 件" % int(got["moved"])
	var names: Array = got.get("stuck_names", [])
	if names.is_empty() and String(got.get("stuck", "")) != "":
		names = [String(got["stuck"])]
	if names.is_empty():
		return line
	var shown := "、".join(PackedStringArray(names.slice(0, STUCK_SHOWN)))
	if names.size() > STUCK_SHOWN:
		shown += "等"
	return line + "；仓库放不下 %d 件（%s）—— 挪一挪仓库，或者不要了" % [int(got["left"]), shown]


#region 公开动作
func store_all() -> Dictionary:
	var got := _flow.store_all()
	if int(got["moved"]) > 0 or int(got["left"]) > 0:
		_line.text = store_text(got)
	changed.emit()
	return got


func discard_board() -> void:
	_flow.discard_board()
	_line.text = "带回来的背包清空了"
	changed.emit()


## 109：整理仓库**当前页**（163；不动别的页，也不动带回来的棋盘 —— 那块是玩家摆的阵）。排不开就原样不动
func tidy() -> bool:
	var page := _shelf.current_page() if _shelf != null else null
	if page == null:
		return false
	var ok := GridTidy.tidy(page)
	if page.item_count() > 1:
		_line.text = "这一页整理好了" if ok else "这堆东西排不开，没动"
	changed.emit()
	return ok


## 109：双击快速置入 —— 带回来的棋盘 → 仓库（按页序落，落到哪页翻到哪页）；仓库 → 带回来的棋盘（有的话；局外平时没有，双击不做事）
func quick_move(view: ContainerView, uid: int) -> bool:
	var from := view.container() if view != null else null
	var inst := from.get_item(uid) if from != null else null
	if inst == null:
		return false
	var ok := false
	if from == _meta.board:
		ok = InventoryService.transfer_auto(_meta.board, uid, _meta.warehouse)
		if not ok:
			_line.text = "仓库放不下「%s」" % Names.of(inst.def)
		else:
			if _shelf != null:
				_shelf.show_item(uid)
	elif _meta.warehouse.owns(from) and _meta.board != null:
		ok = InventoryService.transfer_auto(_meta.warehouse, uid, _meta.board)
		if not ok:
			_line.text = "带回来的背包里放不下「%s」" % Names.of(inst.def)
	if ok:
		changed.emit()
	return ok
#endregion


## 作者 2026-10-13：搬空了棋盘留着，标签说一声已清空
func _sync_board_label() -> void:
	if _board_label == null or _meta.board == null:
		return
	_board_label.text = "带回来的背包　已清空" if _meta.board.item_count() == 0 else "带回来的背包　位置照旧，包已换成默认背景"


func _refresh() -> void:
	if _meta.board == null and _board_view != null or _meta.board != null and (_board_view == null or _board_view.inventory != _meta.board):
		_rebuild_board_view()
	if _size_label != null:
		_size_label.text = "仓库　%d 页，每页 %d × %d 格，不需要包" % [_meta.warehouse.page_count(), _meta.warehouse.size.x, _meta.warehouse.size.y]
	_sync_board_label()
	var pending := _meta.has_pending_board()
	_store_btn.disabled = not pending
	_store_btn.visible = _meta.board != null     # 178：没有带回来的背包就不摆「一键置入」（基地「仓库」页只剩整理）
	var page := _shelf.current_page() if _shelf != null else null
	_tidy_btn.disabled = page == null or page.item_count() <= 1
	if _line != null and _line.text == "":
		_line.text = "带回来的背包里还有 %d 件：置入仓库；不管的话开局屏里它们到地上，出发就没了" % _meta.board.item_count() if pending else "仓库 %d 件" % _meta.warehouse.item_count()
