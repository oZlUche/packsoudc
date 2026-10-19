## 事件结果页的「收获」行（157）：这次事件给的那几件。东西本身已经落在地上（[RunState] 收的），这一行只是按 uid
## 把它们摆成一排、能直接拖进棋盘 —— 背后的容器就是地上，拖拽层登记这块视图就行，不另开一个容器（存档里没有它）。
##
## 拖走一件，这一行少一件；没拖的留在地上。双击 = 进包（由事件屏接 [signal ContainerView.item_double_clicked]）
class_name HarvestRow
extends ContainerView

const CELL := 40.0
const GAP := 12.0

var stash: ItemStash = null
var label_font: Font = null
## 这次给的那几件（按给的先后）
var uids: Array[int] = []


func setup(p_stash: ItemStash, p_uids: Array[int]) -> void:
	stash = p_stash
	uids = p_uids.duplicate()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if stash != null and not stash.changed.is_connected(_on_changed):
		stash.changed.connect(_on_changed)
	_on_changed()


func container() -> ItemContainer:
	return stash


## 还在地上的那几件（拖走的不算）
func shown() -> Array[int]:
	var out: Array[int] = []
	if stash == null:
		return out
	for uid in uids:
		if stash.get_item(uid) != null:
			out.append(uid)
	return out


## 每件一块：[uid, 画布上的矩形]，从左往右排，底对齐
func layout() -> Array:
	var out: Array = []
	var x := 0.0
	var tall := 0.0
	for uid in shown():
		var inst := stash.get_item(uid)
		var box := Vector2(inst.def.shape.size_rotated(inst.rotation)) * CELL if inst.def != null else Vector2(CELL, CELL)
		out.append([uid, Rect2(Vector2(x, 0), box)])
		x += box.x + GAP
		tall = maxf(tall, box.y)
	return out


func uid_at_local(p: Vector2) -> int:
	for pair in layout():
		if (pair[1] as Rect2).has_point(p):
			var inst := stash.get_item(int(pair[0]))
			var c := Vector2i(((p - (pair[1] as Rect2).position) / CELL).floor())
			if inst.def.cells_rotated(inst.rotation).has(c):
				return int(pair[0])
	return -1


func _on_changed() -> void:
	var w := 0.0
	var h := 0.0
	for pair in layout():
		var r := pair[1] as Rect2
		w = r.end.x
		h = maxf(h, r.size.y)
	custom_minimum_size = Vector2(w, h)
	visible = w > 0.0
	queue_redraw()


func _exit_tree() -> void:
	if stash != null and stash.changed.is_connected(_on_changed):
		stash.changed.disconnect(_on_changed)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var uid := uid_at_local(mb.position)
	if uid < 0:
		return
	if mb.double_click:
		item_double_clicked.emit(self, uid)
	else:
		grab_requested.emit(self, uid, mb.position)
	accept_event()


func _draw() -> void:
	if stash == null:
		return
	var font := label_font if label_font != null else get_theme_default_font()
	for pair in layout():
		var inst := stash.get_item(int(pair[0]))
		if inst == null or inst.def == null:
			continue
		var cells := inst.def.cells_rotated(inst.rotation)
		var at := (pair[1] as Rect2).position
		if ItemPainter.draw_art(self, inst.def, inst.rotation, at, CELL, Color.WHITE, Transform2D.IDENTITY, ItemPainter.variant_of(inst)):     # 201
			continue
		ItemPainter.draw_item(self, cells, at, CELL, ItemPainter.body_color(inst.def), ItemPainter.rarity_color(inst.def))
		ItemPainter.draw_label(self, cells, at, CELL, Names.of_item(inst), font, 12, ItemPainter.label_color(inst.def))
