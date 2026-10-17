## 180 补三（作者 2026-10-17 11:32）：开局屏第三页难度块下面的挑战说明 —— 「−」「＋」下方一根顶卷轴，羊皮纸从它垂下，下端一根底卷轴。
##
## 每级一行「Ⅰ.　文字」，**从下到上**：〇级在最底，等级越高越靠上，新的一行总出现在顶卷轴正下方。
## 以罗马数字后的「.」对齐：数字一列固定宽、右对齐，点紧跟其后，正文左对齐自动换行。
## 加一级：纸往下长一行、新行从顶卷轴下展开；减一级：最上面那行收回卷轴、纸缩短（[constant GROW_SEC]）。
## 补五（作者 11:49）：底卷轴一直在，纸再短也由两根卷轴夹着；纸长超上限（[member max_paper]，第三页按「出发」按钮的上沿算）时
## 纸停在上限，底卷轴兼做收束：最早（最低级）的行藏在它后面，滚轮一格滚一行；加一级时回到顶。
## 卷轴、纸都按坐标摆（不进容器）：难度块收起时把这一对卷轴当「开启挑战」按钮背后的两根卷好的卷轴用，
## 用 [member hold_h] 把两根卷轴之间的距离钉住、[member paper_alpha] 把纸藏掉。没图时卷轴、纸都是平色。
## 180 定稿：卷轴 `diff_roller` 304 × 30（上下同图，下面那根竖翻），纸 `diff_parch` 264 宽居中、纵向平铺；字血红不描边，行高 32
class_name ChallengeScroll
extends Control

## 伸缩一行多久
const GROW_SEC := 0.2
## 数字一列多宽（点对齐靠它）、点那一列多宽、纸的左右 / 上下内边距、行间距、字号
const NUM_W := 48.0
const DOT_W := 14.0
const PAD_X := 14.0
const PAD_Y := 8.0
const ROW_GAP := 0.0
const FONT_SIZE := 16
## 一行最矮多高（定稿：行高 32）
const ROW_MIN_H := 32.0
## 卷轴多粗（没图时）
const ROD_H := 18.0

## 纸最长多长（像素，不含卷轴）；≤ 0 = 不限
var max_paper: float = 0.0:
	set(v):
		max_paper = v
		_relayout()
## 纸里往下滚了多少（0 = 顶上，看着最新的几级）
var scroll_y: float = 0.0
## 两根卷轴之间露出来的纸多高（动画就是改它）
var shown_h: float = 0.0:
	set(v):
		shown_h = maxf(0.0, v)
		_place()
## ≥ 0：难度块接管两根卷轴的间距（收起 / 展开动画），纸多高由它定；< 0：按内容
var hold_h: float = -1.0:
	set(v):
		hold_h = v
		if v >= 0.0:
			shown_h = v
		else:
			_relayout()
## 纸的不透明度（收起时两根卷轴在按钮背后，中间不露纸）
var paper_alpha: float = 1.0:
	set(v):
		paper_alpha = v
		if paper != null:
			paper.modulate.a = v
var top_rod: Control = null
var bottom_rod: Control = null
## 纸：裁边，底是羊皮纸
var paper: Panel = null
## 纸里那一列行（最上面是最高级）
var _list: VBoxContainer = null
## 每行：{level, text, box: 外面那层裁边的 Control, line: 里面那排, body: 正文, h: 行高}；顺序同 [member _list] 的子节点（从上到下 = 从高级到低级）
var _rows: Array[Dictionary] = []
var _tween: Tween = null
var _width := 0.0
## 纸多宽（有图按图，居中在两根卷轴之间；没图 = 卷轴宽）
var _paper_w := 0.0
## 正在收回、收完就删的那一行
var _dying: Control = null


