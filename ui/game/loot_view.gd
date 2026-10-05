## 渐进揭示的战利品容器（架构文档 6.2，M6-2；058 第 5 条重做，报告 068）：看得见轮廓、看不清是什么。
##
## 就是一个 [InventoryView]，多了一层「揭没揭示」：没揭示的物品画成灰色剪影 + 噪点。
## 揭示**一件一件来**：当前这件按它的稀有度耗时（[SearchRules.reveal_seconds]，和体积无关），到点亮出来，
## 再按栏位顺序（先上后下、先左后右）挑下一件 —— 只知道「当前搜谁」和「下一个搜谁」。
## 没揭示的东西**可以拖**（挪一挪就换了「下一个」是谁），但只能在容器内挪（容器屏用 [DragLayer.drop_filter] 圈住）；
## **当前正在搜的那件锁住**，抓不起来。「快速搜索」把没亮的全亮。
## **揭示只是表现**：容器里的东西一开始就在那儿，揭不揭示都一样 —— 这也是为什么它不在 core 里。
##
## 时间用 [method advance] 推进（`_process` 每帧调它），测试直接调，不必等真的几秒。
class_name LootView
extends InventoryView

signal item_revealed(uid: int)
signal reveal_finished

const COLOR_SILHOUETTE := Color("2a2e36")
const COLOR_SILHOUETTE_EDGE := Color("3c424d")
const COLOR_NOISE := Color("4a515e")
const COLOR_PROGRESS := Color("dfe3ea")
const COLOR_NEXT := Color("8b93a1")
const NOISE_PER_CELL := 14
## 没给规则时的耗时表（和 SearchRules 的默认一样）
const DEFAULT_SECONDS: Array[float] = [0.3, 0.5, 0.8, 1.2, 2.0, 3.0]

## 每档稀有度的秒数；容器屏从节点规则里给
var reveal_seconds: Array[float] = DEFAULT_SECONDS

var _revealed: Dictionary = {}      # uid -> true
## 在这个容器里出现过的 uid（084：判「没亮的锁在容器里」只看它们；玩家自己棋盘上的东西这里不认识，随便放）
var _known: Dictionary = {}
## 正在搜的那件（锁住）；EMPTY_UID = 没在搜
var _current: int = GridInventory.EMPTY_UID
var _progress: float = 0.0
var _running: bool = false


func _init() -> void:
	show_adjacency = false     # 战利品不参战，邻接的「点亮」什么也不代表（4.8）
	set_process(false)


func set_inventory(inv: GridInventory) -> void:
	super.set_inventory(inv)
	_remember_known(false)
	if inv != null:
		inv.changed.connect(func(): _remember_known(true))


## 记住容器里有哪些。[param later] = 绑定之后才出现的：那是玩家从棋盘 / 地上放进来的自己的东西，**当亮过**
## （084 修：放回容器的道具不能变成「未知」）；绑定那一刻就在的才是要揭示的
func _remember_known(later: bool) -> void:
	if inventory == null:
		return
	for inst in inventory.items():
		var uid := (inst as ItemInstance).uid
		if not _known.has(uid):
			_known[uid] = true
			# 087（作者定）：包不用探明 —— 直接当背景亮着；上面的东西照样一件一件搜
			if later or inventory.acts_as_bag((inst as ItemInstance).def):
				_revealed[uid] = true


#region 揭示
func is_revealed(uid: int) -> bool:
	return _revealed.has(uid)


## 这件是不是这个容器里出现过的（玩家自己的东西放进来之前是「不认识」的）
func knows(uid: int) -> bool:
	return _known.has(uid)


## 这件还锁在容器里（是这个容器的、还没亮出来）。不是这个容器的东西（玩家自己棋盘 / 地上的）从不锁 ——
## 容器屏的落点过滤按它判，不按 [method is_revealed]：后者对棋盘上的包也说「没亮」，把玩家自己的东西全卡住了（084）
func is_locked(uid: int) -> bool:
	if inventory != null and inventory.has_item(uid) and inventory.acts_as_bag(inventory.get_item(uid).def):
		# 087：包本身不锁，但上面还有没亮的东西时拖不走（不然没亮的跟着包走了）
		for cid in inventory.contents_of(uid):
			if _known.has(cid) and not _revealed.has(cid):
				return true
		return false
	return _known.has(uid) and not _revealed.has(uid)


## 还没亮出来的有几件
func unrevealed_count() -> int:
	return _unrevealed_in_slot_order().size()


## 这些已经见过（比如在搜索屏里亮过），不再走时间线
func mark_revealed(uids: Array) -> void:
	for uid in uids:
		_revealed[int(uid)] = true
	queue_redraw()


