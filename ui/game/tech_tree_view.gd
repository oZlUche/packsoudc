## 科技树（118，作者定）：节点按 [member TechDef.column] 横排、按深度竖排 —— **深度 0 在最下面，往上长**。
## 节点之间按前置（[member TechDef.requires]）画线：从前置的顶边中点到本节点的底边中点，两端都点亮了是朱红，否则墨色（229：宽 3 圆头，颜色读树区底纸的 json `line`）。
## 229：每列顶上一枚段头签（[HeaderTag]，`tech.col_<树>_<列>`，319 起两棵树各一套）；列与列之间只垫一道 [constant H_GAP]，外侧交给 [constant MARGIN]。
##
## 节点三种样子（乙 石刻）：**已点亮** = 家的主档木牌、**可点亮**（前置都满足、还没点）= 木牌（慢慢亮暗呼吸）、**锁住** = 灰木牌，墨字；
## 选中叠一圈 `kit/node_sel`（四边外扩 5）。点一个节点发 [signal selected]；数据（等级、前置）全看 [TechService]，这里只画
class_name TechTreeView
extends Control

signal selected(id: StringName)

const NODE_SIZE := Vector2(160, 60)
## 木牌左右各有一颗钉子：字两头让开这么宽（游戏测试 10-22：Warehouse Expansion 压到钉子）
const PEG_ROOM := 20.0
## 列与列、同格并排的节点之间
const H_GAP := 28.0
## 深度之间（画线的地方）
const V_GAP := 46.0
const MARGIN := 6.0
## 列头签那一行（签高 + 到最上一层节点的距离）
const HEADER_H := HeaderTag.HEIGHT + 14.0
## 连线（229 美术设计：树区底纸 json 的 `line`；没图按这个）
const PAPER_ART := "tech/tech_tree_hide"
const LINE_INK := Color("3a2c20")
const LINE_LIT := Color("b3261e")
const LINE_W := 3.0
## 乙 石刻木牌节点与选中圈
const WOOD_ART := {0: "home/btn_wood_primary", 1: "home/btn_wood", 2: "home/btn_wood_disabled"}
const SEL_ART := "kit/node_sel"
const SEL_OUTSET := 5.0
## 锁住的灰木牌上写深墨（名字和等级要看得清，灰牌本身就说明锁着）
const LOCKED_INK := Color("4a443c")

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
## 列号 → 那一列的中线 x（列头签对着它）
var _col_mid: Dictionary = {}
var _line_ink := LINE_INK
var _line_lit := LINE_LIT
var _line_w := LINE_W
## 选中圈画在最上面这层（节点按钮是子控件，自己的 _draw 会被它们盖住）
var _ring: Control = null
var _ring_box: StyleBoxTexture = null


func _init() -> void:
	# 237：呼吸动画只在看得见时跑（基地屏别的页开着时这块树藏着，以前照样每帧改三块 StyleBox）
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	var line: Dictionary = UiTheme.art_meta(PAPER_ART).get("line", {})
	_line_ink = Color(String(line.get("ink", LINE_INK.to_html(false))))
	_line_lit = Color(String(line.get("lit", LINE_LIT.to_html(false))))
	_line_w = float(line.get("width", LINE_W))


func setup(p_meta: MetaState, p_defs: Array[TechDef], p_font: Font) -> void:
	meta = p_meta
	defs = p_defs
	font = p_font
	rebuild()


## 重新排位、重画全部节点（等级变了、选中变了都调它）
func rebuild() -> void:
	UiTheme.clear_children(self)
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
		_style(b, def)
		var id := def.id
		b.pressed.connect(func(): select(id))
		add_child(b)
		# 名字长（英文）放不下就把字号往下收，别被截掉（游戏测试 10-21：Warehouse Expansion 截成 Expansio）
		TextFit.shrink_button_to(b, r.size.x - 2.0 * PEG_ROOM, 10)     # 木牌：让开两头的钉子
		_nodes[def.id] = b
	var tags: Dictionary = {}
	var widest := 0.0
	for c in _col_mid:
		var key := "tech.col_%s_%d" % [tree_of_defs(), int(c)]
		if UiText.TEXT.has(key):
			tags[c] = HeaderTag.new(UiText.t(key))
			widest = maxf(widest, (tags[c] as HeaderTag).size.x)
	for c in tags:     # 三枚取最宽那枚的宽度（UI替换美术 18:59）
		var tag: HeaderTag = tags[c]
		tag.widen(widest)
		tag.position = Vector2(floorf(float(_col_mid[c]) - widest * 0.5), MARGIN)
		add_child(tag)
	_ring = Control.new()
	_ring.name = "SelRing"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	queue_redraw()


## 选中圈：`kit/node_sel` 九宫格（20），四边外扩 [constant SEL_OUTSET]；没图不画
func _draw_ring() -> void:
	if _selected == &"" or not _rects.has(_selected):
		return
	if _ring_box == null:
		_ring_box = UiTheme.nine_box(UiTheme.art_cached(SEL_ART), [20.0, 20.0, 20.0, 20.0])
	if _ring_box.texture != null:
		_ring.draw_style_box(_ring_box, (_rects[_selected] as Rect2).grow(SEL_OUTSET + 6.0))     # 图四周多 6


