## 商店（M6-1 的最小版，6.6）：货架上每格一个按钮（名字 + 价），刷新一个按钮，离开一个按钮。买到的进暂存区（RunState 接的）。
extends GameScreen

var _session: ShopSession = null
var _shelf: VBoxContainer
var _refresh_btn: Button
var _wallet_line: Label


func open(payload: Dictionary) -> void:
	_session = payload.get("session", null)
	var node: MapNode = payload.get("node", null)
	var panel := _centered_panel(Vector2(520, 0))
	var col := _vbox(10)
	panel.add_child(col)
	col.add_child(_label("商店 %d" % (node.id if node != null else -1), 18, UiPalette.FG))
	_wallet_line = _label("", 13, UiPalette.DIM)
	col.add_child(_wallet_line)
	_shelf = _vbox(6)
	col.add_child(_shelf)
	var row := _hbox(8)
	_refresh_btn = _button("", refresh_stock, 14)
	row.add_child(_refresh_btn)
	row.add_child(_button("收起（回地图，店还开着）", to_map, 14))
	row.add_child(_button("离开", leave, 14))
	col.add_child(row)
	if _session != null:
		_session.stock_changed.connect(_rebuild)
		_session.bought.connect(func(_def: ItemDef, _price: int): _rebuild())
		flow.run.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _rebuild())
	_rebuild()


func buy(i: int) -> bool:
	return _session != null and _session.buy(i) != null


func refresh_stock() -> bool:
	return _session != null and _session.refresh()


func leave() -> void:
	if _session != null:
		_session.leave()


## 084：收起回地图，店还开着（地图上「回到这个点」能再开）；走了才算离开
func to_map() -> bool:
	return flow.hide_overlay()


func _rebuild() -> void:
	if _session == null or _shelf == null:
		return
	for child in _shelf.get_children():
		child.queue_free()
	_wallet_line.text = "货币 %d　买到的进暂存区" % flow.run.wallet.balance
	for i in _session.stock.size():
		var def := flow.items.get_def(StringName(String(_session.stock[i]["id"])))
		var idx := i
		var sold := _session.sold.has(i)
		var row := _hbox(10)
		var b := _button("已售" if sold else "买　%d 币" % int(_session.stock[i]["price"]), func(): buy(idx), 13)
		b.custom_minimum_size.x = 110
		b.disabled = not _session.can_buy(i)
		row.add_child(b)
		var line := _log_box(13)
		line.fit_content = true
		line.scroll_active = false
		line.custom_minimum_size.x = 320
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.append_text(_item_line(def) if not sold else "[color=#8b93a1]%s[/color]" % (def.display_name if def != null else "?"))
		row.add_child(line)
		_shelf.add_child(row)
	_refresh_btn.text = "刷新（%d 币）" % _session.refresh_cost()
	_refresh_btn.disabled = not _session.can_refresh()
