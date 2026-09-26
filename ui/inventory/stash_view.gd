## [ItemStash] 的可视化：**一列可拖动的行**。
##
## 暂存区不是一块地方，所以这里没有格子、没有形状、没有旋转（见 [ItemStash]）。
## 一行就是一件东西，3×1 的长条和 1×1 的钉子占一样高。
##
## 行内只画三样：稀有度色条、名字、占格数。占格数留着是因为它是玩家
## **把东西放回棋盘时**唯一关心的信息 —— 在暂存区里不占地方，回去可就占了。
##
## 与 [InventoryView] 一样，全部内容在 [method _draw] 里从容器状态重画，
## 不用子节点表示行（架构原则 1.2）。
class_name StashView
extends ContainerView

const ROW_H := 30.0
const PAD := 6.0
## 空列表也要占出几行的高度，否则它小到没法当落点 —— 而「把东西拿下来」
## 恰恰是在暂存区空着的时候最常做的事
const MIN_ROWS := 4

const COLOR_BG := Color("15171c")
const COLOR_ROW := Color("21252d")
const COLOR_ROW_ALT := Color("1c2027")
const COLOR_BORDER := Color("343943")
const COLOR_TEXT := Color("dfe3ea")
const COLOR_DIM := Color("8b93a1")
## 插入位置的那条线
const COLOR_INSERT := Color(0.42, 0.86, 0.52)

@export var label_font: Font

var stash: ItemStash:
	set = set_stash

## 落点预览的插入行号，-1 表示不显示
var _insert_at: int = -1
## 085：亮一圈的行（uid → true）：拖着的那件能和它合成。拖拽层设
var highlights: Dictionary = {}


func set_stash(s: ItemStash) -> void:
	if stash == s:
		return
	if stash != null and stash.changed.is_connected(_on_changed):
		stash.changed.disconnect(_on_changed)
	stash = s
	if stash != null:
		stash.changed.connect(_on_changed)
	_on_changed()


func container() -> ItemContainer:
	return stash


func _on_changed() -> void:
	_refit()
	queue_redraw()


func _refit() -> void:
	var rows := maxi(MIN_ROWS, stash.item_count() if stash != null else 0)
	custom_minimum_size.y = rows * ROW_H + PAD * 2
	size.y = custom_minimum_size.y


#region 坐标换算
## 本控件内的像素 y → 行号。可能等于行数（落在末尾空白处），调用方自行夹取。
func row_at_local(p: Vector2) -> int:
	return maxi(0, floori((p.y - PAD) / ROW_H))


## 拖拽落点对应的**插入位置**。
##
## 按行的上下半区分：落在上半就插在它前面，下半就插在它后面。
## 只按行号取整的话，想把东西放到最后一行之后是做不到的。
func insert_index_at_global(p: Vector2) -> int:
	if stash == null:
		return 0
	var local := p - global_position
	var raw := (local.y - PAD) / ROW_H
	return clampi(roundi(raw), 0, stash.item_count())


func row_origin_px(row: int) -> Vector2:
	return Vector2(PAD, PAD + row * ROW_H)
#endregion


#region 落点预览
func set_insert_preview(index: int) -> void:
	if _insert_at == index:
		return
	_insert_at = index
	queue_redraw()


func clear_preview() -> void:
	if _insert_at < 0:
		return
	_insert_at = -1
	queue_redraw()
#endregion


func _gui_input(event: InputEvent) -> void:
	if stash == null or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var row := row_at_local(mb.position)
	var list := stash.items()
	if row >= list.size():
		return
	if mb.double_click:
		item_double_clicked.emit(self, (list[row] as ItemInstance).uid)     # 084：双击 = 快速置入
	else:
		grab_requested.emit(self, (list[row] as ItemInstance).uid, mb.position)
	accept_event()


func _draw() -> void:
	var font := label_font if label_font != null else get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)

	var list := stash.items() if stash != null else []
	for i in list.size():
		_draw_row(i, list[i] as ItemInstance, font)

	if list.is_empty():
		draw_string(
			font, Vector2(PAD + 8, PAD + ROW_H * 0.7), "（空）",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_DIM
		)

	if _insert_at >= 0:
		var y := PAD + _insert_at * ROW_H
		draw_line(Vector2(PAD, y), Vector2(size.x - PAD, y), COLOR_INSERT, 2.0)

	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 1.0)


func _draw_row(index: int, inst: ItemInstance, font: Font) -> void:
	var at := row_origin_px(index)
	var w := size.x - PAD * 2
	draw_rect(
		Rect2(at, Vector2(w, ROW_H - 2)),
		COLOR_ROW if index % 2 == 0 else COLOR_ROW_ALT, true
	)

	# 稀有度色条顶在最左边。列表里没有形状可看，颜色是唯一一眼能分出贵贱的东西
	draw_rect(Rect2(at, Vector2(3, ROW_H - 2)), ItemPainter.rarity_color(inst.def), true)
	if highlights.has(inst.uid):
		draw_rect(Rect2(at, Vector2(w, ROW_H - 2)), COLOR_INSERT, false, 2.0)

	var name := inst.def.display_name if inst.def != null else "?"
	draw_string(
		font, at + Vector2(10, ROW_H * 0.68), name,
		HORIZONTAL_ALIGNMENT_LEFT, w - 60, 13, COLOR_TEXT
	)

	# 占格数：在暂存区里不占地方，放回棋盘可就占了
	draw_string(
		font, at + Vector2(w - 44, ROW_H * 0.68), "%d 格" % inst.cells().size(),
		HORIZONTAL_ALIGNMENT_LEFT, 44, 12, COLOR_DIM
	)
