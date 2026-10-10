## 150：一屏的读数层 —— 铺在地图那一块上、自己不接鼠标；按 [HudLayout] 造 [HudWidget]、摆好、跟着窗口与内容重排。
##
## 每件摆好都登记进地上层（128：地上的东西被它盖住就让开；藏着的不算）。
## 「摆读数」模式（[method set_editing]）：组件能拖（松手吸附网格、换算回最近的锚点 + 偏移）、右键切显隐、滚轮切大小档；
## [method save] 写回布局文件，[method reset] 删掉存的那份回默认。
##
## 150 补 1：锚在右边一列（`top_right` / `right` / `bottom_right`）的是「右边那一条」：先按整块摆，占多宽就是 [method right_inset]，
## 屏幕把地图往左让这么多（原来的右栏就是这样没了的）；其余的在让出之后剩下那块里对齐（顶上那排读数仍在地图正上方居中）。
## 补 2：布局里 `debug_only` 的那几件只在 [member debug] 开着时造
class_name HudHost
extends Control

## 布局改了（拖、切显隐、切档、重置）
signal layout_changed()
## 摆完一遍（地图屏跟着让出顶上的高度）
signal arranged()

## 同一行里两件之间、行与行之间的空隙
const GAP := 6
const LINE_GAP := 4

var layout: HudLayout = null
## id → [HudWidget]
var widgets: Dictionary = {}
var editing: bool = false
## 150 补 2：调试模式（屏幕从 [member GameSettings.debug_mode] 拿来设）。关着时 `debug_only` 的不造、不占地上
var debug: bool = true
## 右边那一条此刻占多宽（[method arrange] 算）
var _right: float = 0.0
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
	arrange()


func widget(id: StringName) -> HudWidget:
	return widgets.get(id, null)


## 全部刷一遍（地图屏每次动完调它；组件自己也订了各自的信号）
func refresh() -> void:
	for w in widgets.values():
		(w as HudWidget).refresh()
	_queue_arrange()


## 顶上那几组占到多高（地图屏把地图往下让这么多，默认布局下画面和 150 之前一样）。右边那一条不算（它让的是宽）
func top_inset() -> float:
	var bottom := 0.0
	for e in (layout.entries if layout != null else []):
		var w: HudWidget = widgets.get(StringName(e["id"]), null)
		if w != null and w.visible and String(e["anchor"]).begins_with("top") and not on_right(String(e["anchor"])):
			bottom = maxf(bottom, w.position.y + w.size.y)
	return bottom


## 150 补 1：右边那一条占多宽（地图屏把地图往左让这么多）
func right_inset() -> float:
	return _right


## 这个锚点属不属于右边那一条
static func on_right(anchor: String) -> bool:
	return anchor.ends_with("right")


## 这个锚点对齐用的那块的大小：右边那一条按整块，其余按让出右边之后剩下的
func _frame(anchor: String) -> Vector2:
	return size if on_right(anchor) else Vector2(maxf(0.0, size.x - _right), size.y)


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
	for e in layout.entries:
		var w: HudWidget = widgets.get(StringName(e["id"]), null)
		if w == null or not w.visible:
			continue
		var key := "%s@%s" % [e["anchor"], e["offset"]]
		if not groups.has(key):
			groups[key] = {"anchor": e["anchor"], "offset": e["offset"], "lines": {}}
			order.append(key)
		var lines: Dictionary = groups[key]["lines"]
		var ln := int(e.get("line", 0))
		if not lines.has(ln):
			lines[ln] = []
		(lines[ln] as Array).append(w)
	# 先摆右边那一条，量出它占多宽；其余的在剩下那块里摆
	_right = 0.0
	for key in order:
		if on_right(String(groups[key]["anchor"])):
			_place_group(groups[key])
			for ln in groups[key]["lines"]:
				for w in groups[key]["lines"][ln]:
					_right = maxf(_right, size.x - (w as HudWidget).position.x)
	for key in order:
		if not on_right(String(groups[key]["anchor"])):
			_place_group(groups[key])
	var ground := GroundLayer.current()
	if ground != null and ground.is_inside_tree():
		ground.settle.call_deferred()
	arranged.emit()


func _place_group(g: Dictionary) -> void:
	var pivot: Vector2 = HudLayout.ANCHORS.get(String(g["anchor"]), Vector2.ZERO)
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
	var frame := _frame(String(g["anchor"]))
	var origin: Vector2 = pivot * frame + (g["offset"] as Vector2) - pivot * group_size
	origin = origin.clamp(Vector2.ZERO, (frame - group_size).max(Vector2.ZERO))
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
	var best := "top_left"
	var best_d := INF
	for a in HudLayout.ANCHORS:
		var d := center.distance_to((HudLayout.ANCHORS[a] as Vector2) * size)
		if d < best_d:
			best_d = d
			best = a
	var pivot: Vector2 = HudLayout.ANCHORS[best]
	var offset := w.position + pivot * w.size - pivot * _frame(best)
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
	e["tier"] = "small" if String(e.get("tier", "small")) == "large" else "large"
	w.set_tier(HudLayout.TIERS[e["tier"]])
	arrange()
	layout_changed.emit()


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