## [param width]：纸多宽（= 难度块宽）
func _init(width: float = 308.0) -> void:
	_width = width
	_paper_w = minf(width, float(UiTheme.art_meta(UiTheme.ART_PARCHMENT_STRIP).get("width", width))) if UiTheme.art(UiTheme.ART_PARCHMENT_STRIP) != null else width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper = Panel.new()
	paper.theme_type_variation = UiTheme.PANEL_PARCHMENT
	paper.clip_contents = true
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.set_tone(paper, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	add_child(paper)
	_list = UiTheme.vbox(int(ROW_GAP))
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(_list)
	top_rod = make_rod(UiTheme.ART_SCROLL_ROD_TOP)
	add_child(top_rod)
	bottom_rod = make_rod(UiTheme.ART_SCROLL_ROD_BOTTOM)
	if bottom_rod is TextureRect:
		(bottom_rod as TextureRect).flip_v = true     # 上下同图，下面那根竖翻
	add_child(bottom_rod)
	paper.gui_input.connect(_on_paper_input)
	_relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_THEME_CHANGED:
		if _tween == null:
			_relayout()


func _get_minimum_size() -> Vector2:
	if top_rod == null:
		return Vector2.ZERO
	return Vector2(_width, rods_h() + shown_h)


## 一根卷轴：有图贴图，没图平色（[param thick]：没图时多粗）
static func make_rod(art_name: String, thick: float = ROD_H) -> Control:
	var tex := UiTheme.art(art_name)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.custom_minimum_size.y = maxf(thick, tex.get_size().y)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return pic
	var flat := ColorRect.new()
	flat.color = UiTheme.SCROLL_ROD
	flat.custom_minimum_size.y = thick
	flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flat


## 两根卷轴加起来多粗
func rods_h() -> float:
	return top_rod.custom_minimum_size.y + bottom_rod.custom_minimum_size.y


## 按 [member shown_h] 摆：顶卷轴 | 纸 | 底卷轴，贴紧
func _place() -> void:
	if paper == null:
		return
	var top := top_rod.custom_minimum_size.y
	top_rod.position = Vector2.ZERO
	top_rod.size = Vector2(_width, top)
	paper.position = Vector2((_width - _paper_w) * 0.5, top)
	paper.size = Vector2(_paper_w, shown_h)
	bottom_rod.position = Vector2(0.0, top + shown_h)
	bottom_rod.size = Vector2(_width, bottom_rod.custom_minimum_size.y)
	update_minimum_size()


## 换成这几行（[[级, 文字], ...]，从低级到高级）。和现在比只多了最高一级 / 只少了最高一级时播伸缩，别的情况直接换
func set_lines(lines: Array, animate: bool = true) -> void:
	var now := _rows.map(func(r: Dictionary) -> Array: return [r["level"], r["text"]])
	now.reverse()     # _rows 从高到低，lines 从低到高
	if now == lines:
		return
	_finish()
	var can_anim := animate and is_inside_tree() and hold_h < 0.0
	if lines.size() == now.size() + 1 and lines.slice(0, now.size()) == now:
		var row := _add_row(int(lines[-1][0]), String(lines[-1][1]), 0)
		scroll_y = 0.0     # 新的一级：回到顶
		_grow(row, can_anim)
		return
	if lines.size() == now.size() - 1 and now.slice(0, lines.size()) == lines:
		_shrink(_rows[0], can_anim)
		return
	for r in _rows:
		(r["box"] as Control).free()
	_rows.clear()
	for i in range(lines.size() - 1, -1, -1):
		_add_row(int(lines[i][0]), String(lines[i][1]), -1)
	scroll_y = 0.0
	_relayout()


## 一行「Ⅰ.　文字」：外层裁边（展开 / 收回靠它的高），里面 数字（固定宽、右对齐）| 点 | 正文（自动换行）
func _add_row(level: int, text: String, at: int) -> Dictionary:
	var box := Control.new()
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := UiTheme.hbox(0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	var num := UiTheme.make_label("〇" if level <= 0 else TextTemplate.roman(level), FONT_SIZE, UiTheme.INK)
	num.custom_minimum_size.x = NUM_W
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN     # 正文折几行，数字都贴第一行
	num.name = "Num"
	line.add_child(num)
	var dot := UiTheme.make_label(".", FONT_SIZE, UiTheme.INK)
	dot.custom_minimum_size.x = DOT_W
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dot.name = "Dot"
	line.add_child(dot)
	var body := UiTheme.make_label(text, FONT_SIZE, UiTheme.PARCHMENT_RED)
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.custom_minimum_size.x = text_width()
	body.name = "Text"
	line.add_child(body)
	var row := {"level": level, "text": text, "box": box, "line": line, "body": body, "h": 0.0}
	_list.add_child(box)
	_measure(row)
	if at >= 0:
		_list.move_child(box, at)
		_rows.insert(at, row)
	else:
		_rows.append(row)
	box.custom_minimum_size = Vector2(_paper_w - PAD_X * 2.0, float(row["h"]))
	return row


## 量一行多高（进树之后字体才是正文字体，[method _relayout] 时重量）
func _measure(row: Dictionary) -> void:
	var h := _row_height(row["body"])
	row["h"] = h
	(row["line"] as Control).size = Vector2(_paper_w - PAD_X * 2.0, h)


## 正文一列多宽
func text_width() -> float:
	return maxf(40.0, _paper_w - PAD_X * 2.0 - NUM_W - DOT_W)


## 行高：按正文换行后的实际高（长句占几行就几行高）
func _row_height(body: Label) -> float:
	var font := body.get_theme_font("font")
	var fs := body.get_theme_font_size("font_size")
	if font == null:
		return float(FONT_SIZE) * 1.5
	var one := font.get_height(fs)
	var multi := font.get_multiline_string_size(body.text, HORIZONTAL_ALIGNMENT_LEFT, text_width(), fs).y
	var n := maxi(1, roundi(multi / one))     # 折成几行；Label 行间还有 line_spacing
	return maxf(ROW_MIN_H, one * n + float(body.get_theme_constant("line_spacing")) * (n - 1) + 2.0)


func _grow(row: Dictionary, animate: bool) -> void:
	var box: Control = row["box"]
	var h := float(row["h"])
	if not animate:
		_relayout()
		return
	box.custom_minimum_size.y = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(box, ^"custom_minimum_size:y", h, GROW_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, ^"shown_h", paper_height(), GROW_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_callback(_finish)


func _shrink(row: Dictionary, animate: bool) -> void:
	var box: Control = row["box"]
	_rows.erase(row)
	if not animate:
		box.free()
		_relayout()
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(box, ^"custom_minimum_size:y", 0.0, GROW_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, ^"shown_h", paper_height(), GROW_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_callback(func():
		if is_instance_valid(box):
			box.queue_free()
		_finish())
	_dying = box


## 动画直接到头（又按了一下、测试）
func _finish() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if _dying != null and is_instance_valid(_dying):
		_dying.free()
	_dying = null
	_relayout()


## 所有行加起来多高
func content_height() -> float:
	if _rows.is_empty():
		return ROW_MIN_H + PAD_Y * 2.0     # 一行都没有：留一行高的空纸
	var h := 0.0
	for r in _rows:
		h += float(r["h"])
	return h + ROW_GAP * maxf(0.0, _rows.size() - 1) + PAD_Y * 2.0


## 纸该多长：内容高，夹在上限里
func paper_height() -> float:
	var h := content_height()
	return minf(h, max_paper) if max_paper > 0.0 else h


## 收束了（内容超长，底卷轴藏着最早的行）
func capped() -> bool:
	return max_paper > 0.0 and content_height() > max_paper + 0.5


## 最多能往下滚多少
func max_scroll() -> float:
	return maxf(0.0, content_height() - paper_height())


func _relayout() -> void:
	if paper == null:
		return
	for r in _rows:
		_measure(r)
		(r["box"] as Control).custom_minimum_size.y = float(r["h"])
	scroll_y = clampf(scroll_y, 0.0, max_scroll())
	_sync_scroll()
	if _tween == null:
		shown_h = hold_h if hold_h >= 0.0 else paper_height()


func _sync_scroll() -> void:
	if _list != null:
		_list.position = Vector2(PAD_X, PAD_Y - scroll_y)
		_list.size.x = _paper_w - PAD_X * 2.0


## 滚 [param rows] 行（正 = 往下看更早的级）
func scroll_rows(rows: int) -> void:
	var step := float(_rows[0]["h"]) + ROW_GAP if not _rows.is_empty() else 0.0
	scroll_y = clampf(scroll_y + step * rows, 0.0, max_scroll())
	_sync_scroll()


func _on_paper_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or not capped():
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_rows(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		paper.accept_event()


## 现在的几行（从上到下 = 从高级到低级；测试看）
func rows() -> Array[Dictionary]:
	return _rows


## 拼成一段字（测试看）
func text() -> String:
	return "\n".join(_rows.map(func(r: Dictionary) -> String: return String(r["text"])))
