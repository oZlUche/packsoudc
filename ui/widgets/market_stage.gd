## 251 补充一 §10.1（作者 14:49「古罗马风格的市场（木质凉棚），货物摆在台子上且更散开」；15:57 第三版：一张带透视的大平桌、货分前后两排）：
## 集市页的棚子 —— 底图 `market/bg`（缺图照 `market/layout.json` 画一座占位的木凉棚：横梁、两根立柱、吊着的招牌、一张透视的木桌）+ 摆法（同 199 铸炉：底图像素）。
## `layout.json`：`size` 设计像素（有底图按底图）、`sign` / `funds` 矩形、`tables` 一项（`back_y` / `back_x` 后沿、`front_y` / `front_x` 前沿、`band` 桌沿厚）、
## `cell` 货的格子边长（scale 1 时）、`spots` 每个货位 `foot`（货底中点）+ `scale`（后排小、前排大），按级数取前 4 / 6 / 8 个。
## 整棚等比「包含」缩进自己的矩形、上下左右居中（补充二 §12.1：整页，同 199 铸炉），[method at] / [method to_local_rect] 把设计像素换成控件坐标，
## 货位、价签、钱袋读数由集市页照它摆。招牌上的字（「集市」）由代码写（中英文），底图只画空牌；没点出集市时只画空棚（不画木桌）。
## 补充二：铁匠铺整页也用它（`MarketStage.new("smithy/layout", "smithy/bg")`：砖墙底图 + 大类键 / 格子区 / 打造界面 / 钱牌 / 招牌的矩形），
## 不是集市的那页缺底图时只铺一块平底（占位凉棚只画集市）
class_name MarketStage
extends Control

const LAYOUT := "market/layout"
const BG := "market/bg"
## 占位木色（UI替换美术换底图后不用）
const WOOD := Color("8a5a32")
const WOOD_DARK := Color("5e3b1f")
const WOOD_TOP := Color("b07a46")
const SIGN := Color("6b4423")
const SIGN_INK := Color("f3e6c8")
const PLATE := Color("efe4c8")
const PLATE_EDGE := Color("8a6a44")
const SIGN_FONT := 24

## 招牌上写什么
var sign_text := "":
	set(v):
		sign_text = v
		queue_redraw()
## 画不画木桌（没点出集市 = 空棚）
var tables := true:
	set(v):
		tables = v
		queue_redraw()

var _layout: Dictionary = {}
var _bg := BG
var _pergola := true


## 默认是集市；[param p_layout] / [param p_bg] 换成别的整页（铁匠铺）
func _init(p_layout: String = LAYOUT, p_bg: String = BG) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bg = p_bg
	_pergola = p_layout == LAYOUT
	_layout = UiTheme.art_meta(p_layout)
	UiTheme.set_tone(self, UiTheme.TONE_LIGHT if String(_layout.get("tone", "light")) == "light" else UiTheme.TONE_DARK)


func layout() -> Dictionary:
	return _layout


## 设计像素的整棚大小（有底图按底图）
func design_size() -> Vector2:
	var bg := UiTheme.art_cached(_bg)
	if bg != null:
		return bg.get_size()
	var s: Array = _layout.get("size", [480, 960])
	return Vector2(float(s[0]), float(s[1]))


## 设计像素 → 控件坐标的缩放
func scale_factor() -> float:
	var d := design_size()
	if d.x <= 0.0 or d.y <= 0.0 or size.x <= 0.0:
		return 1.0
	return minf(size.x / d.x, size.y / d.y) if size.y > 0.0 else size.x / d.x


## 整棚在控件里的左上角（上下左右居中）
func origin() -> Vector2:
	return (size - design_size() * scale_factor()) * 0.5


## 设计像素的一个点 → 控件坐标
func at(p: Vector2) -> Vector2:
	return origin() + p * scale_factor()


## layout 里的一个矩形（{x, y, w, h}）换成控件坐标
func to_local_rect(r: Dictionary) -> Rect2:
	var k := scale_factor()
	return Rect2(origin() + Vector2(float(r.get("x", 0)), float(r.get("y", 0))) * k, Vector2(float(r.get("w", 0)), float(r.get("h", 0))) * k)


func spots() -> Array:
	return _layout.get("spots", [])


## 第 i 个货位的货底中点（控件坐标）
func foot_of(spot: Dictionary) -> Vector2:
	var f: Array = spot.get("foot", [0, 0])
	return at(Vector2(float(f[0]), float(f[1])))


