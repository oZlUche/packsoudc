## 251 补充一 §10.2：铁匠铺格子区里的一格配方。补充二 补图（UI替换美术 10-25 15:14，对照 smithy_cats/grid_sheet.png）：
## 格子区是一块深铁框（`smithy/grid_frame` 九宫格，四边 22，铆钉 + 浅纸内衬），里面固定 5 列 × 2 行铺满、格线 #8a7a62 一像素（只画格与格之间）；
## 一格 = 道具图居中（不要灰卡）+ 底下一块纸名牌（格宽 − 40，#efe6d2，粗墨字 15，一像素墨边）。不能打的（[member lit] 假）：名牌 #cfc8b6、字 #8a8378、图压灰；
## 选中的描一圈 #d4401c 三像素。点一下发 [signal clicked]（铁匠铺展开 / 收起下方铁砧）；打完 [method flash] 亮一下。
## 不到 10 张配方的空位用 [method blank] 补（只有格线）
class_name RecipeCell
extends Control

signal clicked(cell: RecipeCell)

const FRAME := "smithy/grid_frame"
const FRAME_EDGE := 22
const LINE := Color("8a7a62")
## 名牌：比格窄这么多、多高、离格底多远（原尺寸；整页按 k 缩）
const PLATE_INSET := 40.0
const PLATE_H := 28.0
const PLATE_GAP := 12.0
const PLATE := Color("efe6d2")
const PLATE_OFF := Color("cfc8b6")
const INK := Color("2e2219")
const INK_OFF := Color("8a8378")
const NAME_SIZE := 15
const SELECT := Color("d4401c")
const SELECT_W := 3.0
## 压灰的道具图
const DIM := Color(0.5, 0.5, 0.5, 0.75)
## 道具图占名牌上面那块的多少
const ART_FILL := 0.78

var recipe_id: StringName = &""
var def: ItemDef = null
var title := ""
var lit := true:
	set(v):
		lit = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()
## 右边 / 下边画不画格线（最右一列、最下一行贴着铁框，不画）
var line_right := true
var line_bottom := true
var _k := 1.0
var _glow := Color.WHITE


## [param size_px]：这一格多大；[param k]：整页缩放（1 = 底图原尺寸）
static func make(p_id: StringName, p_def: ItemDef, name: String, size_px: Vector2, k: float = 1.0) -> RecipeCell:
	var c := RecipeCell.new()
	c.recipe_id = p_id
	c.def = p_def
	c.title = name
	c._k = maxf(0.4, k)
	c.custom_minimum_size = size_px
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return c


## 空位：只有格线，不接点
static func blank(size_px: Vector2) -> RecipeCell:
	var c := RecipeCell.new()
	c.custom_minimum_size = size_px
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 补充二：铁匠铺的格子区（深铁框九宫格，没图退回 227 素框）
static func shelf() -> PanelContainer:
	var p := PanelContainer.new()
	var tex := UiTheme.art_cached(FRAME)
	var box: StyleBox = null
	if tex != null:
		var t := StyleBoxTexture.new()
		t.texture = tex
		t.texture_margin_left = FRAME_EDGE
		t.texture_margin_top = FRAME_EDGE
		t.texture_margin_right = FRAME_EDGE
		t.texture_margin_bottom = FRAME_EDGE
		t.set_content_margin_all(FRAME_EDGE)
		box = t
	else:
		box = BoardFrame.box("plain", false)
	p.add_theme_stylebox_override("panel", box)
	UiTheme.set_tone(p, UiTheme.TONE_LIGHT)
	return p


## 格子区的框边多厚（自己坐标；里面铺格就从这里往里算）
static func shelf_edge(shelf_panel: PanelContainer) -> float:
	var box := shelf_panel.get_theme_stylebox("panel")
	return box.get_margin(SIDE_LEFT) if box != null else 0.0


## 格与格之间不留空（格线由格子自己画）
static func space(grid: GridContainer) -> void:
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)


func is_blank() -> bool:
	return recipe_id == &""


## 名牌那块（自己坐标）
func plate_rect() -> Rect2:
	var w := maxf(24.0, size.x - PLATE_INSET * _k)
	var h := PLATE_H * _k
	return Rect2(Vector2((size.x - w) * 0.5, size.y - PLATE_GAP * _k - h), Vector2(w, h))


## 道具图那块（自己坐标；名牌上面那块按图的比例缩进去、居中）
func art_rect() -> Rect2:
	var area := Rect2(Vector2.ZERO, Vector2(size.x, plate_rect().position.y)).grow(-PLATE_GAP * _k * 0.5)
	var n := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
	var aspect := float(n.x) / float(n.y)
	var w := minf(area.size.x, area.size.y * aspect) * ART_FILL
	var r := Rect2(Vector2.ZERO, Vector2(w, w / aspect))
	r.position = area.get_center() - r.size * 0.5
	return r


## 打完：亮一下再回去
func flash() -> void:
	if not is_inside_tree():
		return
	_glow = Color(1.6, 1.4, 1.1)
	var tw := create_tween()
	tw.tween_method(_set_glow, _glow, Color.WHITE, 0.45)


func _set_glow(c: Color) -> void:
	_glow = c
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not is_blank():
		accept_event()
		clicked.emit(self)


func _draw() -> void:
	if line_right:
		draw_line(Vector2(size.x - 0.5, 0), Vector2(size.x - 0.5, size.y), LINE, 1.0)
	if line_bottom:
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), LINE, 1.0)
	if is_blank():
		return
	var tint := (Color.WHITE if lit else DIM) * _glow
	var ar := art_rect()
	var tex := ItemPainter.art_of(def, ar.size.y / maxf(1.0, float(def.shape.size_rotated(0).y)) if def != null and def.shape != null else ItemPainter.ART_CELL)
	if tex != null:
		draw_texture_rect(tex, ar, false, tint)
	elif def != null:
		draw_rect(ar.grow(-ar.size.x * 0.1), ItemPainter.body_color(def) * tint)
	var pr := plate_rect()
	draw_rect(pr, PLATE if lit else PLATE_OFF)
	draw_rect(pr.grow(-0.5), INK, false, 1.0)
	var f := UiPalette.cjk_font_bold()
	var fs := maxi(11, roundi(NAME_SIZE * _k))
	var room := pr.size.x - 8.0 * _k
	while fs > 9 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1     # 长名字先缩字（英文名不截断）
	var y := pr.get_center().y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	draw_string(f, Vector2(pr.position.x + 4.0 * _k, y), title, HORIZONTAL_ALIGNMENT_CENTER, room, fs, INK if lit else INK_OFF)
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-SELECT_W * 0.5), SELECT, false, SELECT_W)
