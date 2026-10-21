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
## 225（作者 18:27 定包架）：包也带回来了、照旧铺着（这时棋盘要求包）；最左一列是**包架**（[BagRackView]），
## 「一键置入」货进仓库、包进包架；从棋盘拖空包只能落包架，包架上的包只在包架里挪。
extends MarginContainer

const ContainerScreenScript := preload("res://ui/game/container_screen.gd")

signal changed()

## 两块格子之间的空隙
const ROW_GAP := 20.0
## 带回来的棋盘最少显示几行（再高就滚）
const BOARD_MIN_ROWS := 6
## 177 补 1.1：一键置入的提示行最多列几个放不下的名字
const STUCK_SHOWN := 3
## 224（作者 15:19：所有棋盘都显示外框和格线）：带回来的背包套素皮带框（`board/frame_player`，和战利品屏右边同一张九宫格），格子离框外沿这么远
const BOARD_FRAME_PAD := 24
const BOARD_FRAME_ART := "res://assets/ui/board/frame_player.png"

var _meta: MetaState = null
var _flow: GameFlow = null
var _font: Font
var _drag: DragLayer
## 163：仓库分页（结算屏自己建；基地是右半边那一块）
var _shelf: WarehousePages = null
var _own_shelf := true
var _board_box: VBoxContainer
## 225：包架（挂牌 + 一列）与它的视图
var _rack_box: Control = null
var _rack_view: BagRackView = null
var _board_view: InventoryView
var _board_label: Label = null
var _board_scroll: ScrollContainer = null
var _line: Label
var _store_btn: Button
var _tidy_btn: Button
var _size_label: Label = null
## 224：结算屏第二页 —— 「一键置入」「整理」换石键图按钮（补充二 180 × 67，字由代码写），按钮行间隔 14；在 [method setup] 之前设
var art_buttons := false
## 224 补充二：带回来的棋盘格子定死这个边长（结算屏 72，同背包窗）；0 = 跟仓库一样大。在 [method setup] 之前设
var board_cell := 0.0
var _buttons: HBoxContainer = null
## 230：悬浮窗「出售」怎么卖一件（`func(uid) -> int`）；基地屏换成自己的（写出售页那一行）。不给 = 直接卖、存档
var sell_one: Callable = Callable()


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

	_rack_box = BagRackView.boxed(_meta.rack, _font)
	_rack_view = BagRackView.view_in(_rack_box)
	row.add_child(_rack_box)
	_board_box = UiTheme.vbox(6)
	row.add_child(_board_box)

	if _own_shelf:
		if art_buttons:     # 224（作者 16:32）：仓库连同分页签右对齐，带回来的背包仍靠左
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)
		var right := UiTheme.vbox(6)
		row.add_child(right)
		_size_label = UiTheme.make_label("", 13, UiPalette.DIM)
		_size_label.visible = not art_buttons     # 224：结算屏不写裸露的说明字（字照旧更新，只是不显示）
		right.add_child(_size_label)
		_shelf = WarehousePages.new()
		right.add_child(_shelf)

	_line = UiTheme.make_label("", 13, UiPalette.FG)
	_line.visible = not art_buttons
	col.add_child(_line)
	var buttons := UiTheme.hbox(14 if art_buttons else 8)
	_buttons = buttons
	col.add_child(buttons)
	_store_btn = _small_button(UiText.t("wh.store_all"), store_all)
	buttons.add_child(_store_btn)
	_tidy_btn = _small_button(UiText.t("wh.tidy"), tidy)
	buttons.add_child(_tidy_btn)

	if _drag == null:
		_drag = DragLayer.new()
		_drag.label_font = _font
		add_child(_drag)     # 容器把它铺满，盖在两块格子上
	_drag.register_view(_rack_view)     # 225
	_rack_view.item_double_clicked.connect(quick_move)
	if not _drag.drop_filter.is_valid():
		_drag.drop_filter = _allow_drop
	if _own_shelf:
		_shelf.setup(_meta.warehouse, _font, _drag, TechWarehousePages.plan_of(_flow.tech_defs))
		_drag.register_view(_shelf.view)
		_shelf.view.item_double_clicked.connect(quick_move)
		_shelf.view.actions_for = func(uid: int) -> Array: return warehouse_actions(uid, true)     # 230
	_shelf.page_changed.connect(func(_i: int): _refresh())     # 「整理」只管当前页：翻页了按钮跟着亮灭
	_rebuild_board_view()


func _small_button(text: String, handler: Callable) -> Button:
	if art_buttons:
		var en := UiText.lang == "en"     # 补充二：英文「Put all away」26 号顶满，小一号
		return UiTheme.make_art_text_button(text, handler, "result/btn_small_stone", Vector2(180, 67), Vector2(90, 33), 22 if en else 26, 7.0)
	return UiTheme.make_button(text, handler, UiPalette.Tier.SECONDARY, 13)


