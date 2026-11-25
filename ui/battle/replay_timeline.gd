## 回放时间轴（157）：一条横杆，长度 = 整场时长；每一下伤害、每一次倒下在杆上一个刻度
## （打对手的朝上、挨打的朝下，颜色随一方），游标是回放现在的时刻。
##
## 点一下 / 拖动 = 跳到那一刻（[signal seek_requested]，回放层调现成的 [method BattleView.seek]）；拖着时回放停着，
## 松手按原来的状态接着放（[signal scrub_started] / [signal scrub_ended]）。只画、只发信号，不认识模拟。
##
## 167（作者定 D 版）：石板上的铜章凹槽 —— 槽体九宫格（两端符石不拉伸）、已播的魔晶色亮段（同一套九宫格，按进度裁）、
## 菱形魔晶游标（`pivot` 对准当前时刻）、两色刻度贴图（倒下的拉长 1.5 倍、加宽；没播到的压到 35%）
class_name ReplayTimeline
extends Control

signal seek_requested(t: float)
signal scrub_started
signal scrub_ended
## 游标挪了（回放走、拖动、跳到头都发；日月盘跟着它）
signal cursor_moved(t: float)

const HEIGHT := 34.0
## 167：贴图（[method UiTheme.art] 的名字）、槽的半高（刻度从槽边起）、倒下的刻度放大、没播到的透明度
const ART_GROOVE := "replay/timeline_groove"
const ART_FILL := "replay/timeline_fill"
const ART_CURSOR := "replay/timeline_cursor"
const ART_TICKS := ["replay/timeline_tick_mine", "replay/timeline_tick_theirs"]
const ART_BAR_HALF := 5.0
const DEATH_SCALE := 1.5
const UNPLAYED_ALPHA := 0.35

## 整场多少秒
var duration: float = 0.0
## [[秒, 朝上?, 哪一方打出的（0 我 / 1 对手）, 倒下?], ...]
var ticks: Array = []
var cursor: float = 0.0:
	set(v):
		cursor = v
		queue_redraw()
		cursor_moved.emit(v)