## 第 i 个货位的格子边长（控件像素）：`cell` × 这一位的 `scale` × 整棚缩放
func cell_of(spot: Dictionary) -> float:
	return float(_layout.get("cell", 26)) * float(spot.get("scale", 1.0)) * scale_factor()


func _draw() -> void:
	var k := scale_factor()
	var o := origin()
	var d := design_size()
	var bg := UiTheme.art_cached(_bg)
	if bg != null:
		draw_texture_rect(bg, Rect2(o, d * k), false)
	elif _pergola:
		_draw_placeholder(o, d, k)
	else:
		draw_rect(Rect2(o, d * k), WOOD_DARK)
	_draw_sign_text()


## 占位凉棚：顶上一排椽头 + 横梁、左右两根立柱、招牌两根吊绳、一张透视木桌（桌面梯形 + 前沿 + 腿）、钱袋读数的纸牌
func _draw_placeholder(o: Vector2, d: Vector2, k: float) -> void:
	var line := maxf(1.0, 2.0 * k)
	var beam := Rect2(o + Vector2(0, 56) * k, Vector2(d.x, 30) * k)
	for i in int(d.x / 46.0):
		draw_rect(Rect2(o + Vector2(8 + i * 46.0, 36) * k, Vector2(18, 22) * k), WOOD_DARK)
	draw_rect(beam, WOOD)
	draw_rect(beam, WOOD_DARK, false, line)
	for x in [20.0, d.x - 44.0]:
		var post := Rect2(o + Vector2(x, 86) * k, Vector2(24, d.y - 86) * k)
		draw_rect(post, WOOD)
		draw_rect(post, WOOD_DARK, false, line)
	var sign := to_local_rect(_layout.get("sign", {}))
	if sign.size.x > 0.0:
		for fx in [0.25, 0.75]:
			var x := sign.position.x + sign.size.x * float(fx)
			draw_line(Vector2(x, beam.end.y), Vector2(x, sign.position.y), WOOD_DARK, line)
		draw_rect(sign, SIGN)
		draw_rect(sign.grow(-3.0 * k), WOOD_TOP, false, line)
	if not tables:
		return
	for t in _layout.get("tables", []):
		var tb := t as Dictionary
		var bx: Array = tb.get("back_x", [0, 0])
		var fx2: Array = tb.get("front_x", [0, 0])
		var by := float(tb.get("back_y", 0))
		var fy := float(tb.get("front_y", 0))
		var band := float(tb.get("band", 24))
		var bl := at(Vector2(float(bx[0]), by))
		var br := at(Vector2(float(bx[1]), by))
		var fl := at(Vector2(float(fx2[0]), fy))
		var fr := at(Vector2(float(fx2[1]), fy))
		var leg_h := 110.0 * k
		for lx in [fl.x + 14.0 * k, fr.x - 30.0 * k]:
			draw_rect(Rect2(Vector2(lx, fl.y + band * k), Vector2(16.0 * k, leg_h)), WOOD_DARK)
		draw_colored_polygon(PackedVector2Array([bl, br, fr, fl]), WOOD_TOP)
		draw_polyline(PackedVector2Array([bl, br, fr, fl, bl]), WOOD_DARK, line)
		var front := Rect2(fl, Vector2(fr.x - fl.x, band * k))
		draw_rect(front, WOOD)
		draw_rect(front, WOOD_DARK, false, line)
	var funds := to_local_rect(_layout.get("funds", {}))
	if funds.size.x > 0.0:
		draw_rect(funds, PLATE)
		draw_rect(funds, PLATE_EDGE, false, maxf(1.0, 1.5 * k))


func _draw_sign_text() -> void:
	var sign := to_local_rect(_layout.get("sign", {}))
	if sign_text == "" or sign.size.x <= 0.0:
		return
	var f := UiPalette.cjk_font_bold()
	var fs := maxi(12, roundi(SIGN_FONT * minf(1.0, scale_factor() * 1.4)))
	var w := f.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > sign.size.x and w > 0.0:     # 270：字比招牌框宽就缩字，别压两侧天平
		fs = maxi(10, floori(fs * sign.size.x / w))
		w = f.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := sign.get_center().y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	draw_string(f, Vector2(sign.get_center().x - w * 0.5, y), sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SIGN_INK)
