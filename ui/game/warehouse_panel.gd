## 仓库面板（058 第 7 条）：左边是撤离带回来的棋盘（有的话），右边是仓库的格子，同一套拖拽；「一键置入」按栏位顺序逐件放，
## 放不下就停在那一件提示；「剩下的不要了」清掉带回来的棋盘。结算屏与局外屏共用。
##
## 109（作者定）：「整理」把仓库重排（先大后小，占用的聚左上，见 [GridTidy]）；两块格子都能双击快速置入（和局内一样）。
##
## 带回来的棋盘是一块不要求包的格子：包已经不在（只计图鉴），东西位置照旧 —— 作者说的「包统一替换成最大的默认背景包」。
extends MarginContainer

signal changed()

var _meta: MetaState = null
var _flow: GameFlow = null
var _font: Font
var _drag: DragLayer
var _board_box: VBoxContainer
var _board_view: InventoryView = null
var _warehouse_view: InventoryView
var _line: Label
var _store_btn: Button
var _discard_btn: Button
var _tidy_btn: Button
var _size_label: Label


func setup(flow: GameFlow, font: Font) -> void:
	_flow = flow
	_meta = flow.meta
	_font = font
	_build()
	_meta.changed.connect(_refresh)
	_meta.warehouse.changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	_board_box = VBoxContainer.new()
	_board_box.add_theme_constant_override("separation", 6)
	row.add_child(_board_box)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	_size_label = _label("", 13, UiPalette.DIM)
	right.add_child(_size_label)
	_warehouse_view = InventoryView.new()
	_warehouse_view.label_font = _font
	_warehouse_view.inventory = _meta.warehouse
	_warehouse_view.show_adjacency = false
	_warehouse_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# 110：扩建后仓库会很高，竖向滚动。反馈：最小高度压到 4 行（约 240），有空间再长，别把结算屏的按钮挤出窗口
	var wh_scroll := ScrollBox.wrap(_warehouse_view, 4)
	wh_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(wh_scroll)
	_warehouse_view.item_double_clicked.connect(quick_move)

	_line = _label("", 13, UiPalette.FG)
	col.add_child(_line)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	_store_btn = _button("一键置入", store_all)
	buttons.add_child(_store_btn)
	_discard_btn = _button("剩下的不要了", discard_board)
	buttons.add_child(_discard_btn)
	_tidy_btn = _button("整理", tidy)
	buttons.add_child(_tidy_btn)

	_drag = DragLayer.new()
	_drag.label_font = _font
	add_child(_drag)     # 容器把它铺满，盖在两块格子上
	_drag.register_view(_warehouse_view)
	_rebuild_board_view()


## 带回来的棋盘换了（置入完了、丢了、新的一局带回来）就重画那一块
func _rebuild_board_view() -> void:
	# 审查 A3：旧视图先从拖拽层撤登记 —— 只 queue_free 的话拖拽层还拿着它，之后拖仓库里的东西会碰到已释放的视图、卡在「正在拖」
	if _board_view != null and _drag != null:
		_drag.unregister_view(_board_view)
	for child in _board_box.get_children():
		child.queue_free()
	_board_view = null
	if _meta.board == null:
		_board_box.visible = false
		return
	_board_box.visible = true
	_board_box.add_child(_label("带回来的背包　位置照旧，包已换成默认背景", 13, UiPalette.DIM))
	_board_view = InventoryView.new()
	_board_view.label_font = _font
	_board_view.inventory = _meta.board
	_board_view.show_adjacency = false
	_board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_board_box.add_child(ScrollBox.wrap(_board_view, 6))     # 带回来的棋盘也可能很高：同样竖向滚动
	_drag.register_view(_board_view)
	_board_view.item_double_clicked.connect(quick_move)     # 视图每次新建，信号跟着重接


#region 公开动作
func store_all() -> Dictionary:
	var got := _flow.store_all()
	if int(got["moved"]) > 0 or int(got["left"]) > 0:
		_line.text = "放进 %d 件%s" % [int(got["moved"]),
			"；仓库放不下，卡在「%s」，还剩 %d 件 —— 挪一挪仓库，或者不要了" % [got["stuck"], int(got["left"])] if String(got["stuck"]) != "" else ""]
	changed.emit()
	return got


func discard_board() -> void:
	_flow.discard_board()
	_line.text = "带回来的背包清空了"
	changed.emit()


## 109：整理仓库（只动仓库，不动带回来的棋盘 —— 那块是玩家摆的阵）。排不开就原样不动
func tidy() -> bool:
	var ok := GridTidy.tidy(_meta.warehouse)
	if _meta.warehouse.item_count() > 1:
		_line.text = "仓库整理好了" if ok else "这堆东西排不开，没动"
	changed.emit()
	return ok


## 109：双击快速置入 —— 带回来的棋盘 → 仓库；仓库 → 带回来的棋盘（有的话；局外平时没有，双击不做事）
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
		elif _meta.board.item_count() == 0:
			_meta.discard_board()     # 搬空了 = 和「一键置入」搬完一样，带回来的背包就没了
	elif from == _meta.warehouse and _meta.board != null:
		ok = InventoryService.transfer_auto(_meta.warehouse, uid, _meta.board)
		if not ok:
			_line.text = "带回来的背包里放不下「%s」" % Names.of(inst.def)
	if ok:
		changed.emit()
	return ok


func has_pending() -> bool:
	return _meta.has_pending_board()
#endregion


func _refresh() -> void:
	if _meta.board == null and _board_view != null or _meta.board != null and (_board_view == null or _board_view.inventory != _meta.board):
		_rebuild_board_view()
	_size_label.text = "仓库　%d × %d 格，不需要包" % [_meta.warehouse.size.x, _meta.warehouse.size.y]     # 110：扩建后跟着变
	var pending := _meta.has_pending_board()
	_store_btn.disabled = not pending
	_discard_btn.disabled = not pending
	_tidy_btn.disabled = _meta.warehouse.item_count() <= 1
	if _line != null and _line.text == "":
		_line.text = "带回来的背包里还有 %d 件：置入或不要了；不管的话开局屏里它们到地上，出发就没了" % _meta.board.item_count() if pending else "仓库 %d 件" % _meta.warehouse.item_count()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.label(l, font_size, color)     # 121：字体在主题里，颜色先选变体
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UiPalette.style_button(b, UiPalette.Tier.SECONDARY, UiPalette.button_font_size(13, UiPalette.Tier.SECONDARY))     # 090
	b.pressed.connect(handler)
	return b
