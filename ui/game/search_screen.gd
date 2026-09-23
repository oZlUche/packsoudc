## 搜索点（M6-1 的最小版）：搜几次是玩家的旋钮（5.4.2 / 6.2）。每搜一次列出找到的、更新遭遇概率；
## 中了遭遇会话就结束，流程接着放战斗回放。渐进揭示是 M6-2 的事。
extends GameScreen

var _session: SearchSession = null
var _line: Label
var _found: RichTextLabel
var _search_btn: Button


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(520, 0))
	var col := _vbox(10)
	panel.add_child(col)
	col.add_child(_label("搜索点 %d" % (node.id if node != null else -1), 18, UiPalette.FG))
	col.add_child(_wrapped("每搜一次先找几件，再掷一次遭遇：搜得越多越险。随时可以离开，找到的东西带走。", 12, UiPalette.DIM, 480))
	_line = _label("", 14, UiPalette.FG)
	col.add_child(_line)
	_found = _log_box(13)
	_found.custom_minimum_size.y = 140
	col.add_child(_found)
	var row := _hbox(8)
	_search_btn = _button("搜一次", search, 14)
	row.add_child(_search_btn)
	row.add_child(_button("离开", leave, 14))
	col.add_child(row)
	if _session != null:
		_session.searched.connect(_on_searched)
		for id in _session.found:
			_found.append_text(_item_line(flow.items.get_def(id)) + "\n")
	_refresh()


func search() -> void:
	if _session != null and _session.can_search():
		_session.search()


func leave() -> void:
	if _session != null:
		_session.leave()


func _on_searched(found: Array[StringName], met: Dictionary) -> void:
	if found.is_empty():
		_found.append_text("[color=#8b93a1]这一次空手[/color]\n")
	for id in found:
		_found.append_text(_item_line(flow.items.get_def(id)) + "\n")
	if not met.is_empty():
		_found.append_text("[color=#d9534f]—— 有敌人！[/color]\n")
	_refresh()


func _refresh() -> void:
	if _session == null:
		return
	_line.text = "还能搜 %d 次，下一次遭遇 %.0f%%" % [_session.searches_left(), _session.next_encounter_chance() * 100.0]
	_search_btn.disabled = not _session.can_search()
