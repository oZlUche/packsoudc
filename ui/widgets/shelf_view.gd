## 261 补充二（作者 17:14 选 C 石砌壁龛）：书架页整座画出来 —— 壁龛底图；图鉴 / 成就 / 科技按进度五档（[ShelfCell]），对局记录一张（作者 17:09「没有变化的必要」），
## 特殊道具每件一根展示柱（拿到过的摆它自己的道具图，没拿到空柱），第六格静物油灯；悬停换提亮图 + 格里一团暖光；格下铜框纸签写格名与数。
## 件和摆位从 UI替换美术 的 `home/shelf/layout.json` 读（相对书架左上，物件整张 400 × 400 贴格左上）；前五格各盖一颗透明按钮（点开窗、悬停）。
## 字全由代码写，浅底墨字；物件只画一面，代码不加影子
class_name ShelfView
extends Control

signal open_requested(key: String)

const ART := "home/shelf/"
const LAYOUT := ART + "layout"
const TAG_SIZE := 18
## 纸签宽 = 字宽 + 36；字的基线在纸签中心往下 6.5（18 号时）
const TAG_PAD := 36.0
const TAG_BASELINE := 6.5
const INK := Color("2e2219")
const STONE := Color("ddd6c8")
const HOVER_LIFT := Color(1.15, 1.15, 1.15)
## 展示柱：layout.json 的 keepsake_columns 是用字写的规则，数抄在这里 —— n 件中线 = 格左 + 20 + 360 × (2k + 1) / (2n)，柱底 = 格上 + 397，
## 道具不透明部分的底边在柱底往上 208（红垫中间）、等比缩进 128 见方；柱距 360 / n 不够 136 时柱和道具一起按 (360 / n − 8) / 柱宽 缩
const COL_LEFT := 20.0
const COL_SPAN := 360.0
const COL_BOTTOM := 397.0
const COL_SEAT := 208.0
const COL_MIN_STEP := 136.0
const COL_SHRINK_PAD := 8.0
const ITEM_BOX := 128.0
## 道具图取 @2x 那张（160 px / 格）
const ITEM_PX := 160.0

## 每格 {key, rect, tag_center, tiers（分档的图名，五张）, file（一张）, compose, still_life}
var _cells: Array[Dictionary] = []
var _body_size := Vector2(1308, 952)
var _btns: Dictionary = {}
## 格 → [分子, 分母]、格 → 纸签上的字
var _progress: Dictionary = {}
var _tags: Dictionary = {}
## 特殊道具：[[ItemDef, 拿到过没有], …]（`keepsake_ids` 的顺序）
var _keepsakes: Array = []
var _tag_box: StyleBoxTexture = null
## 道具图路径 → 不透明部分（Image.get_used_rect），算一次
static var _used: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var lay := UiTheme.art_meta(LAYOUT)
	var body: Array = (lay.get("shelf_body", {}) as Dictionary).get("size", [])
	if body.size() == 2:
		_body_size = Vector2(float(body[0]), float(body[1]))
	custom_minimum_size = _body_size
	for raw in lay.get("cells", []):
		var c: Dictionary = raw
		var r: Array = c.get("rect", [0, 0, 0, 0])
		var tc: Array = c.get("tag_center", [])
		_cells.append({"key": String(c.get("key", "")), "rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
			"tag_center": Vector2(float(tc[0]), float(tc[1])) if tc.size() == 2 else Vector2.ZERO,
			"tiers": c.get("tiers", []), "file": String(c.get("file", "")), "compose": String(c.get("compose", "")), "still_life": String(c.get("still_life", ""))})
	_tag_box = UiTheme.art_box(ART + "shelf_tag")
	for c in _cells:
		var key: String = c["key"]
		if key == "":
			continue     # 第六格静物：不可点、不亮
		var b := Button.new()
		b.name = "Shelf_" + key
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = (c["rect"] as Rect2).position
		b.size = (c["rect"] as Rect2).size
		b.pressed.connect(func(): open_requested.emit(key))
		b.mouse_entered.connect(queue_redraw)
		b.mouse_exited.connect(queue_redraw)
		add_child(b)
		_btns[key] = b


## 一格的进度与纸签字（meta_screen 算好了给）
func set_cell(key: String, progress: Array, tag: String) -> void:
	_progress[key] = progress
	_tags[key] = tag
	queue_redraw()


func set_keepsakes(list: Array) -> void:
	_keepsakes = list
	queue_redraw()


func buttons() -> Dictionary:
	return _btns


func cell_keys() -> Array:
	return _cells.map(func(c: Dictionary) -> String: return c["key"])


func cell_rect(key: String) -> Rect2:
	for c in _cells:
		if c["key"] == key:
			return c["rect"]
	return Rect2()


func tag_text(key: String) -> String:
	return String(_tags.get(key, ""))


func hot(key: String) -> bool:
	return _btns.has(key) and (_btns[key] as Button).is_hovered()


