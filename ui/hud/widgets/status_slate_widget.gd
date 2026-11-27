## 作者 11-27（确认清单 85 A，规格 art/ui/s-map-status/规格.md）：地图左上（顶端栏下面）一块深石板，上节「状态」、下节「委托」。
## 原来栏里第二行的 buff 一句（buffs）和左上的委托小牌（commissions，336）合进这一块。
##
## - 状态：每个 buff 一行，名字在左；右边灰字写来源（名字末尾括号里的「科技」之类）或「剩 N 步」。停在一行上开那个状态的悬浮窗。
## - 委托：节标题后面金字「已办成 / 带了几条」；每条一行，名字照旧截到 [constant NAME_MAX] 字，右边粗体进度，办成了绿字「已办成」。
## - 两节之间一道虚线。每节标题右边一枚圆钮（▾ 展开 / ▸ 收起），收起只剩标题行（「状态 N」「委托 x / y」）；
##   两节各自记在设置里（[member GameSettings.status_open] / [member GameSettings.commissions_open]），下一局照旧。
## - 某一节没内容整节不显示；两节都没有整块不显示
extends HudWidget

## 名字最多几个字，长了截断加「…」：英文大字号下长名字会把石板撑宽（测试报告 v8.81–v8.82）
const NAME_MAX := 16
const MIN_WIDTH := 250.0
const PAD := 16.0
const ROW_GAP := 4.0
const SECTION_GAP := 8.0
const KNOB := 24.0
## 规格里的颜色
const INK_LIGHT := Color("f4efe4")
const INK_DIM := Color("a89f8a")
const GOLD := Color("ffc928")
const GREEN := Color("8fd16a")
const KNOB_FILL := Color("4a4339")
const BRASS := Color("c9a04e")
const DASH := Color("6d6450")
## 石板里的几种字（小主题里的变体，不逐个覆写）
const V_TITLE := &"SlateTitle"
const V_ROW := &"SlateRow"
const V_DIM := &"SlateDim"
const V_NUM := &"SlateNum"
const V_GOLD := &"SlateGold"
const V_DONE := &"SlateDone"
const V_SECTION := &"SlateSection"

static var _theme: Theme = null
static var _theme_scale := -1.0

var _body: VBoxContainer
var _status: _Section
var _dash: Control
var _comm: _Section


static func short_name(n: String) -> String:
	return n if n.length() <= NAME_MAX else n.left(NAME_MAX - 1).strip_edges() + "…"


## 名字末尾括号里的来源拆出来：「耐久（科技）」→ ["耐久", "科技"]；没有括号 → [名字, ""]
static func split_source(n: String) -> PackedStringArray:
	var re := RegEx.create_from_string("^(.*?)\\s*[（(]([^（）()]+)[）)]$")
	var m := re.search(n)
	if m == null or m.get_string(1).strip_edges() == "":
		return PackedStringArray([n, ""])
	return PackedStringArray([m.get_string(1).strip_edges(), m.get_string(2).strip_edges()])


func _init() -> void:
	super()
	theme = _slate_theme()
	set_meta(&"tone", UiTheme.TONE_DARK)
	_text.visible = false     # 字只给测试和显隐用，画的是两节
	_body = UiTheme.vbox(int(SECTION_GAP))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.custom_minimum_size.x = MIN_WIDTH
	add_child(_body)
	_status = _Section.new(self, &"status")
	_body.add_child(_status)
	_dash = _Dash.new()
	_body.add_child(_dash)
	_comm = _Section.new(self, &"commissions")
	_body.add_child(_comm)


func title() -> String:
	return UiText.t("hud.slate_status") + " / " + UiText.t("hud.slate_commissions")


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_PASS     # 行与圆钮自己接鼠标


func watch() -> Array[Signal]:
	var out: Array[Signal] = []
	var bm := BuffModule.of(run)
	if bm != null:
		out.append(bm.buffs_changed)
	var cm := CommissionModule.of(run)
	if cm != null:
		out.append(cm.progressed)
	return out


#region 内容
## 状态的行：{name, side, def}（side = 右边灰字：来源或「剩 N 步」）
func status_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if run == null:
		return out
	for id_ in run.meta_buffs:
		out.append(_status_row(run.buff_defs.get(id_, null), String(id_), 0))
	for entry in BuffModule.entries_of(run):
		var id_ := String(entry["id"])
		out.append(_status_row(run.buff_defs.get(StringName(id_), null), id_, int(entry["left"])))
	return out


