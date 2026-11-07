## 285（作者 2026-11-07 14:46）：开局第二页中栏的一块预设挂牌 —— 仓库页签那副挂牌（[constant UiTheme.BUTTON_PRESET_TAG]，横向拉宽）。
## 牌面两行：上 名字；下 小字 —— 免费不写（牌上没有钱就是免费）、收费 = 金币 + 价钱（[CoinLabel]）、高级缺件 = 小锁 +「缺 n 件」（整块灰着按不动）。
## 悬停 = 这一套的清单，缺的那几件红字：引擎的悬停窗只认纯文本，这里自己出一块富文本（[method _make_custom_tooltip]），摆法照旧交给 [TipAnchor]
class_name PresetTag
extends Button

const W := 84.0
const H := 64.0
const NAME_FONT := 15
const SMALL_FONT := 12
## 悬停清单里缺的那几件
const MISSING_INK := Color("e0584a")

var name_label: Label = null
## 收费的价钱（没有 null）
var coin: CoinLabel = null
## 高级缺件那行（没有 null）
var short_label: Label = null
var _lines: Array[String] = []
var _missing: Array[bool] = []


## [param price] > 0 = 收费；[param missing] > 0 = 高级缺件（灰着）。[param lines] 清单道具名，[param flags] 同序、true 的写红
static func make(title: String, price: int = 0, missing: int = 0, lines: Array[String] = [], flags: Array[bool] = []) -> PresetTag:
	var b := PresetTag.new()
	b._build(title, price, missing, lines, flags)
	return b


func _build(title: String, price: int, missing: int, lines: Array[String], flags: Array[bool]) -> void:
	theme_type_variation = UiTheme.BUTTON_PRESET_TAG
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(W, H)
	_lines = lines
	_missing = flags
	disabled = missing > 0
	var ink := UiTheme.SETUP_TAB_LOCKED_INK if disabled else UiTheme.INK
	var col := UiTheme.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 14.0     # 挂绳那截不写字
	add_child(col)
	name_label = UiTheme.make_label(title, NAME_FONT, ink)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	TextFit.shrink_label(name_label, W - 2.0 * UiTheme.PRESET_TAG_EDGE, NAME_FONT, SMALL_FONT)
	if price > 0:
		coin = CoinLabel.new()
		coin.font_size = SMALL_FONT
		coin.amount = price
		coin.centered = true
		coin.ink = ink
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(coin)
	elif missing > 0:
		short_label = UiTheme.make_label("    " + UiText.t("setup.preset_short") % missing, SMALL_FONT, ink)     # 前面空出小锁的位
		short_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		short_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		short_label.draw.connect(_draw_lock)
		col.add_child(short_label)
	tooltip_text = "\n".join(lines)


## 小锁（同仓库页签锁着那把），画在「缺 n 件」前面
func _draw_lock() -> void:
	var font := short_label.get_theme_font("font")
	var fs := short_label.get_theme_font_size("font_size")
	var w := font.get_string_size(short_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := (short_label.size.x - w) * 0.5 + 2.0
	var c := Vector2(x0 + 3.0, short_label.size.y * 0.5 + 2.0)
	var ink := short_label.get_theme_color("font_color")
	short_label.draw_arc(c + Vector2(0, -4), 3.5, PI, TAU, 10, ink, 1.4, true)
	short_label.draw_rect(Rect2(c + Vector2(-5, -4), Vector2(10, 8)), ink)


## 清单是第几件缺（测试看）
func missing_flags() -> Array[bool]:
	return _missing


func _make_custom_tooltip(_for_text: String) -> Object:
	if _lines.is_empty():
		return null
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.scroll_active = false
	var rows: Array[String] = []
	for i in _lines.size():
		var miss := i < _missing.size() and _missing[i]
		rows.append("[color=#%s]%s[/color]" % [MISSING_INK.to_html(false), _lines[i]] if miss else _lines[i])
	rt.text = "\n".join(rows)
	return rt
