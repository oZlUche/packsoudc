## 容器屏（063；作者：搜索和战利品本质上是同一个界面，只是装载的生成规则不同）。
##
## 左边是渐进揭示的容器（[LootView]），右边是自己的棋盘与暂存区，同一层拖拽盖着三块 —— 亮出来的直接拖走。
## 装的是**尸体容器 / 待拾取**（payload 带 `container`）时按钮是「快速搜索 / 全部拾取 / 收起」—— 收起只是回地图，没拿的留在这个点上，
## 地图上「回到这个点」能再开，走了才没（084）；
## 装的是**搜索会话**（payload 带 `session`）时容器是会话的收获箱：这一屏就是**刚搜的那一次**（084 作者定的循环：事件屏选「搜索」
## 自动搜一次 → 这里亮出来拖走 → 「关闭」回事件屏再搜 / 走）；没亮的只对新来的走时间线；遭遇那一次不开这一屏。
## 在这一屏亮过的（`flow.seen_loot`）再开不重新揭示。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")

var _container: GridInventory = null
var _session: SearchSession = null
var _loot: LootView
var _drag: DragLayer
var _line: Label
var _log: RichTextLabel = null
var _skip_btn: Button
var _leave_btn: Button = null


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
	left.add_child(_label("搜索点 %d　第 %d 次翻找" % [node.id if node != null else -1, _session.searches_done] if _session != null else "战利品　拖到棋盘或暂存区带走",
		16, UiPalette.FG))
	_loot = LootView.new()
	_loot.label_font = font
	_loot.inventory = _container
	# 每档稀有度搜几秒是节点规则里的数（058 第 5 条）：会话有自己的规则，尸体容器用这一局的
	var search_rules: SearchRules = _session.rules if _session != null else (flow.run.node_rules.search if flow.run != null and flow.run.node_rules != null else null)
	if search_rules != null and not search_rules.reveal_seconds.is_empty():
		_loot.reveal_seconds = search_rules.reveal_seconds
	_loot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_loot)
	_line = _label("", 13, UiPalette.FG)
	left.add_child(_line)
	if _session != null:
		_log = _log_box(12)
		_log.custom_minimum_size.y = 72
		left.add_child(_log)
	var buttons := _hbox(8)
	_skip_btn = _button("快速搜索", skip_reveal, 13)
	buttons.add_child(_skip_btn)
	buttons.add_child(_button("全部拾取（进暂存区）", take_all, 13))
	if _session != null:
		buttons.add_child(_button("关闭（回到事件：再搜 / 走）", close_search, 13))
		buttons.add_child(_button("收起（回地图）", to_map, 13))
	else:
		_leave_btn = _button("收起（剩下的留在这里，走了就没）", to_map, 13)
		buttons.add_child(_leave_btn)
	left.add_child(buttons)

	var inv := InventoryPanelScript.new()
	_drag = DragLayer.new()
	_drag.label_font = font
	inv.setup(flow.run, font, _drag)
	row.add_child(inv)
	_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_drag)
	_drag.register_view(_loot)
	# 没亮的只能在容器里挪位（换「下一个」是谁），拖出去要等亮了 —— 作者定的。
	# 只锁容器里没亮的那几件：自己棋盘上的包与道具随便挪（084 修：原来按 is_revealed 判，把玩家自己的东西也卡住了）
	_drag.drop_filter = func(inst: ItemInstance, target: ItemContainer) -> bool:
		return not _loot.is_locked(inst.uid) or target == _container

	_loot.item_revealed.connect(func(uid: int):
		flow.seen_loot[uid] = true     # 084：收起再开不重新揭示
		_refresh())
	_loot.reveal_finished.connect(_refresh)
	if _session != null:
		_session.searched.connect(_on_searched)
		_session.haul_changed.connect(func(box: GridInventory):
			_container = box
			_loot.inventory = box)
		# 084：这一屏打开时那一次已经搜完了：亮新来的，见过的不重放
		_loot.mark_revealed(flow.seen_loot.keys())
		_loot.start_reveal()
	elif _container != null:
		_loot.mark_revealed(flow.seen_loot.keys())
		_container.changed.connect(_on_container_changed)
		_loot.start_reveal()
	_refresh()


#region 公开动作
## 084：关闭搜索屏回到事件屏（再搜一次 / 走由事件的选项定）
func close_search() -> bool:
	return flow.close_search()


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


## 搜索会话：离开这个点的搜索（收获交到待拾取）。待拾取：同「收起」—— 剩下的留在这个点上，走了才没（084）
func leave() -> void:
	if _session != null:
		_session.leave()
	else:
		to_map()


## 084：收起回地图，什么都不结束：会话还开着 / 没拿的还在这个点上，地图上「回到这个点」能再开
func to_map() -> bool:
	return flow.hide_overlay()


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
	var searching := "　正在搜一件（%.1f 秒）" % _loot.current_seconds() if _loot.is_revealing() else ""
	if _session != null:
		var tail := "这里搜完了" if _session.is_exhausted() else "还能搜 %d 次，再搜遭遇 %.0f%%" % [_session.searches_left(), _session.next_encounter_chance() * 100.0]
		_line.text = "收获 %d 件（亮了 %d 件）%s　　%s　　拖走想要的，关闭回到事件" % [_container.item_count(), revealed, searching, tail]
	else:
		var total := 0
		for inst in _container.items():
			var item := inst as ItemInstance
			if _loot.is_revealed(item.uid):
				total += ItemValue.of(item.def)
		_line.text = "%d 件，亮了 %d 件，已知的值 %d 币%s" % [_container.item_count(), revealed, total, searching]
	_skip_btn.disabled = _loot.unrevealed_count() == 0
