## 图鉴里的一格缩略图（089，作者定：图鉴跟棋盘的格子无关，做成网格排列的缩略图，每行 N 个、能上下滚）。
##
## 一件道具一格：按形状缩放画在格子里（底色 = 稀有度），下面写名字，右上角写累计件数；**没获得的画灰的**。
## 鼠标停上去发 [signal hovered]（持有它的屏开悬浮窗），移开发 [signal unhovered]
class_name CodexTile
extends Control

signal hovered(tile: CodexTile)
signal unhovered(tile: CodexTile)

const SIZE := Vector2(96, 112)
const PAD := 8.0
const NAME_H := 18.0
const COLOR_DARK := Color("2a2e36")
const COLOR_DARK_EDGE := Color("3c424d")

var def: ItemDef = null
var lit: bool = false
var count: int = 0
var label_font: Font


func _init(p_def: ItemDef = null, p_lit: bool = false, p_count: int = 0, p_font: Font = null) -> void:
	def = p_def
	lit = p_lit
	count = p_count
	label_font = p_font
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered.emit(self))
	mouse_exited.connect(func(): unhovered.emit(self))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.PANEL)
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.LINE, false, 1.0)
	if def == null:
		return
	var font := label_font if label_font != null else get_theme_default_font()
	# 形状缩放进上半块
	var cells: Array[Vector2i] = def.cells_rotated(0) if def.shape != null else [Vector2i.ZERO] as Array[Vector2i]
	var box := def.shape.size_rotated(0) if def.shape != null else Vector2i.ONE
	var area := Vector2(size.x - PAD * 2, size.y - PAD * 2 - NAME_H)
	var cell := minf(area.x / maxf(1.0, float(box.x)), area.y / maxf(1.0, float(box.y)))
	cell = minf(cell, 40.0)
	var anchor := Vector2(PAD + (area.x - cell * box.x) * 0.5, PAD + (area.y - cell * box.y) * 0.5)
	var body := ItemPainter.body_color(def) if lit else COLOR_DARK
	var edge := ItemPainter.rarity_color(def).lightened(0.2) if lit else COLOR_DARK_EDGE
	ItemPainter.draw_item(self, cells, anchor, cell, body, edge)
	# 名字
	var name := Names.of(def) if lit else Names.of(def)
	var color := UiPalette.FG if lit else Color("4a515e")
	draw_string(font, Vector2(PAD, size.y - PAD), name, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - PAD * 2), 12, color)
	# 累计件数
	if lit and count > 1:
		var text := "×%d" % count
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8
		draw_rect(Rect2(size.x - w - 4, 4, w, 16), UiPalette.HEAL)
		draw_string(font, Vector2(size.x - w, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("101216"))
