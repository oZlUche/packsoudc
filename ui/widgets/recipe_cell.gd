## 251 补充一 §10.2：铁匠铺右边的一格配方 —— 产物摆在一块带框的小棋盘里（227），底下一块纸名牌写产物名；
## 能打的亮、不能打的压灰（[member lit]，悬浮窗写原因）；点一下发 [signal clicked]（铁匠铺展开 / 收起下方卷轴），选中的外圈描一道铁红。
## 打完 [method flash] 亮一下。格子里的棋盘只是画，不接拖拽
class_name RecipeCell
extends VBoxContainer

signal clicked(cell: RecipeCell)

## 产物那块棋盘的格子区最大多大（像素）；格子边长按产物大小缩进去
const BOX := 56.0
const CELL_MAX := 28.0
const NAME_SIZE := 13
const DIM := Color(0.55, 0.55, 0.55, 0.7)

var recipe_id: StringName = &""
var view: InventoryView = null
var lit := true:
	set(v):
		lit = v
		modulate = Color.WHITE if lit else DIM
var selected := false:
	set(v):
		selected = v
		queue_redraw()


static func make(p_id: StringName, def: ItemDef, name: String, font: Font) -> RecipeCell:
	var c := RecipeCell.new()
	c.recipe_id = p_id
	c._build(def, name, font)
	return c


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_constant_override("separation", 2)


func _build(def: ItemDef, name: String, font: Font) -> void:
	var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
	var cell := floorf(minf(CELL_MAX, minf(BOX / size.x, BOX / size.y)))
	var grid := GridInventory.new(BoardFrame.padded_size(size, cell), 0, false)     # 太窄的（1×4 长剑）补一列空格，框才不被裁
	if def != null:
		grid.place(ItemInstance.create(def, 0), Vector2i.ZERO, 0)
	view = InventoryView.new()
	view.label_font = font
	view.show_adjacency = false
	view.inventory = grid
	view.cell_px = cell
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := CenterContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	slot.add_child(view)
	var frame := BoardFrame.wrap(view, "plain")
	slot.custom_minimum_size = Vector2.ONE * (BOX + frame.inset() * 2.0)
	custom_minimum_size.x = slot.custom_minimum_size.x     # 一格一样宽：长名字省略（全名在悬浮窗）
	var plate := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 4, 1, 4, 1)
	UiTheme.set_tone(plate, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", NAME_SIZE)
	plate.add_child(l)
	add_child(plate)


## 打完：亮一下再回去
func flash() -> void:
	if not is_inside_tree():
		return
	modulate = Color(1.6, 1.4, 1.1)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE if lit else DIM, 0.45)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(self)


func _draw() -> void:
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size).grow(3.0), UiPalette.HOT_IRON, false, 3.0)
