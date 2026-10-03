## 科技树（118，作者定）：节点按 [member TechDef.column] 横排、按深度竖排 —— **深度 0 在最下面，往上长**。
## 节点之间按前置（[member TechDef.requires]）画线：从前置的顶边中点到本节点的底边中点，两端都点亮了是橙色，否则线色。
##
## 节点三种样子：**已点亮**（主按钮橙底白字）、**可点亮**（前置都满足、还没点：深底亮边，边框慢慢呼吸）、**锁住**（暗字无边）。
## 选中的节点再加一圈前景色的边。点一个节点发 [signal selected]；数据（等级、前置）全看 [TechService]，这里只画
class_name TechTreeView
extends Control

signal selected(id: StringName)

const NODE_SIZE := Vector2(160, 60)
## 列与列、同格并排的节点之间
const H_GAP := 28.0
## 深度之间（画线的地方）
const V_GAP := 46.0
const MARGIN := 12.0

enum State { LIT, AVAILABLE, LOCKED }

var meta: MetaState = null
var defs: Array[TechDef] = []
var font: Font = null

## 科技 id → 节点按钮
var _nodes: Dictionary = {}
## 科技 id → 节点在本控件里的矩形
var _rects: Dictionary = {}
## 科技 id → 节点的底框（可点亮的那几个要呼吸）
var _boxes: Dictionary = {}
var _selected: StringName = &""
var _t: float = 0.0


func setup(p_meta: MetaState, p_defs: Array[TechDef], p_font: Font) -> void:
	meta = p_meta
	defs = p_defs
	font = p_font
	rebuild()


## 重新排位、重画全部节点（等级变了、选中变了都调它）
func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_nodes.clear()
	_rects.clear()
	_boxes.clear()
	_place()
	for def in defs:
		var r: Rect2 = _rects.get(def.id, Rect2())
		var b := Button.new()
		b.position = r.position
		b.size = r.size
		b.custom_minimum_size = r.size
		b.clip_text = true
		b.text = "%s\n%s" % [Names.of(def), level_text(meta, def)]
		if font != null:
			b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 14)
		_style(b, def)
		var id := def.id
		b.pressed.connect(func(): select(id))
		add_child(b)
		_nodes[def.id] = b
	queue_redraw()


## 选中一个节点（发 [signal selected]）；没有这个 id 返回 false
func select(id: StringName) -> bool:
	if not _nodes.has(id):
		return false
	_selected = id
	for def in defs:
		_style(_nodes[def.id], def)
	selected.emit(id)
	return true


func selected_id() -> StringName:
	return _selected


## 节点按钮（测试看）
func node_button(id: StringName) -> Button:
	return _nodes.get(id, null)


## 节点的矩形（测试看位置：深度大的在上面）
func node_rect(id: StringName) -> Rect2:
	return _rects.get(id, Rect2())


func state_of(id: StringName) -> State:
	var def := TechService.find(defs, id)
	if def == null:
		return State.LOCKED
	if TechService.level(meta, id) >= 1:
		return State.LIT
	return State.AVAILABLE if TechService.prereqs_met(meta, def) else State.LOCKED


## 节点第二行：多级写「Lv n / m」，单级写「已点亮 / 未点亮」
static func level_text(m: MetaState, def: TechDef) -> String:
	var lv := TechService.level(m, def.id)
	if def.max_level() <= 1:
		return "已点亮" if lv >= 1 else "未点亮"
	return "Lv %d / %d" % [lv, def.max_level()]


#region 排位
## 列手写、深度按前置算（作者定）。同列同深度的几个按 order、id 并排；每列宽 = 那列最多并排几个
func _place() -> void:
	var lay := TechService.layout(defs)
	var slots := {}     # Vector2i(列, 深度) → [def…]
	var max_col := 0
	var max_depth := 0
	for def in defs:
		var at: Vector2i = lay.get(def.id, Vector2i.ZERO)
		if not slots.has(at):
			slots[at] = []
		(slots[at] as Array).append(def)
		max_col = maxi(max_col, at.x)
		max_depth = maxi(max_depth, at.y)
	var widths: Array[int] = []
	widths.resize(max_col + 1)
	for key in slots:
		var at: Vector2i = key
		var list: Array = slots[at]
		list.sort_custom(func(a: TechDef, b: TechDef) -> bool:
			return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
		widths[at.x] = maxi(widths[at.x], list.size())
	var col_x: Array[float] = []
	var x := MARGIN
	for c in max_col + 1:
		col_x.append(x)
		var n := maxi(1, widths[c])
		x += n * NODE_SIZE.x + (n - 1) * H_GAP + H_GAP * 2
	for key in slots:
		var at: Vector2i = key
		var list: Array = slots[at]
		var n := maxi(1, widths[at.x])
		var col_w := n * NODE_SIZE.x + (n - 1) * H_GAP
		var row_w := list.size() * NODE_SIZE.x + (list.size() - 1) * H_GAP
		var start: float = col_x[at.x] + (col_w - row_w) / 2.0
		var y := MARGIN + (max_depth - at.y) * (NODE_SIZE.y + V_GAP)     # 深度 0 在最下面
		for i in list.size():
			_rects[(list[i] as TechDef).id] = Rect2(Vector2(start + i * (NODE_SIZE.x + H_GAP), y), NODE_SIZE)
	custom_minimum_size = Vector2(x - H_GAP + MARGIN, MARGIN * 2 + (max_depth + 1) * NODE_SIZE.y + max_depth * V_GAP)
#endregion


#region 画
func _style(b: Button, def: TechDef) -> void:
	var st := state_of(def.id)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	box.set_content_margin_all(6)
	match st:
		State.LIT:
			box.bg_color = UiPalette.BTN_PRIMARY
			b.add_theme_color_override("font_color", UiPalette.BTN_PRIMARY_TEXT)
		State.AVAILABLE:
			box.bg_color = UiPalette.PANEL
			box.border_color = UiPalette.BTN_SECONDARY_EDGE
			box.set_border_width_all(2)
			b.add_theme_color_override("font_color", UiPalette.FG)
		State.LOCKED:
			box.bg_color = UiPalette.PANEL.darkened(0.2)
			b.add_theme_color_override("font_color", UiPalette.DIM)
	if def.id == _selected:
		box.border_color = UiPalette.FG
		box.set_border_width_all(3)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, box)
	b.add_theme_color_override("font_hover_color", b.get_theme_color("font_color"))
	b.add_theme_color_override("font_pressed_color", b.get_theme_color("font_color"))
	_boxes[def.id] = box


func _draw() -> void:
	for def in defs:
		if not _rects.has(def.id):
			continue
		var to: Rect2 = _rects[def.id]
		for req in def.requires:
			if not _rects.has(req):
				continue
			var from: Rect2 = _rects[req]
			var lit := TechService.level(meta, req) >= 1 and TechService.level(meta, def.id) >= 1
			draw_line(Vector2(from.get_center().x, from.position.y), Vector2(to.get_center().x, to.end.y),
				UiPalette.BTN_PRIMARY if lit else UiPalette.LINE.lightened(0.25), 3.0 if lit else 2.0, true)


## 可点亮的节点边框慢慢呼吸（选中的那个不闪）
func _process(delta: float) -> void:
	_t += delta
	var k := 0.5 + 0.5 * sin(_t * 2.4)
	for id in _boxes:
		if id == _selected or state_of(id) != State.AVAILABLE:
			continue
		(_boxes[id] as StyleBoxFlat).border_color = UiPalette.BTN_SECONDARY_EDGE.lerp(UiPalette.FG, k * 0.6)
#endregion
