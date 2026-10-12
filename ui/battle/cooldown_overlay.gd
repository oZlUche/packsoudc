## 冷却旋转遮罩（103 第 7 条）：盖在回放里一方棋盘（[InventoryView]）上，每件有冷却的道具一块扇形遮罩，
## 从 12 点起顺时针转，转完一圈就绪。只认日志喂进来的「这一轮从几秒到几秒」，不认识模拟。
##
## 进度一律由 [member now] 算（[CooldownClock.progress]），[BattleView] 每帧把带倍速的回放时刻写进来 —— 倍速、跳转都对。
## 道具是不规则形状：扇形按道具包围盒算，再和每一格求交，只画在道具自己的格子上
class_name CooldownOverlay
extends Control

const MASK := Color(0.0, 0.0, 0.0, 0.55)
## 157：出手那一下格子亮一下（回放时刻的 0.15 秒 —— 倍速快了自然就短）
const FLASH := Color(1.0, 0.95, 0.7, 0.4)
const FLASH_SEC := 0.15

var view: InventoryView = null
## uid → [这一轮开始（秒）, 就绪（秒）, 周期]
var cycles: Dictionary = {}
## 157：uid → 亮到几秒（回放时刻）
var _flash: Dictionary = {}
## 157：亮过几次（测试看：跳转时一次都不该有）
var flashes: int = 0
var now: float = 0.0:
	set(v):
		now = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## 回放从头开始：清空，按开战时的首个就绪时刻起算（第一轮从 0 秒开始）
func reset(initial: Dictionary) -> void:
	cycles.clear()
	_flash.clear()
	for uid in initial:
		var ready := float(initial[uid])
		cycles[int(uid)] = [0.0, ready, ready]
	queue_redraw()


## 一件道具出手（或因耐力不够跳过）：新一轮从 [param at] 到 [param ready_at]。
## 一件道具多条冷却规则时只跟周期最长的那条（103）：周期更短的那条不覆盖正在走的长周期
func note_cycle(uid: int, at: float, ready_at: float) -> void:
	var period := ready_at - at
	var cur: Array = cycles.get(uid, [])
	if not cur.is_empty() and period + 0.0001 < float(cur[2]) and at + 0.0001 < float(cur[1]):
		return
	cycles[uid] = [at, ready_at, period]
	queue_redraw()


## 157：一件出手了（或它的规则触发了）：从 [param at] 起亮 [constant FLASH_SEC] 秒
func flash(uid: int, at: float) -> void:
	flashes += 1
	_flash[uid] = at + FLASH_SEC
	queue_redraw()


func flashing(uid: int) -> bool:
	return _flash.has(uid) and now < float(_flash[uid]) and now >= float(_flash[uid]) - FLASH_SEC


func progress_of(uid: int) -> float:
	var c: Array = cycles.get(uid, [])
	return CooldownClock.progress(float(c[0]), float(c[1]), now) if not c.is_empty() else 1.0


func _draw() -> void:
	if view == null or view.inventory == null:
		return
	var cell := InventoryView.CELL
	for uid in _flash:
		if not flashing(int(uid)):
			continue
		var lit := view.inventory.get_item(int(uid))
		if lit != null:
			for c in lit.cells():
				draw_rect(Rect2(Vector2(lit.origin + c) * cell, Vector2(cell, cell)), FLASH)
	for uid in cycles:
		var p := progress_of(uid)
		if p >= 1.0:
			continue
		var item := view.inventory.get_item(int(uid))
		if item == null:
			continue
		var top := Vector2(item.origin) * cell
		var box := Rect2(top, Vector2(item.size()) * cell)
		var fan := CooldownClock.sector(box.get_center(), box.size.length(), p)
		if fan.is_empty():
			continue
		for c in item.cells():
			var at := Vector2(item.origin + c) * cell
			var square := PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)])
			for piece in Geometry2D.intersect_polygons(fan, square):
				draw_colored_polygon(piece, MASK)
