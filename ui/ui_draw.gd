## 画布上的小图形（154）：几处 `_draw` 共用的画法，抽到这里免得各写一份。
class_name UiDraw
extends RefCounted


## 环形进度条：底环一整圈，进度环从正上方（−90°）顺时针走 [param progress]（0～1）。
## [param back_width] < 0 时底环与进度环一样粗。战利品的「正在搜」（[LootView]）与宝箱屏的锁孔环（154）都用它
static func ring(canvas: CanvasItem, center: Vector2, radius: float, progress: float, back_color: Color, fore_color: Color,
		width: float = 3.0, back_width: float = -1.0, points: int = 32) -> void:
	canvas.draw_arc(center, radius, 0.0, TAU, points, back_color, back_width if back_width >= 0.0 else width)
	if progress > 0.0:
		canvas.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), points, fore_color, width)
