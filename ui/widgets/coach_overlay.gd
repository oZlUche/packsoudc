## 166（作者定）：静态教程 —— 整屏压一层阴影，目标周围挖一个洞（包围盒外扩 [constant HOLE_PAD]，洞边一圈高光），
## 一只手绘箭头（`assets/ui/coach/arrow.png`，图朝右，按方向转；缺图画一笔折线箭头）从洞外指向洞，箭尾一块悬浮窗底（[constant UiTheme.PANEL_TOOLTIP]）写说明。
## **点任意处下一步**（键盘任意键也算，Esc 也是），最后一步点了收掉、发 [signal finished]。阴影层吞掉所有点击。
##
## 步骤是数据（`data/authoring/coach/<id>.json`：`{"id", "steps": [{"target": 目标 id, "text", "texts": {"en"}}]}`）；
## 目标的位置每一步现问（[member target_rect]：地图屏给 [method HudHost.rect_of]，战斗屏给 [method BattleView.control_rect]，背包窗、战前屏各有 `control_rect`）—— 部件挪了位置，教程跟着走
class_name CoachOverlay
extends Control

signal finished()

const DIR := "res://data/authoring/coach/"
const SHADE := Color(0, 0, 0, 0.62)
const HOLE_PAD := 8.0
const RIM := 2.0
const ARROW_ART := "res://assets/ui/coach/arrow.png"
const ARROW_SIZE := Vector2(160, 80)
const PAPER_WIDTH := 380.0

## `func(target_id: StringName) -> Rect2`（全局坐标；空矩形 = 找不到，不挖洞、说明放正中）
var target_rect: Callable = Callable()
var font: Font = null

var steps: Array = []
var index: int = -1
var _paper: PanelContainer
var _line: Label
var _arrow: Texture2D = null


## 218 补充一：[param id] 这份教程该不该自己放（写了、这个存档还没看过）
static func due(flow: GameFlow, id: StringName) -> bool:
	return id != &"" and (flow == null or flow.meta == null or not flow.meta.coach_seen.has(String(id)))


## 218 补充一：在 [param host] 上铺满放 [param id] 这份教程，走完记进 [member MetaState.coach_seen]、存局外。没有步骤返回 null
static func run_on(host: Control, id: StringName, flow: GameFlow, p_font: Font, p_target_rect: Callable) -> CoachOverlay:
	var p_steps := load_steps(id)
	if p_steps.is_empty() or host == null:
		return null
	var o := CoachOverlay.new()
	o.font = p_font
	o.target_rect = p_target_rect
	host.add_child(o)
	o.finished.connect(func():
		if flow != null and flow.meta != null and not flow.meta.coach_seen.has(String(id)):
			flow.meta.coach_seen.append(String(id))
			flow.save_meta())
	o.start(p_steps)
	return o


## 读一份步骤；文件不在 / 读不成返回空
static func load_steps(id: StringName) -> Array:
	var path := DIR + String(id) + ".json"
	if not FileAccess.file_exists(path):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or not ((d as Dictionary).get("steps", null) is Array):
		return []
	return (d["steps"] as Array).filter(func(s): return s is Dictionary)


## 步骤里有问题的地方（target 不在 [param known_ids] 里、没写字）；空 = 没问题。
## [param known_ids] 空 = 地图屏的读数部件（[method HudWidgets.has]）与顶端栏两头（235，[constant HudWidgets.BAR_ENDS]）；166 补充二：战斗屏传 [constant BattleView.COACH_TARGETS]
static func problems(p_steps: Array, known_ids: Array = []) -> Array[String]:
	var out: Array[String] = []
	for i in p_steps.size():
		var s: Dictionary = p_steps[i]
		var target := StringName(String(s.get("target", "")))
		var known := known_ids.has(target) if not known_ids.is_empty() else (HudWidgets.has(target) or HudWidgets.BAR_ENDS.has(target))
		if not known:
			out.append("steps[%d]：没有这个目标 '%s'" % [i, target])
		if String(s.get("text", "")) == "":
			out.append("steps[%d]：没写说明" % i)
		if String((s.get("texts", {}) as Dictionary).get("en", "")) == "":     # 221 F3
			out.append("steps[%d]：没写英文（texts.en）" % i)
	return out


