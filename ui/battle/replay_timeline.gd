## 回放时间轴（157）：一条横杆，长度 = 整场时长；每一下伤害、每一次倒下在杆上一个刻度
## （打对手的朝上、挨打的朝下，颜色随一方），游标是回放现在的时刻。
##
## 点一下 / 拖动 = 跳到那一刻（[signal seek_requested]，回放层调现成的 [method BattleView.seek]）；拖着时回放停着，
## 松手按原来的状态接着放（[signal scrub_started] / [signal scrub_ended]）。只画、只发信号，不认识模拟
class_name ReplayTimeline
extends Control

signal seek_requested(t: float)
signal scrub_started
signal scrub_ended

const HEIGHT := 34.0
const PAD := 6.0
const TICK := 9.0
const SIDE_COLORS := [Color("6fa8dc"), Color("e06666")]

## 整场多少秒
var duration: float = 0.0
## [[秒, 朝上?, 哪一方打出的（0 我 / 1 对手）, 倒下?], ...]
var ticks: Array = []
var cursor: float = 0.0:
	set(v):
		cursor = v
		queue_redraw()
var _scrubbing := false


func _init() -> void:
	custom_minimum_size = Vector2(240, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## 换一场：时长与刻度从日志来
func load_result(result: BattleResult) -> void:
	duration = result.duration_sec() if result != null else 0.0
	ticks = ticks_of(result)
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
	var w := maxf(1.0, size.x - PAD * 2)
	return clampf((x - PAD) / w, 0.0, 1.0) * duration


func x_of(t: float) -> float:
	var w := maxf(1.0, size.x - PAD * 2)
	return PAD + (clampf(t / duration, 0.0, 1.0) if duration > 0.0 else 0.0) * w


func scrubbing() -> bool:
	return _scrubbing


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
	var mid := size.y * 0.5
	draw_line(Vector2(PAD, mid), Vector2(size.x - PAD, mid), UiPalette.LINE.lightened(0.3), 2.0)
	for t in ticks:
		var x := x_of(float(t[0]))
		var up: bool = t[1]
		var c: Color = SIDE_COLORS[int(t[2])]
		var len := TICK * (1.5 if bool(t[3]) else 1.0)
		draw_line(Vector2(x, mid), Vector2(x, mid - len if up else mid + len), Color(c, 0.85), 2.0 if bool(t[3]) else 1.0)
	var cx := x_of(cursor)
	draw_line(Vector2(cx, 2), Vector2(cx, size.y - 2), UiPalette.FG, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, 0), Vector2(cx + 5, 0), Vector2(cx, 6)]), UiPalette.FG)
