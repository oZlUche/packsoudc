## 230：悬浮窗脚下的道具操作按钮（UI替换美术 甲 平墨签 `tip/tipbtn_*`，作者 19:06「按钮的样式我要平的」）：
## 平色九宫格、字居中、按下不下沉；高 [constant HEIGHT]，宽由悬浮窗按行给（一行两颗各 [constant HALF]，独占一行 [constant FULL]）。
## 危险的（[member ItemActions.Action.danger]）两步：第一下变「再点一次」（`tipbtn_danger`），[constant CONFIRM_SEC] 秒不点回弹
class_name TipButton
extends Button

const HEIGHT := 28.0
const FULL := 360.0
const GAP := 6.0
const HALF := (FULL - GAP) / 2.0
const FONT_SIZE := 14
## 字宽 + 这么多超过半宽就拆行（§2.6）
const LABEL_PAD := 16.0
const CONFIRM_SEC := 2.0
## 图四周留的投影边（layout.json `pad`）
const BLEED := 6.0
## 价钱（金币 + 数字）离右边
const COIN_RIGHT := 10.0
const INK := {"normal": Color("efe6d2"), "hover": Color("fff6e2"), "pressed": Color("ddd2bb"), "disabled": Color("7d786e"), "danger": Color("fff0e6")}

## 按下（危险的第二下）要做的事
signal chosen(action: ItemActions.Action)

var action: ItemActions.Action
## 危险按钮第一下之后还剩几秒（0 = 没在等）
var confirm_left := 0.0


static func make(a: ItemActions.Action, width: float) -> TipButton:
	var b := TipButton.new()
	b.action = a
	b.text = a.label
	b.disabled = not a.enabled
	var short := CoinShort.has(a.reason)     # 「金币不够」不写字：价钱那枚金币变红、斜划一道
	b.tooltip_text = CoinShort.strip(a.reason) if short else a.reason
	b.custom_minimum_size = Vector2(width, HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiPalette.cjk_font_bold())
	b.add_theme_font_size_override("font_size", UiTheme.sz(FONT_SIZE))
	b._style(false)
	if a.coin >= 0 or short:     # 251 补充一：价钱 = 金币 + 数字，靠右摆在签上
		var c := CoinLabel.make(a.coin, UiTheme.sz(FONT_SIZE), INK["normal"] if a.enabled else INK["disabled"])
		c.short = short
		# 游戏测试 v4.85：按钮还没排版（尺寸 0）时按预设摆，金币和数字掉到按钮下沿外面 —— 改成竖着撑满、靠右留 COIN_RIGHT，字在自己的矩形里竖向居中
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.anchor_top = 0.0
		c.anchor_bottom = 1.0
		c.offset_right = -COIN_RIGHT
		c.offset_left = -COIN_RIGHT - c.custom_minimum_size.x
		c.offset_top = 0.0
		c.offset_bottom = 0.0
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
		b.add_child(c)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(b._on_pressed)
	return b


## 这段字放不放得下半宽
static func fits_half(label: String) -> bool:
	return UiPalette.cjk_font_bold().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.sz(FONT_SIZE)).x + LABEL_PAD <= HALF


func _box(state: String) -> StyleBox:
	var tex := UiTheme.art_cached("tip/tipbtn_" + state)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = {"danger": Color("7a2a1e"), "disabled": Color("3a342c"), "hover": Color("5a4a38"), "pressed": Color("3e3226")}.get(state, Color("4a3c2e"))
		return flat
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.set_texture_margin_all(12.0)
	box.set_expand_margin_all(BLEED)
	# 内边距不跟九宫格边走（那 12 含投影边）：上下 0、左右 8，按钮高就是 HEIGHT（UI替换美术 21:37 量出 46）
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	return box


## 平常 / 等第二下 两套样子
func _style(confirming: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var key: String = "danger" if confirming and state in ["normal", "hover"] else state
		add_theme_stylebox_override(state, _box(key))
	add_theme_stylebox_override("hover_pressed", _box("pressed"))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink: Color = INK["danger"] if confirming else INK["normal"]
	add_theme_color_override("font_color", ink)
	add_theme_color_override("font_focus_color", ink)
	add_theme_color_override("font_hover_color", INK["danger"] if confirming else INK["hover"])
	add_theme_color_override("font_pressed_color", INK["pressed"])
	add_theme_color_override("font_hover_pressed_color", INK["pressed"])
	add_theme_color_override("font_disabled_color", INK["disabled"])


func _on_pressed() -> void:
	if action == null or not action.enabled:
		return
	if action.danger and confirm_left <= 0.0:
		confirm_left = CONFIRM_SEC
		text = UiText.t("act.confirm")
		_style(true)
		return
	confirm_left = 0.0
	chosen.emit(action)


## 正等着第二下
func confirming() -> bool:
	return confirm_left > 0.0


func _process(delta: float) -> void:
	tick(delta)


## 两步确认的倒计时（测试直接喂时间）
func tick(delta: float) -> void:
	if confirm_left <= 0.0:
		return
	confirm_left -= delta
	if confirm_left <= 0.0:
		confirm_left = 0.0
		text = action.label
		_style(false)
