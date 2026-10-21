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
## 190：顶端栏有长槽时栏里同一行两件之间的空隙（中间放一枚铜点）
const BAR_GAP := 24
## 166：顶端栏至少多高、左右留多宽、里面的组上下至少留多少。
## 作者 2026-10-13（「凹槽没有和石板位置对齐，考虑增加顶端栏纵向面积」）：64 → 88，组在板边上下内边距之间居中（底下的投影不算）
const BAR_HEIGHT := 88.0
const GROUP := &"hud_host"
const BAR_SIDE := 16.0
## 作者 2026-10-17（体力条和金币栏更靠近中央，右边同理）：左右两组各往里收屏宽的这么多成（至少 [constant BAR_SIDE]）
const BAR_SIDE_FRAC := 0.1
const BAR_PAD := 4.0
## 没有栏时三个槽退回哪个锚点
const BAR_FALLBACK := {"bar_left": "top_left", "bar_center": "top", "bar_right": "top_right"}
const HudBarScript := preload("res://ui/hud/widgets/hud_bar.gd")

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
	add_to_group(GROUP)     # 叠层居中时让开顶端栏（[method GameScreen._centered_panel]）
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
		if StringName(e["id"]) in HudWidgets.DEV_ONLY and not DevGate.on():
			continue     # 186：调试台箭头只在开发包里有
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


## 186：给玩家的一句（[param urgent] = 要紧：朱红、停得久）。226 批一：提示行组件删了，转给告示层（[NoticeLayer]）
func notice(text: String, urgent: bool = false) -> void:
	NoticeLayer.post(self, text, urgent)


## 全部刷一遍（地图屏每次动完调它；组件自己也订了各自的信号）。231 补充二：按住时只记下要刷（[method hold]）
func refresh() -> void:
	for w in widgets.values():
		(w as HudWidget).poke()
	_queue_arrange()


#region 231 补充二：顶栏别剧透
## 按住着：读数的信号照响，组件只记「要刷」不刷（一按「开战」结算就同步算完了，回放没放之前顶栏不能先变）
var held := false


## 按住（战前屏按「开战」/ 蛮神秒杀之前）
func hold() -> void:
	held = true


## 放开（回放看完 / 跳到底、离开战斗屏）：记着要刷的那几件刷一遍；[param roll] = 金币 / 信力这类数从旧值滚到新值（[method HudWidget.release_hold]）。
## 没按住时什么也不做（两次放开不重复刷）
func release(roll: bool = true) -> void:
	if not held:
		return
	held = false
	for w in widgets.values():
		(w as HudWidget).release_hold(roll)
	_queue_arrange()


## 场上的读数层（正常只有地图屏那一个；都按住 / 都放开，不挑）
static func hosts_in(tree: SceneTree) -> Array[HudHost]:
	var out: Array[HudHost] = []
	if tree != null:
		for n in tree.get_nodes_in_group(GROUP):
			if n is HudHost and not (n as Node).is_queued_for_deletion():
				out.append(n)
	return out


static func hold_in(tree: SceneTree) -> void:
	for host in hosts_in(tree):
		host.hold()


static func release_in(tree: SceneTree, roll: bool = true) -> void:
	for host in hosts_in(tree):
		host.release(roll)
#endregion


## 顶上那几组（含顶端栏）占到多高。右边那一条不算（它让的是宽）
func top_inset() -> float:
	var bottom := _bar_h
	for e in (layout.entries if layout != null else []):
		var w: HudWidget = widgets.get(StringName(e["id"]), null)
		var a := String(e["anchor"])
		if w != null and w.visible and w.takes_space() and (a.begins_with("top") or HudLayout.in_bar(a)) and not on_right(a):
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


## 场上那个读数层的顶端栏多高（没有读数层 / 藏着 = 0）：叠层面板在栏下面居中
static func bar_height_in(tree: SceneTree) -> float:
	var host := tree.get_first_node_in_group(GROUP) as HudHost if tree != null else null
	return host.bar_height() if host != null and host.is_visible_in_tree() else 0.0


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


## 166：顶端栏里排组的那块（左右各留 [constant BAR_SIDE]；上下去掉栏底的内边距 —— 有石板就是板面那一段，不含底下的投影）
func _bar_frame() -> Rect2:
	var m := _bar_margins()
	var side := bar_side()
	return Rect2(side, m.x, maxf(0.0, size.x - side * 2.0), maxf(0.0, _bar_h - m.x - m.y))


