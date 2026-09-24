## 背包整理面板（M6）：一局里的作战棋盘 + 暂存区，同一套拖拽（M1 的 [DragLayer]）。
##
## 拖一下就重新编译一次读数（生命、预估 DPS、套装进度）—— 编译是纯函数（4.2），这条读数永远和真打出来的一致。
## 地图屏把它叠在地图上；出发前、走到哪都能开。战斗中不会开：战斗在开打那一瞬就算完了，回放是叠层，挡着它。
##
## 是个 MarginContainer：容器按内容定大小，拖拽层作为它的第二个子节点自然铺满同一块矩形 —— 一个普通 Control
## 不会从子节点算最小尺寸，放进竖排布局里会被压成零高。
extends MarginContainer

const STORAGE_WIDTH := 220

var _run: RunState = null
var _font: Font
var _drag: DragLayer
var _readout: Label
var _hint: Label
var board_view: InventoryView
var storage_view: StashView


## [param drag] 给了就把两个视图登记到那一层（战利品屏要一层盖住三个容器）；不给就自己造一层盖在面板上
func setup(run: RunState, font: Font, drag: DragLayer = null) -> void:
	_run = run
	_font = font
	_drag = drag
	_build()
	_run.board.changed.connect(_refresh_readout)
	_refresh_readout()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(_label("作战棋盘　只有包里的东西参战", 13, UiPalette.DIM))
	board_view = InventoryView.new()
	board_view.label_font = _font
	board_view.inventory = _run.board
	board_view.show_adjacency = true
	board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(board_view)
	_readout = _label("", 14, UiPalette.FG)
	left.add_child(_readout)
	_hint = _label("左键拖动　R 旋转　右键 / Esc 取消　压着别人放手会把人顶出来", 11, UiPalette.DIM)
	left.add_child(_hint)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(_label("暂存区　背着但不参战，撤离时不带出去", 13, UiPalette.DIM))
	storage_view = StashView.new()
	storage_view.label_font = _font
	storage_view.stash = _run.storage
	storage_view.custom_minimum_size.x = STORAGE_WIDTH
	storage_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(storage_view)

	if _drag == null:
		_drag = DragLayer.new()
		_drag.label_font = _font
		add_child(_drag)     # 容器把它铺到和 row 一样大，盖在上面
	_drag.register_view(board_view)
	_drag.register_view(storage_view)
	_drag.stash = _run.storage
	_drag.items_displaced.connect(_on_displaced)


func _refresh_readout() -> void:
	var spec := _run.compile_player()
	var lines: Array[String] = []
	if _run.tracker != null:
		for set_id in _run.tracker.tracked_ids():
			var p := _run.tracker.progress_of(set_id)
			lines.append("%s %d/%s%s" % [set_id, p["count"], "—" if p["next"] < 0 else str(p["next"]), "　已激活" if p["active"] else ""])
	var dormant := FaithState.dormant_uids(_run.board).size()
	_readout.text = "%s%s　生命 %d　预估 DPS %.1f　参战 %d 件（%d 件会出手）　可用格 %d（空 %d）%s" % [
		_run.faith_line(), "（%d 件休眠）" % dormant if dormant > 0 else "",
		spec.max_hp_int(), spec.rough_dps(), spec.items.size(), spec.active_items().size(),
		_run.board.usable_cell_count(), _run.board.free_cell_count(),
		"　套装：" + "、".join(lines) if not lines.is_empty() else ""]


func _on_displaced(instances: Array, grabbed: bool) -> void:
	var names: Array[String] = []
	for inst in instances:
		var item := inst as ItemInstance
		names.append(item.def.display_name if item.def != null else "?")
	_hint.text = "顶出了「%s」，已经拿在手上" % names[0] if grabbed else "顶出了 %d 件（%s），都放进暂存区了" % [names.size(), "、".join(names)]


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
