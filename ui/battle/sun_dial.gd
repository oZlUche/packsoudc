## 388 日神（UI设计定稿 A，作者 11-25）：战斗框顶边正中一枚日月盘 —— 盘面白昼金 / 黑夜靛，两边同时算时斜切两半；
## 盘里写离换边的秒数（一位小数），外圈一道弧倒计时（12 点起顺时针，长 = 这一段剩下的 ÷ 这一段多长）；另一边是 0 秒写 ∞、圈画满。
## 时间轴由 [method SunCycle.clock_of] 从回放日志还原，[member now] 跟着回放走。悬停发 [signal hovered]，宿主开石刻悬浮窗
class_name SunDial
extends Control

signal hovered(at: Vector2)
signal unhovered

## 盘径、外圈宽、弧宽、铜边宽（规格按 1600×900 量）
const DIAMETER := 80.0
const RING := 7.0
const ARC := 5.0
const BRASS := 4.0
const SIZE := DIAMETER + RING * 2.0 + 6.0
const BRASS_COLOR := Color("#C9A04E")
const RING_BG := Color("#1A1610")
const DAY_ARC := Color("#FFD776")
const NIGHT_ARC := Color("#B9C6FF")
const DAY_GRAD: Array[Color] = [Color("#FFF1C2"), Color("#F0C868"), Color("#C99636")]
const NIGHT_GRAD: Array[Color] = [Color("#46507A"), Color("#262C4A"), Color("#151A30")]
const DAY_INK := Color("#6B3F0E")
const NIGHT_INK := Color("#E8ECFF")
const ICONS := {"day": "res://assets/ui/effects/sun_day.png", "night": "res://assets/ui/effects/sun_night.png"}

var clock: SunCycle = null
var duration: float = 0.0
var now: float = 0.0:
	set(v):
		now = v
		queue_redraw()
var _segs: Array = []
var _cap := 0.0
var _icons: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hovered.emit(get_global_rect().get_center() + Vector2(SIZE * 0.5, 0)))
	mouse_exited.connect(func(): unhovered.emit())
	for k in ICONS:
		if ResourceLoader.exists(String(ICONS[k])):
			_icons[k] = load(String(ICONS[k]))


## 换一场：有日神就显示
func load_result(result: BattleResult) -> void:
	clock = SunCycle.clock_of(result)
	duration = result.duration_sec() if result != null else 0.0
	visible = clock != null
	_segs = []
	if clock != null:
		_cap = clock.horizon(duration)
		_segs = clock.segments(_cap)
	now = 0.0


## 这一刻：{day, night, left, span}
func state() -> Dictionary:
	return SunCycle.clock_at(_segs, now, _cap) if clock != null else {}


## 悬浮窗：第一行「黑夜 · 还有 4.8 秒」，第二行这一边的加成，第三行两边各几秒
func tip_parts() -> Dictionary:
	var s := state()
	if s.is_empty():
		return {}
	var both := bool(s["day"]) and bool(s["night"])
	var side := UiText.t("sun.both") if both else (UiText.t("sun.day") if bool(s["day"]) else UiText.t("sun.night"))
	var head := side + UiText.t("tip.gap") + (UiText.t("sun.forever") if float(s["left"]) < 0.0 else UiText.t("sun.left") % ("%.1f" % float(s["left"])))
	var lines: Array[String] = []
	if bool(s["day"]):
		lines.append(UiText.t("sun.day_bonus") % _num(clock.day_damage))
	if bool(s["night"]):
		lines.append(UiText.t("sun.night_bonus") % _num(clock.night_haste))
	lines.append("[color=#%s]%s[/color]" % [UiPalette.DIM.to_html(false), UiText.t("sun.lengths") % [_num(clock.day_sec), _num(clock.night_sec)]])
	return {"head": head, "body": "\n".join(lines)}


## 整数不带小数点，别的留一位
static func _num(x: float) -> String:
	return str(roundi(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x


func _draw() -> void:
	var s := state()
	if s.is_empty():
		return
	var c := size * 0.5
	var r := DIAMETER * 0.5
	var day := bool(s["day"])
	var night := bool(s["night"])
	var left := float(s["left"])
	# 投影、外圈底
	draw_circle(c + Vector2(0, 3), r + RING + 2.0, Color(0, 0, 0, 0.35))
	draw_circle(c, r + RING, RING_BG)
	# 弧：这一段剩下的（不会变 = 画满）
	var frac := 1.0 if left < 0.0 or float(s["span"]) <= 0.0 else clampf(left / float(s["span"]), 0.0, 1.0)
	var arc_col := NIGHT_ARC if night and not day else DAY_ARC
	if frac > 0.0:
		draw_arc(c, r + RING * 0.5, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, arc_col, ARC, true)
	# 铜边
	draw_circle(c, r, BRASS_COLOR)
	var inner := r - BRASS
	if day and night:
		_disc(c, inner, DAY_GRAD, PI * 0.75, PI * 1.75)     # 左上一半金
		_disc(c, inner, NIGHT_GRAD, -PI * 0.25, PI * 0.75)  # 右下一半靛
		_icon("day", c + Vector2(-inner * 0.36, -inner * 0.36), inner * 0.62, DAY_INK)
		_icon("night", c + Vector2(inner * 0.36, inner * 0.1), inner * 0.62, NIGHT_INK)
		_seconds(c, inner, left, NIGHT_INK, true)
	else:
		_disc(c, inner, DAY_GRAD if day else NIGHT_GRAD, 0.0, TAU)
		var ink := DAY_INK if day else NIGHT_INK
		_icon("day" if day else "night", c + Vector2(0, -inner * 0.28), DIAMETER * 0.5, ink)
		_seconds(c, inner, left, ink, false)


## 一块径向渐变的扇面（[param from] 到 [param to] 弧度）：由外往里一圈圈叠
func _disc(c: Vector2, r: float, grad: Array[Color], from: float, to: float) -> void:
	const STEPS := 14
	for i in STEPS:
		var k := float(i) / float(STEPS - 1)
		var rr := r * (1.0 - k * 0.92)
		var col := grad[2].lerp(grad[1], minf(1.0, k * 2.0)) if k < 0.5 else grad[1].lerp(grad[0], (k - 0.5) * 2.0)
		if to - from >= TAU - 0.001:
			draw_circle(c + Vector2(-r, -r) * 0.18 * k, rr, col)
		else:
			var pts := PackedVector2Array([c])
			for j in 33:
				var a := from + (to - from) * float(j) / 32.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)


func _icon(key: String, at: Vector2, px: float, tint: Color) -> void:
	var tex: Texture2D = _icons.get(key, null)
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(at - Vector2(px, px) * 0.5, Vector2(px, px)), false, tint)


func _seconds(c: Vector2, inner: float, left: float, ink: Color, shadow: bool) -> void:
	var f := UiPalette.display_font()
	var px := roundi(DIAMETER * 0.2)
	var text := "∞" if left < 0.0 else "%.1f" % left
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := c + Vector2(-w * 0.5, inner * 0.62)
	if shadow:
		draw_string(f, base + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.6))
	draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
