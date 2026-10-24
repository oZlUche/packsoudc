## 251 补充一 §10.3（作者 14:49「金钱一定要用金币图标而不是文本」）：钱数 = 一枚金币（`assets/ui/hud/coin.png`，顶端栏那枚）+ 数字，不写「币」字。
## 集市的价签、钱袋读数，铁匠铺的工钱、钱袋读数都用它（一处写、两页用；局内商店以后也换它）。字由代码画在 `_draw` 里，
## 本身不带底 —— 摆在签 / 牌 / 卷轴上（226 不裸字）。缺图画一个描边金圆。点不着
class_name CoinLabel
extends Control

const ART := "res://assets/ui/hud/coin.png"
## 金币比字高大这么多（和顶端栏一样：币与数字同高）
const COIN_SCALE := 1.15
const GAP := 4.0
const FALLBACK_FILL := Color("e2b33c")
const FALLBACK_EDGE := Color("7a5414")

var amount := 0:
	set(v):
		amount = v
		_fit()
		queue_redraw()
var font_size := 18:
	set(v):
		font_size = v
		_fit()
		queue_redraw()
var ink := Color("2a1d0c"):
	set(v):
		ink = v
		queue_redraw()
## 数字居中摆在自己的矩形里（false = 靠左）
var centered := false

static var _tex: Texture2D = null
## 按像素缓存的小金币（按钮的图标位用）
static var _icons: Dictionary = {}


static func make(p_amount: int, p_size: int = 18, p_ink: Color = Color("2a1d0c")) -> CoinLabel:
	var c := CoinLabel.new()
	c.font_size = p_size
	c.ink = p_ink
	c.amount = p_amount
	return c


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## 金币原图（缺图 null）
static func coin_texture() -> Texture2D:
	if _tex == null and ResourceLoader.exists(ART):
		_tex = load(ART) as Texture2D
	return _tex


## 缩到 [param px] 见方的金币（Button.icon 不会自己缩图）；缺图 null
static func coin_icon(px: int) -> Texture2D:
	if _icons.has(px):
		return _icons[px]
	var src := coin_texture()
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var t := ImageTexture.create_from_image(img)
	_icons[px] = t
	return t


func coin_side() -> float:
	return roundf(font_size * COIN_SCALE)


func _text() -> String:
	return "%d" % amount


func _fit() -> void:
	var f := UiPalette.cjk_font_bold()
	var w := f.get_string_size(_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	custom_minimum_size = Vector2(ceilf(coin_side() + GAP + w), maxf(coin_side(), f.get_height(font_size)))


func _draw() -> void:
	var f := UiPalette.cjk_font_bold()
	var side := coin_side()
	var x := maxf(0.0, (size.x - custom_minimum_size.x) * 0.5) if centered else 0.0
	var mid := size.y * 0.5
	var rect := Rect2(Vector2(x, mid - side * 0.5), Vector2(side, side))
	var tex := coin_texture()
	if tex != null:
		draw_texture_rect(tex, rect, false)
	else:
		draw_circle(rect.get_center(), side * 0.45, FALLBACK_FILL)
		draw_arc(rect.get_center(), side * 0.45, 0.0, TAU, 24, FALLBACK_EDGE, 1.5)
	var y := mid + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5
	draw_string(f, Vector2(x + side + GAP, y), _text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
