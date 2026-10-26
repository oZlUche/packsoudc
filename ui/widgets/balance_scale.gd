## 256（安德烈乌斯「求饶」）：天平窗的整块舞台（作者 2026-10-26 15:49 定稿，青铜那一稿）—— 四层图：
## 底座（立柱、标题牌、差额牌、下面的石台，`ransom/ransom_base` 1000 × 724，非矩形）、横梁（绕自己正中转，正中对齐底座的 pivot）、
## 左右两只盘（不转只平移，盘层的 hook 点挂在梁的钩上：钩 = pivot + rot(倾角)·(±arm, hook_dy)）。坐标与各控件的位置都在
## `ransom/ransom_layout.json`。左盘上方的托盘棋盘、右盘下的开价小牌跟着盘走：屏往 [member tray_slot] 里放托盘，开价由这里画（金币 + 数）。
## 差额牌上写「还差 N」/「够了」。字都落在石牌 / 石台上（226：不裸字）。没有图时（美术目录缺）按同一套坐标画占位
class_name BalanceScale
extends Control

const LAYOUT := "ransom/ransom_layout"
const BASE_ART := "ransom/ransom_base"
const BEAM_ART := "ransom/ransom_beam"
const PAN_LEFT_ART := "ransom/ransom_pan_left"
const PAN_RIGHT_ART := "ransom/ransom_pan_right"
const FONT_SIZE := 20
const PLATE_FONT := 18
const INK := Color("2e2219")
## 石台底下那行小字（浅底：淡墨）
const INK_SOFT := Color("605a50")
## 缺图时的占位色
const BRONZE := Color("8a6a3a")
const PLATE := Color("e4ded2")

## 左盘的重量 / 右盘的开价
var left := 0:
	set(v):
		left = v
		_relayout()
var right := 0:
	set(v):
		right = v
		_relayout()

## 托盘棋盘的位置（左盘的 tray_rect，跟着盘走）：屏把托盘放进来，底边坐在盘沿上
var tray_slot: VBoxContainer = null
var _lay: Dictionary = {}


