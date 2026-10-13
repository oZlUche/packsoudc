## 150：一屏的读数层 —— 铺在地图那一块上、自己不接鼠标；按 [HudLayout] 造 [HudWidget]、摆好、跟着窗口与内容重排。
##
## 每件摆好都登记进地上层（128：地上的东西被它盖住就让开；藏着的不算）。
## 「摆读数」模式（[method set_editing]）：组件能拖（松手吸附网格、换算回最近的锚点 + 偏移）、右键切显隐、滚轮切大小档；
## [method save] 写回布局文件，[method reset] 删掉存的那份回默认。
##
## 150 补 1：锚在右边一列（`top_right` / `right` / `bottom_right`）的是「右边那一条」：先按整块摆，占多宽就是 [method right_inset]，
## 屏幕把地图往左让这么多（原来的右栏就是这样没了的）；其余的在让出之后剩下那块里对齐（顶上那排读数仍在地图正上方居中）。
## 补 2：布局里 `debug_only` 的那几件只在 [member debug] 开着时造。
## 166：`hud_bar`（顶端栏）开着时横贯顶部，锚在 `bar_left / bar_center / bar_right` 的组排进栏里（栏高随里面最高的一组，至少 [constant BAR_HEIGHT]）；
## 其余锚点在栏下面剩下的那块里对齐。没有栏（藏了 / 删了）时三个槽退回 `top_left / top / top_right`。
## 地图铺满整屏，读数浮在上面：[method content_inset] 告诉地图哪几条边被顶栏、左下 / 右下的部件占着
class_name HudHost
extends Control

## 布局改了（拖、切显隐、切档、重置）
signal layout_changed()
## 摆完一遍（地图屏跟着让出顶上的高度）
signal arranged()

## 同一行里两件之间、行与行之间的空隙
const GAP := 6
const LINE_GAP := 4
## 166：顶端栏至少多高、左右留多宽、里面的组上下至少留多少
const BAR_HEIGHT := 64.0
const BAR_SIDE := 16.0
const BAR_PAD := 4.0
## 没有栏时三个槽退回哪个锚点
const BAR_FALLBACK := {"bar_left": "top_left", "bar_center": "top", "bar_right": "top_right"}

var layout: HudLayout = null
## id → [HudWidget]
var widgets: Dictionary = {}
var editing: bool = false
## 150 补 2：调试模式（屏幕从 [member GameSettings.debug_mode] 拿来设）。关着时 `debug_only` 的不造、不占地上
var debug: bool = true
## 作者 2026-10-12：右边另外让出多宽（调试台抽屉开着时盖在右边：右边那一条整体往左挪这么多，地图跟着让）
var extra_right: float = 0.0
## 右边那一条此刻占多宽（[method arrange] 算，含 [member extra_right]）
var _right: float = 0.0
## 166：顶端栏此刻多高（没有栏 0）
var _bar_h: float = 0.0
var _run: RunState = null
var _screen: Control = null
var _pending: bool = false


func _init() -> void:
	name = "HudHost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_queue_arrange)


## 按布局造组件、接上一局。布局里没写的种类按默认布局补上（藏着），「摆读数」时能拖出来
func setup(run: RunState, screen: Control, p_layout: HudLayout) -> void:
	_run = run
	_screen = screen
	layout = p_layout
	for w in widgets.values():
		(w as HudWidget).release()
		(w as Node).queue_free()
		remove_child(w)
	widgets.clear()
	var fallback := HudLayout.default_for(layout.screen)
	for id in HudWidgets.KINDS:
		if layout.entry_of(id).is_empty():
			var e := fallback.entry_of(id)
			if e.is_empty():
				e = HudLayout.entry(id, "top_left", Vector2.ZERO)
			e = e.duplicate()
			e["visible"] = false
			layout.entries.append(e)
	for e in layout.entries:
		if bool(e.get("debug_only", false)) and not debug:
			continue
		var w := HudWidgets.create(StringName(e["id"]))
		if w == null:
			continue
		w.host = self
		w.shown = bool(e.get("visible", true))
		w.set_tier(HudLayout.TIERS.get(String(e.get("tier", "small")), HudWidget.Tier.SMALL))
		add_child(w)
		widgets[w.id] = w
		w.setup(run, screen)
		w.set_editing(editing)
		w.resized.connect(_queue_arrange)
		w.visibility_changed.connect(_queue_arrange)
		var ground := GroundLayer.current()
		if ground != null:
			ground.reserve(w)
	if widgets.has(&"hud_bar"):
		move_child(widgets[&"hud_bar"], 0)     # 166：栏垫在别的组件下面（同一层里先画）
	arrange()


func widget(id: StringName) -> HudWidget:
	return widgets.get(id, null)


## 全部刷一遍（地图屏每次动完调它；组件自己也订了各自的信号）
func refresh() -> void:
	for w in widgets.values():
		(w as HudWidget).refresh()
	_queue_arrange()