## 这一格现在画哪张图（不带 `home/shelf/`）：分档的按 [ShelfCell] 取档，悬停取 `_hover`；拼的（特殊道具）空串
func piece_name(key: String, hover: bool = false) -> String:
	for c in _cells:
		if c["key"] != key:
			continue
		var name := ""
		var tiers: Array = c["tiers"]
		if not tiers.is_empty():
			var p: Array = _progress.get(key, [0, 0])
			name = String(tiers[mini(ShelfCell.tier_of(int(p[0]), int(p[1])), tiers.size() - 1)])
			if UiTheme.art_cached(ART + name) == null:
				name = String(tiers[0])     # 缺图退 t0
		elif c["file"] != "":
			name = c["file"]
		elif c["still_life"] != "":
			name = c["still_life"]
		if name != "" and hover and UiTheme.art_cached(ART + name + "_hover") != null:
			name += "_hover"
		return name
	return ""


## 特殊道具第 k 根柱（共 n 根）：[柱的框, 缩放]
func column_rect(cell: Rect2, k: int, n: int) -> Array:
	var col := UiTheme.art_cached(ART + "keepsake_column")
	var csize := col.get_size() if col != null else Vector2(132, 218)
	var step := COL_SPAN / float(n)
	var k_scale := 1.0 if step >= COL_MIN_STEP else (step - COL_SHRINK_PAD) / csize.x
	var cx := cell.position.x + COL_LEFT + COL_SPAN * float(2 * k + 1) / float(2 * n)
	var bottom := cell.position.y + COL_BOTTOM
	var s := csize * k_scale
	return [Rect2(cx - s.x * 0.5, bottom - s.y, s.x, s.y), k_scale]


## 柱顶道具图摆在哪：不透明部分等比缩进 128 见方，水平居中，底边在柱底往上 208
func keepsake_item_rect(column: Rect2, k_scale: float, tex: Texture2D) -> Rect2:
	var used := used_rect(tex)
	var box := ITEM_BOX * k_scale
	var f := minf(box / maxf(used.size.x, 1.0), box / maxf(used.size.y, 1.0))
	var s := used.size * f
	var seat := column.end.y - COL_SEAT * k_scale
	return Rect2(column.get_center().x - s.x * 0.5, seat - s.y, s.x, s.y)


static func used_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())     # 按路径记，别拿着贴图（退出时算泄漏）
	if not _used.has(key):
		var img := tex.get_image()
		_used[key] = Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO, tex.get_size())
	return _used[key]


static func item_art(def: ItemDef) -> Texture2D:
	var t := ItemPainter.art_of(def, ITEM_PX)
	return t if t != null else ItemPainter.art_of(def)


func _draw() -> void:
	var body := UiTheme.art_cached(ART + "shelf_body")
	if body != null:
		draw_texture(body, Vector2.ZERO)
	else:
		draw_rect(Rect2(Vector2.ZERO, _body_size), STONE)
	for c in _cells:
		var key: String = c["key"]
		var r: Rect2 = c["rect"]
		var lit := hot(key)
		if lit:
			var glow := UiTheme.art_cached(ART + "shelf_hover")     # 书架上、物件下
			if glow != null:
				draw_texture(glow, r.position)
		if c["compose"] == "keepsake_columns":
			_draw_keepsakes(r, lit)
			continue
		var tex := UiTheme.art_cached(ART + piece_name(key, lit))
		if tex != null:
			draw_texture(tex, r.position)
	var font := UiPalette.cjk_font_bold()
	var px := UiTheme.sz(TAG_SIZE)
	for c in _cells:
		var text := tag_text(c["key"])
		if text == "":
			continue
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var h := maxf(34.0, px + 16.0)
		var at: Vector2 = c["tag_center"]
		var tag := Rect2(at.x - (w + TAG_PAD) * 0.5, at.y - h * 0.5, w + TAG_PAD, h)
		if _tag_box != null:
			draw_style_box(_tag_box, tag)
		draw_string(font, Vector2(at.x - w * 0.5, at.y + TAG_BASELINE * px / float(TAG_SIZE)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)


func _draw_keepsakes(cell: Rect2, lit: bool) -> void:
	var n := _keepsakes.size()
	var col := UiTheme.art_cached(ART + ("keepsake_column_hover" if lit else "keepsake_column"))
	if col == null:
		col = UiTheme.art_cached(ART + "keepsake_column")
	for k in n:
		var spot: Array = column_rect(cell, k, n)
		if col != null:
			draw_texture_rect(col, spot[0], false)
		var pair: Array = _keepsakes[k]
		if not bool(pair[1]):
			continue
		var tex := item_art(pair[0])
		if tex == null:
			continue
		draw_texture_rect_region(tex, keepsake_item_rect(spot[0], spot[1], tex), used_rect(tex), HOVER_LIFT if lit else Color.WHITE)