func _status_row(def: RunBuffDef, id_: String, left: int) -> Dictionary:
	var parts := split_source(Names.of(def) if def != null else id_)
	return {"name": parts[0], "side": UiText.t("hud.slate_left") % left if left > 0 else parts[1], "def": def}


func _comm_mod() -> CommissionModule:
	return CommissionModule.of(run) if run != null else null


## 委托的行：{name, state, finished}
func commission_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mod := _comm_mod()
	if mod == null or not mod.is_active():
		return out
	for row in mod.lines():
		var done := bool(row["finished"])
		out.append({"name": short_name(String(row["name"])), "finished": done,
			"state": UiText.t("commission.state_done") if done else UiText.t("commission.progress") % [int(row["done"]), int(row["need"])]})
	return out


## 委托办成了几条
func commissions_done(rows: Array[Dictionary]) -> int:
	return rows.filter(func(r: Dictionary) -> bool: return bool(r["finished"])).size()


## 给测试和显隐的一份字：每节标题一行，展开的节下面每行一条
func text_of() -> String:
	if run == null:
		return ""
	var out: PackedStringArray = []
	var st := status_rows()
	if not st.is_empty():
		out.append("%s %d" % [UiText.t("hud.slate_status"), st.size()])
		if is_open(&"status"):
			for r in st:
				out.append(("%s　%s" % [r["name"], r["side"]]).strip_edges())
	var cm := commission_rows()
	if not cm.is_empty():
		out.append("%s %s" % [UiText.t("hud.slate_commissions"), UiText.t("commission.progress") % [commissions_done(cm), cm.size()]])
		if is_open(&"commissions"):
			for r in cm:
				out.append("%s　%s" % [r["name"], r["state"]])
	return "\n".join(out)
#endregion


#region 收起 / 展开
func _settings() -> GameSettings:
	var f = screen.get("flow") if screen != null else null
	return f.settings if f != null else null


## 这一节展开着没有（没有设置 = 展开）
func is_open(section: StringName) -> bool:
	var s := _settings()
	if s == null:
		return bool(_local_open.get(section, true))
	return s.status_open if section == &"status" else s.commissions_open


## 没有设置时（测试直接造宿主）记在这里
var _local_open := {}


## 点圆钮：切换这一节并记进设置
func toggle(section: StringName) -> void:
	var open := not is_open(section)
	var s := _settings()
	if s == null:
		_local_open[section] = open
	else:
		if section == &"status":
			s.status_open = open
		else:
			s.commissions_open = open
		var f = screen.get("flow")
		if f != null and f.has_method("save_settings"):
			f.save_settings()
	refresh()
#endregion


func refresh() -> void:
	super()
	if _status == null:
		return
	var st := status_rows()
	var cm := commission_rows()
	_status.fill(UiText.t("hud.slate_status"), "%d" % st.size(), is_open(&"status"), st.map(func(r: Dictionary) -> Array:
		return [r["name"], r["side"], V_DIM, r["def"]]))
	_comm.fill(UiText.t("hud.slate_commissions"), UiText.t("commission.progress") % [commissions_done(cm), cm.size()], is_open(&"commissions"),
		cm.map(func(r: Dictionary) -> Array: return [r["name"], r["state"], V_DONE if bool(r["finished"]) else V_NUM, null]),
		true)
	_status.visible = not st.is_empty()
	_comm.visible = not cm.is_empty()
	_dash.visible = _status.visible and _comm.visible
	reset_size()


## 停在状态那一行：开那个状态的悬浮窗（名字 + 效果）
func _hover_row(def: RunBuffDef, ctl: Control, on: bool) -> void:
	var tip: HoverTip = screen.get("_tip") if screen != null else null
	if tip == null or editing:
		return
	if not on:
		tip.release()
		return
	if def == null:
		return
	var body := def.summary()
	if body == "":
		body = Names.description_of(def)
	tip.show_text(Names.of(def) + ("\n" + body if body != "" else ""), ctl.global_position + Vector2(ctl.size.x + 8.0, 0.0))


