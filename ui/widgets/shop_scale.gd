## 290（局内商店重做，作者 2026-11-07 15:11）：商店中下那座天秤 —— 左盘 = 你拿的货的售价（+ 商人放上的钱），右盘 = 你给的东西的收购价 + 你放上的钱。
## 总价高的那边往下沉，横梁正中挂差额牌（「还差 N」「够了」「找你 N」「他只付得起 N」），秤座就是「成交」键（屏放进 `controls.deal` 那一格）。
##
## 和 256 求饶的 [BalanceScale] 同一套拆法与版式键（底座 / 横梁绕 pivot 转 / 两只盘只平移、挂在梁的钩上 / 一枚金币按摞堆）：
## 版式 `shop/scale_layout.json`，图 `shop/scale_base`、`shop/scale_beam`、`shop/scale_pan_left`、`shop/scale_pan_right`、`shop/scale_coin`。
## 美术定稿之前（UI设计 出了 A / B / C 三版，等作者挑）没有图：按同一套坐标画铜色占位
class_name ShopScale
extends Control

const LAYOUT := "shop/scale_layout"
const ART := "shop/scale_"
const FONT_SIZE := 16
const PLATE_FONT := 15
const INK := Color("2e2219")
const BRONZE := Color("b08a3a")
const BRONZE_DARK := Color("6b4f22")
const PLATE := Color("efe3c6")

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

var _lay: Dictionary = {}


func _init() -> void:
	_lay = layout()
	custom_minimum_size = BalanceScale._v(_lay["base_size"])
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


func control_rect(p_name: String) -> Rect2:
	return BalanceScale._rect((_lay.get("controls", {}) as Dictionary).get(p_name, [0, 0, 0, 0]))


## 横梁斜几度（正 = 左盘低）：差额占重的那边的比例，夹在 ±max_tilt_deg
func tilt_degrees() -> float:
	if left == right:
		return 0.0
	var k := float(left - right) / float(maxi(1, maxi(left, right)))
	return clampf(k, -1.0, 1.0) * float(_lay.get("max_tilt_deg", 8))


## 两只钩（梁两端）：[左, 右]
func hooks() -> Array[Vector2]:
	var pivot := BalanceScale._v(_lay["pivot"])
	var a := deg_to_rad(-tilt_degrees())
	var arm := float(_lay["arm"])
	var dy := float(_lay["hook_dy"])
	return [pivot + Vector2(-arm, dy).rotated(a), pivot + Vector2(arm, dy).rotated(a)] as Array[Vector2]


## 盘层左上角：[左, 右]
func pan_origins() -> Array[Vector2]:
	var h := hooks()
	var hook_in := BalanceScale._v(_lay["hook_in_pan"])
	return [h[0] - hook_in, h[1] - hook_in] as Array[Vector2]


## 盘上那张价牌（舞台坐标）：[左, 右]
func price_rects() -> Array[Rect2]:
	var r := BalanceScale._rect(_lay["price_rect"])
	var pans := pan_origins()
	return [Rect2(pans[0] + r.position, r.size), Rect2(pans[1] + r.position, r.size)] as Array[Rect2]


## 一只盘里画几枚金币：钱占这一盘总价的比例 × 一摞满的枚数，放了钱就至少 1 枚
func pile_count(coins: int, total: int) -> int:
	var pile: Dictionary = _lay.get("coin_pile", {})
	if coins <= 0 or pile.is_empty():
		return 0
	var full := 0
	for h in pile["full"]:
		full += int(h)
	return clampi(ceili(float(full) * coins / float(maxi(1, total))), 1, (pile["order"] as Array).size())


