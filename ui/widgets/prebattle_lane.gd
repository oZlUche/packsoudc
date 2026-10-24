## 战前准备屏两列中间的那条中缝（UI替换美术 bronze3 `prebattle_lane`，作者 2026-10-21 16:15；替掉 157 的天平）：
## 两道刻线（各一暗一亮）+ 每 [constant STUD_STEP] 一颗铜钉，从铭牌上沿到属性签下沿；
## 交叉双剑铜章 `bronze/medal_swords` 压在整块面板正中（[member center_on] 的中线），刻线在铜章上下断开。
##
## 作者 2026-10-22：这枚铜章看着能按，就该能按 —— 点它等于按「开战」（发 [signal pressed]，屏幕侧接）。
## 只有铜章那块方框接鼠标，中缝的其余部分照旧穿透（[method _has_point]）；铜章交给战斗屏之后
## （[member medal_hidden]）和「开战」灰着时都不接点击。
class_name PrebattleLane
extends Control

## 铜章被点了（在铜章里按下、还在铜章里松开才算，和按钮一样拖出去不认）
signal pressed

const MEDAL_ART := "bronze/medal_swords"
const WIDTH := 126.0
const STUD_STEP := 70.0
const STUD_R := 4.5
const MEDAL_SIDE := 132.0
## 刻线在铜章上下各让开这么多
const MEDAL_GAP := 6.0
## 没有排版文件时的刻线（dx 相对中线）
const LINES := [
	{"dx": -4, "color": "#3a2810", "alpha": 0.8, "w": 2.4},
	{"dx": -2, "color": "#e8c886", "alpha": 0.6, "w": 1.2},
	{"dx": 3, "color": "#3a2810", "alpha": 0.8, "w": 2.4},
	{"dx": 5, "color": "#e8c886", "alpha": 0.6, "w": 1.2},
]

## 铜章竖直居中对着谁（面板）；没给 = 自己的中线
var center_on: Control = null:
	set(c):
		center_on = c
		if c != null:
			c.resized.connect(queue_redraw)
var _lines: Array = LINES
## 231：开战过场把铜章交给战斗屏的 [DuelMedal]（同一个位置接着画）—— 这边不再画
var medal_hidden := false:
	set(v):
		medal_hidden = v
		if v:
			_release_press()
		queue_redraw()
## 能不能按：战前屏在 [method PrebattleScreen._refresh] 里跟着「开战」的禁用态一起同步
var _enabled := true
## 鼠标停在铜章上（画一圈亮边，告诉玩家这里能按）
var _hover := false
## 在铜章里按下了（松开才发 [signal pressed]）
var _down := false


func _init() -> void:
	# 2026-10-22：从 MOUSE_FILTER_IGNORE 改成 STOP —— 但只有铜章那块方框算数（[method _has_point]），
	# 中缝其余部分照旧穿透，不会抢两边棋盘的鼠标
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(WIDTH, 0)
	var spec: Dictionary = BoardFrame.layout().get("prebattle_lane", {})
	if spec.get("lines", null) is Array:
		_lines = spec["lines"]


## 铜章在屏幕上的框（教程、测试看）
func medal_rect() -> Rect2:
	return Rect2(global_position + Vector2(size.x * 0.5, _medal_y()) - Vector2.ONE * MEDAL_SIDE * 0.5, Vector2.ONE * MEDAL_SIDE)


## 铜章在本控件坐标系里的框（[method _draw] 用的同一个中心，命中判定也用它）
func _medal_local_rect() -> Rect2:
	return Rect2(Vector2(floorf(size.x * 0.5), _medal_y()) - Vector2.ONE * MEDAL_SIDE * 0.5, Vector2.ONE * MEDAL_SIDE)


## 现在能不能按：铜章还画着、并且「开战」没灰
func _clickable() -> bool:
	return _enabled and not medal_hidden


## 战前屏把「开战」的禁用态同步过来（能开 = true）
func set_enabled(v: bool) -> void:
	if _enabled == v:
		return
	_enabled = v
	if not v:
		_release_press()
	queue_redraw()


## 只有铜章那块算这个控件的地盘：中缝其余部分照旧穿透，不抢两边棋盘的鼠标。
## 返回 false 时 Godot 会把事件交给后面的人，光标也不按这里的形状走
func _has_point(point: Vector2) -> bool:
	if not _clickable():
		return false
	return _medal_local_rect().has_point(point)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _clickable():
		return
	if mb.pressed:
		_down = true
		queue_redraw()
		accept_event()
		return
	# 松开：按下和松开都在铜章里才算按（拖出去不认，和按钮一样）
	var was := _down
	_down = false
	queue_redraw()
	if was and _medal_local_rect().has_point(mb.position):
		accept_event()
		pressed.emit()


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if not _clickable():
		return
	_hover = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover = false
	_release_press()
	queue_redraw()


## 清掉「按着」这一态（松手、移出、禁用、铜章交出去时都走它）
func _release_press() -> void:
	if not _down:
		return
	_down = false
	queue_redraw()


func _medal_y() -> float:
	if center_on != null and center_on.is_inside_tree() and is_inside_tree():
		return center_on.global_position.y + center_on.size.y * 0.5 - global_position.y
	return size.y * 0.5


func _draw() -> void:
	var cx := floorf(size.x * 0.5)
	var my := _medal_y()
	var cut_top := my - MEDAL_SIDE * 0.5 - MEDAL_GAP
	var cut_bottom := my + MEDAL_SIDE * 0.5 + MEDAL_GAP
	for l in _lines:
		var x := cx + float(l.get("dx", 0))
		var c := Color(String(l.get("color", "#3a2810")), float(l.get("alpha", 1.0)))
		var w := float(l.get("w", 1.0))
		_segment(x, 0.0, minf(cut_top, size.y), c, w)
		_segment(x, maxf(cut_bottom, 0.0), size.y, c, w)
	var y := STUD_STEP * 0.5
	while y < size.y:
		if y < cut_top - STUD_R or y > cut_bottom + STUD_R:
			_stud(Vector2(cx + 0.5, y))
		y += STUD_STEP
	var medal := UiTheme.art_cached(MEDAL_ART)
	if medal != null and not medal_hidden:
		# 按下去时整枚往下挪 2 px，做出「压下」的手感
		var drop := 2.0 if _down else 0.0
		draw_texture_rect(medal, Rect2(Vector2(cx, my + drop) - Vector2.ONE * MEDAL_SIDE * 0.5, Vector2.ONE * MEDAL_SIDE), false)
		# 悬停一圈亮边；按着时更亮 —— 这枚铜章能按，得让人看得出来
		if _clickable() and (_hover or _down):
			var ring := Color("f0dcb4", 0.75 if _down else 0.45)
			draw_arc(Vector2(cx, my + drop), MEDAL_SIDE * 0.5 - 3.0, 0.0, TAU, 64, ring, 2.0, true)


func _segment(x: float, from: float, to: float, c: Color, w: float) -> void:
	if to > from:
		draw_line(Vector2(x, from), Vector2(x, to), c, w, true)


## 铜钉：暗圈 + 铜面 + 左上一点亮
func _stud(at: Vector2) -> void:
	draw_circle(at, STUD_R + 1.0, Color("3a2810", 0.8))
	draw_circle(at, STUD_R, Color("c89a4a"))
	draw_circle(at + Vector2(-1.2, -1.2), 1.6, Color("f0dcb4", 0.85))
