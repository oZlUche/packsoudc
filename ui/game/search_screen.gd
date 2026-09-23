## 搜索点（M6-2，架构文档 6.2 / 5.4.2）：搜几次是玩家的旋钮。每搜一次，找到的东西落进收获容器、一件一件亮出来，
## 再掷一次遭遇 —— 中了会话就结束，流程接着放战斗回放。亮出来的可以直接拖到棋盘或暂存区；离开时剩下的进战利品屏
## （那里不再重新揭示：flow 记得哪些已经见过）。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

var _session: SearchSession = null
var _loot: LootView
var _drag: DragLayer
var _line: Label
var _log: RichTextLabel
var _search_btn: Button
var _skip_btn: Button


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(0, 0))
	var row := _hbox(24)
	panel.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("搜索点 %d　每搜一次更险，随时可以走" % (node.id if node != null else -1), 16, UiPalette.FG))
	_loot = LootView.new()
	_loot.label_font = font
	_loot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_loot)
	_line = _label("", 13, UiPalette.FG)
	left.add_child(_line)
	_log = _log_box(12)
	_log.custom_minimum_size.y = 72
	left.add_child(_log)
	var buttons := _hbox(8)
	_search_btn = _button("搜一次", search, 13)
	buttons.add_child(_search_btn)
	_skip_btn = _button("快速搜索", skip_reveal, 13)
	buttons.add_child(_skip_btn)
	buttons.add_child(_button("离开", leave, 13))
	left.add_child(buttons)

	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
	row.add_child(inv)
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(_loot)

	if _session != null:
		_loot.inventory = _session.haul_box
		_loot.item_revealed.connect(func(_uid: int): _refresh())
		_loot.reveal_finished.connect(_refresh)
		_session.searched.connect(_on_searched)
		_session.haul_changed.connect(func(box: GridInventory): _loot.inventory = box)
		# 读档回来接着搜：已经搜过的那几次的收获早就在待拾取里了，这里的容器从空开始
	_refresh()


#region 公开动作
func search() -> void:
	if _session != null and _session.can_search():
		_session.search()


func skip_reveal() -> void:
	_loot.skip()


func leave() -> void:
	if _session != null:
		_session.leave()


func loot_view() -> LootView:
	return _loot
#endregion


func _on_searched(found: Array[StringName], met: Dictionary) -> void:
	if found.is_empty():
		_log.append_text("[color=#8b93a1]这一次空手[/color]\n")
	else:
		_log.append_text("翻出 %d 件……\n" % found.size())
	if not met.is_empty():
		_log.append_text("[color=#d9534f]—— 有敌人！[/color]\n")
		return      # 会话结束了，流程接着放回放，这一屏马上撤
	_loot.start_reveal()
	_refresh()


func _refresh() -> void:
	if _session == null or _line == null:
		return
	_line.text = "还能搜 %d 次，下一次遭遇 %.0f%%　　收获 %d 件（亮了 %d 件）" % [
		_session.searches_left(), _session.next_encounter_chance() * 100.0,
		_session.haul_box.item_count(), _session.haul_box.item_count() - _loot.unrevealed_count()]
	_search_btn.disabled = not _session.can_search()
	_skip_btn.disabled = _loot.unrevealed_count() == 0