func _draw() -> void:
	var pans := pan_origins()
	var base_size := BalanceScale._v(_lay["base_size"])
	if not _layer("base", Vector2.ZERO, base_size):
		_draw_post()
	var beam_size := BalanceScale._v(_lay["beam_size"])
	draw_set_transform(BalanceScale._v(_lay["pivot"]), deg_to_rad(-tilt_degrees()))
	if not _layer("beam", -beam_size * 0.5, beam_size):
		draw_rect(Rect2(-beam_size * 0.5, beam_size), BRONZE)
		draw_rect(Rect2(-beam_size * 0.5, beam_size), BRONZE_DARK, false, 2.0)
	draw_set_transform(Vector2.ZERO)
	var pan_size := BalanceScale._v(_lay["pan_size"])
	for i in 2:
		if not _layer("pan_left" if i == 0 else "pan_right", pans[i], pan_size):
			_draw_pan(pans[i], pan_size)
	_draw_pile(pans[0], pile_count(left_coins, left))
	_draw_pile(pans[1], pile_count(right_coins, right))
	var prices := price_rects()
	_draw_amount(prices[0], left)
	_draw_amount(prices[1], right)
	var status := control_rect("status")
	draw_rect(status, PLATE)
	draw_rect(status, BRONZE_DARK, false, 2.0)
	var amount := CoinShort.coin_amount(plate)
	_draw_coin_text(status, CoinShort.strip(plate) if amount >= 0 else plate, amount, UiTheme.sz(PLATE_FONT))


## 一层图（有就画、返回 true）
func _layer(p_name: String, at: Vector2, size_px: Vector2) -> bool:
	var tex := UiTheme.art_cached(ART + p_name)
	if tex == null:
		return false
	draw_texture_rect(tex, Rect2(at, size_px), false)
	return true


## 占位：立柱从梁心到秤座（「成交」键顶上），柱顶一枚圆钮
func _draw_post() -> void:
	var pivot := BalanceScale._v(_lay["pivot"])
	var deal := control_rect("deal")
	var foot := deal.position.y if deal.size.y > 0.0 else size.y
	draw_rect(Rect2(pivot.x - 5.0, pivot.y, 10.0, foot - pivot.y), BRONZE)
	draw_rect(Rect2(pivot.x - 22.0, foot - 8.0, 44.0, 8.0), BRONZE_DARK)
	draw_circle(pivot, 9.0, BRONZE_DARK)
	draw_circle(pivot, 5.0, BRONZE)


## 占位：两根吊绳 + 一只浅碗
func _draw_pan(at: Vector2, size_px: Vector2) -> void:
	var hook := at + BalanceScale._v(_lay["hook_in_pan"])
	var rim_y := at.y + size_px.y * 0.68
	draw_line(hook, Vector2(at.x + 6.0, rim_y), BRONZE_DARK, 1.5, true)
	draw_line(hook, Vector2(at.x + size_px.x - 6.0, rim_y), BRONZE_DARK, 1.5, true)
	var bowl := PackedVector2Array([Vector2(at.x, rim_y), Vector2(at.x + size_px.x, rim_y),
		Vector2(at.x + size_px.x - 14.0, at.y + size_px.y), Vector2(at.x + 14.0, at.y + size_px.y)])
	draw_colored_polygon(bowl, BRONZE)
	draw_polyline(bowl + PackedVector2Array([bowl[0]]), BRONZE_DARK, 2.0, true)


func _draw_pile(origin: Vector2, n: int) -> void:
	if n <= 0:
		return
	var pile: Dictionary = _lay["coin_pile"]
	var step := float(pile["step"])
	var tex := UiTheme.art_cached(ART + "coin")
	var cs := tex.get_size() if tex != null else Vector2(20, 6)
	for k in n:
		var cell: Array = pile["order"][k]
		var r := Rect2(origin + Vector2(float(pile["cols"][int(cell[0])]) - cs.x * 0.5, float(pile["base_y"]) - (int(cell[1]) + 1) * step), cs)
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			draw_rect(r, CoinLabel.FALLBACK_FILL)
			draw_rect(r, BRONZE_DARK, false, 1.0)


## 价牌：「金币 + 数」（钱 = 金币图标 + 数）
func _draw_amount(r: Rect2, amount: int) -> void:
	draw_rect(r, PLATE)
	draw_rect(r, BRONZE_DARK, false, 1.5)
	_draw_coin_text(r, "", amount, UiTheme.sz(FONT_SIZE))


## 一行居中：「字 + 金币 + 数」（amount < 0 只写字）
func _draw_coin_text(r: Rect2, words: String, amount: int, fs: int) -> void:
	var f := UiPalette.cjk_font_bold()
	var num := "%d" % amount if amount >= 0 else ""
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
	var tex := CoinLabel.coin_texture()
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2(x, mid.y - side * 0.5), Vector2(side, side)), false)
	else:
		draw_circle(Vector2(x + side * 0.5, mid.y), side * 0.45, CoinLabel.FALLBACK_FILL)
	draw_string(f, Vector2(x + side + CoinLabel.GAP, base_y), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
