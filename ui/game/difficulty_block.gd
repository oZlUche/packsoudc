## 180 补四 / 补五（作者 2026-10-17 11:38 / 11:43 / 11:49）：开局屏第三页右栏的难度块，按坐标摆（不进容器），好让卷轴走位。
##
## 收起（〇级）：一颗居中写「开启挑战」的铜牌按钮，背后横着两根卷好的卷轴（上下各露一截）。
## 展开（≥ Ⅰ）：「当前难度」铜牌（按钮面原位）| 翻页计数器 |「−」「＋」| 卷轴羊皮纸（[ChallengeScroll]）。
## 两根卷轴就是羊皮纸的顶、底卷轴，收起与展开共用同一对节点：
## - 展开（约 0.45 秒）：0–[constant MOVE_SEC] 两根卷轴合在一起一起往下移到纸的位置，按钮面淡出、铜牌 / 计数器（〇）/ 加减淡入；
##   之后 [constant SPREAD_SEC] 两根卷轴上下拉开放出 Ⅰ 级那一行，计数器从〇往上翻到 Ⅰ。
## - 收起（Ⅰ 级按「−」）：反过来 —— 计数器翻回〇、卷轴合上收掉那一行，合上的卷轴上移回按钮背后，按钮面淡入。
## - 动画关着一帧到位；动画中块上盖一层挡板，点一下直接到终态
class_name DifficultyBlock
extends Control

signal step_pressed(delta: int)
signal open_pressed

## 块多宽、收起时多高（对美术样稿 diff_open 304 × 104）、按钮面 / 铜牌多大
const WIDTH := 308.0
const CLOSED_H := 104.0
const FACE_SIZE := Vector2(248, 76)
## 卷轴下移 / 上移多久、拉开 / 合上多久
const MOVE_SEC := 0.2
const SPREAD_SEC := 0.25
## 竖着的间距、加减键多大
const GAP := 10.0
const STEP_BTN := Vector2(56, 44)

## 收起时的「开启挑战」按钮面（字在按钮上）
var open_btn: Button = null
## 展开后顶上的「当前难度」铜牌
var title: PanelContainer = null
var counter: PanelContainer = null
var flipper: FlipCounter = null
var steps: HBoxContainer = null
var minus_btn: Button = null
var plus_btn: Button = null
var scroll: ChallengeScroll = null
## 两根卷轴（整卷 [member scroll]）的顶在块里的 y（动画改它）
var rods_y: float = 0.0:
	set(v):
		rods_y = v
		if scroll != null:
			scroll.position = Vector2(0.0, v)
		update_minimum_size()
var _open := false
var _tween: Tween = null
## 动画中盖在块上的挡板：点一下直接到终态
var _shield: Control = null
## 动画的终态：{numeral, lines}（再点 / 再按时直接摆成它）
var _target := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 块高 = 底卷轴的下沿：展开时计数器、加减由往下走的卷轴一路「扫」出来，收起时它们在块外、被裁掉也点不着。
	# 铜牌、计数器、加减从不 visible = false（藏着的容器最小尺寸不更新，算位置会错），只改透明度
	clip_contents = true
	custom_minimum_size.x = WIDTH
	# 叠放次序（下 → 上）：铜牌、计数器、加减 | 卷轴（往下走时压过它们）|「开启挑战」按钮面（收起时压在卷轴前）| 动画挡板
	scroll = ChallengeScroll.new(WIDTH)
	scroll.minimum_size_changed.connect(update_minimum_size)
	open_btn = UiTheme.make_difficulty_plate("开启挑战", func(): open_pressed.emit())
	title = PanelContainer.new()
	title.theme_type_variation = UiTheme.PANEL_DIFF_TITLE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.set_tone(title, UiTheme.tone_of(UiTheme.PANEL_DIFF_TITLE))
	var words := UiTheme.make_variant_label("当前难度", UiTheme.LABEL_DIFF_TITLE)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_child(words)
	add_child(title)
	# 180 补二：翻页计数器 —— 黑底白字牌面、深黄铜框，罗马数字（0 级写「〇」）
	counter = PanelContainer.new()
	counter.theme_type_variation = UiTheme.PANEL_FLIP_COUNTER
	add_child(counter)
	flipper = FlipCounter.new()
	flipper.set_value("〇")
	counter.add_child(flipper)
	steps = UiTheme.hbox(16)
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(steps)
	minus_btn = _step_button("−", -1)
	plus_btn = _step_button("＋", 1)
	counter.minimum_size_changed.connect(_layout)
	steps.minimum_size_changed.connect(_layout)
	add_child(scroll)
	add_child(open_btn)
	_shield = Control.new()
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.visible = false
	_shield.gui_input.connect(_on_shield_input)
	add_child(_shield)
	_apply(false)


func _step_button(text: String, delta: int) -> Button:
	var b := UiTheme.make_button(text, func(): step_pressed.emit(delta), UiPalette.Tier.MINOR, 24)
	b.theme_type_variation = UiTheme.BUTTON_STEP     # 补四：到头真变灰
	b.custom_minimum_size = STEP_BTN
	steps.add_child(b)
	return b


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_layout()


func _get_minimum_size() -> Vector2:
	if scroll == null:
		return Vector2(WIDTH, CLOSED_H)
	return Vector2(WIDTH, maxf(CLOSED_H, rods_y + scroll.get_combined_minimum_size().y))


## 按钮面 / 铜牌的位置（同一处）
func face_rect() -> Rect2:
	return Rect2(Vector2((WIDTH - FACE_SIZE.x) * 0.5, (CLOSED_H - FACE_SIZE.y) * 0.5), FACE_SIZE)


