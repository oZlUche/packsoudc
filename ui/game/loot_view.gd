## 渐进揭示的战利品容器（架构文档 6.2，M6-2）：看得见轮廓、看不清是什么。
##
## 就是一个 [InventoryView]，多了一层「揭没揭示」：没揭示的物品画成灰色剪影 + 噪点，抓不起来；
## 一个 [Tween] 驱动一批揭示的进度，按栏位顺序（先上后下、先左后右）一件一件亮出来，
## 「快速搜索」把 Tween 推到终点。**揭示只是表现**：容器里的东西一开始就在那儿，揭不揭示都一样 ——
## 这也是为什么它不在 core 里。
##
## 单件间隔是占位（6.2：0.15～0.4 秒，将来受角色「搜索速度」属性影响）。
class_name LootView
extends InventoryView

signal item_revealed(uid: int)
signal reveal_finished

## 每件揭示的间隔（秒）。占位，等角色系统
const INTERVAL := 0.3
const COLOR_SILHOUETTE := Color("2a2e36")
const COLOR_SILHOUETTE_EDGE := Color("3c424d")
const COLOR_NOISE := Color("4a515e")
const NOISE_PER_CELL := 14

var reveal_interval: float = INTERVAL

var _revealed: Dictionary = {}      # uid -> true
var _queue: Array[int] = []         # 这一批按顺序待揭示的 uid
var _tween: Tween = null


func _init() -> void:
	show_adjacency = false     # 战利品不参战，邻接的「点亮」什么也不代表（4.8）


#region 揭示
func is_revealed(uid: int) -> bool:
	return _revealed.has(uid)


## 还没亮出来的有几件
func unrevealed_count() -> int:
	var n := 0
	if inventory == null:
		return 0
	for inst in inventory.items():
		if not _revealed.has((inst as ItemInstance).uid):
			n += 1
	return n


## 这些已经见过（比如在搜索屏里亮过），不再走时间线
func mark_revealed(uids: Array) -> void:
	for uid in uids:
		_revealed[int(uid)] = true
	queue_redraw()


## 把容器里还没亮的按栏位顺序排成一批，启动时间线。没有要亮的直接发 reveal_finished
func start_reveal() -> void:
	_stop()
	_queue = _unrevealed_in_slot_order()
	if _queue.is_empty():
		reveal_finished.emit()
		return
	_tween = create_tween()
	_tween.tween_method(_step, 0.0, 1.0, reveal_interval * _queue.size())
	_tween.finished.connect(_on_finished)


## 快速搜索：推到终点，这一批全亮
func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
	_step(1.0)
	if not _queue.is_empty():
		_on_finished()


## 全亮，不管在不在批次里
func reveal_all() -> void:
	_stop()
	if inventory != null:
		for inst in inventory.items():
			_revealed[(inst as ItemInstance).uid] = true
	_queue.clear()
	queue_redraw()


func is_revealing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _step(progress: float) -> void:
	var n := _queue.size()
	var k := clampi(int(floor(progress * n + 1e-6)), 0, n)
	for i in k:
		var uid := _queue[i]
		if not _revealed.has(uid):
			_revealed[uid] = true
			item_revealed.emit(uid)
	queue_redraw()


func _on_finished() -> void:
	_step(1.0)
	_queue.clear()
	_tween = null
	reveal_finished.emit()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## 栏位顺序：先上后下、先左后右
func _unrevealed_in_slot_order() -> Array[int]:
	var out: Array[int] = []
	if inventory == null:
		return out
	var list: Array = []
	for inst in inventory.items():
		var item := inst as ItemInstance
		if not _revealed.has(item.uid):
			list.append(item)
	list.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.origin.y < b.origin.y if a.origin.y != b.origin.y else a.origin.x < b.origin.x)
	for item in list:
		out.append((item as ItemInstance).uid)
	return out
#endregion


#region 画与抓
func _draw() -> void:
	super._draw()
	if inventory == null:
		return
	for inst in inventory.items():
		var item := inst as ItemInstance
		if _revealed.has(item.uid):
			continue
		_draw_silhouette(item)


## 剪影盖在物品上：只剩轮廓，看不出是什么。噪点按 uid 定死，不闪
func _draw_silhouette(item: ItemInstance) -> void:
	var cells := item.cells()
	var anchor := cell_origin_px(item.origin)
	ItemPainter.draw_item(self, cells, anchor, CELL, COLOR_SILHOUETTE, COLOR_SILHOUETTE_EDGE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item.uid)
	for c in cells:
		var p := anchor + Vector2(c) * CELL
		for i in NOISE_PER_CELL:
			var q := p + Vector2(rng.randf_range(3.0, CELL - 5.0), rng.randf_range(3.0, CELL - 5.0))
			draw_rect(Rect2(q, Vector2(2.0, 2.0)), COLOR_NOISE, true)
	var font := label_font if label_font != null else get_theme_default_font()
	ItemPainter.draw_label(self, cells, anchor, CELL, "?", font, 16, Color("6b7280"))


## 没揭示的抓不起来
func _gui_input(event: InputEvent) -> void:
	if inventory != null and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var c := cell_at_local(mb.position)
			var uid := inventory.cell_uid(c)
			if uid == GridInventory.EMPTY_UID:
				uid = inventory.bag_at(c)
			if uid != GridInventory.EMPTY_UID and not _revealed.has(uid):
				accept_event()
				return
	super._gui_input(event)
#endregion
