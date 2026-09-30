## 图鉴里的一格缩略图（089，作者定：图鉴跟棋盘的格子无关，做成网格排列的缩略图，每行 N 个、能上下滚）。
##
## 一件道具一格：按形状缩放画在格子里（底色 = 稀有度），下面写名字，右上角写累计件数；**没获得的画灰的**。
## 鼠标停上去发 [signal hovered]（持有它的屏开悬浮窗），移开发 [signal unhovered]
class_name CodexTile
extends Control

signal hovered(tile: CodexTile)
signal unhovered(tile: CodexTile)
## 095：左键点了（有异体的格子弹出异体列表）
signal pressed(tile: CodexTile)

const SIZE := Vector2(96, 112)
const PAD := 8.0
const NAME_H := 18.0
const COLOR_DARK := Color("2a2e36")
const COLOR_DARK_EDGE := Color("3c424d")

var def: ItemDef = null
var lit: bool = false
var count: int = 0
var label_font: Font
## 095：这一格的全部异体（原件 + 各神的赐福版，原件在前）；只有一个 = 没有异体
var variants: Array[ItemDef] = []
## 各异体点亮没有（与 variants 对齐）
var variant_lit: Array[bool] = []
## 各异体的累计件数
var variant_counts: Array[int] = []
## 叠影每层的错位
const STACK_OFFSET := Vector2(5, -5)


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
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(self))


## 095：有几个异体（原件不算）
func variant_count() -> int:
	return maxi(0, variants.size() - 1)


## 095：异体里点亮了几个（含原件）
func variants_lit() -> int:
	var n := 0
	for v in variant_lit:
		if v:
			n += 1
	return n


func _draw() -> void:
	# 095：有异体的格子画成一叠 —— 后面错位垫两层，各按那位神的赐福版的稀有度描边
	if variant_count() > 0:
		var layers := mini(variant_count(), 2)
		for i in range(layers, 0, -1):
			var off := STACK_OFFSET * float(i)
			var vdef: ItemDef = variants[mini(i, variants.size() - 1)]
			var on := variant_lit[mini(i, variant_lit.size() - 1)] if not variant_lit.is_empty() else false
			draw_rect(Rect2(off, size), UiPalette.PANEL.darkened(0.15))
			draw_rect(Rect2(off, size), (ItemPainter.rarity_color(vdef).lightened(0.1) if on else COLOR_DARK_EDGE), false, 1.0)
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
	# 095：异体角标「1/3」（点亮几个 / 共几个）
	if variant_count() > 0:
		var vt := "%d/%d" % [variants_lit(), variants.size()]
		var vw := font.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8
		draw_rect(Rect2(4, 4, vw, 16), Color("6f9fe0"))
		draw_string(font, Vector2(8, 16), vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("101216"))
	# 累计件数
	if lit and count > 1:
		var text := "×%d" % count
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8
		draw_rect(Rect2(size.x - w - 4, 4, w, 16), UiPalette.HEAL)
		draw_string(font, Vector2(size.x - w, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("101216"))
