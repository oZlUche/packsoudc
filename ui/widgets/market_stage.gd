## 251 补充一 §10.1（作者 14:49「古罗马风格的市场（木质凉棚），货物摆在台子上且更散开」；15:57 第三版：一张带透视的大平桌、货分前后两排）：
## 集市页的棚子 —— 底图 `market/bg` + 摆法（同 199 铸炉：底图像素）。
## `layout.json`：`size` 设计像素（有底图按底图）、`sign` / `funds` 矩形、`tables` 一项（`back_y` / `back_x` 后沿、`front_y` / `front_x` 前沿、`band` 桌沿厚）、
## `cell` 货的格子边长（scale 1 时）、`spots` 每个货位 `foot`（货底中点）+ `scale`（后排小、前排大），按级数取前 4 / 6 / 8 个。
## 整棚等比「包含」缩进自己的矩形、上下左右居中（补充二 §12.1：整页，同 199 铸炉），[method at] / [method to_local_rect] 把设计像素换成控件坐标，
## 货位、价签、钱袋读数由集市页照它摆。招牌上的字（「集市」）由代码写（中英文），底图只画空牌。
## 补充二：铁匠铺整页也用它（`MarketStage.new("smithy/layout", "smithy/bg")`：砖墙底图 + 大类键 / 格子区 / 打造界面 / 钱牌 / 招牌的矩形）
class_name MarketStage
extends Control

const LAYOUT := "market/layout"
const BG := "market/bg"
const SIGN_INK := Color("f3e6c8")
const SIGN_FONT := 24

## 招牌上写什么
var sign_text := "":
	set(v):
		sign_text = v
		queue_redraw()
var _layout: Dictionary = {}
var _bg := BG


## 默认是集市；[param p_layout] / [param p_bg] 换成别的整页（铁匠铺）
func _init(p_layout: String = LAYOUT, p_bg: String = BG) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bg = p_bg
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
	var bg := UiTheme.art_cached(_bg)
	if bg != null:
		draw_texture_rect(bg, Rect2(origin(), design_size() * scale_factor()), false)
	_draw_sign_text()


func _draw_sign_text() -> void:
	var sign_ := to_local_rect(_layout.get("sign", {}))
	if sign_text == "" or sign_.size.x <= 0.0:
		return
	var f := UiPalette.cjk_font_bold()
	var fs := maxi(12, roundi(SIGN_FONT * minf(1.0, scale_factor() * 1.4)))
	var w := f.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > sign_.size.x and w > 0.0:     # 270：字比招牌框宽就缩字，别压两侧天平
		fs = maxi(10, floori(fs * sign_.size.x / w))
		w = f.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := sign_.get_center().y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	draw_string(f, Vector2(sign_.get_center().x - w * 0.5, y), sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SIGN_INK)
