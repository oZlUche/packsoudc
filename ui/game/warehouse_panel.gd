## 仓库面板（058 第 7 条）：左边是撤离带回来的棋盘（有的话），右边是仓库的格子，同一套拖拽；「一键置入」按栏位顺序逐件放，
## 放不下就停在那一件提示；「剩下的不要了」清掉带回来的棋盘。结算屏与局外屏共用。
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
	col.add_child(row)

	_board_box = VBoxContainer.new()
	_board_box.add_theme_constant_override("separation", 6)
	row.add_child(_board_box)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	right.add_child(_label("仓库　%d × %d 格，不需要包" % [_meta.warehouse.size.x, _meta.warehouse.size.y], 13, UiPalette.DIM))
	_warehouse_view = InventoryView.new()
	_warehouse_view.label_font = _font
	_warehouse_view.inventory = _meta.warehouse
	_warehouse_view.show_adjacency = false
	_warehouse_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(_warehouse_view)

	_line = _label("", 13, UiPalette.FG)
	col.add_child(_line)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	_store_btn = _button("一键置入", store_all)
	buttons.add_child(_store_btn)
	_discard_btn = _button("剩下的不要了", discard_board)
	buttons.add_child(_discard_btn)

	_drag = DragLayer.new()
	_drag.label_font = _font
	add_child(_drag)     # 容器把它铺满，盖在两块格子上
	_drag.register_view(_warehouse_view)
	_rebuild_board_view()


## 带回来的棋盘换了（置入完了、丢了、新的一局带回来）就重画那一块
func _rebuild_board_view() -> void:
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
	_board_box.add_child(_board_view)
	_drag.register_view(_board_view)


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


func has_pending() -> bool:
	return _meta.has_pending_board()
#endregion


func _refresh() -> void:
	if _meta.board == null and _board_view != null or _meta.board != null and (_board_view == null or _board_view.inventory != _meta.board):
		_rebuild_board_view()
	var pending := _meta.has_pending_board()
	_store_btn.disabled = not pending
	_discard_btn.disabled = not pending
	if _line != null and _line.text == "":
		_line.text = "带回来的背包里还有 %d 件：置入或不要了；不管的话开局屏里它们进暂存区，出发就没了" % _meta.board.item_count() if pending else "仓库 %d 件" % _meta.warehouse.item_count()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(handler)
	return b