## 选中一个节点（发 [signal selected]）；没有这个 id 返回 false
func select(id: StringName) -> bool:
	if not _nodes.has(id):
		return false
	_selected = id
	for def in defs:
		_style(_nodes[def.id], def)
	if _ring != null:
		_ring.queue_redraw()
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
		return UiText.t("tech.lit") if lv >= 1 else UiText.t("tech.unlit")
	return "Lv %d / %d" % [lv, def.max_level()]


## 319：这张树是哪一棵（看第一个节点；空树当数值树）
func tree_of_defs() -> String:
	return String(defs[0].tree) if not defs.is_empty() else String(TechDef.TREE_STAT)


#region 排位
## 列手写、深度按前置算（作者定）。同列同深度的几个按 order、id 并排；每列宽 = 那列最多并排几个。
## 229：列与列之间一道 [constant H_GAP]（原来每列两侧各垫一道）；顶上留 [constant HEADER_H] 放列头签
func _place() -> void:
	var lay := TechService.layout(defs)
	var slots := {}     # Vector2i(列, 深度) → [def…]
	var max_col := 0
	var max_depth := 0
	for def in defs:
		var at: Vector2i = lay.get(def.id, Vector2i.ZERO)
		(slots.get_or_add(at, []) as Array).append(def)
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
	_col_mid.clear()
	for c in max_col + 1:
		col_x.append(x)
		var n := maxi(1, widths[c])
		var w := n * NODE_SIZE.x + (n - 1) * H_GAP
		_col_mid[c] = x + w * 0.5
		x += w + H_GAP
	for key in slots:
		var at: Vector2i = key
		var list: Array = slots[at]
		var n := maxi(1, widths[at.x])
		var col_w := n * NODE_SIZE.x + (n - 1) * H_GAP
		var row_w := list.size() * NODE_SIZE.x + (list.size() - 1) * H_GAP
		var start: float = col_x[at.x] + (col_w - row_w) / 2.0
		var y := MARGIN + HEADER_H + (max_depth - at.y) * (NODE_SIZE.y + V_GAP)     # 深度 0 在最下面
		for i in list.size():
			_rects[(list[i] as TechDef).id] = Rect2(Vector2(start + i * (NODE_SIZE.x + H_GAP), y), NODE_SIZE)
	custom_minimum_size = Vector2(x - H_GAP + MARGIN, MARGIN * 2 + HEADER_H + (max_depth + 1) * NODE_SIZE.y + max_depth * V_GAP)
#endregion


#region 画
func _style(b: Button, def: TechDef) -> void:
	var st := state_of(def.id)
	var box := _wood_box(st)
	var fg := UiTheme.INK if st != State.LOCKED else LOCKED_INK
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)
	if box == null:
		return
	# 121 特例：节点的样子按点亮状态实时换、可点亮的还要呼吸（_process 改这份底），每个节点得有自己的一份
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, box)
	_boxes[def.id] = box


## 乙 石刻木牌（点亮 / 可点亮 / 锁住三张图）；没图 null
func _wood_box(st: State) -> StyleBoxTexture:
	var wood := UiTheme.art_box(String(WOOD_ART[int(st)]))
	if wood != null:
		wood.set_content_margin_all(6)
		wood.content_margin_left = PEG_ROOM
		wood.content_margin_right = PEG_ROOM
	return wood


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
			var c := _line_lit if lit else _line_ink
			var pts := line_points(from, to, _rects.values())
			draw_polyline(pts, c, _line_w, true)
			for p in pts:
				draw_circle(p, _line_w * 0.5, c)     # 圆头（折角也圆）


## 319：前置 [param from] 到本节点 [param to] 的连线折点 —— 平常是前置顶边中点到本节点底边中点一条直线；
## 同一列、中间隔着别的节点（[method TechService.row_of] 往上挪过的）就绕到右边的列缝里走：前置右边 → 缝 → 本节点右边
static func line_points(from: Rect2, to: Rect2, rects: Array) -> PackedVector2Array:
	var a := Vector2(from.get_center().x, from.position.y)
	var b := Vector2(to.get_center().x, to.end.y)
	var blocked := false
	if is_equal_approx(a.x, b.x):
		var lane := Rect2(Vector2(a.x - 1.0, b.y), Vector2(2.0, a.y - b.y))
		for r in rects:
			var rr: Rect2 = r
			if rr != from and rr != to and rr.intersects(lane):
				blocked = true
				break
	if not blocked:
		return PackedVector2Array([a, b])
	var gx := from.end.x + H_GAP * 0.5
	var y0 := from.get_center().y
	var y1 := to.get_center().y
	return PackedVector2Array([Vector2(from.end.x, y0), Vector2(gx, y0), Vector2(gx, y1), Vector2(to.end.x, y1)])


## 可点亮的节点慢慢呼吸（选中的那个不闪）
func _process(delta: float) -> void:
	_t += delta
	var k := 0.5 + 0.5 * sin(_t * 2.4)
	for id in _boxes:
		if id == _selected or state_of(id) != State.AVAILABLE:
			continue
		(_boxes[id] as StyleBoxTexture).modulate_color = Color.WHITE.lerp(Color(1.06, 1.05, 1.02), k)     # 木牌：慢慢亮一点再暗回去
#endregion
