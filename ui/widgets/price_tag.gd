## 商店价签（226 §1.5，作者 17:25 定乙 铜挂牌 `notice/price_bronze`）：挂在货架格下面，挂绳朝上；
## 宽 = 字宽 + [constant LEFT] + [constant RIGHT]，高 40（上 12 是挂绳，字在下面 28 的签身里居中），深棕字由代码写。
## 卖掉了照旧写价钱，再盖 `notice/stamp_sold`（英文 `_en`）：戳 56 × 56，中心对准价签右上角，往上压到商品格、不挡价钱。点不着。
## 251 补充一 §10.1：[member coin] ≥ 0 是金币式 —— 签身上画「金币 + 数字」（[CoinLabel] 那枚币），不写「币」字（基地集市用）
class_name PriceTag
extends Control

const ART := "notice/price_bronze"
const STAMP_ART := "notice/stamp_sold"
const HEIGHT := 40.0
## 签身从图顶下 12 起（挂绳）
const BODY_TOP := 12.0
const LEFT := 26.0
const RIGHT := 12.0
const FONT_SIZE := 14
const STAMP := 56.0
const INK := Color("2a1d0c")

var text := "":
	set(v):
		text = v
		_fit()
		queue_redraw()
## 金币式的钱数；-1 = 写 [member text]
var coin := -1:
	set(v):
		coin = v
		_fit()
		queue_redraw()
## 卖掉了：盖已售戳
var sold := false:
	set(v):
		sold = v
		queue_redraw()

var _box: StyleBoxTexture = null


func _init(p_text: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text = p_text


## 金币式：一张写着 [param amount] 的价签
static func coins(amount: int) -> PriceTag:
	var p := PriceTag.new()
	p.coin = amount
	return p


func _coin_side() -> float:
	return roundf(FONT_SIZE * CoinLabel.COIN_SCALE)


func _fit() -> void:
	var f := UiPalette.cjk_font_bold()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	if coin >= 0:
		w = _coin_side() + CoinLabel.GAP + f.get_string_size("%d" % coin, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	custom_minimum_size = Vector2(ceilf(w + LEFT + RIGHT), HEIGHT)
	size = custom_minimum_size


## 戳的矩形（价签坐标）
func stamp_rect() -> Rect2:
	return Rect2(Vector2(size.x, 0.0) - Vector2(STAMP, STAMP) * 0.5, Vector2(STAMP, STAMP))


func _draw() -> void:
	if _box == null:
		_box = UiTheme.art_box(ART)
	var box := _box
	if box != null:
		draw_style_box(box, Rect2(Vector2.ZERO, size))
	else:
		draw_rect(Rect2(Vector2(0.0, BODY_TOP), Vector2(size.x, size.y - BODY_TOP)), Color("b07a3a"))
	var f := UiPalette.cjk_font_bold()
	var mid := BODY_TOP + (size.y - BODY_TOP) * 0.5
	var y := mid + (f.get_ascent(FONT_SIZE) - f.get_descent(FONT_SIZE)) * 0.5
	if coin >= 0:
		var side := _coin_side()
		var tex := CoinLabel.coin_texture()
		var r := Rect2(Vector2(LEFT, mid - side * 0.5), Vector2(side, side))
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			draw_circle(r.get_center(), side * 0.45, CoinLabel.FALLBACK_FILL)
		draw_string(f, Vector2(LEFT + side + CoinLabel.GAP, y), "%d" % coin, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
	else:
		draw_string(f, Vector2(LEFT, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
	if sold:
		var tex := UiTheme.art_cached(UiTheme.lang_art(STAMP_ART))
		if tex != null:
			draw_texture_rect(tex, stamp_rect(), false)
