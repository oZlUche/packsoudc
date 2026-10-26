## 256（安德烈乌斯「求饶」）：天平 —— 底座 + 立柱 + 横梁 + 两只盘（整图非矩形；美术出图前由这里画占位）。
## 左盘是玩家放上去的（金币一枚 1 + 道具的局内出售价），右盘是对方的开价；两盘上各印一枚金币 + 数（钱 = 金币图标 + 数）。
## 横梁按两边的差倾斜：左轻 → 右盘低；齐平或左重 → 水平 / 左低。梁中间一块小牌写「还差 N」/「够了」。
## 字都画在盘和牌上（226：不裸字）。点不着，托盘（棋盘）与金币步进件由屏摆在它上下
class_name BalanceScale
extends Control

const SIZE := Vector2(560, 210)
## 横梁最多斜几度
const MAX_TILT := 10.0
const BEAM_HALF := 210.0
const PIVOT_Y := 40.0
const HANG := 70.0
const PAN_W := 150.0
const PAN_DEPTH := 26.0
const FONT_SIZE := 18
const PLATE_FONT := 15
const BRONZE := Color("8a6a3a")
const BRONZE_DARK := Color("4e3a1e")
const BRONZE_LIGHT := Color("c9a462")
const PLATE := Color("e4ded2")
const INK := Color("2e2219")

## 左盘的重量 / 右盘的开价
var left := 0:
	set(v):
		left = v
		queue_redraw()
var right := 0:
	set(v):
		right = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 横梁斜几度（正 = 左低）：差额占开价的比例，夹在 ±[constant MAX_TILT]
func tilt_degrees() -> float:
	if left == right:
		return 0.0
	var k := float(left - right) / float(maxi(1, right))
	return clampf(k, -1.0, 1.0) * MAX_TILT


## 梁中那块牌上的字
func plate_text() -> String:
	return UiText.t("ransom.enough") if left >= right else UiText.t("ransom.short_by") % (right - left)


func _draw() -> void:
	var pivot := Vector2(size.x * 0.5, PIVOT_Y)
	# 底座与立柱
	var foot_y := size.y - 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(pivot.x - 70, foot_y), Vector2(pivot.x + 70, foot_y),
		Vector2(pivot.x + 40, foot_y - 22), Vector2(pivot.x - 40, foot_y - 22)]), BRONZE_DARK)
	draw_rect(Rect2(pivot.x - 7, pivot.y, 14, foot_y - 22 - pivot.y), BRONZE)
	# 横梁（左低为正：左端往下）
	var a := deg_to_rad(tilt_degrees())
	var l_end := pivot + Vector2(-cos(a), sin(a)) * BEAM_HALF
	var r_end := pivot + Vector2(cos(a), -sin(a)) * BEAM_HALF
	draw_line(l_end, r_end, BRONZE_DARK, 9.0)
	draw_line(l_end, r_end, BRONZE, 5.0)
	draw_circle(pivot, 10.0, BRONZE_DARK)
	draw_circle(pivot, 6.0, BRONZE_LIGHT)
	_draw_pan(l_end, left)
	_draw_pan(r_end, right)
	_draw_plate(pivot + Vector2(0, 26))


## 一只盘：挂绳 + 盘身 + 盘上的金币与数
func _draw_pan(hook: Vector2, amount: int) -> void:
	var rim := hook + Vector2(0, HANG)
	draw_line(hook, rim + Vector2(-PAN_W * 0.42, 0), BRONZE_DARK, 2.0)
	draw_line(hook, rim + Vector2(PAN_W * 0.42, 0), BRONZE_DARK, 2.0)
	var bowl := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		bowl.append(rim + Vector2((t - 0.5) * PAN_W, sin(t * PI) * PAN_DEPTH))
	draw_colored_polygon(bowl, BRONZE)
	draw_line(rim + Vector2(-PAN_W * 0.5, 0), rim + Vector2(PAN_W * 0.5, 0), BRONZE_LIGHT, 3.0)
	var f := UiPalette.cjk_font_bold()
	var text := "%d" % amount
	var side := roundf(FONT_SIZE * CoinLabel.COIN_SCALE)
	var w := side + CoinLabel.GAP + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var mid := rim + Vector2(0, PAN_DEPTH * 0.45)
	var at := Vector2(mid.x - w * 0.5, mid.y - side * 0.5)
	var tex := CoinLabel.coin_texture()
	if tex != null:
		draw_texture_rect(tex, Rect2(at, Vector2(side, side)), false)
	else:
		draw_circle(at + Vector2(side, side) * 0.5, side * 0.45, CoinLabel.FALLBACK_FILL)
	draw_string(f, Vector2(at.x + side + CoinLabel.GAP, mid.y + (f.get_ascent(FONT_SIZE) - f.get_descent(FONT_SIZE)) * 0.5),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, PLATE)


## 梁中的小石牌：「还差 N」/「够了」
func _draw_plate(center: Vector2) -> void:
	var f := UiPalette.cjk_font_bold()
	var text := plate_text()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT).x + 20.0
	var r := Rect2(center - Vector2(w * 0.5, 13), Vector2(w, 26))
	draw_rect(r, PLATE)
	draw_rect(r, BRONZE_DARK, false, 2.0)
	draw_string(f, Vector2(r.position.x, center.y + (f.get_ascent(PLATE_FONT) - f.get_descent(PLATE_FONT)) * 0.5),
		text, HORIZONTAL_ALIGNMENT_CENTER, w, PLATE_FONT, INK)
