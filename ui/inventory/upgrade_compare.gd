## 298：升级前后两块信息窗并排 —— 左 = 现在这把（真实例），右 = 锤 / 打完那把（预览件）。用悬浮窗的皮和 [method ItemTooltip.describe_full] 的排版，不要新图。
## 右窗正文里和左窗对不上的行（逐行比字：改了数的、新添的）左侧一条金线；名字和稀有度在头里，不比。不写差值。
## 常驻的信息窗：不用停、不会收；窗里的关键词 / 配方词 / 道具词停 [constant HoverTip.TERM_SEC] 秒照按钮那样叫出悬浮窗（[method HoverTip.show_meta]）。
## 用在砧（[AnvilColumn]，配得上时）和铁匠铺（[SmithyPanel]，升级类配方点开时；仓库没这把 → 左窗品质 0、整窗压暗）
class_name UpgradeCompare
extends Control

const GAP := 12.0
## 金线：宽、离正文左边多远
const MARK_W := 3.0
const MARK_GAP := 7.0
const MARK_COLOR := HoverTip.RING_COLOR
## 仓库里没有这把：左窗整窗压暗
const DIMMED := Color(0.55, 0.55, 0.55)

var left: HoverTip.TipWindow = null
var right: HoverTip.TipWindow = null
## 叫出词悬浮窗用的那个（空 = 第一次要用时沿祖先找，[method HoverTip.host_for]）
var tip: HoverTip = null
var _marks: Control = null
## 右窗正文里要画金线的段（段号）
var _marked: Array[int] = []
## 每扇窗的排版宽（铁匠铺砧面上的空窄，按空算）
var window_width := HoverTip.scaled(HoverTip.MAX_WIDTH)
## 正叫着悬浮窗的那个词（空 = 没有）
var _shown := ""


func _init() -> void:
	name = "UpgradeCompare"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	left = _window()
	right = _window()
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


func _window() -> HoverTip.TipWindow:
	var w := HoverTip.TipWindow.new(HoverTip.scaled(HoverTip.MAX_WIDTH))
	w.visible = true
	w.resized.connect(_layout)
	add_child(w)
	return w


## 摆上两把：[param before] 现在这把，[param after] 之后那把；[param dimmed] = 左窗压暗（铁匠铺仓库里没有这把）
func show_pair(before: ItemInstance, after: ItemInstance, dimmed: bool = false) -> void:
	if before == null or after == null:
		clear()
		return
	_fill(left, before)
	_fill(right, after)
	left.modulate = DIMMED if dimmed else Color.WHITE
	_marked = differing(_lines(left), _lines(right))
	visible = true
	_layout()


## 收起（词悬浮窗一起收）
func clear() -> void:
	_release()
	visible = false
	_marked.clear()


func _fill(w: HoverTip.TipWindow, inst: ItemInstance) -> void:
	w.reset_state()
	w.full_width = window_width
	var full := ItemTooltip.describe_full(inst)
	w.set_item(full)
	w.terms = full.get("terms", {})
	w.set_fav(-1)
	w.clear_actions()
	w.reset_size()


func _layout() -> void:
	if left == null or right == null or _marks == null:
		return
	left.position = Vector2.ZERO
	right.position = Vector2(left.size.x + GAP, 0.0)
	size = Vector2(right.position.x + right.size.x, maxf(left.size.y, right.size.y))
	custom_minimum_size = size
	_marks.position = Vector2.ZERO
	_marks.size = size
	move_child(_marks, -1)     # 金线压在窗上
	_marks.queue_redraw()


## 一扇窗正文的各段（去掉 BBCode 的字；段号和 [method RichTextLabel.get_paragraph_offset] 对得上）
static func _lines(w: HoverTip.TipWindow) -> PackedStringArray:
	return w.body.get_parsed_text().split("\n") if w.body.visible else PackedStringArray()


## [param after] 里哪几段在 [param before] 里找不到（段号）
static func differing(before: PackedStringArray, after: PackedStringArray) -> Array[int]:
	var had := {}
	for l in before:
		had[l.strip_edges()] = true
	var out: Array[int] = []
	for i in after.size():
		var l := after[i].strip_edges()
		if l != "" and not had.has(l):
			out.append(i)
	return out


## 右窗画了金线的那几行的字（测试看）
func marked_lines() -> Array[String]:
	var all := _lines(right)
	var out: Array[String] = []
	for i in _marked:
		if i < all.size():
			out.append(all[i])
	return out


func left_dimmed() -> bool:
	return left.modulate != Color.WHITE


func _draw_marks() -> void:
	if not visible or _marked.is_empty():
		return
	var body := right.body
	var n := body.get_paragraph_count()
	var o := body.global_position - _marks.global_position
	for i in _marked:
		if i >= n:
			continue
		var y0 := float(body.get_paragraph_offset(i))
		var y1 := float(body.get_paragraph_offset(i + 1)) if i + 1 < n else float(body.get_content_height())
		if y1 <= y0:
			continue
		_marks.draw_rect(Rect2(o.x - MARK_GAP - MARK_W, o.y + y0 + 2.0, MARK_W, y1 - y0 - 4.0), MARK_COLOR)


func _process(delta: float) -> void:
	if visible:
		tick(delta, get_global_mouse_position())


## 词停留的计时（测试直接喂）：停够了叫出悬浮窗，离开那个词就放手（钉住的照悬浮窗自己的规矩留着）
func tick(delta: float, at: Vector2) -> void:
	var meta := ""
	var from: HoverTip.TipWindow = null
	for w in [left, right]:
		var tw := w as HoverTip.TipWindow
		if tw.hover_term != "":
			tw.hover_t += delta
			meta = tw.hover_term
			from = tw
	if meta == _shown:
		_marks.queue_redraw()
		return
	if meta == "" or from.hover_t >= HoverTip.TERM_SEC:
		_release()
		if meta != "":
			var host := _tip()
			if host != null and host.show_meta(meta, from.terms, at):
				_shown = meta


func _release() -> void:
	if _shown == "":
		return
	_shown = ""
	var host := _tip()
	if host != null:
		host.release()


func _tip() -> HoverTip:
	if tip == null or not is_instance_valid(tip):
		tip = HoverTip.host_for(self)
	return tip


## 两扇窗的字（测试看）
func texts() -> Array[String]:
	return [left.text(), right.text()]
