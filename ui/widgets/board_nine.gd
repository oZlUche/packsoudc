## 255 补充一（作者 2026-10-26 10:51「所有面板的尺寸不变，不应棋盘大小而变化，改成最宽 9 格，低于九格时增加内距」）：
## 棋盘（连同它的框）坐在这一格里 —— 宽永远按 [constant CharacterDef.BOARD_MAX_W] 格 + 框两边的缩进，窄的棋盘水平居中，差额就是内距。
## 格子边长跟着 [member view]（基地按中列宽算格），框缩进是 [member pad]；高照子节点
class_name BoardNine
extends Container

## 量格子边长的那块棋盘
var view: InventoryView = null
## 框每边从外沿到格子的缩进（没框 = 0）
var pad := 0.0


## 把 [param c]（棋盘的框，或没框的棋盘本身）原地套进一格九格宽的位子；[param p_view] 是里面那块棋盘
static func hold(c: Control, p_view: InventoryView, p_pad: float) -> BoardNine:
	var n := BoardNine.new()
	n.name = "BoardNine"
	n.view = p_view
	n.pad = p_pad
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	n.size_flags_vertical = c.size_flags_vertical
	var parent := c.get_parent()
	if parent != null:
		var at := c.get_index()
		parent.remove_child(c)
		parent.add_child(n)
		parent.move_child(n, at)
	n.add_child(c)
	if p_view != null:
		p_view.cell_px_changed.connect(n.update_minimum_size)
	return n


## 九格宽（框在内）；棋盘本身比九格还宽时按它自己的
func width() -> float:
	var cell := view.cell_px if view != null else InventoryView.CELL
	var cols := maxi(CharacterDef.BOARD_MAX_W, view.inventory.size.x if view != null and view.inventory != null else 0)
	return cols * cell + 2.0 * pad


## [param cols] 列、格边长 [param cell] 的棋盘在九格宽的位子里往右挪多少（自己摆框的屏用：背包窗、搜刮屏）
static func offset_for(cols: int, cell: float) -> float:
	return floorf(maxi(0, CharacterDef.BOARD_MAX_W - cols) * cell * 0.5)


func _child() -> Control:
	for c in get_children():
		if c is Control and (c as Control).visible:
			return c
	return null


func _get_minimum_size() -> Vector2:
	var c := _child()
	var m := c.get_combined_minimum_size() if c != null else Vector2.ZERO
	return Vector2(maxf(width(), m.x), m.y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c is Control:
				var s := (c as Control).get_combined_minimum_size()
				fit_child_in_rect(c, Rect2(Vector2(floorf((size.x - s.x) * 0.5), 0.0), Vector2(s.x, size.y)))