func _init() -> void:
	_lay = layout()
	custom_minimum_size = _v(_lay["base_size"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_slot = VBoxContainer.new()
	tray_slot.alignment = BoxContainer.ALIGNMENT_END
	tray_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_slot)
	_relayout()


## 版式：美术的 json；没有就用同形状的一份（尺寸与美术稿一样，测试与占位都按它摆）
static func layout() -> Dictionary:
	var d := UiTheme.art_meta(LAYOUT)
	if not d.is_empty():
		return d
	return {"base_size": [1000, 724], "pivot": [500, 110], "arm": 330, "hook_dy": 18, "max_tilt_deg": 8, "beam_size": [760, 64],
		"pan_size": [340, 362], "hook_in_pan": [170, 8], "tray_rect": [20, 90, 320, 258], "price_rect": [112, 320, 228, 354],
		"controls": {"title": [404, 26, 596, 62], "status": [424, 200, 576, 236], "subtitle": [250, 576, 750, 604],
			"stepper": [86, 620, 366, 686], "deal": [606, 626, 756, 678], "refuse": [780, 626, 930, 678], "hint": [300, 690, 700, 712]}}


## 底座上某个控件的框（`controls` 里的名字：title / status / subtitle / stepper / deal / refuse / hint）
func control_rect(name: String) -> Rect2:
	return _rect((_lay.get("controls", {}) as Dictionary).get(name, [0, 0, 0, 0]))


## 横梁斜几度（正 = 左盘低）：差额占开价的比例，夹在 ±max_tilt_deg
func tilt_degrees() -> float:
	if left == right:
		return 0.0
	var k := float(left - right) / float(maxi(1, right))
	return clampf(k, -1.0, 1.0) * float(_lay.get("max_tilt_deg", 8))


## 差额牌上的字
func plate_text() -> String:
	return UiText.t("ransom.enough") if left >= right else UiText.t("ransom.short_by") % (right - left)


## 两只钩（梁两端）在舞台上的位置：[左, 右]。美术的倾角正 = 右盘沉，所以这里取 tilt_degrees 的反号
func hooks() -> Array[Vector2]:
	var pivot := _v(_lay["pivot"])
	var a := deg_to_rad(-tilt_degrees())
	var arm := float(_lay["arm"])
	var dy := float(_lay["hook_dy"])
	return [pivot + Vector2(-arm, dy).rotated(a), pivot + Vector2(arm, dy).rotated(a)] as Array[Vector2]


## 盘层左上角：[左, 右]
func pan_origins() -> Array[Vector2]:
	var h := hooks()
	var hook_in := _v(_lay["hook_in_pan"])
	return [h[0] - hook_in, h[1] - hook_in] as Array[Vector2]


## 右盘开价小牌（舞台坐标）
func price_rect() -> Rect2:
	var r := _rect(_lay["price_rect"])
	return Rect2(pan_origins()[1] + r.position, r.size)


func _relayout() -> void:
	if tray_slot != null and not _lay.is_empty():
		var r := _rect(_lay["tray_rect"])
		tray_slot.position = pan_origins()[0] + r.position
		tray_slot.size = r.size
	queue_redraw()


func _draw() -> void:
	var pans := pan_origins()
	_draw_layer(BASE_ART, Vector2.ZERO, _v(_lay["base_size"]))
	# 横梁：绕自己正中转，正中在 pivot
	var beam_size := _v(_lay["beam_size"])
	draw_set_transform(_v(_lay["pivot"]), deg_to_rad(-tilt_degrees()))
	_draw_layer(BEAM_ART, -beam_size * 0.5, beam_size)
	draw_set_transform(Vector2.ZERO)
	var pan_size := _v(_lay["pan_size"])
	_draw_layer(PAN_LEFT_ART, pans[0], pan_size)
	_draw_layer(PAN_RIGHT_ART, pans[1], pan_size)
	_draw_coin_amount(price_rect(), right)
	_draw_centered(control_rect("status"), plate_text(), PLATE_FONT)


## 一层图；缺图画个占位（底座只画立柱和石台，梁一根线，盘一只碗）
func _draw_layer(art: String, at: Vector2, size_px: Vector2) -> void:
	var tex := UiTheme.art_cached(art)
	if tex != null:
		draw_texture_rect(tex, Rect2(at, size_px), false)
		return
	match art:
		BASE_ART:
			var pivot := _v(_lay["pivot"])
			draw_rect(Rect2(pivot.x - 18, pivot.y, 36, 450), PLATE)
			draw_rect(Rect2(40, 568, size_px.x - 80, 152), PLATE)
			for k in ["title", "status"]:
				draw_rect(control_rect(k), PLATE)
				draw_rect(control_rect(k), INK, false, 2.0)
		BEAM_ART:
			draw_rect(Rect2(at + Vector2(0, size_px.y * 0.4), Vector2(size_px.x, size_px.y * 0.2)), BRONZE)
		_:
			var rim := at + Vector2(0, 250)
			draw_rect(Rect2(rim, Vector2(size_px.x, 50)), BRONZE)
			draw_rect(Rect2(at + _rect(_lay["price_rect"]).position, _rect(_lay["price_rect"]).size), PLATE)


## 小牌上的「金币 + 数」（钱 = 金币图标 + 数）
func _draw_coin_amount(r: Rect2, amount: int) -> void:
	var f := UiPalette.cjk_font_bold()
	var text := "%d" % amount
	var side := roundf(FONT_SIZE * CoinLabel.COIN_SCALE)
	var w := side + CoinLabel.GAP + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var mid := r.get_center()
	var at := Vector2(mid.x - w * 0.5, mid.y - side * 0.5)
	var tex := CoinLabel.coin_texture()
	if tex != null:
		draw_texture_rect(tex, Rect2(at, Vector2(side, side)), false)
	else:
		draw_circle(at + Vector2(side, side) * 0.5, side * 0.45, CoinLabel.FALLBACK_FILL)
	draw_string(f, Vector2(at.x + side + CoinLabel.GAP, mid.y + (f.get_ascent(FONT_SIZE) - f.get_descent(FONT_SIZE)) * 0.5),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)


func _draw_centered(r: Rect2, text: String, font_size: int) -> void:
	var f := UiPalette.cjk_font_bold()
	draw_string(f, Vector2(r.position.x, r.get_center().y + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5),
		text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, INK)


static func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## json 里的框是 [左, 上, 右, 下]
static func _rect(a) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))