## 一节：标题行（标题 + 数 + 圆钮）+ 行
class _Section:
	extends VBoxContainer
	var owner_: Node
	var key: StringName
	var head: HBoxContainer
	var title_l: Label
	var count_l: Label
	var knob: _Knob
	var rows: VBoxContainer

	func _init(p_owner: Node, p_key: StringName) -> void:
		owner_ = p_owner
		key = p_key
		name = "Section_" + String(p_key)
		theme_type_variation = V_SECTION
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		head = HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(head)
		title_l = _label(V_TITLE)
		head.add_child(title_l)
		count_l = _label(V_GOLD)
		head.add_child(count_l)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(gap)
		knob = _Knob.new()
		knob.pressed.connect(func(): owner_.call("toggle", key))
		head.add_child(knob)
		rows = VBoxContainer.new()
		rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rows)

	## [param lines]：每行 [左, 右, 右的变体, 悬浮的 def]；[param count_when_open] 假 = 展开时不写标题后面的数（状态节）
	func fill(p_title: String, count: String, open: bool, lines: Array, count_when_open: bool = false) -> void:
		title_l.text = p_title
		count_l.text = count
		count_l.visible = count_when_open or not open
		knob.open = open
		knob.queue_redraw()
		rows.visible = open
		for c in rows.get_children():
			rows.remove_child(c)
			c.queue_free()
		for ln in lines:
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_STOP if ln[3] != null else Control.MOUSE_FILTER_IGNORE
			var left := _label(V_ROW)
			left.text = String(ln[0])
			left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(left)
			var right := _label(StringName(ln[2]))
			right.text = String(ln[1])
			right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(right)
			if ln[3] != null:
				var def: RunBuffDef = ln[3]
				row.mouse_entered.connect(func(): owner_.call("_hover_row", def, row, true))
				row.mouse_exited.connect(func(): owner_.call("_hover_row", def, row, false))
			rows.add_child(row)

	## 行的字（测试看）：每行 "左|右"
	func row_texts() -> Array[String]:
		var out: Array[String] = []
		for row in rows.get_children():
			out.append("%s|%s" % [(row.get_child(0) as Label).text, (row.get_child(1) as Label).text])
		return out

	static func _label(variation: StringName) -> Label:
		var l := Label.new()
		l.theme_type_variation = variation
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l


## 收起钮：直径 24 的圆，底 #4A4339、黄铜描边，展开 ▾ / 收起 ▸
class _Knob:
	extends Control
	signal pressed()
	var open := true

	func _init() -> void:
		custom_minimum_size = Vector2(KNOB, KNOB)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r - 1.0, KNOB_FILL)
		draw_arc(c, r - 1.0, 0.0, TAU, 32, BRASS, 1.5, true)
		var s := r * 0.36
		var tri: PackedVector2Array
		if open:
			tri = PackedVector2Array([c + Vector2(-s, -s * 0.6), c + Vector2(s, -s * 0.6), c + Vector2(0, s * 0.8)])
		else:
			tri = PackedVector2Array([c + Vector2(-s * 0.6, -s), c + Vector2(-s * 0.6, s), c + Vector2(s * 0.8, 0)])
		draw_colored_polygon(tri, INK_LIGHT)


## 两节之间的虚线
class _Dash:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(0, 3)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_dashed_line(Vector2(0, 1.5), Vector2(size.x, 1.5), DASH, 1.0, 4.0)


## 深石板底 + 几种字的小主题（字号跟字号档）
static func _slate_theme() -> Theme:
	if _theme != null and _theme_scale == UiTheme.text_scale:
		return _theme
	var t := Theme.new()
	t.set_type_variation(UiTheme.PANEL_HUD, "PanelContainer")
	var slate := UiTheme.art_box(UiTheme.ART_STONE_SLATE)
	if slate != null:
		slate.set_content_margin_all(PAD)
		t.set_stylebox("panel", UiTheme.PANEL_HUD, slate)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("3a352d")
		flat.set_content_margin_all(PAD)
		t.set_stylebox("panel", UiTheme.PANEL_HUD, flat)
	var bold := UiPalette.cjk_font_bold()
	for v in [[V_TITLE, 17, INK_LIGHT, true], [V_ROW, 15, INK_LIGHT, false], [V_DIM, 15, INK_DIM, false],
			[V_NUM, 15, INK_LIGHT, true], [V_GOLD, 17, GOLD, true], [V_DONE, 15, GREEN, true]]:
		t.set_type_variation(v[0], "Label")
		t.set_font_size("font_size", v[0], UiTheme.sz(int(v[1])))
		t.set_color("font_color", v[0], v[2])
		if bool(v[3]) and bold != null:
			t.set_font("font", v[0], bold)
	t.set_type_variation(V_SECTION, "VBoxContainer")
	t.set_constant("separation", V_SECTION, int(ROW_GAP))
	t.set_type_variation("TooltipLabel", "Label")
	t.set_color("font_color", "TooltipLabel", UiTheme.INK)
	_theme = t
	_theme_scale = UiTheme.text_scale
	return t
