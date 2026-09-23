## 战利品（M6-2，架构文档 6.2）：尸体容器 / 搜索收获摆在左边的 [LootView] 里，一件一件亮出来；右边是自己的棋盘与暂存区，
## 同一套拖拽（M1 的 [DragLayer]）—— 想带走的直接拖到棋盘或暂存区，剩下的离开时不要了。
##
## 「快速搜索」把揭示推到终点；「全部拾取」全进暂存区。在搜索屏里已经亮过的（`flow.seen_loot`）不再走时间线。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

var _container: GridInventory = null
var _loot: LootView
var _drag: DragLayer
var _line: Label
var _skip_btn: Button


func open(payload: Dictionary) -> void:
	_container = payload.get("container", flow.run.pending_loot)
	if _container == null:
		_container = flow.run.pending_loot
	var panel := _centered_panel(Vector2(0, 0))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("战利品　拖到棋盘或暂存区带走", 16, UiPalette.FG))
	_loot = LootView.new()
	_loot.label_font = font
	_loot.inventory = _container
	_loot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_loot)
	_line = _label("", 13, UiPalette.DIM)
	left.add_child(_line)
	var buttons := _hbox(8)
	_skip_btn = _button("快速搜索", skip_reveal, 13)
	buttons.add_child(_skip_btn)
	buttons.add_child(_button("全部拾取（进暂存区）", take_all, 13))
	buttons.add_child(_button("离开（剩下的不要了）", leave, 13))
	left.add_child(buttons)

	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
	row.add_child(inv)

	# 拖拽层盖在整屏最上面：它按各视图的全局矩形找落点，画在自己身上
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(_loot)

	if _container != null:
		_loot.mark_revealed(flow.seen_loot.keys())
		_loot.item_revealed.connect(func(_uid: int): _refresh_line())
		_loot.reveal_finished.connect(_refresh_line)
		_container.changed.connect(_on_container_changed)
		_loot.start_reveal()
	_refresh_line()


#region 公开动作
func skip_reveal() -> void:
	_loot.skip()


## 全进暂存区（先全亮）
func take_all() -> void:
	_loot.reveal_all()
	flow.take_all_loot()


## 剩下的不要了
func leave() -> void:
	flow.discard_loot()


func loot_view() -> LootView:
	return _loot
#endregion


func _on_container_changed() -> void:
	_refresh_line()
	# 都拖走了就不用留在这儿
	if _container.item_count() == 0 and not _drag.is_dragging():
		flow.discard_loot()


func _refresh_line() -> void:
	if _container == null or _line == null:
		return
	var total := 0
	var revealed := 0
	for inst in _container.items():
		var item := inst as ItemInstance
		if _loot.is_revealed(item.uid):
			revealed += 1
			total += ItemValue.of(item.def)
	_line.text = "%d 件，亮了 %d 件，已知的值 %d 币" % [_container.item_count(), revealed, total]
	_skip_btn.disabled = _loot.unrevealed_count() == 0
