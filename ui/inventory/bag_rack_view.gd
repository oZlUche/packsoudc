## 225 包架（补充二 §11.2 / §11.8，美术设计 18:36）：局外的 [BagRack] 画成一列 —— 227 的素框 `board/frame_plain`（铜面板屏用 `_dark`）
## 套着，一格一种包，格与格之间是格缝；同种几只在格右下角挂一枚 `notice/count_badge`「×n」（×1 不挂）。
## 包架也是一块棋盘，归「所有棋盘都显示外框 + 格子」那条规矩管：空的时候也画一格空格。
##
## 拖拽：按下一格 = 拿起这种包的第一只（[signal ContainerView.grab_requested]）；放手在上面由 [DragLayer] 收进包架（只收空包）。
## 双击一格交给宿主（开局屏 = 摆上棋盘；基地出售页 = 卖一只）。挂牌「包架」见 [method boxed]
class_name BagRackView
extends ContainerView

const BOARD_LAYOUT := "res://assets/ui/board/layout.json"
const FRAME_DIR := "board/"
## 一格多大、包在格里留多宽的边
const SLOT := 60.0
const SLOT_PAD := 6.0
const BADGE_ART := "notice/count_badge"
const BADGE_H := 20.0
const BADGE_MIN_W := 28.0
const BADGE_TEXT := 14
const BADGE_INSET := 2.0
const BADGE_INK := Color("2e2219")

var rack: BagRack = null
var label_font: Font = null
## 几列（1 = 竖着一列）
var columns: int = 1
## 铜面板屏用深色石边
var dark := false
## 至少画几格（空的也画，让玩家看得见这是个能放包的地方）
var min_slots: int = 1


func setup(p_rack: BagRack, p_columns: int = 1, p_dark: bool = false) -> BagRackView:
	rack = p_rack
	columns = maxi(1, p_columns)
	dark = p_dark
	mouse_filter = Control.MOUSE_FILTER_STOP
	if rack != null and not rack.changed.is_connected(_on_changed):
		rack.changed.connect(_on_changed)
	_on_changed()
	return self


## 挂牌「包架」+ 这一列，竖着叠在一起（开局屏、基地、结算屏都用这个）
static func boxed(p_rack: BagRack, font: Font, p_columns: int = 1, p_dark: bool = false) -> VBoxContainer:
	var box := UiTheme.vbox(0)
	box.name = "BagRack"
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tag := HeaderTag.hanging(UiText.t("rack.title"))
	var hold := CenterContainer.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold.add_child(tag)
	box.add_child(hold)
	var view := BagRackView.new()
	view.label_font = font
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view.setup(p_rack, p_columns, p_dark))
	return box


## [method boxed] 造的那一组里的视图
static func view_in(box: Control) -> BagRackView:
	for c in box.get_children():
		if c is BagRackView:
			return c
	return null


func container() -> ItemContainer:
	return rack


## 素框（九宫，四边平铺；格子缩进 `cells_offset`）
func _piece() -> Dictionary:
	var layout: Dictionary = {}
	if FileAccess.file_exists(BOARD_LAYOUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BOARD_LAYOUT))
		layout = parsed if parsed is Dictionary else {}
	return ((layout.get("pieces", {}) as Dictionary).get("plain_dark" if dark else "plain", {}) as Dictionary)


func _inset() -> float:
	return float(_piece().get("cells_offset", 16))


func slot_count() -> int:
	return maxi(min_slots, rack.kinds().size() if rack != null else 0)


## 第 i 格（画布坐标）
func slot_rect(i: int) -> Rect2:
	var c := i % columns
	var r := i / columns
	return Rect2(Vector2(_inset() + c * SLOT, _inset() + r * SLOT), Vector2(SLOT, SLOT))


## 按下的那一格是哪种包：那种的第一只的 uid；空格 / 格外 -1（悬浮窗也问它）
func uid_at_local(p: Vector2) -> int:
	if rack == null:
		return -1
	var kinds := rack.kinds()
	for i in kinds.size():
		if slot_rect(i).has_point(p):
			var inst := rack.first_of(kinds[i])
			return inst.uid if inst != null else -1
	return -1


func _on_changed() -> void:
	var n := slot_count()
	var rows := (n + columns - 1) / columns
	var cols := mini(columns, n)
	custom_minimum_size = Vector2(cols * SLOT, rows * SLOT) + Vector2.ONE * 2.0 * _inset()
	queue_redraw()


