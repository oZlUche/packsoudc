## 冷却进度（103 第 7 条）：回放层画旋转遮罩用的纯函数。
##
## [b]进度只是时刻的函数[/b] —— 不用 Tween / AnimationPlayer（它们走真实时间，调倍速或跳转就对不上）：
## 回放的 `_now` 跟着倍速走，进度从 `_now` 算，倍速与跳转都免费正确。
class_name CooldownClock
extends RefCounted


## 一轮冷却走了多少：0 = 刚出手（整个遮住），1 = 就绪（遮罩消失）。时刻都是秒
static func progress(fired_at: float, ready_at: float, now: float) -> float:
	if ready_at <= fired_at:
		return 1.0
	return clampf((now - fired_at) / (ready_at - fired_at), 0.0, 1.0)


## 遮罩的扇形多边形：以 [param center] 为圆心、[param radius] 为半径，从 12 点起**顺时针**扫过 (1 − progress) × 360°，
## 剩下的那块是遮住的部分 —— 走完一圈遮罩转没。返回空数组表示不画
static func sector(center: Vector2, radius: float, p: float, segments: int = 32) -> PackedVector2Array:
	var left := 1.0 - clampf(p, 0.0, 1.0)
	if left <= 0.0:
		return PackedVector2Array()
	var pts := PackedVector2Array([center])
	# 已走过的部分从 12 点顺时针露出来；遮住的是从「走到的位置」顺时针到 12 点
	var start := -PI / 2.0 + TAU * (1.0 - left)
	var n := maxi(2, ceili(segments * left))
	for i in n + 1:
		var a := start + TAU * left * float(i) / float(n)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
