## 乙 石刻输入框（kit `field_normal` / `field_focus` + `icon_search`）：刻进石板的一道浅槽，高 36，九宫格 16，图四周多 6；
## 字从 36 起（左头放放大镜，左 10、上 8），墨字、占位字淡棕。百科搜索框在用；缺图照旧引擎默认的框
class_name StoneField
extends LineEdit

const ART := "kit/field_"
const ICON_ART := "kit/icon_search"
const HEIGHT := 36.0
const TEXT_LEFT := 36.0
const ICON_AT := Vector2(10, 8)
const FONT_SIZE := 16
const INK := Color("2e2219")
const PLACEHOLDER := Color("8a7a64")


func _init(p_placeholder: String = "", search: bool = true) -> void:
	placeholder_text = p_placeholder
	if UiTheme.art_cached(ART + "normal") == null:
		return
	custom_minimum_size.y = HEIGHT
	for pair in [["normal", "normal"], ["focus", "focus"], ["read_only", "normal"]]:
		var box := StyleBoxTexture.new()
		box.texture = UiTheme.art_cached(ART + String(pair[1]))
		box.set_texture_margin_all(16.0)
		box.set_expand_margin_all(6.0)
		box.content_margin_left = TEXT_LEFT if search else 12.0
		box.content_margin_right = 10.0
		box.content_margin_top = 0.0
		box.content_margin_bottom = 0.0
		add_theme_stylebox_override(String(pair[0]), box)
	add_theme_font_override("font", UiPalette.cjk_font())
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", INK)
	add_theme_color_override("font_placeholder_color", PLACEHOLDER)
	add_theme_color_override("caret_color", INK)
	add_theme_color_override("selection_color", Color(0.75, 0.55, 0.30, 0.45))
	if search:
		var icon := TextureRect.new()
		icon.name = "SearchIcon"
		icon.texture = UiTheme.art_cached(ICON_ART)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = ICON_AT - Vector2(6, 6)     # 图四周多 6
		add_child(icon)
