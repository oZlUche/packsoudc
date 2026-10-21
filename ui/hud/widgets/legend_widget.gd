## 166（作者定）：左下角的节点图例 —— 一列「图标 + 名字」，只列**这张图上有的**节点类型（岔路口不列），顺序按 [constant MapNodeStyle.STYLES]。
## 图标就是地图上的那一枚（155：`assets/nodes/<type>.png`，按类型色着色；缺图画圆里一个字），名字是 [constant MapNodeStyle.NAMES] 的短名。
## 184：最上面一行「你」是玩家的小兵棋子，「出生」那一行是 182 的小旗（有图就用图，原色不着色）
extends HudWidget

const ICON := 24.0
const ROW_GAP := 4.0
const TEXT_GAP := 8.0
## 作者 2026-10-13（图例看不清、字压边框）：图例自己一块深色半透明底、白字，内边距让图标和字离边框远一点
const BG := Color(0.08, 0.07, 0.06, 0.78)
const PAD_X := 10
const PAD_Y := 6

static var _dark_theme: Theme = null

var _rows: VBoxContainer


func _init() -> void:
	super()
	theme = _legend_theme()     # 深底（tone dark）：不挂墨色字，自己的底和白字
	set_meta(&"tone", UiTheme.TONE_DARK)     # 169：里面的字按深底取版（HudWidget 默认挂的是凹槽的浅）
	_text.visible = false
	_rows = UiTheme.vbox(int(ROW_GAP))
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


func title() -> String:
	return "图例"


## 图上有的类型（按表的顺序）
func types() -> Array[StringName]:
	var out: Array[StringName] = []
	if run == null or run.map == null:
		return out
	var have := {}
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		have[NodeEvents.effective_type(n)] = true     # 揭开了的随机点按揭开的算
	for t in MapNodeStyle.STYLES:
		if have.has(t) and MapNodeStyle.NAMES.has(t):
			out.append(t)
	return out


func text_of() -> String:
	var names: Array[String] = []
	for t in types():
		names.append(MapNodeStyle.name_of(t))
	return UiText.t("hud.buff_sep").join(names)


func refresh() -> void:
	super()
	if _rows == null:
		return
	UiTheme.clear_children(_rows)
	if run == null:
		return
	if run.map != null and UiTheme.art_cached(UiTheme.ART_LEGEND_PAWN) != null:
		_add_row(&"", UiText.t("hud.you"), UiTheme.ART_LEGEND_PAWN)
	for t in types():
		_add_row(t, MapNodeStyle.name_of(t), UiTheme.ART_LEGEND_FLAG if t == &"spawn" and UiTheme.art_cached(UiTheme.ART_LEGEND_FLAG) != null else "")


func _add_row(type: StringName, text: String, art_name: String) -> void:
	var row := UiTheme.hbox(int(TEXT_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := _Mark.new()
	mark.type = type
	mark.art_name = art_name
	row.add_child(mark)
	var name := Label.new()
	name.theme_type_variation = UiTheme.LABEL_HUD
	name.text = text
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name)
	_rows.add_child(row)


## 一行的名字（测试看）
func row_names() -> Array[String]:
	var out: Array[String] = []
	if _rows == null:
		return out
	for row in _rows.get_children():
		out.append((row.get_child(1) as Label).text)
	return out


## 深色底 + 白字的一份小主题（只给图例）
static func _legend_theme() -> Theme:
	if _dark_theme != null:
		return _dark_theme
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = Color(1, 1, 1, 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = PAD_X
	box.content_margin_right = PAD_X
	box.content_margin_top = PAD_Y
	box.content_margin_bottom = PAD_Y
	var t := Theme.new()
	t.set_type_variation(UiTheme.PANEL_HUD, "PanelContainer")
	t.set_stylebox("panel", UiTheme.PANEL_HUD, box)
	t.set_type_variation(UiTheme.LABEL_HUD, "Label")
	t.set_color("font_color", UiTheme.LABEL_HUD, Color.WHITE)
	t.set_color("font_color", "Label", Color.WHITE)
	_dark_theme = t
	return t


## 一枚图标：图（按类型色着色）或者圆里一个字
class _Mark:
	extends Control
	var type: StringName = &""
	## 184：整张小图（棋子、小旗），不按类型色着色
	var art_name: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(ICON, ICON)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if art_name != "":
			var pic := UiTheme.art_cached(art_name)
			if pic != null:
				draw_texture_rect(pic, Rect2(Vector2.ZERO, size), false)
				return
		var style := MapNodeStyle.of(type)
		var col: Color = style["color"]
		var tex := MapNodeStyle.icon(type)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, col)
			return
		draw_circle(size * 0.5, ICON * 0.5, Color(col, 0.25))
		draw_arc(size * 0.5, ICON * 0.5 - 1.0, 0.0, TAU, 24, col, 1.5)
		var font := get_theme_default_font()
		if font != null:
			var g := String(style["glyph"])
			var w := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, Vector2((size.x - w) * 0.5, size.y * 0.5 + 5.0), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
