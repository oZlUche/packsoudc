## 容器屏（063；作者：搜索和战利品本质上是同一个界面，只是装载的生成规则不同）。
##
## 左边是渐进揭示的容器（[LootView]），右边是自己的棋盘与暂存区，同一层拖拽盖着三块 —— 亮出来的直接拖走。
## 装的是**尸体容器 / 待拾取**（payload 带 `container`）时按钮是「快速搜索 / 全部拾取 / 离开（剩下的不要了）」；
## 装的是**搜索会话**（payload 带 `session`）时容器是会话的收获箱，多一个「再搜一次」和风险行，每搜一次只对新来的走时间线；
## 遭遇会话就结束，流程接着放回放。在搜索屏里已经亮过的（`flow.seen_loot`）到了待拾取不再重新揭示。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

var _container: GridInventory = null
var _session: SearchSession = null
var _loot: LootView
var _drag: DragLayer
var _line: Label
var _log: RichTextLabel = null
var _skip_btn: Button
var _search_btn: Button = null


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	if _session != null:
		_container = _session.haul_box
	else:
		_container = payload.get("container", null)
		if _container == null:
			_container = flow.run.pending_loot
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(0, 0))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("搜索点 %d　每搜一次更险，随时可以走" % (node.id if node != null else -1) if _session != null else "战利品　拖到棋盘或暂存区带走",
		16, UiPalette.FG))
	_loot = LootView.new()
	_loot.label_font = font
	_loot.inventory = _container
	_loot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_loot)
	_line = _label("", 13, UiPalette.FG)
	left.add_child(_line)
	if _session != null:
		_log = _log_box(12)
		_log.custom_minimum_size.y = 72
		left.add_child(_log)
	var buttons := _hbox(8)
	if _session != null:
		_search_btn = _button("再搜一次", search, 13)
		buttons.add_child(_search_btn)
	_skip_btn = _button("快速搜索", skip_reveal, 13)
	buttons.add_child(_skip_btn)
	buttons.add_child(_button("全部拾取（进暂存区）", take_all, 13))
	buttons.add_child(_button("离开" if _session != null else "离开（剩下的不要了）", leave, 13))
	left.add_child(buttons)

	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
	row.add_child(inv)
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(_loot)

	_loot.item_revealed.connect(func(_uid: int): _refresh())
	_loot.reveal_finished.connect(_refresh)
	if _session != null:
		_session.searched.connect(_on_searched)
		_session.haul_changed.connect(func(box: GridInventory):
			_container = box
			_loot.inventory = box)
	elif _container != null:
		_loot.mark_revealed(flow.seen_loot.keys())
		_container.changed.connect(_on_container_changed)
		_loot.start_reveal()
	_refresh()


#region 公开动作
func search() -> void:
	if _session != null and _session.can_search():
		_session.search()


func skip_reveal() -> void:
	_loot.skip()


## 全进暂存区（先全亮）。搜索会话里就是把收获箱搬空
func take_all() -> void:
	_loot.reveal_all()
	if _session != null:
		InventoryService.transfer_all(_container, flow.run.storage)
		_refresh()
	else:
		flow.take_all_loot()


func leave() -> void:
	if _session != null:
		_session.leave()
	else:
		flow.discard_loot()


func loot_view() -> LootView:
	return _loot


func is_search() -> bool:
	return _session != null
#endregion


func _on_searched(found: Array[StringName], met: Dictionary) -> void:
	if _log != null:
		_log.append_text("[color=#8b93a1]这一次空手[/color]\n" if found.is_empty() else "翻出 %d 件……\n" % found.size())
		if not met.is_empty():
			_log.append_text("[color=#d9534f]—— 有敌人！[/color]\n")
	if met.is_empty():
		_loot.start_reveal()
	_refresh()


func _on_container_changed() -> void:
	_refresh()
	if _container.item_count() == 0 and not _drag.is_dragging():
		flow.discard_loot()


func _refresh() -> void:
	if _container == null or _line == null:
		return
	var revealed := _container.item_count() - _loot.unrevealed_count()
	if _session != null:
		_line.text = "还能搜 %d 次，下一次遭遇 %.0f%%　　收获 %d 件（亮了 %d 件）" % [
			_session.searches_left(), _session.next_encounter_chance() * 100.0, _container.item_count(), revealed]
		_search_btn.disabled = not _session.can_search()
	else:
		var total := 0
		for inst in _container.items():
			var item := inst as ItemInstance
			if _loot.is_revealed(item.uid):
				total += ItemValue.of(item.def)
		_line.text = "%d 件，亮了 %d 件，已知的值 %d 币" % [_container.item_count(), revealed, total]
	_skip_btn.disabled = _loot.unrevealed_count() == 0
