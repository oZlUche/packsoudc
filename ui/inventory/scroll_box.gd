## 110：把一块格子视图包进只竖向滚动的容器（仓库扩建后最多 26 行，一屏放不下）。
## 宽度跟格子走，高度最多 [param max_rows] 行；拖拽的落点换算见 [method DragLayer.visible_rect]
class_name ScrollBox
extends RefCounted


static func wrap(view: InventoryView, max_rows: int = 10) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var cols := view.inventory.size.x if view.inventory != null else 8
	var rows := view.inventory.size.y if view.inventory != null else max_rows
	sc.custom_minimum_size = Vector2(cols * InventoryView.CELL + 14.0, mini(rows, max_rows) * InventoryView.CELL)
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sc.add_child(view)
	if view.inventory != null:     # 仓库长高了（扩建）：窗口跟着长到上限为止
		var inv := view.inventory
		inv.changed.connect(func():
			if is_instance_valid(sc):
				sc.custom_minimum_size.y = mini(inv.size.y, max_rows) * InventoryView.CELL)
	return sc