## 顶上那几组（含顶端栏）占到多高。右边那一条不算（它让的是宽）
func top_inset() -> float:
	var bottom := _bar_h
	for e in (layout.entries if layout != null else []):
		var w: HudWidget = widgets.get(StringName(e["id"]), null)
		var a := String(e["anchor"])
		if w != null and w.visible and (a.begins_with("top") or HudLayout.in_bar(a)) and not on_right(a):
			bottom = maxf(bottom, w.position.y + w.size.y)
	return bottom


## 166：底下那几组（左下图例与路线、右下腰带……）从下往上占到多高
func bottom_inset() -> float:
	var top := 0.0
	for e in (layout.entries if layout != null else []):
		var w: HudWidget = widgets.get(StringName(e["id"]), null)
		if w != null and w.visible and String(e["anchor"]).begins_with("bottom"):
			top = maxf(top, size.y - w.position.y)
	return top


## 166：地图该躲开的边（[member MapView.content_inset]：position = 左、上，size = 右、下）
func content_inset() -> Rect2:
	return Rect2(0.0, top_inset(), 0.0, bottom_inset())


## 166：顶端栏多高（没有栏 0）
func bar_height() -> float:
	return _bar_h


## 166：一件读数在屏幕上的包围盒（教程挖洞用：部件挪了位置教程跟着走）；没有 / 藏着返回空矩形
func rect_of(id: StringName) -> Rect2:
	var w: HudWidget = widgets.get(id, null)
	if w == null or not w.is_visible_in_tree():
		return Rect2()
	return w.get_global_rect()


## 150 补 1：右边那一条占多宽（地图屏把地图往左让这么多）；调试台开着时连它让出的一起算
func right_inset() -> float:
	return _right


## 这个锚点属不属于右边那一条
static func on_right(anchor: String) -> bool:
	return anchor.ends_with("right")


## 这个锚点对齐用的那块：在顶端栏下面；右边那一条按整块宽，其余按让出右边之后剩下的
func _frame(anchor: String) -> Rect2:
	var w := maxf(0.0, size.x - extra_right) if on_right(anchor) else maxf(0.0, size.x - _right)
	return Rect2(0.0, _bar_h, w, maxf(0.0, size.y - _bar_h))


## 166：顶端栏里排组的那块（左右各留 [constant BAR_SIDE]）
func _bar_frame() -> Rect2:
	return Rect2(BAR_SIDE, 0.0, maxf(0.0, size.x - BAR_SIDE * 2.0), _bar_h)


## 有没有顶端栏（布局里那件看得见）
func _bar() -> HudWidget:
	var b: HudWidget = widgets.get(&"hud_bar", null)
	return b if b != null and b.visible else null


#region 摆放
func _queue_arrange() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	arrange.call_deferred()


## 按布局把看得见的组件摆好：锚点与偏移相同的是一组，组里按 line 分行，整组按锚点对齐
func arrange() -> void:
	_pending = false
	if layout == null:
		return
	var groups := {}
	var order: Array[String] = []
	var bar := _bar()
	for e in layout.entries:
		var w: HudWidget = widgets.get(StringName(e["id"]), null)
		if w == null or not w.visible or w == bar:
			continue
		var anchor := String(e["anchor"])
		var offset: Vector2 = e["offset"]
		if HudLayout.in_bar(anchor):
			if bar != null:
				offset = Vector2.ZERO     # 栏里的槽不用偏移：一个槽一组
			else:
				anchor = BAR_FALLBACK[anchor]
		var key := "%s@%s" % [anchor, offset]
		if not groups.has(key):
			groups[key] = {"anchor": anchor, "offset": offset, "lines": {}}
			order.append(key)
		var lines: Dictionary = groups[key]["lines"]
		var ln := int(e.get("line", 0))
		if not lines.has(ln):
			lines[ln] = []
		(lines[ln] as Array).append(w)
	# 166：先定顶端栏多高（里面最高的一组 + 上下留白），铺满顶部；栏里的槽在栏里摆
	_bar_h = 0.0
	if bar != null:
		_bar_h = BAR_HEIGHT
		for key in order:
			if HudLayout.in_bar(String(groups[key]["anchor"])):
				_bar_h = maxf(_bar_h, _measure(groups[key]).y + BAR_PAD * 2.0)
		bar.position = Vector2.ZERO
		bar.size = Vector2(size.x, _bar_h)
		for key in order:
			var a := String(groups[key]["anchor"])
			if HudLayout.in_bar(a):
				_place_group(groups[key], _bar_frame(), HudLayout.BAR_ANCHORS[a])
	# 再摆右边那一条，量出它占多宽；其余的在剩下那块里摆
	_right = extra_right
	for key in order:
		var a := String(groups[key]["anchor"])
		if on_right(a) and not HudLayout.in_bar(a):
			_place_group(groups[key], _frame(a), HudLayout.ANCHORS[a])
			for ln in groups[key]["lines"]:
				for w in groups[key]["lines"][ln]:
					_right = maxf(_right, size.x - (w as HudWidget).position.x)
	for key in order:
		var a := String(groups[key]["anchor"])
		if not on_right(a) and not HudLayout.in_bar(a):
			_place_group(groups[key], _frame(a), HudLayout.ANCHORS.get(a, Vector2.ZERO))
	var ground := GroundLayer.current()
	if ground != null and ground.is_inside_tree():
		ground.settle.call_deferred()
	arranged.emit()


