## 保险箱屏（092，作者定）：叠在地图上的一层。左边是保险箱的格子（大小按局外规则，初始 3×3），右边是背包（棋盘 + 暂存区）。
##
## 放进保险箱的道具**视为已带出**：结算时不管撤离还是行动失败都进局外（结算屏单独一格看得见）。包放不进去（局外不留包）。
## 拖着放、双击放（棋盘双击 → 保险箱；保险箱双击 → 试着回棋盘，放不下进暂存区）。「收起」= 回地图，站在这个点上随时能再开。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

var _safe: GridInventory = null
var _view: InventoryView
var _drag: DragLayer
var _line: Label
var _inv: Control = null


func open(payload: Dictionary) -> void:
	_safe = flow.run.safe
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(0, 0))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("保险箱　%d × %d 格%s" % [_safe.size.x, _safe.size.y, "　点 %d" % node.id if node != null else ""], 16, UiPalette.FG))
	left.add_child(_wrapped("放进来的东西就算带出去了：结算时不管撤离还是行动失败都进仓库。包放不进来。拖过来，或双击棋盘上的东西。", 12, UiPalette.DIM, 340))
	_view = InventoryView.new()
	_view.label_font = font
	_view.inventory = _safe
	_view.show_adjacency = false
	_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_view)
	_line = _label("", 13, UiPalette.HEAL)
	left.add_child(_line)
	var buttons := _hbox(8)
	var back := _button("收起", to_map, 13, UiPalette.Tier.PRIMARY)
	back.tooltip_text = "回到地图；站在这个点上随时能再开（Esc）"
	buttons.add_child(back)
	left.add_child(buttons)

	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
	inv.quick_target = _safe     # 棋盘上双击 → 进保险箱
	inv.hint_sink = func(text: String): _line.text = text
	_inv = inv
	row.add_child(inv)
	_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(uid))
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(_view)
	# 包不进保险箱（局外不留包，MetaState.keeps）
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		return target != _safe or MetaState.keeps(inst.def)
	var tip := HoverTip.new(font)
	add_child(tip)
	tip.watch(_view)
	_safe.changed.connect(_refresh)
	_refresh()


#region 公开动作
## 保险箱里的一件回背包（放不下进暂存区）。测试直接调
func take_back(uid: int) -> bool:
	var inst := _safe.get_item(uid)
	if inst == null:
		return false
	if InventoryService.transfer_auto(_safe, uid, flow.run.board):
		return true
	if InventoryService.transfer_auto(_safe, uid, flow.run.storage):
		_line.text = "背包放不下「%s」，放进了暂存区" % Names.of(inst.def)
		return true
	return false


## 棋盘 / 暂存区里的一件放进保险箱。测试直接调；包不收
func put_in(uid: int) -> bool:
	var run := flow.run
	var from: ItemContainer = run.board if run.board.has_item(uid) else (run.storage if run.storage.has_item(uid) else null)
	if from == null:
		return false
	var inst := from.get_item(uid)
	if inst == null or not MetaState.keeps(inst.def):
		_line.text = "包放不进保险箱"
		return false
	if InventoryService.transfer_auto(from, uid, _safe):
		return true
	_line.text = "保险箱放不下「%s」" % Names.of(inst.def)
	return false


## 收起：回地图（站在这个点上随时能再开）
func to_map() -> bool:
	return flow.hide_overlay()


func escape() -> bool:
	return to_map()


func safe_view() -> InventoryView:
	return _view
#endregion


func _refresh() -> void:
	if _line == null or _safe == null:
		return
	var value := 0
	for inst in _safe.items():
		value += ItemValue.of((inst as ItemInstance).def)
	_line.text = "保险箱里 %d 件、值 %d 币 —— 已视为带出" % [_safe.item_count(), value]
