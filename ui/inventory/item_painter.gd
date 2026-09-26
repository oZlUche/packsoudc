## 物品的统一画法。网格内的物品与拖拽中的残影共用它，
## 否则两套绘制迟早会在圆角、描边、配色上走样。
class_name ItemPainter
extends RefCounted

## 作者定（087）：颜色代表稀有度，从低到高 白、绿、蓝、紫、金、红
const RARITY_COLORS: Array[Color] = [
	Color("d8dce3"),  # 0 普通　白
	Color("5fa85f"),  # 1 优良　绿
	Color("4a86c8"),  # 2 稀有　蓝
	Color("b06ccf"),  # 3 史诗　紫
	Color("e0b040"),  # 4 传说　金
	Color("d9453f"),  # 5 神话　红
]


## 物品主色（087 作者定）：**整格的底色就是稀有度的颜色**，不靠边框。往面板色压一点，字才看得清；描边同色稍亮
static func body_color(def: ItemDef) -> Color:
	if def == null:
		return Color("555a63")
	return rarity_color(def).lerp(Color("171a20"), 0.28)


## 名字的颜色：底色亮（白 / 金）就用深字，别的用浅字
static func label_color(def: ItemDef) -> Color:
	var b := body_color(def)
	return Color("14161b") if b.get_luminance() > 0.5 else Color("e6e9ef")


static func rarity_color(def: ItemDef) -> Color:
	if def == null:
		return RARITY_COLORS[0]
	return RARITY_COLORS[clampi(def.rarity, 0, RARITY_COLORS.size() - 1)]


## 画一件物品。
##
## [param cells] 为占格集合，[param anchor] 是 (0,0) 格在画布上的左上角像素坐标。
## 只在轮廓边上描线 —— 逐格描边会让 L 形看起来像散落的方块，而不是一件物品。
static func draw_item(
	canvas: CanvasItem,
	cells: Array[Vector2i],
	anchor: Vector2,
	cell: float,
	body: Color,
	edge: Color
) -> void:
	if cells.is_empty():
		return
	var occupied := {}
	for c in cells:
		occupied[c] = true

	# 先铺满整体，格与格之间不留缝，视觉上才是一件东西
	for c in cells:
		var p := anchor + Vector2(c) * cell
		canvas.draw_rect(Rect2(p, Vector2(cell, cell)), body, true)

	# 只描外轮廓，并向内缩 1px：
	# 描在格线正中时，相邻两件物品的边会叠成一条，看不出是两件
	const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	const INSET := 1.5
	for c in cells:
		var p := anchor + Vector2(c) * cell
		for d in DIRS:
			if occupied.has(c + d):
				continue
			var a: Vector2
			var b: Vector2
			match d:
				Vector2i.UP:
					a = p + Vector2(0, INSET)
					b = p + Vector2(cell, INSET)
				Vector2i.DOWN:
					a = p + Vector2(0, cell - INSET)
					b = p + Vector2(cell, cell - INSET)
				Vector2i.LEFT:
					a = p + Vector2(INSET, 0)
					b = p + Vector2(INSET, cell)
				_:
					a = p + Vector2(cell - INSET, 0)
					b = p + Vector2(cell - INSET, cell)
			canvas.draw_line(a, b, edge, 2.0)


## 在物品包围盒内居中写一行字。
static func draw_label(
	canvas: CanvasItem,
	cells: Array[Vector2i],
	anchor: Vector2,
	cell: float,
	text: String,
	font: Font,
	font_size: int,
	color: Color
) -> void:
	if cells.is_empty() or font == null or text.is_empty():
		return
	var mx := Vector2i.ZERO
	for c in cells:
		mx.x = maxi(mx.x, c.x)
		mx.y = maxi(mx.y, c.y)
	var box := Vector2(mx.x + 1, mx.y + 1) * cell
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := anchor + (box - text_size) * 0.5 + Vector2(0, text_size.y * 0.78)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
