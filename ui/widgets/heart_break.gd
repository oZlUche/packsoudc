## 作者 11-12：打输扣体力（逃跑失败也算）回到地图时放一段 —— 屏幕中央一颗红心被斜着劈开、变成黑心，
## 然后慢慢缩小、飞回左上角的体力条，落在原来最右边那颗红心的位置（那颗从此是黑的）。扣两点就从右往左连劈两颗。
## 点一下鼠标直接跳到结尾。还没落下的心，体力条照旧画成红的（[member owed]）
class_name HeartBreak
extends Control

## 中央那颗心多大
const SIZE := 168.0
## 各段多久（一颗心合计 1.73 s）：弹出、一刀划过、裂开变黑、停一下、飞回去
const POP_SEC := 0.2
const SLASH_SEC := 0.15
const SPLIT_SEC := 0.3
const HOLD_SEC := 0.28
const FLY_SEC := 0.8
## 两半各往外错开多远（中央那颗的大小下）
const GAP := 9.0
## 刀口方向：右上 → 左下，斜着劈
const CUT := Vector2(0.62, -1.0)
## 哪些扣体力的原因放这一段
const REASONS := [&"battle_lost", &"flee"]
const SLASH := Color("fff1e6")
const EDGE := Color("1a1214")

## 还欠着没演的心：体力条按这个数多画几颗红的（导演记账、这里落一颗减一颗）
static var owed := 0

var _widget: Control = null     # 体力条（落点）
var _index := -1     # 正在演的是第几颗（体力条里的序号）
var _t := 0.0     # 这一颗演到第几秒
var _tween: Tween = null


static func total_sec() -> float:
	return POP_SEC + SLASH_SEC + SPLIT_SEC + HOLD_SEC + FLY_SEC


## 在 [param parent] 上铺满放，落到 [param widget]（体力条）上。没欠的就不放
static func play_on(parent: Control, widget: Control) -> HeartBreak:
	if owed <= 0 or parent == null or widget == null:
		return null
	var hb := HeartBreak.new()
	hb._widget = widget
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_STOP     # 点一下跳过（演着时地图也点不着）
	parent.add_child(hb)
	hb._next()
	return hb


## 下一颗：体力条里还红着的最右边那颗
func _next() -> void:
	if owed <= 0 or not is_instance_valid(_widget):
		skip()
		return
	_index = int(_widget.call("hearts").y) - 1
	_t = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_t, 0.0, total_sec(), total_sec())
	_tween.tween_callback(_land)


func _set_t(v: float) -> void:
	_t = v
	queue_redraw()


## 落下：体力条那颗变黑，接着演下一颗
func _land() -> void:
	owed = maxi(0, owed - 1)
	_refresh_widget()
	_next()


## 跳到结尾：欠的全落下，自己摘掉
func skip() -> void:
	owed = 0
	if _tween != null:
		_tween.kill()
		_tween = null
	_refresh_widget()
	queue_free()


func _refresh_widget() -> void:
	if is_instance_valid(_widget) and _widget.has_method("refresh"):
		_widget.call("refresh")
		_widget.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		accept_event()
		skip()


#region 各段的进度（测试看）
static func _cl(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func _out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func pop() -> float:
	return _out(_cl(_t / POP_SEC))


func slash() -> float:
	return _cl((_t - POP_SEC) / SLASH_SEC)


func split() -> float:
	return _out(_cl((_t - POP_SEC - SLASH_SEC) / SPLIT_SEC))


func fly() -> float:
	return smoothstep(0.0, 1.0, _cl((_t - total_sec() + FLY_SEC) / FLY_SEC))
#endregion


## 落点（本控件坐标）：体力条第 i 颗心的框
func _target() -> Rect2:
	if not is_instance_valid(_widget) or _index < 0:
		return Rect2(size * 0.5, Vector2.ZERO)
	var r: Rect2 = _widget.call("heart_rect", _index)
	var to_me := get_global_transform().affine_inverse()
	return Rect2(to_me * r.position, to_me.basis_xform(r.size))


func _draw() -> void:
	if _index < 0:
		return
	var f := fly()
	var goal := _target()
	var s := lerpf(SIZE, goal.size.x, f) * lerpf(0.6, 1.0, pop())
	var center := (size * 0.5).lerp(goal.get_center(), f)
	var k := s / SIZE
	var cut := CUT.normalized()
	var normal := Vector2(-cut.y, cut.x)
	var gap := GAP * split() * (1.0 - f) * k
	var col := UiPalette.HP.lerp(UiPalette.HEART_LOST, split())
	col.a = pop()
	var heart := _heart(center, s)
	var a := center - cut * s
	var b := center + cut * s
	if split() <= 0.0:     # 还没劈开：整颗（刀口不能先露出来）
		_fill(heart, col, k)
	for side in ([] if split() <= 0.0 else [-1.0, 1.0]):
		var half_plane := PackedVector2Array([a, b, b + normal * side * s * 2.0, a + normal * side * s * 2.0])
		for piece in Geometry2D.intersect_polygons(heart, half_plane):
			_fill(Transform2D(0.0, normal * side * gap) * (piece as PackedVector2Array), col, k)
	# 刀光：一道亮线从右上划到左下，裂开时淡掉
	var sl := slash()
	if sl > 0.0 and split() < 1.0:
		var top := center + cut * s * 0.62
		var end := top.lerp(center - cut * s * 0.62, sl)
		var glow := 1.0 - split()
		draw_line(top, end, Color(UiPalette.HP, 0.45 * glow), 10.0 * k, true)
		draw_line(top, end, Color(SLASH, glow), 3.0 * k, true)


## 填色 + 描一圈深边
func _fill(poly: PackedVector2Array, col: Color, k: float) -> void:
	draw_colored_polygon(poly, col)
	var ring := poly.duplicate()
	ring.append(poly[0])
	draw_polyline(ring, Color(EDGE, col.a), maxf(1.0, 3.0 * k), true)


## 一颗心的外形（[param s] 见方，心在正中）
static func _heart(center: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var u := TAU * i / 48.0
		var x := 16.0 * pow(sin(u), 3.0)
		var y := 13.0 * cos(u) - 5.0 * cos(2.0 * u) - 2.0 * cos(3.0 * u) - cos(4.0 * u)
		pts.append(center + Vector2(x, -y - 2.5) * (s / 34.0))
	return pts
