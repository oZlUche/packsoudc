## 281 寂灭的路（三）：结算屏第二页的黑洞（代码占位，等美术）——盖在带回来的寂灭上：黑圈张开、转一圈、收回去，露出寂灭，然后自己摘掉。
## 关了动效就不放
class_name JimieBlackHole
extends Control

const OPEN_SEC := 0.6
const HOLD_SEC := 0.8
const CLOSE_SEC := 0.6
const CORE := Color(0.02, 0.01, 0.04)
const RIM := Color(0.42, 0.22, 0.62, 0.85)

## 0 → 1 张开，1 → 0 收回去
var grow: float = 0.0:
	set(v):
		grow = v
		queue_redraw()
var spin: float = 0.0:
	set(v):
		spin = v
		queue_redraw()


## 盖在 [param view] 里 uid 那件道具上（找不到就不放）。返回放了的那个
static func cover(view: InventoryView, uid: int) -> JimieBlackHole:
	if view == null:
		return null
	var rect := view.item_rect(uid)
	if rect.size == Vector2.ZERO:
		return null
	var side := maxf(rect.size.x, rect.size.y) * 1.4
	var hole := JimieBlackHole.new()
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.position = rect.get_center() - Vector2(side, side) * 0.5
	hole.size = Vector2(side, side)
	view.add_child(hole)
	hole.play()
	return hole


func play() -> void:
	var tw := create_tween()
	tw.tween_property(self, "grow", 1.0, OPEN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "spin", TAU, OPEN_SEC + HOLD_SEC + CLOSE_SEC)
	tw.tween_interval(HOLD_SEC)
	tw.tween_property(self, "grow", 0.0, CLOSE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)


func _draw() -> void:
	var r := size.x * 0.5 * grow
	if r <= 0.5:
		return
	var c := size * 0.5
	draw_circle(c, r, CORE)
	draw_arc(c, r, spin, spin + TAU * 0.75, 48, RIM, maxf(2.0, r * 0.12), true)
