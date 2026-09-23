## 战利品（M6-1 的最小版）：尸体容器 / 搜索收获摆在一个容器里，全拿进暂存区，或不要了。
## 渐进揭示与拖到棋盘上（6.2）是 M6-2 的事。
extends GameScreen

var _container: GridInventory = null


func open(payload: Dictionary) -> void:
	_container = payload.get("container", flow.run.pending_loot)
	var panel := _centered_panel(Vector2(520, 0))
	var col := _vbox(10)
	panel.add_child(col)
	col.add_child(_label("战利品", 18, UiPalette.FG))
	if _container != null:
		var view := InventoryView.new()
		view.label_font = font
		view.inventory = _container
		view.show_adjacency = false
		view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(view)
		var list := _log_box(13)
		list.custom_minimum_size.y = 24 * mini(8, _container.item_count() + 1)
		var total := 0
		for inst in _container.items():
			var def := (inst as ItemInstance).def
			total += ItemValue.of(def)
			list.append_text(_item_line(def) + "\n")
		list.append_text("一共 %d 件，值 %d 币" % [_container.item_count(), total])
		col.add_child(list)
	var row := _hbox(8)
	row.add_child(_button("全部拾取（进暂存区）", take_all, 14))
	row.add_child(_button("不要了", discard, 14))
	col.add_child(row)


func take_all() -> void:
	flow.take_all_loot()


func discard() -> void:
	flow.discard_loot()
