## 226 批一（作者 17:25「告示签做成横向打开的卷轴」）：一句告示一卷 —— 纸身横向九宫格 `notice/notice_scroll_paper`，
## 两头各一根轴 `notice/notice_scroll_roller`（要紧的换 `_urgent` 两张：朱红边线、朱漆轴头）。字由代码写：思源宋体 18、墨色，固定在整卷中心。
## 几何（美术 `art/ui/notice/README.md` 末节，1x）：纸宽 = 字宽 + 2 × [constant PAD]、高 [constant PAPER_H]，在 [constant ROLLER_H] 高的轴里垂直居中；
## 轴中心在纸边外 [constant ROLLER_OUT]，画在纸上面；整卷宽 = 纸宽 + 2 × [constant SIDE]。
## 开卷 [constant OPEN_SEC] 秒 ease-out：纸从中心往两边展开、两根轴贴着纸边往外走，字用纸的矩形裁切（两边各收 [constant CLIP_IN]），展到哪露到哪；
## 收卷 [constant CLOSE_SEC] 秒 ease-in 原路滚回，合上后 [constant FADE_SEC] 秒淡出。动效关着（测试、截图、设置）直接到终态
class_name NoticeScroll
extends Control

const PAPER := "notice/notice_scroll_paper"
const ROLLER := "notice/notice_scroll_roller"
const PAPER_H := 34.0
const ROLLER_W := 18.0
const ROLLER_H := 54.0
const PAD := 26.0
const ROLLER_OUT := 4.0
const SIDE := 14.0
const CLIP_IN := 6.0
const FONT_SIZE := 18
const INK := Color("2e2219")
const OPEN_SEC := 0.25
const CLOSE_SEC := 0.22
const FADE_SEC := 0.1
## 缺图时的纸色、轴色
const PAPER_FALLBACK := Color("e9dfc8")
const ROLLER_FALLBACK := Color("6b4a2e")

var text := ""
var urgent := false
## 展开了多少（0 = 合着，1 = 全开）
var amount := 1.0:
	set(v):
		amount = clampf(v, 0.0, 1.0)
		_sync()

var _label: Label
var _clip: Control
var _rollers: Control
var _paper_w := 0.0


static func make(p_text: String, p_urgent: bool = false) -> NoticeScroll:
	var s := NoticeScroll.new()
	s.text = p_text
	s.urgent = p_urgent
	s._build()
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build() -> void:
	name = "NoticeScroll"
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_label = Label.new()
	_label.text = text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.label_settings = LabelSettings.new()
	_label.label_settings.font = UiPalette.cjk_font()
	_label.label_settings.font_size = UiTheme.sz(FONT_SIZE)
	_label.label_settings.font_color = INK     # 纸是浅色（tone light）：墨字，深底上也是同一卷
	_clip.add_child(_label)
	_rollers = Control.new()
	_rollers.name = "Rollers"
	_rollers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rollers.draw.connect(_draw_rollers)
	add_child(_rollers)     # 轴压在纸和字上面
	var tw := UiPalette.cjk_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.sz(FONT_SIZE)).x
	_paper_w = ceilf(tw) + 2.0 * PAD
	custom_minimum_size = Vector2(_paper_w + 2.0 * SIDE, ROLLER_H)
	size = custom_minimum_size
	resized.connect(_sync)
	_sync()


## 这一卷写的字（测试读）
func label() -> Label:
	return _label


## 纸此刻在本控件里的矩形
func paper_rect() -> Rect2:
	var w := _paper_w * amount
	return Rect2(Vector2((size.x - w) * 0.5, (ROLLER_H - PAPER_H) * 0.5), Vector2(w, PAPER_H))


## 两根轴的中心 x（左、右）
func roller_x() -> Vector2:
	var r := paper_rect()
	return Vector2(r.position.x - ROLLER_OUT, r.end.x + ROLLER_OUT)


func _sync() -> void:
	if _clip == null:
		return
	var r := paper_rect()
	var inset := minf(CLIP_IN, r.size.x * 0.5)
	_clip.position = Vector2(r.position.x + inset, r.position.y)
	_clip.size = Vector2(maxf(0.0, r.size.x - 2.0 * inset), r.size.y)
	_label.reset_size()
	# 字钉在整卷中心：裁切框挪，字反着挪
	_label.position = Vector2((size.x - _label.size.x) * 0.5, (PAPER_H - _label.size.y) * 0.5) - Vector2(_clip.position.x, 0.0)
	_rollers.size = size
	queue_redraw()
	_rollers.queue_redraw()


func _art(name_: String) -> Texture2D:
	return UiTheme.art_cached(name_ + ("_urgent" if urgent else ""))


func _draw() -> void:
	var r := paper_rect()
	if r.size.x <= 0.0:
		return
	var tex := _art(PAPER)
	if tex == null:
		draw_rect(r, PAPER_FALLBACK)
		return
	var m: Array = UiTheme.art_meta(PAPER).get("margin", [10, 6, 10, 6])
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = minf(float(m[0]), r.size.x * 0.5)
	box.texture_margin_right = minf(float(m[2]), r.size.x * 0.5)
	box.texture_margin_top = float(m[1])
	box.texture_margin_bottom = float(m[3])
	draw_style_box(box, r)


func _draw_rollers() -> void:
	var tex := _art(ROLLER)
	for x in [roller_x().x, roller_x().y]:
		var at := Rect2(Vector2(x - ROLLER_W * 0.5, 0.0), Vector2(ROLLER_W, ROLLER_H))
		if tex != null:
			_rollers.draw_texture_rect(tex, at, false)
		else:
			_rollers.draw_rect(at, ROLLER_FALLBACK)


## 开卷（[param on] = 动效开着）。返回 Tween（关着 null，直接全开）
func open(on: bool) -> Tween:
	modulate.a = 1.0
	if not on:
		amount = 1.0
		return null
	amount = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "amount", 1.0, OPEN_SEC)
	return tw


## 收卷再淡出，完了调 [param done]（关着动效直接调）
func close(on: bool, done: Callable = Callable()) -> Tween:
	if not on:
		amount = 0.0
		modulate.a = 0.0
		if done.is_valid():
			done.call()
		return null
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "amount", 0.0, CLOSE_SEC)
	tw.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	if done.is_valid():
		tw.tween_callback(done)
	return tw
