## 战前准备屏两列中间的那条中缝（UI替换美术 bronze3 `prebattle_lane`，作者 2026-10-21 16:15；替掉 157 的天平）：
## 两道刻线（各一暗一亮）+ 每 [constant STUD_STEP] 一颗铜钉，从铭牌上沿到属性签下沿；
## 交叉双剑铜章 `bronze/medal_swords` 压在整块面板正中（[member center_on] 的中线），刻线在铜章上下断开。纯装饰，点不着
class_name PrebattleLane
extends Control

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
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var spec: Dictionary = BoardFrame.layout().get("prebattle_lane", {})
	if spec.get("lines", null) is Array:
		_lines = spec["lines"]


## 铜章在屏幕上的框（教程、测试看）
func medal_rect() -> Rect2:
	return Rect2(global_position + Vector2(size.x * 0.5, _medal_y()) - Vector2.ONE * MEDAL_SIDE * 0.5, Vector2.ONE * MEDAL_SIDE)


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
		draw_texture_rect(medal, Rect2(Vector2(cx, my) - Vector2.ONE * MEDAL_SIDE * 0.5, Vector2.ONE * MEDAL_SIDE), false)


func _segment(x: float, from: float, to: float, c: Color, w: float) -> void:
	if to > from:
		draw_line(Vector2(x, from), Vector2(x, to), c, w, true)


## 铜钉：暗圈 + 铜面 + 左上一点亮
func _stud(at: Vector2) -> void:
	draw_circle(at, STUD_R + 1.0, Color("3a2810", 0.8))
	draw_circle(at, STUD_R, Color("c89a4a"))
	draw_circle(at + Vector2(-1.2, -1.2), 1.6, Color("f0dcb4", 0.85))
