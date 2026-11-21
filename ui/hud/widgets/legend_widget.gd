## 166（作者定）：左下角的节点图例 —— 一列「图标 + 名字」，只列**这张图上有的**节点类型（岔路口不列），顺序按 [constant MapNodeStyle.STYLES]。
## 图标就是地图上的那一枚（155：`assets/nodes/<type>.png`，按类型色着色；缺图画圆里一个字），名字是 [constant MapNodeStyle.NAMES] 的短名。
## 184：最上面一行「你」是玩家的小兵棋子，「出生」那一行是 182 的小旗（原色不着色）
## 267：材料节点（矿脉 / 林地 / 遗骸 / 符文堆）各算一行（图上有才列，排在「搜索」后面）；
## 最下面一段「产物」：由外到内每种环一行，写产物表里倍率 ≥ 1.5 的标签名
##
## 作者 2026-11-21：像卷轴一样收起 —— 挂杆下第一行写「图例」，点一下整幅卷起（只剩挂杆、「图例」和旗尾），再点放下；
## 卷起 / 放下约 0.2 秒（关了动效就直接切）。默认放下，记在设置里（[member GameSettings.legend_open]）。
## 教程要指名字时可以 [method set_expanded] 临时放下
extends HudWidget

const ICON := 24.0
const ROW_GAP := 4.0
const TEXT_GAP := 8.0
## 232（作者 19:23 选 10）：图例的底是一面双尾旗（`hud/legend_pennant` 九宫格，钉子、绳、横杆都在图里），白字；最窄这么宽，英文长名往宽撑
const PENNANT := "hud/legend_pennant"
const MIN_WIDTH := 158.0
## 卷起 / 放下的时长
const SCROLL_SEC := 0.2

static var _dark_theme: Theme = null

var _rows: VBoxContainer
## 挂杆下的「图例」
var _title: Label
## 卷起来的那一截：裁掉露在高度外的行
var _clip: Control
var _scroll_tw: Tween = null
## §4.3：名字和产物段展开着没有
var _expanded: bool = false
## §4.3：临时展开（教程用；不写进设置）
var _forced: bool = false


func _init() -> void:
	super()
	theme = _legend_theme()     # 深底（tone dark）：不挂墨色字，自己的底和白字
	set_meta(&"tone", UiTheme.TONE_DARK)     # 169：里面的字按深底取版（HudWidget 默认挂的是凹槽的浅）
	_text.visible = false
	var body := UiTheme.vbox(int(ROW_GAP))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = UiTheme.LABEL_HUD
	_title.text = UiText.t("hud.legend")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_title)
	_clip = Control.new()
	_clip.name = "Scroll"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_clip)
	_rows = UiTheme.vbox(int(ROW_GAP))
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_rows)


func title() -> String:
	return "图例"


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP     # 点旗卷起 / 放下


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(p_run: RunState, p_screen: Control) -> void:
	var f = p_screen.get("flow") if p_screen != null else null
	_expanded = f != null and f.settings != null and bool(f.settings.legend_open)
	super(p_run, p_screen)


## §4.3：现在名字露着没有（收起时只有图标）
func expanded() -> bool:
	return _expanded or _forced


## §4.3：点一下切换并记进设置
func toggle_expanded() -> void:
	_expanded = not _expanded
	var f = screen.get("flow") if screen != null else null
	if f != null and f.settings != null:
		f.settings.legend_open = _expanded
		f.save_settings()
	_apply_expanded(true)


## §4.3：教程临时展开（[param on] 假 = 回到玩家自己选的样子）
func set_expanded(on: bool) -> void:
	_forced = on
	_apply_expanded()


func _apply_expanded(animate: bool = false) -> void:
	if _rows == null:
		return
	var open := expanded()
	var full := _rows.get_combined_minimum_size()
	_rows.size = full
	custom_minimum_size.x = MIN_WIDTH
	tooltip_text = "" if open else text_of()     # 卷起时停上去照样读得到图上有哪些
	if _scroll_tw != null:
		_scroll_tw.kill()
		_scroll_tw = null
	var to := full.y if open else 0.0
	if animate and _motion() and is_inside_tree():
		_scroll_tw = create_tween()
		_scroll_tw.tween_method(_set_open_h.bind(full.x), _clip.custom_minimum_size.y, to, SCROLL_SEC).set_trans(Tween.TRANS_SINE)
	else:
		_set_open_h(to, full.x)


