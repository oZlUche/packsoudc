## 251 补充二 §12.1：铁匠铺左列的大类木牌（UI替换美术 smithy_cats 定稿：`smithy/cat_{normal,hover,pressed,on,disabled}.png`，212 × 56，平木牌，
## 选中 `on` 是亮木 + 热铁红描边 + 右边指向格子的小尖；`smithy/cat_layout.json` 给九宫格四边、字的边距与字色）。
## 用法同 [method StoneChip.entry]：toggle 键，正在看的那类按下（`set_pressed_no_signal`）。[member dim] = 这一类没有能打的配方 → 贴压灰那张、灰墨字，
## 但还能点开看要什么料；一张配方都没有的类直接 disabled。字由代码画（粗体），整页缩放时 [member scale_k] 跟着缩
class_name CatKey
extends Button

const ART := "smithy/cat_"
const LAYOUT := "smithy/cat_layout"
const SIZE := Vector2(212, 56)
const FONT_SIZE := 22

## 压灰（没有能打的配方，仍能点）
var dim := false:
	set(v):
		dim = v
		queue_redraw()
## 整页缩放（1 = 底图原尺寸）
var scale_k := 1.0:
	set(v):
		scale_k = v
		custom_minimum_size = (SIZE * scale_k).floor()
		queue_redraw()

var _boxes := {}
var _ink := {}
var _margin := Vector2(8, 24)


## 有木牌图就是 [CatKey]，缺图退回目录条石签
static func make(text: String, handler: Callable) -> Button:
	if UiTheme.art_cached(ART + "normal") == null:
		return StoneChip.entry(text, handler)
	var b := CatKey.new()
	b.text = text
	b.pressed.connect(handler)
	return b


## 一列木牌之间的空（整页缩放跟着变）
static func space(column: VBoxContainer, px: int) -> void:
	column.add_theme_constant_override("separation", px)


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	custom_minimum_size = SIZE
	var spec := UiTheme.art_meta(LAYOUT)
	var nine: Dictionary = spec.get("nine_slice", {})
	var cm: Dictionary = spec.get("content_margin", {})
	_margin = Vector2(float(cm.get("left", 8)), float(cm.get("right", 24)))
	var cols: Dictionary = (spec.get("font", {}) as Dictionary).get("colors", {})
	for st in ["normal", "hover", "pressed", "on", "disabled"]:
		_ink[st] = Color(String(cols.get(st, "#7d7064" if st == "disabled" else "#2e2219")))
		var box := StyleBoxTexture.new()
		box.texture = UiTheme.art_cached(ART + st)
		box.texture_margin_left = float(nine.get("left", 14))
		box.texture_margin_right = float(nine.get("right", 30))
		box.texture_margin_top = float(nine.get("top", 14))
		box.texture_margin_bottom = float(nine.get("bottom", 14))
		_boxes[st] = box
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(s, none)     # 底由 _draw 按态贴
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))


## 现在贴哪一态：选中 on 压过一切；没有能打的（[member dim]）贴压灰
func state() -> String:
	if button_pressed:
		return "on"
	if disabled or dim:
		return "disabled"
	match get_draw_mode():
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			return "pressed"
		DRAW_HOVER:
			return "hover"
	return "normal"


func _draw() -> void:
	var st := state()
	var box := _boxes[st] as StyleBoxTexture
	if box.texture != null:
		draw_style_box(box, Rect2(Vector2.ZERO, size))
	var f := UiPalette.cjk_font_bold()
	var left := _margin.x * scale_k
	var w := size.x - left - _margin.y * scale_k
	# 258：字号按档放大；键宽不变，放不下就缩回小档的字号
	var fs := maxi(12, roundi(UiTheme.sz(FONT_SIZE) * scale_k))
	var floor_fs := maxi(12, roundi(FONT_SIZE * scale_k))
	while fs > floor_fs and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	var y := size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	draw_string(f, Vector2(left, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, _ink[st])
