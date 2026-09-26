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
## 087：信仰那一句单独一个标签，停上去开悬浮窗（具体效果、信力怎么涨）
var _faith_label: Label
var _hint: Label
var board_view: InventoryView
var storage_view: StashView
var tip: HoverTip
var _stamina: Label
## 084：棋盘上双击的东西优先去这里（容器屏设成战利品 / 收获箱）；null = 去暂存区
var quick_target: ItemContainer = null
## 双击之后的提示回调（容器屏想自己写）：`func(text: String)`
var hint_sink: Callable = Callable()


## [param drag] 给了就把两个视图登记到那一层（战利品屏要一层盖住三个容器）；不给就自己造一层盖在面板上
func setup(run: RunState, font: Font, drag: DragLayer = null) -> void:
	_run = run
	_font = font
	_drag = drag
	_build()
	_run.board.changed.connect(_refresh_readout)
	_refresh_readout()


func _build() -> void:
	# 087（作者定）：棋盘在上、暂存区在下（容器屏：左上容器、右上背包、右下暂存区）
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(_label("作战棋盘　只有包里的东西参战　拖出棋盘 = 放进暂存区", 13, UiPalette.DIM))
	board_view = InventoryView.new()
	board_view.label_font = _font
	board_view.inventory = _run.board
	board_view.show_adjacency = true
	board_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(board_view)
	_faith_label = _label("", 14, UiPalette.FG)
	_faith_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_faith_label.mouse_entered.connect(func():
		if tip != null:
			tip.show_text(FaithTooltip.describe(_run.active_faith(), _run.faith_power, _run.items), _faith_label.global_position + Vector2(0, _faith_label.size.y)))
	_faith_label.mouse_exited.connect(func():
		if tip != null:
			tip.hide_tip())
	left.add_child(_faith_label)
	_readout = _label("", 14, UiPalette.FG)
	left.add_child(_readout)
	# 084：耐力消耗评估（低 / 中 / 高 / 极高），停上去看每秒消耗与回复
	_stamina = _label("", 13, UiPalette.STAMINA)
	_stamina.mouse_filter = Control.MOUSE_FILTER_STOP
	_stamina.mouse_entered.connect(func():
		if tip != null:
			tip.show_text(StaminaEstimate.describe(_run.compile_player()), _stamina.global_position + Vector2(0, _stamina.size.y)))
	_stamina.mouse_exited.connect(func():
		if tip != null:
			tip.hide_tip())
	left.add_child(_stamina)
	_hint = _label("左键拖动　双击快速置入　R 旋转　右键 / Esc 取消　压着别人放手会把人顶出来　放到棋盘外就进暂存区", 11, UiPalette.DIM)
	left.add_child(_hint)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(_label("暂存区（不限大小）　不参战、留在这个点（回来能拿）、撤离不带出去", 13, UiPalette.DIM))
	storage_view = StashView.new()
	storage_view.label_font = _font
	storage_view.stash = _run.storage
	storage_view.custom_minimum_size.x = maxf(STORAGE_WIDTH, _run.board.size.x * InventoryView.CELL)
	storage_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(storage_view)

	if _drag == null:
		_drag = DragLayer.new()
		_drag.label_font = _font
		add_child(_drag)     # 容器把它铺到和 row 一样大，盖在上面
	_drag.register_view(board_view)
	_drag.register_view(storage_view)
	_drag.stash = _run.storage
	_drag.drop_outside_to_stash = true     # 084：棋盘外的空间全都是暂存区
	_drag.items_displaced.connect(_on_displaced)
	# 087 合成（作者定）：相邻即合 —— 棋盘上两件有配方的挨着，走到下一个点时自动合成；拖起一件时能合的那几件高光，
	# 挨上了画「合」并提示一句
	_drag.craft = func(a: ItemInstance, b: ItemInstance) -> ItemDef: return _run.craft_output(a.def, b.def)
	_run.board.changed.connect(_refresh_badges)
	_refresh_badges()
	# 084：停在道具上的悬浮说明（名、稀有度、标签、效果、武器的冷却与 DPS、槽）
	tip = HoverTip.new(_font)
	add_child(tip)
	tip.watch(board_view)
	tip.watch(storage_view)
	board_view.item_double_clicked.connect(quick_move)
	storage_view.item_double_clicked.connect(quick_move)


## 084：双击快速置入。暂存区 → 棋盘（放不下就提示）；棋盘 → quick_target（容器屏的战利品 / 收获箱），没有就 → 暂存区。返回挪了没有
func quick_move(view: ContainerView, uid: int) -> bool:
	var from := view.container()
	var inst := from.get_item(uid) if from != null else null
	if inst == null:
		return false
	if from == _run.storage:
		if InventoryService.transfer_auto(_run.storage, uid, _run.board):
			return true
		_hint_text("背包里没有空间放「%s」" % inst.def.display_name)
		return false
	if from == _run.board:
		if quick_target != null and InventoryService.transfer_auto(_run.board, uid, quick_target):
			return true
		if InventoryService.transfer_auto(_run.board, uid, _run.storage):
			if quick_target != null:
				_hint_text("容器里放不下「%s」，放进了暂存区" % inst.def.display_name)
			return true
	return false


var _pair_keys: Dictionary = {}


## 相邻、有配方的两件都画「合」；新挨上一对就提示一句
func _refresh_badges() -> void:
	var marks := {}
	var keys := {}
	for pair in _run.craft_pairs():
		var a: ItemInstance = pair[0]
		var b: ItemInstance = pair[1]
		var out: ItemDef = pair[2]
		marks[a.uid] = "合"
		marks[b.uid] = "合"
		var key := "%d:%d" % [a.uid, b.uid]
		keys[key] = true
		if not _pair_keys.has(key):
			_hint_text("「%s」和「%s」挨在一起：走到下一个点时合成「%s」" % [a.def.display_name, b.def.display_name, out.display_name])
	_pair_keys = keys
	board_view.badges = marks
	board_view.queue_redraw()


func _hint_text(text: String) -> void:
	_hint.text = text
	if hint_sink.is_valid():
		hint_sink.call(text)


func _refresh_readout() -> void:
	var spec := _run.compile_player()
	if _stamina != null:
		var e := StaminaEstimate.of(spec)
		_stamina.text = "耐力消耗：%s（每秒 %.1f，回 %.1f）　停上去看细节" % [e["rating"], e["cost"], e["regen"]]
	var lines: Array[String] = []
	if _run.tracker != null:
		for set_id in _run.tracker.tracked_ids():
			var p := _run.tracker.progress_of(set_id)
			lines.append("%s %d/%s%s" % [set_id, p["count"], "—" if p["next"] < 0 else str(p["next"]), "　已激活" if p["active"] else ""])
	var dormant := FaithState.dormant_uids(_run.board).size()
	var power := _run.faith_power.line() if _run.faith_power != null else ""
	if _faith_label != null:
		_faith_label.text = "%s%s%s　停上去看效果与信力怎么涨" % [_run.faith_line(), "（%d 件休眠）" % dormant if dormant > 0 else "", "　" + power if power != "" else ""]
	_readout.text = "生命 %d　预估 DPS %.1f　参战 %d 件（%d 件会出手）　可用格 %d（空 %d）%s" % [
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