func _exit_tree() -> void:
	if rack != null and rack.changed.is_connected(_on_changed):
		rack.changed.disconnect(_on_changed)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or not mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	var uid := uid_at_local(mb.position)
	if uid < 0:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		item_context.emit(self, uid)     # 230：右键 = 钉住悬浮窗
	elif mb.double_click:
		item_double_clicked.emit(self, uid)
	else:
		grab_requested.emit(self, uid, mb.position)
	accept_event()


func _draw() -> void:
	_draw_frame()
	if rack == null:
		return
	_draw_seams()
	var kinds := rack.kinds()
	for i in kinds.size():
		var inst := rack.first_of(kinds[i])
		if inst != null:
			_draw_bag(inst, slot_rect(i))
			_draw_badge(rack.count_of(kinds[i]), slot_rect(i))


func _draw_frame() -> void:
	var piece := _piece()
	var tex := UiTheme.art_cached(FRAME_DIR + String(piece.get("file", "frame_plain_dark.png" if dark else "frame_plain.png")).get_basename())
	var r := Rect2(Vector2.ZERO, size)
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.set_texture_margin_all(float(piece.get("margin", 46)))
		sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sbt.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		draw_style_box(sbt, r)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("c9c7c2")
		flat.border_color = Color("8e8b85")
		flat.set_border_width_all(2)
		flat.set_corner_radius_all(4)
		draw_style_box(flat, r)


## 格与格之间的缝（227 `cell_seams`：深线 + 右 / 下错开一点的一条亮线，两端各留 2；外圈不画）
func _draw_seams() -> void:
	var layout: Dictionary = {}
	if FileAccess.file_exists(BOARD_LAYOUT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BOARD_LAYOUT))
		layout = parsed if parsed is Dictionary else {}
	var seams: Dictionary = layout.get("cell_seams", {})
	var dark_c := Color(String(seams.get("seam", "#8e8b85")))
	var hi_c := Color(String(seams.get("hi", "#ebe9e4")))
	var seam_w := float(seams.get("seam_w", 1.6))
	var hi_w := float(seams.get("hi_w", 1.0))
	var hi_off := float(seams.get("hi_offset", 1.4))
	var n := slot_count()
	var rows := (n + columns - 1) / columns
	var cols := mini(columns, n)
	var o := Vector2.ONE * _inset()
	for r in range(1, rows):
		var y := o.y + r * SLOT
		draw_line(Vector2(o.x + 2.0, y), Vector2(o.x + cols * SLOT - 2.0, y), dark_c, seam_w)
		draw_line(Vector2(o.x + 2.0, y + hi_off), Vector2(o.x + cols * SLOT - 2.0, y + hi_off), hi_c, hi_w)
	for c in range(1, cols):
		var x := o.x + c * SLOT
		draw_line(Vector2(x, o.y + 2.0), Vector2(x, o.y + rows * SLOT - 2.0), dark_c, seam_w)
		draw_line(Vector2(x + hi_off, o.y + 2.0), Vector2(x + hi_off, o.y + rows * SLOT - 2.0), hi_c, hi_w)


## 一种包缩进一格里（按包的外形等比缩，居中）
func _draw_bag(inst: ItemInstance, slot: Rect2) -> void:
	var box := Vector2(inst.def.shape.size_rotated(0))
	var room := SLOT - 2.0 * SLOT_PAD
	var cell := room / maxf(1.0, maxf(box.x, box.y))
	var at := slot.position + (Vector2.ONE * SLOT - box * cell) * 0.5
	if ItemPainter.draw_art(self, inst.def, 0, at, cell, Color.WHITE, Transform2D.IDENTITY, ItemPainter.variant_of(inst)):
		return
	var cells := inst.def.cells_rotated(0)
	ItemPainter.draw_item(self, cells, at, cell, ItemPainter.body_color(inst.def), ItemPainter.rarity_color(inst.def))


## 格右下角的「×n」（n ≤ 1 不画）：浅石小牌，墨字 Cinzel Bold 14（256：画法搬进 [method ItemPainter.draw_badge]，军功牌也用）
func _draw_badge(n: int, slot: Rect2) -> void:
	if n <= 1:
		return
	ItemPainter.draw_badge(self, UiText.t("rack.count") % n, slot)