## 开始（或接着）一件一件搜：当前那件锁住计时，搜完挑下一件。没有要亮的直接发 reveal_finished
func start_reveal() -> void:
	if _running:
		return
	if not _pick_current():
		reveal_finished.emit()
		return
	_running = true
	set_process(true)
	queue_redraw()


## 快速搜索：没亮的全亮
func skip() -> void:
	var had := _running or unrevealed_count() > 0
	_stop()
	for uid in _unrevealed_in_slot_order():
		_revealed[uid] = true
		item_revealed.emit(uid)
	queue_redraw()
	if had:
		reveal_finished.emit()


## 全亮，不管在不在搜
func reveal_all() -> void:
	_stop()
	if inventory != null:
		for inst in inventory.items():
			_revealed[(inst as ItemInstance).uid] = true
	queue_redraw()


func is_revealing() -> bool:
	return _running


## 正在搜的那件（锁住的）；没在搜 = EMPTY_UID
func current_uid() -> int:
	return _current if _running else GridInventory.EMPTY_UID


## 下一个要搜的：当前之外、栏位顺序最靠前的没亮的。挪一挪东西它就变
func next_uid() -> int:
	for uid in _unrevealed_in_slot_order():
		if uid != _current:
			return uid
	return GridInventory.EMPTY_UID


## 当前这件搜了几成
func progress() -> float:
	return _progress if _running else 0.0


## 当前这件要几秒（按稀有度）
func current_seconds() -> float:
	var inst := inventory.get_item(_current) if inventory != null and _running else null
	return _seconds_for(inst) if inst != null else 0.0


## 时间推进。一次推进可以跨过好几件（比如卡了一帧）
func advance(delta: float) -> void:
	if not _running:
		return
	var left := maxf(0.0, delta)
	while _running and left > 0.0:
		var inst := inventory.get_item(_current) if inventory != null else null
		if inst == null:
			# 正在搜的那件不在了（不该发生：它锁着）—— 换下一件
			if not _pick_current():
				_finish()
			continue
		var need := _seconds_for(inst)
		var remain := maxf(0.0, (1.0 - _progress) * need)
		if left < remain and need > 0.0:
			_progress += left / need
			left = 0.0
			break
		left -= remain
		_revealed[_current] = true
		item_revealed.emit(_current)
		if not _pick_current():
			_finish()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## 挑当前要搜的：栏位顺序最靠前的没亮的。没有了返回 false
func _pick_current() -> bool:
	var queue := _unrevealed_in_slot_order()
	_progress = 0.0
	if queue.is_empty():
		_current = GridInventory.EMPTY_UID
		return false
	_current = queue[0]
	return true


func _finish() -> void:
	_stop()
	reveal_finished.emit()


func _stop() -> void:
	_running = false
	_current = GridInventory.EMPTY_UID
	_progress = 0.0
	set_process(false)


func _seconds_for(inst: ItemInstance) -> float:
	if inst == null or inst.def == null or reveal_seconds.is_empty():
		return 0.0
	return maxf(0.0, reveal_seconds[clampi(inst.def.rarity, 0, reveal_seconds.size() - 1)])


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
	var next := next_uid()
	for inst in inventory.items():
		var item := inst as ItemInstance
		if _revealed.has(item.uid):
			continue
		_draw_silhouette(item)
		if _running and item.uid == _current:
			_draw_progress(item)
		elif _running and item.uid == next:
			_draw_next(item)


## 087（作者定）：没亮的连名字都不画 —— 名字长的会先从剪影边上露出来，提前暴露身份
func _label_visible(item: ItemInstance) -> bool:
	return _revealed.has(item.uid)


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


## 当前那件：一圈进度环
func _draw_progress(item: ItemInstance) -> void:
	var center := cell_origin_px(item.origin) + Vector2(item.def.shape.size_rotated(item.rotation)) * CELL * 0.5
	var radius := CELL * 0.38
	draw_arc(center, radius, 0.0, TAU, 32, COLOR_NEXT.darkened(0.4), 2.0)
	if _progress > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(_progress, 0.0, 1.0), 32, COLOR_PROGRESS, 3.0)


## 下一件：左上角一个小标
func _draw_next(item: ItemInstance) -> void:
	var anchor := cell_origin_px(item.origin)
	var font := label_font if label_font != null else get_theme_default_font()
	draw_string(font, anchor + Vector2(4.0, 13.0), "下一件", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_NEXT)


## 正在搜的那件锁住，抓不起来；别的没亮的能抓（只能在容器里挪，那道门在拖拽层）
func _gui_input(event: InputEvent) -> void:
	if inventory != null and _running and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var c := cell_at_local(mb.position)
			var uid := inventory.cell_uid(c)
			if uid == GridInventory.EMPTY_UID:
				uid = inventory.bag_at(c)
			if uid != GridInventory.EMPTY_UID and uid == _current:
				accept_event()
				return
	super._gui_input(event)
#endregion
