## 285（作者 2026-11-07 14:46）：开局第二页中栏的一块预设挂牌 —— 仓库页签那副挂牌（[constant UiTheme.BUTTON_PRESET_TAG]，横向拉宽）。
## 牌面两行：上 名字；下 小字 —— 免费不写（牌上没有钱就是免费）、收费 = 金币 + 价钱（[CoinLabel]）、
## 高级 = 券的小图 + ×1（第二版，作者 14:56「新兵券、制式券」），没券时前面一把小锁、整块灰着按不动。悬停 = 这一套的清单，摆法照旧交给 [TipAnchor]
class_name PresetTag
extends Button

const W := 84.0
const H := 64.0
const NAME_FONT := 15
const SMALL_FONT := 12
const TICKET_PX := 18.0

var name_label: Label = null
## 收费的价钱（没有 null）
var coin: CoinLabel = null
## 高级那行（券的小图 + ×1；没有 null）
var ticket_row: HBoxContainer = null
## 没券时的小锁（没有 null）
var lock: Control = null


## [param price] > 0 = 收费；[param is_advanced] = 高级（[param ticket] 券的图），[param has_ticket] false = 没券（灰着）
static func make(title: String, price: int = 0, ticket: Texture2D = null, has_ticket: bool = true, is_advanced: bool = false) -> PresetTag:
	var b := PresetTag.new()
	b._build(title, price, ticket, has_ticket, is_advanced)
	return b


func _build(title: String, price: int, ticket: Texture2D, has_ticket: bool, is_advanced: bool) -> void:
	theme_type_variation = UiTheme.BUTTON_PRESET_TAG
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(W, H)
	disabled = is_advanced and not has_ticket
	var ink := UiTheme.SETUP_TAB_LOCKED_INK if disabled else UiTheme.INK
	var col := UiTheme.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 14.0     # 挂绳那截不写字
	add_child(col)
	name_label = _plate_label(title, NAME_FONT, ink)
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
	elif is_advanced:
		ticket_row = UiTheme.hbox(2)
		ticket_row.alignment = BoxContainer.ALIGNMENT_CENTER
		ticket_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ticket_row)
		if disabled:
			lock = Control.new()
			lock.custom_minimum_size = Vector2(12, 14)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock.draw.connect(_draw_lock.bind(ink))
			ticket_row.add_child(lock)
		var pic := TextureRect.new()
		pic.texture = ticket
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(TICKET_PX, TICKET_PX)
		pic.modulate = Color(1, 1, 1, 0.55) if disabled else Color.WHITE
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticket_row.add_child(pic)
		var n := _plate_label(UiText.t("setup.preset_ticket"), SMALL_FONT, ink)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticket_row.add_child(n)


## 字写在木牌上，不跟页面的深浅走（浅底会把语义色压暗：UI设计 11-07 量到锁着的名字只剩 #716654）
static func _plate_label(p_text: String, font_size: int, ink: Color) -> Label:
	var l := UiTheme.make_label(p_text, font_size, ink)
	l.remove_meta(&"dark_color")
	return l


## 小锁（同仓库页签锁着那把）
func _draw_lock(ink: Color) -> void:
	var c := Vector2(6.0, lock.size.y * 0.5 + 2.0)
	lock.draw_arc(c + Vector2(0, -4), 3.5, PI, TAU, 10, ink, 1.4, true)
	lock.draw_rect(Rect2(c + Vector2(-5, -4), Vector2(10, 8)), ink)
