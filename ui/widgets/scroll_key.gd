## 商店按钮（UI替换美术，作者 2026-10-21 17:39 定纸卷那一案，同战斗屏的继续纸卷）：两头卷轴的纸键，九宫格横向按字长拉。
## 两种：普通键（收起、离开：宽 = 字宽 + 52，最窄 116）与币座键（刷新、「随身」买钮：右端 [member coin_cap] 宽的币座不拉，
## 金币画在图里，价钱数字由这里写在金币右边，只写数字）。卖掉的随身钮 = 禁用态 + 226 的已售戳（中心对准币座中心）。
## 排版全读 `assets/ui/shop/keys.json`（美术 `layout.json` 原样）；缺图退回平板按钮的样子（[method UiTheme.make_button]）。
## 乙 石刻那批（`kit/layout.json`）再加两种：主键 [method primary]（纸卷左头压蜡封，`kit/key_primary_*`，字在 [16, 宽] 里居中）
## 与矮键 [method short]（同图压到 44 高）；主键可以带一行小字 [member sub]（神坛「献祭」的预览）
class_name ScrollKey
extends Button

const ART_DIR := "shop/"
const LAYOUT := "shop/keys"
const KIT_LAYOUT := "kit/layout"
const PRIMARY_ART := "kit/key_primary_"
## 矮键的高与字号
const SHORT_H := 44.0
const SHORT_FONT := 18
## 带小字的主键：整颗高、小字字号、小字中心离底边
const SUB_H := 64.0
const SUB_FONT := 14
const SUB_FROM_BOTTOM := 20.0
## 带小字时大字往上让（内容区下边）
const SUB_LIFT := 16.0
const STAMP_ART := "notice/stamp_sold"
const STATES := ["normal", "hover", "pressed", "disabled"]

## 币座键（右端币座 + 价钱数字）
var coin := false
## 币座宽（含右头卷轴）
var coin_cap := 90.0
## 价钱：负数 = 不写
var price := -1:
	set(v):
		price = v
		queue_redraw()
## 作者 2026-10-27 17:13：钱不够 —— 币座上的价钱写红
var poor := false:
	set(v):
		poor = v
		queue_redraw()
## 卖掉了：压已售戳（一般同时 disabled）
var sold := false:
	set(v):
		sold = v
		queue_redraw()
## 有没有用上图（缺图时是平板按钮）
var art := false
## 主键（蜡封纸卷）
var primary_key := false
## 第二行小字（只有 [method primary] 给了 [param two_line] 的键才留位置）
var sub := "":
	set(v):
		sub = v
		_fit_sub()
		queue_redraw()
var _two_line := false
var _left := 26.0
var _right := 26.0

var _colors := {}
var _price_size := 20
var _price_dx := 37.0
var _price_cy := 28.0
var _pressed_dy := 1.0


## [param p_coin] = 币座键；[param p_price] 币座键上的数字（负数不写）
static func make(text: String, handler: Callable, p_coin: bool = false, p_price: int = -1) -> Button:
	var spec := UiTheme.art_meta(LAYOUT)
	if UiTheme.art_cached(ART_DIR + ("key_coin" if p_coin else "key") + "_normal") == null:
		var flat := UiTheme.make_button("", handler, UiPalette.Tier.SECONDARY, 13)
		show_price(flat, text, p_price)
		return flat
	var b := ScrollKey.new()
	b.coin = p_coin
	b.text = text
	b._dress(spec)
	b.price = p_price
	b.pressed.connect(handler)
	return b


## 主键：要动真格的那一下（神坛「献祭」、读档「读取」「在此开新档」）。[param two_line] = 底下留一行小字（[member sub]），整颗高 64
static func primary(text: String, handler: Callable, two_line: bool = false) -> Button:
	if UiTheme.art_cached(PRIMARY_ART + "normal") == null:
		return make(text, handler)
	var b := ScrollKey.new()
	b.primary_key = true
	b._two_line = two_line
	b.text = text
	b._dress(UiTheme.art_meta(LAYOUT))
	b.pressed.connect(handler)
	return b


## 矮键：同纸卷压到 44 高、字 18（回地图、整理背包、上一页、删除）
static func short(text: String, handler: Callable) -> Button:
	var b := make(text, handler)
	if b is ScrollKey:
		b.custom_minimum_size.y = SHORT_H
		b.add_theme_font_size_override("font_size", UiTheme.sz(SHORT_FONT))
	return b


## 写字和价钱：纸卷键字只写名字、数字画在币座上；缺图的平板按钮把数字（或「已售」）接在字后面
static func show_price(b: Button, label: String, p: int = -1, p_sold: bool = false) -> void:
	if b is ScrollKey:
		b.text = label
		b.price = p
		b.sold = p_sold
	elif p_sold:
		b.text = "%s %s" % [label, UiText.t("shop.sold_tag")]
	else:
		b.text = label if p < 0 else "%s %d" % [label, p]


## 写大字和小字：带小字的主键分两行画；别的按钮（缺图的平板）把小字接成第二行
static func show_sub(b: Button, label: String, line: String) -> void:
	if b is ScrollKey and b._two_line:
		b.text = label
		b.sub = line
	else:
		b.text = label + ("\n" + line if line != "" else "")


