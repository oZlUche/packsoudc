## 290（局内商店重做，作者 2026-11-07 15:11）：商店中下那座天秤 —— 左盘 = 你拿的货的售价（+ 商人放上的钱），右盘 = 你给的东西的收购价 + 你放上的钱。
## 总价高的那边往下沉，横梁正中挂差额牌（「还差 N」「够了」「找你 N」「他只付得起 N」），秤座就是「成交」键（屏放进 `controls.deal` 那一格）。
##
## 和 256 求饶的 [BalanceScale] 同一套拆法与版式键（底座 / 横梁绕 pivot 转 / 两只盘只平移、挂在梁的钩上 / 一枚金币按摞堆）：
## 版式 `shop/scale_layout.json`，图 `shop/scale_base`、`shop/scale_beam`、`shop/scale_pan_left`、`shop/scale_pan_right`、`shop/scale_coin`。
## 美术：A 铜天平（作者 2026-11-07 18:37 挑定，art/ui/shop290/final）
class_name ShopScale
extends PanScale

const LAYOUT := "shop/scale_layout"
const ART := "shop/scale_"
const FONT_SIZE := 16
const PLATE_FONT := 15
const INK := Color("2e2219")
const MIN_FONT := 11

## 两盘的总价（左：你拿的；右：你给的 + 你的钱）
var left := 0:
	set(v):
		left = v
		queue_redraw()
var right := 0:
	set(v):
		right = v
		queue_redraw()
## 盘里看得见的钱：左盘是商人放上的，右盘是你放上的
var left_coins := 0:
	set(v):
		left_coins = v
		queue_redraw()
var right_coins := 0:
	set(v):
		right_coins = v
		queue_redraw()
## 差额牌上的字（屏按 [method ShopSession.status] 写）
var plate := "":
	set(v):
		plate = v
		queue_redraw()


func _init() -> void:
	_lay = layout()
	custom_minimum_size = _v(_lay["base_size"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 版式：美术的 json；没有就用这一份（UI设计 样图的尺寸：1920 × 1200 下 420 × 204，下面 52 像素是「成交」键）
static func layout() -> Dictionary:
	var d := UiTheme.art_meta(LAYOUT)
	if not d.is_empty():
		return d
	return {"base_size": [420, 204], "pivot": [210, 28], "arm": 150, "hook_dy": 4, "max_tilt_deg": 8, "beam_size": [330, 12],
		"pan_size": [130, 96], "hook_in_pan": [65, 0], "price_rect": [24, 70, 106, 94],
		"coin_pile": {"cols": [44, 65, 86], "base_y": 68, "step": 5.0, "full": [2, 3, 2], "max": 3,
			"order": [[1, 0], [0, 0], [2, 0], [1, 1], [0, 1], [2, 1], [1, 2]]},
		"controls": {"status": [148, 88, 272, 116], "deal": [135, 150, 285, 202]}}


## 横梁斜几度（正 = 左盘低）：差额占重的那边的比例，夹在 ±max_tilt_deg
func tilt_degrees() -> float:
	if left == right:
		return 0.0
	var k := float(left - right) / float(maxi(1, maxi(left, right)))
	return clampf(k, -1.0, 1.0) * float(_lay.get("max_tilt_deg", 8))


## 盘上那张价牌（舞台坐标）：[左, 右]
func price_rects() -> Array[Rect2]:
	var r := _rect(_lay["price_rect"])
	var pans := pan_origins()
	return [Rect2(pans[0] + r.position, r.size), Rect2(pans[1] + r.position, r.size)] as Array[Rect2]


func _draw() -> void:
	var pans := pan_origins()
	_layer("base", Vector2.ZERO, _v(_lay["base_size"]))
	var beam_size := _v(_lay["beam_size"])
	draw_set_transform(_v(_lay["pivot"]), deg_to_rad(-tilt_degrees()))
	_layer("beam", -beam_size * 0.5, beam_size)
	draw_set_transform(Vector2.ZERO)
	var pan_size := _v(_lay["pan_size"])
	_layer("pan_left", pans[0], pan_size)
	_layer("pan_right", pans[1], pan_size)
	_draw_pile(pans[0], _pile(left_coins, left))
	_draw_pile(pans[1], _pile(right_coins, right))
	var prices := price_rects()
	if left > 0:     # UI设计 11-07（先少再多）：空盘不挂价牌、空桌不挂差额牌
		_draw_amount(prices[0], left)
	if right > 0:
		_draw_amount(prices[1], right)
	if plate == "":
		return
	var status := control_rect("status")     # 底座图里已经有空牌
	var amount := CoinShort.coin_amount(plate)
	_draw_coin_text(status, CoinShort.strip(plate) if amount >= 0 else plate, amount, UiTheme.sz(PLATE_FONT), status.size.x - 12.0)


## 一层图
func _layer(p_name: String, at: Vector2, size_px: Vector2) -> void:
	var tex := UiTheme.art_cached(ART + p_name)
	if tex != null:
		draw_texture_rect(tex, Rect2(at, size_px), false)


func _draw_pile(origin: Vector2, n: int) -> void:
	var tex := UiTheme.art_cached(ART + "coin")
	if n <= 0 or tex == null:
		return
	var pile: Dictionary = _lay["coin_pile"]
	var step := float(pile["step"])
	var cs := tex.get_size()
	for k in n:
		var cell: Array = pile["order"][k]
		draw_texture_rect(tex, Rect2(origin + Vector2(float(pile["cols"][int(cell[0])]) - cs.x * 0.5, float(pile["base_y"]) - (int(cell[1]) + 1) * step), cs), false)


## 价牌：「金币 + 数」（钱 = 金币图标 + 数），数直接写在铜盘上
func _draw_amount(r: Rect2, amount: int) -> void:
	_draw_coin_text(r, "", amount, UiTheme.sz(FONT_SIZE))


## 一行居中：「字 + 金币 + 数」（amount < 0 只写字）；给了 max_w 就一号一号往下缩到放得下，最小 MIN_FONT
func _draw_coin_text(r: Rect2, words: String, amount: int, fs: int, max_w := -1.0) -> void:
	var f := UiPalette.cjk_font_bold()
	var num := "%d" % amount if amount >= 0 else ""
	fs = fit_size(f, words, num, fs, max_w)
	var side := roundf(fs * CoinLabel.COIN_SCALE) if amount >= 0 else 0.0
	var gap := CoinLabel.GAP if words != "" and amount >= 0 else 0.0
	var ww := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := ww + gap + (side + CoinLabel.GAP + nw if amount >= 0 else 0.0)
	var mid := r.get_center()
	var base_y := mid.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	var x := mid.x - w * 0.5
	if words != "":
		draw_string(f, Vector2(x, base_y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	if amount < 0:
		return
	x += ww + gap
	CoinLabel.draw_coin(self, Rect2(Vector2(x, mid.y - side * 0.5), Vector2(side, side)))
	draw_string(f, Vector2(x + side + CoinLabel.GAP, base_y), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


## 一行「字 + 金币 + 数」放进 max_w 用的字号（max_w <= 0 不缩）
static func fit_size(f: Font, words: String, num: String, fs: int, max_w: float) -> int:
	while max_w > 0.0 and fs > MIN_FONT and coin_text_width(f, words, num, fs) > max_w:
		fs -= 1
	return fs


static func coin_text_width(f: Font, words: String, num: String, fs: int) -> float:
	var w := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if num == "":
		return w
	var gap := CoinLabel.GAP if words != "" else 0.0
	return w + gap + roundf(fs * CoinLabel.COIN_SCALE) + CoinLabel.GAP + f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
