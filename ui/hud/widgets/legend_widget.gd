## 166（作者定）：左下角的节点图例 —— 一列「图标 + 名字」，只列**这张图上有的**节点类型（岔路口不列），顺序按 [constant MapNodeStyle.STYLES]。
## 图标就是地图上的那一枚（155：`assets/nodes/<type>.png`，按类型色着色；缺图画圆里一个字），名字是 [constant MapNodeStyle.NAMES] 的短名。
## 184：最上面一行「你」是玩家的小兵棋子，「出生」那一行是 182 的小旗（有图就用图，原色不着色）
## 267：材料节点（矿脉 / 林地 / 遗骸 / 符文堆）各算一行（图上有才列，排在「搜索」后面）；选了出征倾向，「你」下面一行「倾向：自然」；
## 最下面一段「产物」：由外到内每种环一行，写产物表里倍率 ≥ 1.5 的标签名
extends HudWidget

const ICON := 24.0
const ROW_GAP := 4.0
const TEXT_GAP := 8.0
## 232（作者 19:23 选 10）：图例的底是一面双尾旗（`hud/legend_pennant` 九宫格，钉子、绳、横杆都在图里），白字；最窄这么宽，英文长名往宽撑
const PENNANT := "hud/legend_pennant"
const MIN_WIDTH := 158.0

static var _dark_theme: Theme = null

var _rows: VBoxContainer


func _init() -> void:
	super()
	theme = _legend_theme()     # 深底（tone dark）：不挂墨色字，自己的底和白字
	set_meta(&"tone", UiTheme.TONE_DARK)     # 169：里面的字按深底取版（HudWidget 默认挂的是凹槽的浅）
	_text.visible = false
	custom_minimum_size.x = MIN_WIDTH
	_rows = UiTheme.vbox(int(ROW_GAP))
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)


func title() -> String:
	return "图例"


## 产物段只写倍率到这么高的标签
const PRODUCE_SHOWN := 1.5


## 图上有的类型（按表的顺序；材料节点紧跟在「搜索」后面）
func types() -> Array[StringName]:
	var out: Array[StringName] = []
	if run == null or run.map == null:
		return out
	var have := {}
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		have[MapNodeStyle.key_of(n)] = true     # 揭开了的随机点按揭开的算；267：材料节点按种类
	for t in MapNodeStyle.STYLES:
		if have.has(t) and MapNodeStyle.NAMES.has(t):
			out.append(t)
		if t == &"search":
			for k in MapNodeStyle.KINDS:
				if have.has(k):
					out.append(k)
	return out


## 267 A：倾向那一行的字；没选是空
func bias_line() -> String:
	if run == null or run.material_bias == &"":
		return ""
	return UiText.t("hud.bias") % TagRegistry.name_of(run.material_bias)


## 267 B：产物段 —— 由外到内，每种不同的产物表一行「外：草木、兽材」（倍率 ≥ 1.5 的标签，按倍率从高到低）；图上没有产物表是空
func produce_lines() -> Array[String]:
	var out: Array[String] = []
	if run == null or run.map == null:
		return out
	var by_ring := {}
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		var r := int(n.layout.get("ring", 0))
		if not n.produce.is_empty() and not by_ring.has(r):
			by_ring[r] = n.produce
	var rings: Array = by_ring.keys()
	rings.sort()
	rings.reverse()
	var tables: Array = []
	for r in rings:
		var names := produce_names(by_ring[r])
		if not names.is_empty() and (tables.is_empty() or tables[-1] != names):
			tables.append(names)
	var where: Array = ["outer", "middle", "inner"] if tables.size() == 3 else (["outer", "inner"] if tables.size() == 2 else [""])
	for i in tables.size():
		var names: Array[String] = tables[i]
		var text := UiText.t("hud.buff_sep").join(names)
		var key: String = where[i] if i < where.size() else ""
		out.append(UiText.t("hud.produce_line") % [UiText.t("hud.produce_ring." + key), text] if key != "" else text)
	return out


## 一张产物表里值得说的标签名（倍率 ≥ [constant PRODUCE_SHOWN]，高的在前）
static func produce_names(table: Dictionary) -> Array[String]:
	var tags: Array = []
	for t in table:
		if float(table[t]) >= PRODUCE_SHOWN:
			tags.append(String(t))
	tags.sort_custom(func(a, b): return float(table[a]) > float(table[b]) or (float(table[a]) == float(table[b]) and a < b))
	var out: Array[String] = []
	for t in tags:
		out.append(TagRegistry.name_of(StringName(t)))
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
	var bias := bias_line()
	if bias != "":
		_add_text(bias)
	for t in types():
		_add_row(t, MapNodeStyle.name_of(t), UiTheme.ART_LEGEND_FLAG if t == &"spawn" and UiTheme.art_cached(UiTheme.ART_LEGEND_FLAG) != null else "")
	var produce := produce_lines()
	if not produce.is_empty():
		_add_text(UiText.t("hud.produce"))
		for line in produce:
			_add_text(line)


## 267：没有图标的一行字（倾向、产物段）
func _add_text(text: String) -> void:
	var row := UiTheme.hbox(0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := Label.new()
	name.theme_type_variation = UiTheme.LABEL_HUD
	name.text = text
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name)
	_rows.add_child(row)


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
		out.append((row.get_child(row.get_child_count() - 1) as Label).text)
	return out


## 双尾旗底 + 白字的一份小主题（只给图例）；旗的图缺了退回深色半透明方块
static func _legend_theme() -> Theme:
	if _dark_theme != null:
		return _dark_theme
	var t := Theme.new()
	t.set_type_variation(UiTheme.PANEL_HUD, "PanelContainer")
	t.set_stylebox("panel", UiTheme.PANEL_HUD, pennant_box())
	t.set_type_variation(UiTheme.LABEL_HUD, "Label")
	t.set_color("font_color", UiTheme.LABEL_HUD, Color.WHITE)
	t.set_color("font_color", "Label", Color.WHITE)
	_dark_theme = t
	return t


## 旗的九宫格（边距读 `legend_pennant.json`）
static func pennant_box() -> StyleBox:
	var tex := UiTheme.art_cached(PENNANT)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.08, 0.07, 0.06, 0.78)
		flat.set_corner_radius_all(4)
		flat.set_content_margin_all(10)
		return flat
	var meta := UiTheme.art_meta(PENNANT)
	var tm: Array = meta.get("texture_margin", [44, 52, 44, 58])
	var cm: Array = meta.get("content_margin", [30, 54, 26, 50])
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = float(tm[0])
	box.texture_margin_top = float(tm[1])
	box.texture_margin_right = float(tm[2])
	box.texture_margin_bottom = float(tm[3])
	box.content_margin_left = float(cm[0])
	box.content_margin_top = float(cm[1])
	box.content_margin_right = float(cm[2])
	box.content_margin_bottom = float(cm[3])
	return box


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
