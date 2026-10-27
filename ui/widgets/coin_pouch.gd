## 商店：玩家当前金币（作者 10-27 选 B 钱袋，14:09 挪到左下角 —— 商店左栏下排按键右边、背包栏左边那块空地）。
## 立着的皮钱袋（`shop/coin_pouch`）+ 袋前一张小纸签（`shop/coin_slip`，九宫格横向拉），签上写「金币 + 数」（[CoinLabel]，墨字）。
## 钱袋底压在纸签后面 [constant OVERLAP]。点不着；钱数就写在签上，不开悬浮窗
class_name CoinPouch
extends Control

const POUCH_ART := "shop/coin_pouch"
const SLIP_ART := "shop/coin_slip"
const SLIP_MIN := Vector2(102, 38)
## 纸签里字的左右留白（右边让开燕尾）
const PAD_LEFT := 12.0
const PAD_RIGHT := 22.0
const OVERLAP := 18.0
## 钱袋比纸签正中往左挪一点（纸签的字区让开了燕尾，看起来才居中）
const POUCH_SHIFT := -4.0
const FONT_SIZE := 21
const INK := Color("2e2219")

var amount := 0:
	set(v):
		amount = v
		_label.amount = v
		_fit()

var _label: CoinLabel = null
var _slip: StyleBoxTexture = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = CoinLabel.make(0, FONT_SIZE, INK)
	_label.centered = true
	add_child(_label)
	_slip = UiTheme.art_box(SLIP_ART)
	_fit()


func _pouch_size() -> Vector2:
	var t := UiTheme.art_cached(POUCH_ART)
	return t.get_size() if t != null else Vector2(92, 121)


func slip_rect() -> Rect2:
	var w := maxf(SLIP_MIN.x, _label.custom_minimum_size.x + PAD_LEFT + PAD_RIGHT)
	return Rect2(Vector2((size.x - w) * 0.5, size.y - SLIP_MIN.y), Vector2(w, SLIP_MIN.y))


func _fit() -> void:
	var ps := _pouch_size()
	var w := maxf(SLIP_MIN.x, _label.custom_minimum_size.x + PAD_LEFT + PAD_RIGHT)
	custom_minimum_size = Vector2(maxf(ps.x, w), ps.y + SLIP_MIN.y - OVERLAP)
	_place_label()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_label()


func _place_label() -> void:
	if _label == null:
		return
	var r := slip_rect()
	_label.position = r.position + Vector2(PAD_LEFT, 0.0)
	_label.size = Vector2(r.size.x - PAD_LEFT - PAD_RIGHT, r.size.y)


func _draw() -> void:
	var ps := _pouch_size()
	var r := slip_rect()
	var at := Vector2(r.get_center().x - ps.x * 0.5 + POUCH_SHIFT, r.position.y + OVERLAP - ps.y)
	var tex := UiTheme.art_cached(POUCH_ART)
	if tex != null:
		draw_texture_rect(tex, Rect2(at, ps), false)
	else:
		draw_circle(at + ps * Vector2(0.5, 0.6), ps.x * 0.4, Color("8b5a33"))
	if _slip != null:
		draw_style_box(_slip, r)
	else:
		draw_rect(r, Color("efe3c6"))