func _init() -> void:
	name = "CoachOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_arrow = HudIcon.load_art(ARROW_ART)
	_paper = PanelContainer.new()
	_paper.theme_type_variation = UiTheme.PANEL_TOOLTIP
	UiTheme.apply_tone(_paper, UiTheme.PANEL_TOOLTIP)     # 170 起悬浮窗是深底：白字
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = PAPER_WIDTH
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(_line)
	resized.connect(_layout)


func start(p_steps: Array) -> void:
	steps = p_steps
	index = -1
	next()


## 下一步；没有了就收掉
func next() -> void:
	index += 1
	if index >= steps.size():
		finished.emit()
		queue_free()
		return
	_line.text = text_of(steps[index])
	_layout()


## 221 F3：一步的字按当前语言取（`texts: {"en": …}`），没写回落 `text`
static func text_of(p_step: Dictionary) -> String:
	var table: Variant = p_step.get("texts", {})
	return Names.pick(table as Dictionary if table is Dictionary else {}, String(p_step.get("text", "")))


func step() -> Dictionary:
	return steps[index] if index >= 0 and index < steps.size() else {}


## 这一步的洞（本控件坐标；找不到目标是空矩形）
func hole() -> Rect2:
	var s := step()
	if s.is_empty() or not target_rect.is_valid():
		return Rect2()
	var r: Rect2 = target_rect.call(StringName(String(s.get("target", ""))))
	if r.size == Vector2.ZERO:
		return Rect2()
	return Rect2(r.position - global_position, r.size).grow(HOLE_PAD)


## 箭头朝上（洞在上半屏，箭头在洞下面）还是朝下
func _points_up(h: Rect2) -> bool:
	return h.get_center().y < size.y * 0.5


## 箭尖、箭尾（本控件坐标）
func arrow_ends() -> Array[Vector2]:
	var h := hole()
	if h.size == Vector2.ZERO:
		return []
	var up := _points_up(h)
	var tip := Vector2(h.get_center().x, h.end.y + 6.0) if up else Vector2(h.get_center().x, h.position.y - 6.0)
	var tail := tip + Vector2(0, ARROW_SIZE.x if up else -ARROW_SIZE.x)
	return [tip, tail]


func _layout() -> void:
	if _paper == null or index < 0:
		return
	_paper.reset_size()
	var box := _paper.get_combined_minimum_size()
	var ends := arrow_ends()
	var at: Vector2
	if ends.is_empty():
		at = (size - box) * 0.5
	else:
		var tail: Vector2 = ends[1]
		var up := tail.y > ends[0].y
		at = Vector2(tail.x - box.x * 0.5, tail.y + 8.0 if up else tail.y - 8.0 - box.y)
	_paper.position = at.clamp(Vector2(8, 8), (size - box - Vector2(8, 8)).max(Vector2(8, 8)))
	_paper.size = box
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		accept_event()
		next()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		next()


func _draw() -> void:
	var h := hole()
	if h.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), SHADE)
		return
	# 洞外四块
	draw_rect(Rect2(0, 0, size.x, h.position.y), SHADE)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), SHADE)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), SHADE)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), SHADE)
	draw_rect(h, UiPalette.STAMINA, false, RIM)
	var ends := arrow_ends()
	var tip: Vector2 = ends[0]
	var tail: Vector2 = ends[1]
	var dir := (tip - tail).normalized()
	if _arrow != null:
		# 图朝右：转到 tail → tip 的方向，图的右端（箭尖）落在 tip
		draw_set_transform(tail, dir.angle(), Vector2.ONE)
		draw_texture_rect(_arrow, Rect2(Vector2(0, -ARROW_SIZE.y * 0.5), ARROW_SIZE), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 没图：一笔稍弯的折线 + 箭头
	var side := Vector2(-dir.y, dir.x)
	var mid := (tip + tail) * 0.5 + side * 14.0
	draw_polyline(PackedVector2Array([tail, mid, tip]), Color("f6eedb"), 4.0, true)
	draw_polyline(PackedVector2Array([tip - dir * 18.0 + side * 10.0, tip, tip - dir * 18.0 - side * 10.0]), Color("f6eedb"), 4.0, true)