var _scrubbing := false
## 167：贴图（缺一样就整条不画）
var _groove: StyleBoxTexture = null
var _fill: StyleBoxTexture = null
var _cursor_tex: Texture2D = null
var _cursor_pivot := Vector2.ZERO
var _tick_tex: Array[Texture2D] = []
## 388 日神：日夜色带的各段 [[起, 止, 白昼?, 黑夜?], ...]（空 = 不画）。只画到游标为止（作者 11-25：随进度露出来）
var sun_segments: Array = []
const SUN_H := 9.0
const SUN_GAP := 2.0
const SUN_ICON := 16.0
const SUN_DAY: Array[Color] = [Color("#FFE39A"), Color("#D9A945")]
const SUN_NIGHT: Array[Color] = [Color("#7D8BD6"), Color("#3A4378")]
var _sun_icons: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(240, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_load_art()


func _load_art() -> void:
	_groove = UiTheme.art_box(ART_GROOVE)
	_fill = UiTheme.art_box(ART_FILL)
	_cursor_tex = UiTheme.art(ART_CURSOR)
	var pivot: Array = UiTheme.art_meta(ART_CURSOR).get("pivot", [])
	if _cursor_tex != null:
		_cursor_pivot = Vector2(float(pivot[0]), float(pivot[1])) if pivot.size() == 2 else _cursor_tex.get_size() * 0.5
	_tick_tex.clear()
	for n in ART_TICKS:
		var tex := UiTheme.art(n)
		if tex != null:
			_tick_tex.append(tex)
	if _groove == null or _fill == null or _cursor_tex == null or _tick_tex.size() != 2:
		_groove = null


## 杆两头留的空：两端符石的宽（槽九宫格的左右边距）
func pad() -> float:
	return _groove.texture_margin_left if _groove != null else 0.0


## 换一场：时长与刻度从日志来
func load_result(result: BattleResult) -> void:
	duration = result.duration_sec() if result != null else 0.0
	ticks = ticks_of(result)
	var clock := SunCycle.clock_of(result)
	sun_segments = clock.segments(duration) if clock != null else []
	custom_minimum_size.y = HEIGHT + (SUN_H + SUN_ICON + 4.0 if not sun_segments.is_empty() else 0.0)
	if not sun_segments.is_empty() and _sun_icons.is_empty():
		for k in ["sun_day", "sun_night"]:
			var path := "res://assets/ui/effects/%s.png" % k
			if ResourceLoader.exists(path):
				_sun_icons[k] = load(path)
	cursor = 0.0


## 刻度：伤害（数不为 0）与倒下。伤害事件的 side 是挨打的一方，打出这一下的是另一方 —— 我方打出的朝上
static func ticks_of(result: BattleResult) -> Array:
	var out: Array = []
	if result == null:
		return out
	for e in result.log:
		var ev := e as BattleEvent
		if ev.name == BattleEvent.DAMAGE and ev.get_int(&"amount") != 0 and ev.side >= 0:
			var by := 1 - ev.side
			out.append([StatMath.to_float(ev.time), by == 0, by, false])
		elif ev.name == BattleEvent.DIED and ev.side >= 0:
			out.append([StatMath.to_float(ev.time), ev.side == 1, 1 - ev.side, true])
	return out


## 杆上的横坐标 ↔ 时刻
func time_at(x: float) -> float:
	var w := maxf(1.0, size.x - pad() * 2)
	return clampf((x - pad()) / w, 0.0, 1.0) * duration


func x_of(t: float) -> float:
	var w := maxf(1.0, size.x - pad() * 2)
	return pad() + (clampf(t / duration, 0.0, 1.0) if duration > 0.0 else 0.0) * w


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and not _scrubbing:
			_scrubbing = true
			scrub_started.emit()
			seek_requested.emit(time_at(mb.position.x))
		elif not mb.pressed and _scrubbing:
			_scrubbing = false
			scrub_ended.emit()
		accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _scrubbing:
		seek_requested.emit(time_at(mm.position.x))
		accept_event()


func _draw() -> void:
	if _groove == null:
		return
	var mid := HEIGHT * 0.5 if not sun_segments.is_empty() else size.y * 0.5
	var band := Rect2(0.0, mid - HEIGHT * 0.5, size.x, HEIGHT)
	_groove.draw(get_canvas_item(), band)
	var cx := x_of(cursor)
	if cx > pad():
		# 亮段那张图两端是透明的（亮段在两端符石之间）：画到游标再加一个右端宽，亮段正好停在游标上
		_fill.draw(get_canvas_item(), Rect2(band.position, Vector2(cx + _fill.texture_margin_right, band.size.y)))
	for t in ticks:
		var x := x_of(float(t[0]))
		var tex: Texture2D = _tick_tex[int(t[2])]
		var k := DEATH_SCALE if bool(t[3]) else 1.0
		var sz := tex.get_size() * k
		var y := mid - ART_BAR_HALF - sz.y if bool(t[1]) else mid + ART_BAR_HALF
		var alpha := 1.0 if float(t[0]) <= cursor else UNPLAYED_ALPHA
		draw_texture_rect(tex, Rect2(Vector2(x - sz.x * 0.5, y), sz), false, Color(1, 1, 1, alpha))
	_draw_sun(mid + ART_BAR_HALF + 1.0)
	draw_texture(_cursor_tex, Vector2(cx, mid) - _cursor_pivot)


## 388：回放条下沿的日夜色带 —— 白昼金、黑夜靛、两边都算的斜条纹；段间空 2；每段起头下面一个小太阳 / 月亮。只画到游标
func _draw_sun(top: float) -> void:
	for seg in sun_segments:
		var t0 := float(seg[0])
		if t0 >= cursor:
			break
		var t1 := minf(float(seg[1]), cursor)
		var x0 := x_of(t0) + (SUN_GAP * 0.5 if t0 > 0.0 else 0.0)
		var x1 := x_of(t1) - (SUN_GAP * 0.5 if t1 >= float(seg[1]) and t1 < duration else 0.0)
		if x1 <= x0:
			continue
		var day := bool(seg[2])
		var night := bool(seg[3])
		var r := Rect2(x0, top, x1 - x0, SUN_H)
		if day and night:
			_stripes(r)
		else:
			var g: Array[Color] = SUN_DAY if day else SUN_NIGHT
			var box := StyleBoxFlat.new()
			box.bg_color = g[1]
			box.set_corner_radius_all(4)
			draw_style_box(box, r)
			var hi := StyleBoxFlat.new()
			hi.bg_color = g[0]
			hi.set_corner_radius_all(4)
			draw_style_box(hi, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)))
		var tex: Texture2D = _sun_icons.get("sun_night" if night and not day else "sun_day", null)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x0, top + SUN_H + 2.0), Vector2(SUN_ICON, SUN_ICON)), false,
				SUN_NIGHT[0] if night and not day else SUN_DAY[1])


## 两边都算的那几秒：金、靛斜条纹
func _stripes(r: Rect2) -> void:
	draw_rect(r, SUN_NIGHT[1])
	var step := 6.0
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var pts := PackedVector2Array()
		for p in [Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y), Vector2(x + r.size.y + step * 0.5, r.position.y), Vector2(x + step * 0.5, r.end.y)]:
			pts.append(Vector2(clampf(p.x, r.position.x, r.end.x), p.y))
		draw_colored_polygon(pts, SUN_DAY[1])
		x += step
