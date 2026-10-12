## 战前准备的中缝与天平（157）：两列之间一道竖缝（两条细线 + 中点一个菱形），顶端一根短横杆按双方强弱倾斜 —— 不写数字。
##
## 强弱 = 生命上限 × 粗算 DPS（和读数行同一份编译）。左边是对手、右边是自己：哪边强哪边沉
class_name BalanceSeam
extends Control

const WIDTH := 44.0
## 最多斜多少（弧度，±25°）
const MAX_TILT := deg_to_rad(25.0)
const BEAM := 36.0

## 现在的倾角（弧度；正 = 右边，也就是自己这边沉）
var tilt: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 120)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 按双方强弱定倾角：比值取对数再 atan，限在 ±25°；一边是 0 就斜满
static func tilt_of(theirs: float, mine: float) -> float:
	if theirs <= 0.0 and mine <= 0.0:
		return 0.0
	if mine <= 0.0:
		return -MAX_TILT
	if theirs <= 0.0:
		return MAX_TILT
	return clampf(atan(log(mine / theirs)), -MAX_TILT, MAX_TILT)


func set_strength(theirs: float, mine: float) -> void:
	tilt = tilt_of(theirs, mine)
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var top := 22.0
	var line := UiPalette.LINE.lightened(0.25)
	draw_line(Vector2(cx - 2, top + 8), Vector2(cx - 2, size.y), line, 1.0)
	draw_line(Vector2(cx + 2, top + 8), Vector2(cx + 2, size.y), line, 1.0)
	var mid := Vector2(cx, size.y * 0.5)
	var d := 6.0
	draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -d), mid + Vector2(d, 0), mid + Vector2(0, d), mid + Vector2(-d, 0)]), line)
	# 天平：支点在缝顶，一根横杆，两端各挂一个小盘
	var pivot := Vector2(cx, top)
	var arm := Vector2(cos(tilt), sin(tilt)) * (BEAM * 0.5)
	draw_line(pivot - arm, pivot + arm, UiPalette.FG, 2.0)
	draw_circle(pivot, 3.0, UiPalette.FG)
	for end in [pivot - arm, pivot + arm]:
		draw_line(end, end + Vector2(0, 7), UiPalette.DIM, 1.0)
		draw_line(end + Vector2(-5, 7), end + Vector2(5, 7), UiPalette.DIM, 2.0)
