## 110：把一块格子视图包进只竖向滚动的容器（仓库扩建后最多 26 行，一屏放不下）。
## 宽度跟格子走，高度最多 [param max_rows] 行；拖拽的落点换算见 [method DragLayer.visible_rect]
class_name ScrollBox
extends RefCounted


static func wrap(view: InventoryView, max_rows: int = 10) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.set_meta("max_rows", max_rows)
	_fit(sc, view, max_rows)
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sc.add_child(view)
	# 仓库长高了（扩建）、格子放大了（139）：窗口跟着变，高到上限为止
	var refit := func():
		if is_instance_valid(sc):
			_fit(sc, view, int(sc.get_meta("max_rows", max_rows)))
	if view.inventory != null:
		view.inventory.changed.connect(refit)
	view.cell_px_changed.connect(refit)
	return sc


## 改最多显示几行（仓库页按可用高度算，作者 2026-10-12：放得下就整块显示，超了才滚）
static func set_rows(sc: ScrollContainer, view: InventoryView, max_rows: int) -> void:
	if sc == null or view == null:
		return
	sc.set_meta("max_rows", max_rows)
	_fit(sc, view, max_rows)


static func _fit(sc: ScrollContainer, view: InventoryView, max_rows: int) -> void:
	var cols := view.inventory.size.x if view.inventory != null else 8
	var rows := view.inventory.size.y if view.inventory != null else max_rows
	# 224：套了外框的（meta `tight`）不滚时不留滚动条那 14 px —— 框贴着格子
	var bar := 0.0 if bool(sc.get_meta("tight", false)) and rows <= max_rows else 14.0
	sc.custom_minimum_size = Vector2(cols * view.cell_px + bar, mini(rows, max_rows) * view.cell_px)