## 224：按钮那一行（结算屏把「继续」靠右放进来）
func button_row() -> HBoxContainer:
	return _buttons


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
	_board_label.visible = not art_buttons
	_board_box.add_child(_board_label)
	_sync_board_label()
	_board_view = InventoryView.new()
	_board_view.label_font = _font
	_board_view.inventory = _meta.board
	_board_view.show_adjacency = false
	_board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if board_cell > 0.0:
		_board_view.cell_px = board_cell
	else:
		_board_view.cell_px = _shelf.view.cell_px if _shelf != null and _shelf.view != null else InventoryView.CELL     # 139：和仓库一样大
	_board_view.seams = ContainerScreenScript.board_layout().get("cell_seams", {})     # 224：格缝同战利品屏
	_board_scroll = ScrollBox.wrap(_board_view, BOARD_MIN_ROWS)     # 带回来的棋盘也可能很高：竖向滚动
	_board_scroll.set_meta("tight", true)
	ScrollBox.set_rows(_board_scroll, _board_view, BOARD_MIN_ROWS)
	var frame := PanelContainer.new()
	frame.name = "BoardFrame"
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.add_theme_stylebox_override("panel", board_frame_box())
	frame.add_child(_board_scroll)
	_board_box.add_child(frame)
	_drag.register_view(_board_view)
	_board_view.item_double_clicked.connect(quick_move)     # 视图每次新建，信号跟着重接
	_board_view.actions_for = board_actions     # 230


## 224：带回来的背包的外框（素皮带框九宫格，四边 54、中段平铺；格子缩进 [constant BOARD_FRAME_PAD]）。没图 = 空框只留边距
static func board_frame_box() -> StyleBox:
	var piece: Dictionary = (ContainerScreenScript.board_layout().get("pieces", {}) as Dictionary).get("player", {})
	var tex := EventImage.load_texture(BOARD_FRAME_ART) if ResourceLoader.exists(BOARD_FRAME_ART) else null
	var box: StyleBox
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.set_texture_margin_all(float(piece.get("margin", 54)))
		sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sbt.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		box = sbt
	else:
		box = StyleBoxEmpty.new()
	box.set_content_margin_all(float(piece.get("cells_offset", BOARD_FRAME_PAD)))
	return box


## 164：带回来的背包的格子边长（基地按中列宽和右边仓库一起算）
func set_board_cell(c: float) -> void:
	if _board_view != null:
		_board_view.cell_px = c
		ScrollBox.set_rows(_board_scroll, _board_view, maxi(BOARD_MIN_ROWS, _meta.board.size.y if _meta.board != null else 0))


func board_view() -> InventoryView:
	return _board_view


## 225：包架的视图
func rack_view() -> BagRackView:
	return _rack_view


## 225：包架那一列连同和棋盘的间隔占多宽（基地按中列宽算带回来背包的格子时扣掉）
func rack_room() -> float:
	return (_rack_box.get_combined_minimum_size().x + ROW_GAP) if _rack_box != null else 0.0


## 225：落点规则 —— 包架上的包只在包架里挪（不上带回来的棋盘）；进包架的只能是包（[BagRack] 自己也会拒）
func _allow_drop(inst: ItemInstance, target: ItemContainer) -> bool:
	if inst == null:
		return false
	if _drag != null and _drag.source() == _meta.rack:
		return target == _meta.rack
	return target != _meta.rack or BagRack.holds(inst.def)


## 仓库分页（结算屏自己的，基地是右半边那块）
func shelf() -> WarehousePages:
	return _shelf


## 仓库当前页的视图
func warehouse_view() -> InventoryView:
	return _shelf.view if _shelf != null else null


## 一键置入的提示行。177 补 1.1：放不下的跳过了，列出卡住的名字（最多三个，多的写「等」）
static func store_text(got: Dictionary) -> String:
	var line := UiText.t("wh.stored") % int(got["moved"])
	var names: Array = got.get("stuck_names", [])
	if names.is_empty() and String(got.get("stuck", "")) != "":
		names = [String(got["stuck"])]
	if names.is_empty():
		return line
	var shown := UiText.t("hud.buff_sep").join(PackedStringArray(names.slice(0, STUCK_SHOWN)))
	if names.size() > STUCK_SHOWN:
		shown = UiText.t("wh.and_more") % shown
	return line + UiText.t("wh.stuck") % [int(got["left"]), shown]


#region 公开动作
func store_all() -> Dictionary:
	var got := _flow.store_all()
	if int(got["moved"]) > 0 or int(got["left"]) > 0:
		_line.text = store_text(got)
	changed.emit()
	return got


func discard_board() -> void:
	_flow.discard_board()
	_line.text = UiText.t("wh.board_cleared")
	changed.emit()


## 109：整理仓库**当前页**（163；不动别的页，也不动带回来的棋盘 —— 那块是玩家摆的阵）。排不开就原样不动
func tidy() -> bool:
	var page := _shelf.current_page() if _shelf != null else null
	if page == null:
		return false
	var ok := GridTidy.tidy(page)
	if page.item_count() > 1:
		_line.text = UiText.t("wh.page_tidied") if ok else UiText.t("wh.tidy_failed")
	changed.emit()
	return ok


