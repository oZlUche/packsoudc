## 150：信仰 + 信力 + 阶（087 / 082）；停上去开悬浮窗（具体效果、信力怎么涨），用所在屏的那个悬浮窗。
## 166（作者定）：有信仰时画这个信仰的徽记（`assets/ui/faith/<id>.png`，32 px）+ 阶与信力的小字；**没信仰时留一个空槽**（固定宽、不写字）。
## 缺图时退回原来那行字（「信仰：暴力之神　…」）
## 信仰重构 A：三态 —— 不奉神（空槽）/ 联系正常（徽记 + 阶 + 信力）/ 联系中断（选的那位神的徽记压暗 + 「联系中断」，悬浮窗写原因）
extends HudWidget

const ICON := 32.0
const ART_DIR := "res://assets/ui/faith/"

var icon: HudIcon
var _two_lines := false


func _init() -> void:
	super()
	icon = HudIcon.make(ICON)
	_prepend_icon(icon)


func title() -> String:
	return "信仰"


func watch() -> Array[Signal]:
	var out: Array[Signal] = [run.faith_changed]
	if run.faith_power != null:
		out.append(run.faith_power.changed)
	return out


## 选了神但联系中断
func _broken() -> bool:
	return run != null and run.selected_faith != &"" and run.active_faith_id() == &""


## 这个信仰的徽记；没有图 null
static func art_of(faith_id: StringName) -> Texture2D:
	return HudIcon.load_art(ART_DIR + String(faith_id) + ".png") if faith_id != &"" else null


func text_of() -> String:
	if _broken():
		return UiText.t("faith.broken")
	var id_ := run.active_faith_id()
	if id_ == &"":
		return ""     # 没信仰：空槽
	var line := run.faith_power.line() if run.faith_power != null else ""
	if art_of(id_) == null:
		return run.faith_line() + (UiText.t("tip.gap") + line if line != "" else "")
	var def := run.active_faith()
	if def == null or run.faith_power == null:
		return ""
	return text_at(run.faith_power.points_of(id_))


## 231 补充二：信力滚数（有徽记那种写法才滚）
func roll_value() -> int:
	var id_ := run.active_faith_id()
	if id_ == &"" or art_of(id_) == null or run.active_faith() == null or run.faith_power == null:
		return -1
	return run.faith_power.points_of(id_)


func text_at(p: int) -> String:
	var def := run.active_faith()
	if def == null:
		return text_of()
	var next := def.next_threshold(p)
	if in_bar:
		return UiText.t("hud.faith_bar_level") % [def.tier_of(p), "\n" if _two_lines else " ", p, ("/%d" % next) if next >= 0 else ""]
	return UiText.t("hud.faith_level") % [def.tier_of(p), p, (" / %d" % next) if next >= 0 else ""]


func _bar_changed() -> void:
	_two_lines = false
	_text.remove_theme_constant_override("line_spacing")
	_text.remove_theme_font_size_override("font_size")
	refresh()


func _bar_sample() -> String:
	return UiText.t("hud.faith_bar_level") % [8, " ", 888, "/888"]


func _bar_padding() -> float:
	return get_theme_stylebox("panel").get_minimum_size().x + ICON + (icon.get_parent() as HBoxContainer).get_theme_constant("separation")


## 按当前一行 / 两行字号给等级和三位信力预留空间；实际更宽时宿主采用实测宽。
func bar_reserve_width() -> float:
	var font := _text.get_theme_font("font")
	var px := _text.get_theme_font_size("font_size")
	var lines := _bar_sample().split(" ", true, 1) if _two_lines else PackedStringArray([_bar_sample()])
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	return ceilf(width + _bar_padding())


## 只在信仰槽内调排版。先用单行；要缩小超过约一成时，把阶位放到信力上方。
func fit_bar_width(room: float) -> void:
	var base: int = UiTheme.sz({Tier.SMALL: UiTheme.FONT_SIZE, Tier.DOUBLE: UiTheme.HUD_DOUBLE_SIZE,
			Tier.LARGE: UiTheme.HUD_LARGE_SIZE}[tier])
	var available := room - _bar_padding()
	var font := _text.get_theme_font("font")
	var single := _text.text.replace("\n", " ")
	var sample := _bar_sample()
	var widest := single if font.get_string_size(single, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x > font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x else sample
	var px := TextFit.size_for(font, widest, base, available, maxi(1, roundi(base * 0.88)))
	var fields := single.split(" ", true, 1)
	var stack := font.get_string_size(widest, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > available and (single.is_empty() or roll_value() >= 0)
	if stack:
		px = mini(base, UiTheme.sz(14))
	if stack != _two_lines:
		_two_lines = stack
		if stack:
			# 两行只有拉丁字母和数字，复用字体行内留白即可维持基准横梁高度。
			_text.add_theme_constant_override("line_spacing", -UiTheme.sz(3))
		else:
			_text.remove_theme_constant_override("line_spacing")
		_text.text = "\n".join(fields) if stack else single
	if px == base:
		if _text.has_theme_font_size_override("font_size"):
			_text.remove_theme_font_size_override("font_size")
	elif _text.get_theme_font_size("font_size") != px:
		_text.add_theme_font_size_override("font_size", px)


func _paint() -> void:
	icon.texture = art_of(run.selected_faith) if run != null else null
	icon.visible = icon.texture != null or run == null or run.selected_faith == &""     # 缺图退回文字时不占那一格
	icon.modulate = Color(1, 1, 1, 0.4) if _broken() else Color.WHITE
	_sync_empty()


## 没信仰：位置留着，底也不画（真的空着；摆读数时照常画出来好拖）
func _sync_empty() -> void:
	self_modulate.a = 0.0 if not editing and run != null and run.selected_faith == &"" else 1.0


## 没信仰也占着位置（一个空槽），不藏
func _sync_visible() -> void:
	visible = editing or (shown and run != null)


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_entered.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null and run != null and not editing:
			tip.show_faith(FaithTooltip.describe_full(run.selected_faith_def(), run.faith_power, run.board, run.items, run.faith_connection()), global_position + Vector2(0, size.y)))     # 188
	mouse_exited.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.release())     # 作者 2026-10-17：钉住了就留着
