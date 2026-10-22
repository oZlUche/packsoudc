## 保险箱屏（092，作者定）：叠在地图上的一层。左边是保险箱的格子（大小按局外规则，初始 3×3），右边是背包（棋盘 + 地上）。
##
## 放进保险箱的道具**视为已带出**：结算时不管撤离还是行动失败都进局外（结算屏单独一格看得见）。包放不进去（局外不留包）。
## 拖着放、双击放（棋盘双击 → 保险箱；保险箱双击 → 试着回棋盘，放不下到地上）。
## 作者定：**关上（里面有东西）就送回基地、不能再改动**，走开也算关上；空着关只是收起，还能再开。
extends GameScreen

var _safe: GridInventory = null
var _module: SafeModule = null
var _view: InventoryView
var _inv: InventoryPanelScript = null


func open(payload: Dictionary) -> void:
	_module = SafeModule.of(flow.run)     # 101：保险箱是一局的模块
	_safe = _module.inventory if _module != null else null
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(0, 0))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	_frame_title(UiText.t("safe.title") % [_safe.size.x, _safe.size.y])     # 157：标题在石板框的标题条上
	_view = InventoryView.new()
	_view.label_font = font
	_view.inventory = _safe
	_view.show_adjacency = false
	_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_view)
	BoardFrame.wrap(_view)     # 227：素框 + 格缝
	var buttons := _hbox(8)
	var back := ScrollKey.make(UiText.t("safe.close"), to_map)     # 乙 石刻：商店纸卷键
	back.tooltip_text = UiText.t("safe.intro") + "\n" + UiText.t("safe.close_tip")     # 226 批二：说明并进「关上」的悬浮窗，重复的那句警告删了
	buttons.add_child(back)
	left.add_child(buttons)

	_inv = _mount_bag(row, _view, Callable(), _safe)     # 棋盘上双击 → 进保险箱；226 批一：回话走告示层
	_view.item_double_clicked.connect(func(_v: ContainerView, uid: int): take_back(uid))
	_tip_double(_view, "act.take_back")     # 230
	_tip_quick(_inv, "act.to_safe", func(inst: ItemInstance) -> String:
		return "" if MetaState.keeps(inst.def) else UiText.t("safe.no_bags"))
	# 包不进保险箱（局外不留包，MetaState.keeps）
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		return _is_open() and (target != _safe or MetaState.keeps(inst.def))
	_safe.changed.connect(_refresh)
	_refresh()


## 保险箱还能改动（装了、没锁）
func _is_open() -> bool:
	return _module != null and _module.is_open()


#region 公开动作
## 保险箱里的一件回背包（放不下到地上）。测试直接调
func take_back(uid: int) -> bool:
	var inst := _safe.get_item(uid)
	if inst == null or not _is_open():
		return false
	var where := _take_to_player(_safe, uid)
	if where == "storage":
		say(UiText.t("safe.to_ground") % Names.of(inst.def))
	return where != ""


## 棋盘 / 地上的一件放进保险箱。测试直接调；包不收
func put_in(uid: int) -> bool:
	var run := flow.run
	if not _is_open():
		say(UiText.t("safe.locked"))
		return false
	var from := run.holder_of(uid)
	if from == null:
		return false
	var inst := from.get_item(uid)
	if inst == null or not MetaState.keeps(inst.def):
		say(UiText.t("safe.no_bags"))
		return false
	if InventoryService.transfer_auto(from, uid, _safe):
		return true
	say(UiText.t("safe.no_room") % Names.of(inst.def))
	return false


## 关上：里面有东西就锁上送回基地（屏关掉）；空着只是收起。返回 true = 离开了这一屏
func to_map() -> bool:
	flow.close_safe()
	return true


func escape() -> bool:
	return to_map()


func safe_view() -> InventoryView:
	return _view
#endregion


func _refresh() -> void:
	if _safe == null:
		return
	# 226 批一：状态行删了 —— 件数并进标题条
	_frame_title(UiText.t("safe.title_count") % [_safe.size.x, _safe.size.y, _safe.item_count()])