## 一组的行（按 line 排好）与整组多大
func _rows(g: Dictionary) -> Array:
	var line_keys: Array = (g["lines"] as Dictionary).keys()
	line_keys.sort()
	var rows: Array = []
	var group_size := Vector2.ZERO
	for ln in line_keys:
		var ws: Array = g["lines"][ln]
		var row_size := Vector2.ZERO
		for w in ws:
			var s := (w as HudWidget).get_combined_minimum_size()
			row_size.x += s.x
			row_size.y = maxf(row_size.y, s.y)
		row_size.x += GAP * maxi(0, ws.size() - 1)
		rows.append({"ws": ws, "size": row_size})
		group_size.x = maxf(group_size.x, row_size.x)
		group_size.y += row_size.y
	group_size.y += LINE_GAP * maxi(0, rows.size() - 1)
	return [rows, group_size]


func _measure(g: Dictionary) -> Vector2:
	return _rows(g)[1]


## 把一组按 [param pivot] 对齐摆进 [param frame]（锚点的那块，或者顶端栏的一个槽）
func _place_group(g: Dictionary, frame: Rect2, pivot: Vector2) -> void:
	var got := _rows(g)
	var rows: Array = got[0]
	var group_size: Vector2 = got[1]
	var origin: Vector2 = frame.position + pivot * frame.size + (g["offset"] as Vector2) - pivot * group_size
	origin = origin.clamp(frame.position, (frame.end - group_size).max(frame.position))
	var y := origin.y
	for row in rows:
		var row_size: Vector2 = row["size"]
		var x := origin.x + pivot.x * (group_size.x - row_size.x)
		for w in row["ws"]:
			var hw := w as HudWidget
			var s := hw.get_combined_minimum_size()
			hw.position = Vector2(x, y + pivot.y * (row_size.y - s.y))
			hw.size = s
			x += s.x + GAP
		y += row_size.y + LINE_GAP
#endregion


#region 摆读数
func set_editing(on: bool) -> void:
	editing = on
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for w in widgets.values():
		(w as HudWidget).set_editing(on)
	arrange()


## 一件拖完松手：中心离哪个锚点最近就归哪个锚点，偏移吸附网格；自成一组（第 0 行）
func drop(w: HudWidget) -> void:
	var e := layout.entry_of(w.id)
	if e.is_empty():
		return
	var center := w.position + w.size / 2.0
	# 166：松在顶端栏里 = 按横向三等分进左 / 中 / 右槽（排在那一槽第 0 行末尾）
	if _bar() != null and w.id != &"hud_bar" and center.y < _bar_h:
		var slot := clampi(int(center.x / maxf(1.0, size.x) * 3.0), 0, 2)
		e["anchor"] = ["bar_left", "bar_center", "bar_right"][slot]
		e["offset"] = Vector2.ZERO
		e["line"] = 0
		layout.entries.erase(e)
		layout.entries.append(e)
		arrange()
		layout_changed.emit()
		return
	var best := "top_left"
	var best_d := INF
	for a in HudLayout.ANCHORS:
		var d := center.distance_to((HudLayout.ANCHORS[a] as Vector2) * size)
		if d < best_d:
			best_d = d
			best = a
	var pivot: Vector2 = HudLayout.ANCHORS[best]
	var fr := _frame(best)
	var offset := w.position - fr.position + pivot * w.size - pivot * fr.size
	e["anchor"] = best
	e["offset"] = Vector2(snappedf(offset.x, HudLayout.GRID), snappedf(offset.y, HudLayout.GRID))
	e["line"] = 0
	arrange()
	layout_changed.emit()


func toggle_shown(w: HudWidget) -> void:
	var e := layout.entry_of(w.id)
	if e.is_empty():
		return
	e["visible"] = not bool(e.get("visible", true))
	w.shown = e["visible"]
	w.set_editing(editing)
	arrange()
	layout_changed.emit()


func toggle_tier(w: HudWidget) -> void:
	var e := layout.entry_of(w.id)
	if e.is_empty():
		return
	e["tier"] = {"small": "double", "double": "large", "large": "small"}.get(String(e.get("tier", "small")), "small")
	w.set_tier(HudLayout.TIERS[e["tier"]])
	arrange()
	layout_changed.emit()


## 作者 2026-10-12：右边另外让出 [param w]（调试台开着时传它的宽，关上传 0）
func set_extra_right(w: float) -> void:
	if is_equal_approx(w, extra_right):
		return
	extra_right = w
	arrange()


## 「保存布局」：写到 [method HudLayout.save_path]（或 [param path]）
func save(path: String = "") -> bool:
	return layout != null and layout.save(path)


## 「重置」：删掉存的那份，回默认布局
func reset() -> void:
	if layout == null:
		return
	HudLayout.reset(layout.screen)
	setup(_run, _screen, HudLayout.default_for(layout.screen))
	layout_changed.emit()
#endregion