## 露出来的行有多高（0 = 卷起）
func _set_open_h(h: float, w: float) -> void:
	_clip.custom_minimum_size = Vector2(w, h)     # 卷起也留着宽，挂杆不缩
	reset_size()


## 卷着没有（测试看；动画走完才算）
func rolled_up() -> bool:
	return _clip != null and _clip.custom_minimum_size.y < 0.5


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if not editing and mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		toggle_expanded()
		accept_event()
		return
	super(event)


## 产物段只写倍率到这么高的标签
const PRODUCE_SHOWN := 1.5


## 图上有的类型（按表的顺序；材料节点紧跟在「搜索」后面）
func types() -> Array[StringName]:
	var out: Array[StringName] = []
	if run == null or run.map == null:
		return out
	var have := {}
	for id_ in run.map.node_ids():
		var n := run.map.get_node(id_)
		have[MapNodeStyle.key_of(n)] = true     # 揭开了的随机点按揭开的算；267：材料节点按种类
	for t in MapNodeStyle.STYLES:
		if have.has(t) and MapNodeStyle.NAMES.has(t):
			out.append(t)
		if t == &"search":
			for k in MapNodeStyle.KINDS:
				if have.has(k):
					out.append(k)
	return out


## 267 B：产物段 —— 由外到内，每种不同的产物表一行「外：草木、兽材」（倍率 ≥ 1.5 的标签，按倍率从高到低）；图上没有产物表是空
func produce_lines() -> Array[String]:
	var out: Array[String] = []
	if run == null or run.map == null:
		return out
	var by_ring := {}
	for id_ in run.map.node_ids():
		var n := run.map.get_node(id_)
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
		var text_ := UiText.t("hud.buff_sep").join(names)
		var key: String = where[i] if i < where.size() else ""
		out.append(UiText.t("hud.produce_line") % [UiText.t("hud.produce_ring." + key), text_] if key != "" else text_)
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
	if run.map != null:
		_add_row(&"", UiText.t("hud.you"), UiTheme.ART_LEGEND_PAWN)
	for t in types():
		_add_row(t, MapNodeStyle.name_of(t), UiTheme.ART_LEGEND_FLAG if t == &"spawn" else "")
	var produce := produce_lines()
	if not produce.is_empty():
		_add_row(&"", UiText.t("hud.produce"), "", false)
		for line in produce:
			_add_row(&"", line, "", false)
	_apply_expanded()


## 267：[param with_mark] 假 = 没有图标的一行字（产物段）
func _add_row(type: StringName, p_text: String, art_name: String, with_mark: bool = true) -> void:
	var row := UiTheme.hbox(int(TEXT_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if with_mark:
		var mark := _Mark.new()
		mark.type = type
		mark.art_name = art_name
		row.add_child(mark)
	var name_ := Label.new()
	name_.theme_type_variation = UiTheme.LABEL_HUD
	name_.text = p_text
	name_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_)
	_rows.add_child(row)


## 一行的名字（测试看）
func row_names() -> Array[String]:
	var out: Array[String] = []
	if _rows == null:
		return out
	for row in _rows.get_children():
		out.append((row.get_child(row.get_child_count() - 1) as Label).text)
	return out


## 双尾旗底 + 白字的一份小主题（只给图例）
static func _legend_theme() -> Theme:
	if _dark_theme != null:
		return _dark_theme
	var t := Theme.new()
	t.set_type_variation(UiTheme.PANEL_HUD, "PanelContainer")
	t.set_stylebox("panel", UiTheme.PANEL_HUD, pennant_box())
	t.set_type_variation(UiTheme.LABEL_HUD, "Label")
	t.set_color("font_color", UiTheme.LABEL_HUD, Color.WHITE)
	t.set_color("font_color", "Label", Color.WHITE)
	# 提示框还是浅羊皮纸底：TooltipLabel 往上找会先碰到这里的白字 Label，得单独钉回墨色（测试 v7.14：卷起悬停白字看不清）
	t.set_type_variation("TooltipLabel", "Label")
	t.set_color("font_color", "TooltipLabel", UiTheme.INK)
	_dark_theme = t
	return t


## 旗的九宫格（边距读 `legend_pennant.json`）
static func pennant_box() -> StyleBox:
	var meta := UiTheme.art_meta(PENNANT)
	var tm: Array = meta.get("texture_margin", [44, 52, 44, 58])
	var cm: Array = meta.get("content_margin", [34, 54, 34, 50])
	return UiTheme.nine_box(UiTheme.art_cached(PENNANT), tm, cm)


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