## 收起时两根卷轴顶在哪、中间夹多高（卷轴中线压在按钮面的上下沿）
func closed_rods_y() -> float:
	return face_rect().position.y - scroll.top_rod.custom_minimum_size.y * 0.5


func closed_hold() -> float:
	return FACE_SIZE.y - scroll.top_rod.custom_minimum_size.y * 0.5 - scroll.bottom_rod.custom_minimum_size.y * 0.5


## 展开时计数器、加减、卷轴顶在哪
func counter_y() -> float:
	return face_rect().end.y + GAP


func steps_y() -> float:
	return counter_y() + counter.get_combined_minimum_size().y + GAP


func open_rods_y() -> float:
	return steps_y() + steps.get_combined_minimum_size().y + GAP


## 展开时羊皮纸的上沿离块顶多远（第三页按它和「出发」按钮算纸能长多长）
func open_paper_top() -> float:
	return open_rods_y() + scroll.top_rod.custom_minimum_size.y


func _layout() -> void:
	if scroll == null:
		return
	var face := face_rect()
	open_btn.position = face.position
	open_btn.size = face.size
	title.position = face.position
	title.size = face.size
	var cm := counter.get_combined_minimum_size()
	counter.position = Vector2((WIDTH - cm.x) * 0.5, counter_y())
	counter.size = cm
	var sm := steps.get_combined_minimum_size()
	steps.position = Vector2((WIDTH - sm.x) * 0.5, steps_y())
	steps.size = sm
	_shield.position = Vector2.ZERO
	_shield.size = Vector2(WIDTH, maxf(size.y, get_combined_minimum_size().y))
	if _tween == null:
		rods_y = open_rods_y() if _open else closed_rods_y()


## 展开着（≥ Ⅰ）
func is_open() -> bool:
	return _open


## 正在展开 / 收起
func transitioning() -> bool:
	return _tween != null


## 一个难度都没解锁：按钮压灰、悬停提示
func set_locked(locked: bool) -> void:
	open_btn.disabled = locked
	open_btn.tooltip_text = "通关一次后开放" if locked else ""


## 摆成：计数器写 [param numeral]、纸上 [param lines]（[[级, 文字]...] 从低到高）、[param open] 展开与否。
## [param dir]：翻页方向；[param animate]：播动画 / 翻页 / 伸缩
func show_state(numeral: String, lines: Array, open: bool, dir: int, animate: bool) -> void:
	finish()
	_target = {"numeral": numeral, "lines": lines}
	if not animate or not is_inside_tree():
		flipper.set_value(numeral, 0, false)
		scroll.set_lines(lines, false)
		_apply(open)
		return
	if open == _open:
		flipper.set_value(numeral, dir, true)
		scroll.set_lines(lines, true)
		return
	_shield.visible = true
	_layout()     # 先按旧的开合摆好（卷轴从原位出发）
	_open = open
	if open:
		_play_open(numeral, lines, dir)
	else:
		_play_close(numeral, lines, dir)


func _play_open(numeral: String, lines: Array, dir: int) -> void:
	for c: Control in [title, counter, steps]:
		c.modulate.a = 0.0
	scroll.hold_h = scroll.shown_h
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, ^"rods_y", open_rods_y(), MOVE_SEC).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(scroll, ^"hold_h", 0.0, MOVE_SEC).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(open_btn, ^"modulate:a", 0.0, MOVE_SEC)
	for c: Control in [title, counter, steps]:
		_tween.tween_property(c, ^"modulate:a", 1.0, MOVE_SEC)
	_tween.chain().tween_callback(func():
		open_btn.visible = false
		flipper.set_value(numeral, dir, true)
		scroll.set_lines(lines, false)     # 卷轴钉在 0 高：行已经在纸里，拉开就露出来
		scroll.paper_alpha = 1.0)
	_tween.chain().tween_method(func(h: float): scroll.hold_h = h, 0.0, _natural_paper(), SPREAD_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_callback(_end_transition)


func _play_close(numeral: String, lines: Array, dir: int) -> void:
	flipper.set_value(numeral, dir, true)
	scroll.hold_h = scroll.shown_h
	open_btn.visible = true
	open_btn.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(scroll, ^"hold_h", 0.0, SPREAD_SEC).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(func():
		scroll.set_lines(lines, false)
		scroll.paper_alpha = 0.0)
	_tween.set_parallel()
	_tween.chain().tween_property(self, ^"rods_y", closed_rods_y(), MOVE_SEC).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(scroll, ^"hold_h", closed_hold(), MOVE_SEC).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(open_btn, ^"modulate:a", 1.0, MOVE_SEC)
	for c: Control in [title, counter, steps]:
		_tween.tween_property(c, ^"modulate:a", 0.0, MOVE_SEC)
	_tween.chain().tween_callback(_end_transition)


## 纸放开以后按内容该多长
func _natural_paper() -> float:
	return scroll.paper_height()


func _end_transition() -> void:
	_tween = null
	_apply(_open)


## 动画直接到终态（再点一下、再按一下、测试）
func finish() -> void:
	if _tween == null:
		return
	_tween.kill()
	_tween = null
	if not _target.is_empty():
		flipper.set_value(String(_target["numeral"]), 0, false)
		scroll.set_lines(_target["lines"], false)
	_apply(_open)


## 不播动画，直接摆成展开 / 收起的样子
func _apply(open: bool) -> void:
	_open = open
	_shield.visible = false
	open_btn.visible = not open
	open_btn.modulate.a = 1.0
	for c: Control in [title, counter, steps]:
		c.modulate.a = 1.0 if open else 0.0
	scroll.paper_alpha = 1.0 if open else 0.0
	scroll.hold_h = -1.0 if open else closed_hold()
	rods_y = open_rods_y() if open else closed_rods_y()
	_layout()


func _on_shield_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		finish()
		_shield.accept_event()
