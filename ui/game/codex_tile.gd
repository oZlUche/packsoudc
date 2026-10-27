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
## 201：没点亮、有图的画成暗影（乙 石刻浅格上：作者 18:27「道具蒙一层阴影，不是整块黑」）
const ART_UNLIT := Color(0.34, 0.32, 0.31)
## 乙 石刻：格底浅亚麻 + 深木细边（`kit/codex_cell`，没点亮 `codex_cell_dim`），图四周多 6；
## 左上异体签深红皮（`codex_badge`）浅字，右上件数铜签（`codex_count`）墨字；名字墨字 12，离底 10
const CELL_ART := "kit/codex_cell"
const BADGE_ART := "kit/codex_badge"
const COUNT_ART := "kit/codex_count"
const NAME_X := 9.0
const NAME_BASE := 10.0
const INK_LIT := Color("2e2219")
const INK_UNLIT := Color("7c6e5a")
const BADGE_INK := Color("f6eedb")
const TAG_AT := 7.0
const TAG_H := 18.0
const TAG_FONT := 11
## 浅格上没点亮的异体叠影：比格底深一档的亚麻，不画成深色块
const STACK_UNLIT := Color("d3c6ae")

static var _boxes := {}

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
## 作者 10-26：没点亮的名字遮成「？」（设置「名字全显」开着时为 false）
var mask_name: bool = true
## 叠影每层的错位
const STACK_OFFSET := Vector2(5, -5)


## 格子上写的名字：点亮了（或「名字全显」）写真名，否则「？」
func shown_name() -> String:
	return Names.of(def) if lit or not mask_name else UiText.t("codex.unknown")


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


## 107：叠影垫几层（最多 2，和原来一样；没异体就 0）
func stack_layers() -> int:
	return mini(variant_count(), 2)


## 107（作者定）：格子里的物品呈现堆叠 —— 后面的层先画、颜色暗一档，描边用那位神赐福版的稀有度色
## （没点亮的用灰），最前面是原件。错位沿用 [constant STACK_OFFSET]
func _draw_variant_stack(cells: Array[Vector2i], anchor: Vector2, cell: float, layers: int) -> void:
	for i in range(layers, 0, -1):
		var vdef: ItemDef = variants[mini(i, variants.size() - 1)]
		var on := variant_lit[mini(i, variant_lit.size() - 1)] if not variant_lit.is_empty() else false
		var body := ItemPainter.body_color(vdef).darkened(0.25) if on else (STACK_UNLIT if _box(CELL_ART, 16.0) != null else COLOR_DARK)
		var edge := ItemPainter.rarity_color(vdef).lightened(0.1) if on else (INK_UNLIT if _box(CELL_ART, 16.0) != null else COLOR_DARK_EDGE)
		ItemPainter.draw_item(self, cells, anchor + STACK_OFFSET * float(i), cell, body, edge)


func _draw() -> void:
	# 107（作者定）：**外框不动，叠的是里面的物品** —— 格子只画一个（底板 + 描边），
	# 异体的叠影在下面画在形状上（见 `_draw_variant_stack`）
	var cell_box := _box(CELL_ART if lit else CELL_ART + "_dim", 16.0)
	if cell_box != null:
		draw_style_box(cell_box, Rect2(Vector2.ZERO, size))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), UiPalette.PANEL)
		draw_rect(Rect2(Vector2.ZERO, size), UiPalette.LINE, false, 1.0)
	if def == null:
		return
	var font := label_font if label_font != null else get_theme_default_font()
	# 形状缩放进上半块
	var cells: Array[Vector2i] = def.cells_rotated(0) if def.shape != null else [Vector2i.ZERO] as Array[Vector2i]
	var box := def.shape.size_rotated(0) if def.shape != null else Vector2i.ONE
	# 107：有异体时先把可用区缩小「错位量 × 层数」，整叠才落得进外框里
	var layers := stack_layers()
	var inset := Vector2(absf(STACK_OFFSET.x), absf(STACK_OFFSET.y)) * float(layers)
	var area := Vector2(size.x - PAD * 2, size.y - PAD * 2 - NAME_H) - inset
	var cell := minf(area.x / maxf(1.0, float(box.x)), area.y / maxf(1.0, float(box.y)))
	cell = minf(cell, 40.0)
	var anchor := Vector2(PAD + (area.x - cell * box.x) * 0.5, PAD + inset.y + (area.y - cell * box.y) * 0.5)
	var body := ItemPainter.body_color(def) if lit else (ItemPainter.body_color(def) * ART_UNLIT if cell_box != null else COLOR_DARK)
	var edge := ItemPainter.rarity_color(def).lightened(0.2) if lit else COLOR_DARK_EDGE
	_draw_variant_stack(cells, anchor, cell, layers)
	# 201：有图就画图；没点亮的压成暗影（还看得出形，看不出细节）。异体叠影照旧用色块（错位叠图会花）
	if not ItemPainter.draw_art(self, def, 0, anchor, cell, Color.WHITE if lit else ART_UNLIT):
		ItemPainter.draw_item(self, cells, anchor, cell, body, edge)
	# 名字
	var name := shown_name()
	if cell_box != null:
		draw_string(font, Vector2(NAME_X, size.y - NAME_BASE), name, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - NAME_X * 2), 12, INK_LIT if lit else INK_UNLIT)
	else:
		draw_string(font, Vector2(PAD, size.y - PAD), name, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - PAD * 2), 12, UiPalette.FG if lit else Color("4a515e"))
	# 095：异体角标「1/3」（点亮几个 / 共几个）
	if variant_count() > 0:
		_draw_tag("%d/%d" % [variants_lit(), variants.size()], font, false, BADGE_ART, BADGE_INK, Color("6f9fe0"))
	# 累计件数
	if lit and count > 1:
		_draw_tag("×%d" % count, font, true, COUNT_ART, INK_LIT, UiPalette.HEAL)


## 角上一枚小签：左上（异体）或右上（件数），有图用皮签 / 铜签，没图照旧色块
func _draw_tag(text: String, font: Font, right: bool, art: String, ink: Color, fallback: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT).x + 12.0
	var box := _box(art, 12.0)
	var r := Rect2(Vector2(size.x - TAG_AT - w if right else TAG_AT, TAG_AT), Vector2(w, TAG_H))
	if box == null:
		r = Rect2(Vector2(size.x - w - 4 if right else 4.0, 4.0), Vector2(w - 4.0, 16.0))
		draw_rect(r, fallback)
		ink = Color("101216")
	else:
		draw_style_box(box, r)
	var y := r.position.y + r.size.y * 0.5 + (font.get_ascent(TAG_FONT) - font.get_descent(TAG_FONT)) * 0.5
	draw_string(font, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, TAG_FONT, ink)


## 九宫格（图四周多 6），按图名缓存；没图 null
static func _box(art: String, margin: float) -> StyleBoxTexture:
	if _boxes.has(art):
		return _boxes[art]
	var tex := UiTheme.art_cached(art)
	var box: StyleBoxTexture = null
	if tex != null:
		box = StyleBoxTexture.new()
		box.texture = tex
		box.set_texture_margin_all(margin)
		box.set_expand_margin_all(6.0)
	_boxes[art] = box
	return box