## 109：双击快速置入 —— 带回来的棋盘 → 仓库（按页序落，落到哪页翻到哪页）；仓库 → 带回来的棋盘（有的话；局外平时没有，双击不做事）
func quick_move(view: ContainerView, uid: int) -> bool:
	var from := view.container() if view != null else null
	var inst := from.get_item(uid) if from != null else null
	if inst == null:
		return false
	var ok := false
	if from == _meta.board and BagRack.holds(inst.def):     # 225：包 → 包架（空包才行）
		ok = not _meta.board.is_bag_with_contents(uid) and _meta.board.remove(uid) != null and _meta.put_bag(inst)
		if not ok:
			_line.text = UiText.t("rack.has_contents") % Names.of(inst.def)
	elif from == _meta.board:
		ok = InventoryService.transfer_auto(_meta.board, uid, _meta.warehouse)
		if not ok:
			_line.text = UiText.t("setup.no_room_warehouse") % Names.of(inst.def)
		else:
			if _shelf != null:
				_shelf.show_item(uid)
	elif _meta.warehouse.owns(from) and _meta.board != null:
		ok = InventoryService.transfer_auto(_meta.warehouse, uid, _meta.board)
		if not ok:
			_line.text = UiText.t("wh.board_no_room") % Names.of(inst.def)
	if ok:
		changed.emit()
	return ok
#endregion


#region 230 悬浮窗按钮
## 带回来的背包上一件：置入仓库 / 收进包架（包）→ 锁定
func board_actions(uid: int) -> Array:
	var inst := _meta.board.get_item(uid) if _meta.board != null else null
	if inst == null:
		return []
	var bag := BagRack.holds(inst.def)
	var quick := ItemActions.make(&"quick", UiText.t("act.to_rack" if bag else "act.store"), func(): quick_move(_board_view, uid))
	if bag and _meta.board.is_bag_with_contents(uid):
		ItemActions.disable(quick, UiText.t("act.bag_full"))
	return [quick, ItemActions.lock(inst, _meta.board, _saved)]


## 仓库里一件：（[param with_quick] 且有带回来的背包时）摆上背包 → 锁定 | 锁定同类 → 出售 | 出售同类
func warehouse_actions(uid: int, with_quick: bool) -> Array:
	var inst := _meta.warehouse.get_item(uid)
	if inst == null:
		return []
	var out: Array = []
	if with_quick and _meta.board != null:
		out.append(ItemActions.make(&"quick", UiText.t("act.to_board"), func(): quick_move(_shelf.view, uid)))
	var page := _shelf.current_page() if _shelf != null else null
	out.append(ItemActions.lock(inst, page if page != null and page.has_item(uid) else _meta.warehouse, _saved))
	out.append(ItemActions.lock_same(inst, _meta.warehouse, _saved))
	var seller := sell_one if sell_one.is_valid() else _sell
	var price_of := func(i: ItemInstance) -> int: return MetaState.sell_price(i.def, _flow.sell_ratio())
	out.append(ItemActions.sell(inst, price_of.call(inst), seller))
	out.append(ItemActions.sell_same(inst, _meta.warehouse, price_of, seller))
	return out


func _sell(uid: int) -> int:
	var got := _flow.sell_item(uid)
	if got >= 0:
		changed.emit()
	return got


## 锁了 / 解了：存档、重画
func _saved() -> void:
	_flow.save_meta()
	if _shelf != null and _shelf.view != null:
		_shelf.view.queue_redraw()
	if _board_view != null:
		_board_view.queue_redraw()
#endregion


## 作者 2026-10-13：搬空了棋盘留着，标签说一声已清空
func _sync_board_label() -> void:
	if _board_label == null or _meta.board == null:
		return
	_board_label.text = UiText.t("wh.board_label_empty") if _meta.board.item_count() == 0 else UiText.t("wh.board_label")


func _refresh() -> void:
	if _meta.board == null and _board_view != null or _meta.board != null and (_board_view == null or _board_view.inventory != _meta.board):
		_rebuild_board_view()
	if _size_label != null:
		_size_label.text = UiText.t("wh.size_label") % [_meta.warehouse.page_count(), _meta.warehouse.size.x, _meta.warehouse.size.y]
	_sync_board_label()
	var pending := _meta.has_pending_board()
	_store_btn.disabled = not pending
	_store_btn.visible = _meta.board != null     # 178：没有带回来的背包就不摆「一键置入」（基地「仓库」页只剩整理）
	var page := _shelf.current_page() if _shelf != null else null
	_tidy_btn.disabled = page == null or page.item_count() <= 1
	if _line != null and _line.text == "":
		_line.text = UiText.t("wh.pending") % _meta.board.item_count() if pending else UiText.t("wh.count") % _meta.warehouse.item_count()
