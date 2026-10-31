## 270：散货摊的【换货 ◎ N】木牌键（UI替换美术 B 定稿 `market/refresh{,_hover,_pressed,_disabled}`，180 × 52，图上不带字；`market/refresh.json` 给字框与字色）。
## 左框写「换货」，右框写金币 + 价；钱不够（[member poor]）贴压灰那张、价钱写红、点不了。按下态字浅色、下移 1 px。整页缩放时 [member scale_k] 跟着缩
class_name RefreshKey
extends Button

const ART := "market/refresh"
const SIZE := Vector2(180, 52)

## 这次换货要多少
var price := 0:
	set(v):
		price = v
		queue_redraw()
## 钱不够
var poor := false:
	set(v):
		poor = v
		disabled = v
		queue_redraw()
## 整页缩放（1 = 底图原尺寸）
var scale_k := 1.0:
	set(v):
		scale_k = v
		custom_minimum_size = (SIZE * scale_k).floor()
		size = custom_minimum_size
		queue_redraw()

var _spec: Dictionary = {}
var _tex := {}


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = SIZE
	_spec = UiTheme.art_meta(ART)
	for st in ["normal", "hover", "pressed", "disabled"]:
		_tex[st] = UiTheme.art_cached(ART if st == "normal" else ART + "_" + st)
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(s, none)     # 底由 _draw 按态贴


## 现在贴哪一态
func state() -> String:
	if disabled:
		return "disabled"
	match get_draw_mode():
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			return "pressed"
		DRAW_HOVER:
			return "hover"
	return "normal"


func _box(key: String, fallback: Rect2) -> Rect2:
	var r: Dictionary = _spec.get(key, {})
	if r.is_empty():
		return fallback
	return Rect2(float(r.get("x", 0)), float(r.get("y", 0)), float(r.get("w", 0)), float(r.get("h", 0)))


func _ink(font_key: String, st: String, fallback: Color) -> Color:
	var cols: Dictionary = (_spec.get(font_key, {}) as Dictionary).get("colors", {})
	return Color(String(cols.get(st, cols.get("normal", fallback.to_html()))))


func _draw() -> void:
	var st := state()
	var k := size.x / SIZE.x if size.x > 0.0 else scale_k
	var tex: Texture2D = _tex.get(st)
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("8a5a32") if st != "disabled" else Color("6e655a"))
	var dy := 1.0 if st == "pressed" else 0.0
	var f := UiPalette.cjk_font_bold()
	# 字框（原尺寸）× 缩放；字号按档放大，框里放不下就一号号缩
	var lb := _box("label", Rect2(12, 0, 90, 52))
	var lfs := maxi(10, roundi(UiTheme.sz(int((_spec.get("font", {}) as Dictionary).get("size", 22))) * k))
	var label := UiText.t("market.refresh")
	while lfs > 10 and f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x > lb.size.x * k:
		lfs -= 1
	var ly := (lb.position.y + lb.size.y * 0.5) * k + (f.get_ascent(lfs) - f.get_descent(lfs)) * 0.5 + dy
	draw_string(f, Vector2(lb.position.x * k, ly), label, HORIZONTAL_ALIGNMENT_CENTER, lb.size.x * k, lfs, _ink("font", st, Color("2e2219")))
	var pb := _box("price", Rect2(102, 9, 66, 34))
	var pfs := maxi(10, roundi(float((_spec.get("price_font", {}) as Dictionary).get("size", 20)) * k))
	var num := "%d" % price
	var side := roundf(pfs * CoinLabel.COIN_SCALE)
	while pfs > 10 and side + CoinLabel.GAP + f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x > pb.size.x * k:
		pfs -= 1
		side = roundf(pfs * CoinLabel.COIN_SCALE)
	var w := side + CoinLabel.GAP + f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	var x := pb.position.x * k + maxf(0.0, (pb.size.x * k - w) * 0.5)
	var mid := (pb.position.y + pb.size.y * 0.5) * k + dy
	var coin := CoinLabel.coin_texture()
	var cr := Rect2(Vector2(x, mid - side * 0.5), Vector2(side, side))
	if coin != null:
		draw_texture_rect(coin, cr, false)
	else:
		draw_circle(cr.get_center(), side * 0.45, CoinLabel.FALLBACK_FILL)
	var pink := _ink("price_font", "poor" if poor else ("pressed" if st == "pressed" else "normal"), Color("2a1d0c"))
	draw_string(f, Vector2(x + side + CoinLabel.GAP, mid + (f.get_ascent(pfs) - f.get_descent(pfs)) * 0.5), num, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, pink)