func _dress(spec: Dictionary) -> void:
	art = true
	var piece: Dictionary = spec.get("key_coin" if coin else "key", {})
	if primary_key:
		piece = UiTheme.art_meta(KIT_LAYOUT).get("key_primary", {})
	var m: Array = piece.get("nine_slice_margin", [20, 20, 96, 20] if coin else ([36, 20, 20, 20] if primary_key else [20, 20, 20, 20]))
	var pad := float(spec.get("pad", 6))
	var h := float(spec.get("height", 56))
	coin_cap = float(piece.get("coin_cap", 90)) if coin else 0.0
	var label: Dictionary = spec.get("label", {})
	var cols: Dictionary = label.get("colors", {})
	for state in STATES:
		_colors[state] = Color(String(cols.get(state, "#2e2219")))
	_pressed_dy = float(label.get("pressed_offset_y", 1))
	var pr: Dictionary = spec.get("price", {})
	_price_size = int(pr.get("size", 20))
	_price_dx = 37.0
	_price_cy = float(pr.get("center_y", 28))
	custom_minimum_size = Vector2(0.0 if coin else (132.0 if primary_key else 116.0), SUB_H if _two_line else h)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_font_override("font", UiPalette.cjk_font_bold())
	add_theme_font_size_override("font_size", UiTheme.sz(int(label.get("size", 22))))     # 258：键宽随字
	# 字：普通键在整颗里居中（两边各 26 → 宽 = 字宽 + 52）；币座键在左边那段里居中再右挪 2；主键在 [16, 宽] 里居中
	_left = 26.0 + (2.0 if coin else 0.0) + (16.0 if primary_key else 0.0)
	_right = 26.0 + coin_cap - (2.0 if coin else 0.0)
	var base := PRIMARY_ART if primary_key else ART_DIR + ("key_coin_" if coin else "key_")
	for state in STATES:
		var box := StyleBoxTexture.new()
		box.texture = UiTheme.art_cached(base + state)
		if box.texture == null:
			box.texture = UiTheme.art_cached(base + "normal")
		box.texture_margin_left = float(m[0])
		box.texture_margin_top = float(m[1])
		box.texture_margin_right = float(m[2])
		box.texture_margin_bottom = float(m[3])
		box.set_expand_margin_all(pad)
		var dy := _pressed_dy if state == "pressed" else 0.0
		box.content_margin_left = _left
		box.content_margin_right = _right
		box.content_margin_top = 2.0 * dy     # 按下：字往下挪 dy（内容区上边让 2 dy，字居中）
		box.content_margin_bottom = 0.0
		add_theme_stylebox_override(state, box)
		add_theme_color_override("font_%s_color" % state if state != "normal" else "font_color", _colors[state])
	add_theme_color_override("font_hover_pressed_color", _colors["pressed"])
	add_theme_color_override("font_focus_color", _colors["normal"])
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover_pressed", get_theme_stylebox("pressed"))


## 字左对齐的整行键（事件选项）：字离左头卷轴 [param px]
func indent(px: float) -> void:
	_left = px
	for state in STATES:
		var box := get_theme_stylebox(state) as StyleBoxTexture
		if box != null:
			box.content_margin_left = px
	update_minimum_size()


## 有小字：大字往上让 [constant SUB_LIFT]，宽也要容得下小字
func _fit_sub() -> void:
	if not art or not _two_line:
		return
	for state in STATES + ["hover_pressed"]:
		var box := get_theme_stylebox(state) as StyleBoxTexture
		if box != null:
			box.content_margin_bottom = SUB_LIFT if sub != "" else 0.0
	var w := UiPalette.cjk_font().get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_FONT).x
	custom_minimum_size.x = maxf(132.0, ceilf(w + _left + _right))
	update_minimum_size()


func _state() -> String:
	if disabled:
		return "disabled"
	match get_draw_mode():
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			return "pressed"
		DRAW_HOVER:
			return "hover"
	return "normal"


## 价钱数字的左端（按钮坐标）：币座左沿 + 37
func price_at() -> Vector2:
	return Vector2(size.x - coin_cap + _price_dx, _price_cy)


## 已售戳中心（按钮坐标）：币座中心
func stamp_center() -> Vector2:
	return Vector2(size.x - coin_cap * 0.5, _price_cy)


func _draw() -> void:
	if art and _two_line and sub != "":
		var st2 := _state()
		var f2 := UiPalette.cjk_font()
		var cy := size.y - SUB_FROM_BOTTOM + (_pressed_dy if st2 == "pressed" else 0.0)
		var y := cy + (f2.get_ascent(SUB_FONT) - f2.get_descent(SUB_FONT)) * 0.5
		draw_string(f2, Vector2(_left, y), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x - _left - _right, SUB_FONT, _colors[st2])
	if not art or not coin:
		return
	var st := _state()
	var dy := _pressed_dy if st == "pressed" else 0.0
	if price >= 0 and not sold:
		var f := UiPalette.cjk_font_bold()
		var s := str(price)
		var at := price_at() + Vector2(0.0, dy)
		var asc := f.get_ascent(_price_size)
		var desc := f.get_descent(_price_size)
		draw_string(f, Vector2(at.x, at.y + (asc - desc) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, _price_size, PriceTag.POOR_INK if poor else _colors[st])
	if sold:
		var tex := UiTheme.art_cached(UiTheme.lang_art(STAMP_ART))
		if tex != null:
			var side := 52.0
			draw_texture_rect(tex, Rect2(stamp_center() - Vector2(side, side) * 0.5, Vector2(side, side)), false)