## 顶端栏左右各留多宽（栏本身还是铺满）
func bar_side() -> float:
	return maxf(BAR_SIDE, size.x * BAR_SIDE_FRAC)


## 栏底的上、下内边距（没栏 0）。190：有长槽图时是槽身上下（`groove.json` 的 `band`，按栏高等比），组在槽身里竖向居中
func _bar_margins() -> Vector2:
	var bar := _bar()
	if bar == null:
		return Vector2.ZERO
	if _grooved():
		var h := _bar_h if _bar_h > 0.0 else BAR_HEIGHT
		var b := HudBarScript.band(h)
		return Vector2(b.x, h - b.y)
	var box := bar.get_theme_stylebox("panel")
	return Vector2.ZERO if box == null else Vector2(box.content_margin_top, box.content_margin_bottom)


## 190：顶端栏在、而且有长槽图
func _grooved() -> bool:
	return _bar() != null and HudBarScript.has_groove()


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
	var grooved := _grooved()
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
		w.set_in_bar(HudLayout.in_bar(anchor), grooved)     # 190：栏里有槽 = 坐在槽底上
		var key := "%s@%s" % [anchor, offset]
		if not groups.has(key):
			groups[key] = {"anchor": anchor, "offset": offset, "lines": {}, "gap": BAR_GAP if grooved and HudLayout.in_bar(anchor) else GAP}
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
		var m := _bar_margins()
		for key in order:
			if HudLayout.in_bar(String(groups[key]["anchor"])):
				_bar_h = maxf(_bar_h, _measure(groups[key]).y + maxf(BAR_PAD, m.x) + maxf(BAR_PAD, m.y))
		bar.position = Vector2.ZERO
		bar.size = Vector2(size.x, _bar_h)
		var dots: Array[Vector2] = []
		for key in order:
			var a := String(groups[key]["anchor"])
			if HudLayout.in_bar(a):
				_place_group(groups[key], _bar_frame(), HudLayout.BAR_ANCHORS[a])
				if grooved:
					dots.append_array(_dots_of(groups[key]))
		bar.call("set_dots", dots)
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
			var frame := _frame(a)
			if _floats(groups[key]):
				frame.size.x = maxf(0.0, size.x - extra_right)     # 186：浮在地图上的（提示行）按整块宽对齐，跟顶端栏同一条中线
			_place_group(groups[key], frame, HudLayout.ANCHORS.get(a, Vector2.ZERO))
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
		row_size.x += float(g.get("gap", GAP)) * maxi(0, ws.size() - 1)
		rows.append({"ws": ws, "size": row_size})
		group_size.x = maxf(group_size.x, row_size.x)
		group_size.y += row_size.y
	group_size.y += LINE_GAP * maxi(0, rows.size() - 1)
	return [rows, group_size]


## 186：整组都不占地图的边（[method HudWidget.takes_space] 为 false）—— 浮在上面，不用让右边那一条
func _floats(g: Dictionary) -> bool:
	for ln in g["lines"]:
		for w in g["lines"][ln]:
			if (w as HudWidget).takes_space():
				return false
	return true


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
			hw.position = Vector2(x, y + pivot.y * (row_size.y - s.y)) + (hw.bar_nudge() if hw.in_bar else Vector2.ZERO)
			hw.size = s
			x += s.x + float(g.get("gap", GAP))
		y += row_size.y + LINE_GAP


## 190：栏里一组的铜点：同一行相邻两件之间的正中各一枚；屏幕控件（右槽的图标按钮）之间不放，整组左边放一枚。
## 竖向在那一行的中线（第一行就是槽身中线）
func _dots_of(g: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var half := float(g.get("gap", GAP)) * 0.5
	var first := true
	for row in _rows(g)[0]:
		var ws: Array = (row["ws"] as Array).filter(func(w): return (w as HudWidget).occupied())
		if ws.is_empty():
			continue
		var w0 := ws[0] as HudWidget
		var cy := w0.position.y - w0.bar_nudge().y + w0.size.y * 0.5
		var parts := true
		for w in ws:
			parts = parts and w is HudPartWidget
		if parts:
			if first:
				out.append(Vector2(w0.position.x - half, cy))
		else:
			for i in range(1, ws.size()):
				var a := ws[i - 1] as HudWidget
				out.append(Vector2(a.position.x + a.size.x + half, cy))
		first = false
	return out
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
