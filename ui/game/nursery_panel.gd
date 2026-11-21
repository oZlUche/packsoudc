## 342 B3：后勤「苗圃」页（[Nursery]）。作者 2026-11-21 19:07：每片地是一块棋盘，作物照形状一株一株摆进去 ——
## 占位排版（等 UI设计 的样张）：顶上一排片键（两片以上）；左边这一片地的棋盘（套框画格线），每株右下角写还差几局，熟了的描金边；
## 右边【收获】（这一片熟了的全收）；下面一排栏键（药材 / 主食 / 蔬菜 / 水果；食堂没开只有药材），一栏一排作物纸条。
## 种法：纸条上【种下】摆进第一个空处；或先点【选中】，再点地里的空格摆在那里（摆不下就转个向再试）
extends VBoxContainer

signal changed()
## 有话要说（收不了、种不了的原因；收了什么）：[param warn] = 是不是要紧的
signal said(text: String, warn: bool)

const CP := preload("res://ui/game/commission_panel.gd")
const INK := Color("2e2219")
const INK_DIM := Color("5a4a3a")
## 背景上的浅字
const LIGHT := Color("f1e3c2")
const CELL := 64.0
const SLIP_W := 180.0
const SLIP_H := 250.0
const SLIP_COLS := 3
const ICON := 22.0
const RIPE := Color("e8c25a")

var flow: GameFlow = null
## 看哪一片、纸条看哪一栏、选中了哪种（点地里的空格就种它）
var shown_plot := 0
var group: StringName = Nursery.GROUP_HERB
var picked: StringName = &""
var field_view: InventoryView = null
var _body: VBoxContainer = null
var _overlay: Control = null


func setup(p_flow: GameFlow) -> void:
	flow = p_flow
	name = "NurseryPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var pad := UiTheme.margins(MarginContainer.new(), 16, 12, 16, 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_body = UiTheme.vbox(14)
	_body.name = "Stage"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.set_tone(_body, UiTheme.TONE_DARK)
	pad.add_child(_body)
	refresh()


func refresh() -> void:
	if _body == null or flow == null or flow.meta == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	field_view = null
	_overlay = null
	var n := flow.meta.nursery
	shown_plot = clampi(shown_plot, 0, n.fields.size() - 1)
	if not groups().has(group):
		group = Nursery.GROUP_HERB
	if n.fields.size() > 1:
		_add_plot_tabs()     # 355：垦户社信赖、代言各多一片
	_add_field(shown_plot)
	_add_slips(shown_plot)


## 作物名（355：食材作物就叫收成的名字）
func crop_name(crop: StringName) -> String:
	var spec: Dictionary = Nursery.CROPS.get(crop, {})
	if spec.has("food"):
		var d := _def(StringName(spec.get("product", &"")))
		return Names.of(d) if d != null else String(crop)
	return UiText.t("nursery.crop_" + String(crop))


## 一种作物的一行说明：种苗成本 → 收什么 × 几，几局（悬停字用）
func crop_text(crop: StringName) -> String:
	var spec: Dictionary = Nursery.CROPS.get(crop, {})
	var product := _def(StringName(spec.get("product", &"")))
	var seed_parts: Array[String] = []
	var seed_: Dictionary = spec.get("seed", {})
	for id in seed_:
		var d := _def(StringName(id))
		seed_parts.append("%s ×%d" % [Names.of(d) if d != null else String(id), int(seed_[id])])
	var cost := UiText.t("nursery.seed_free") if seed_parts.is_empty() else ", ".join(seed_parts)
	return UiText.t("nursery.crop_line") % [cost, Names.of(product) if product != null else "?", int(spec.get("yield", 1)), int(spec.get("runs", 0))]


## 355：纸条能看哪几栏：药材总有；灰灯食堂开了才有主食、蔬菜、水果
func groups() -> Array[StringName]:
	var out: Array[StringName] = [Nursery.GROUP_HERB]
	if flow != null and flow.meta != null and flow.meta.canteen_open():
		out.append_array(Nursery.GROUPS.filter(func(g: StringName) -> bool: return g != Nursery.GROUP_HERB))
	return out


func show_plot(i: int) -> void:
	shown_plot = i
	refresh()


func show_group(g: StringName) -> void:
	group = g
	refresh()


## 选中一种（再点就取消）；点地里的空格就种它
func pick(crop: StringName) -> void:
	picked = &"" if picked == crop else crop
	refresh()


func _def(id: StringName) -> ItemDef:
	return flow.items.get_def(id) if flow.items != null and id != &"" else null


func _item_icon(id: StringName, side: float) -> TextureRect:
	var r := TextureRect.new()
	var d := _def(id)
	r.texture = ShelfView.item_art(d) if d != null else null
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(side, side)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.tooltip_text = Names.of(d) if d != null else ""
	return r


func _tab(text: String, lit: bool, handler: Callable, node_name: String) -> Button:
	var b := UiTheme.make_button(text, handler, UiPalette.Tier.SECONDARY, 15)
	b.name = node_name
	UiTheme.mark(b, lit)
	return b


## 顶上一排片键（有熟了的写「可收获」）
func _add_plot_tabs() -> void:
	var row := UiTheme.hbox(8)
	row.name = "PlotTabs"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	for k in flow.meta.nursery.fields.size():
		var idx := k
		var text := UiText.t("nursery.plot") % (k + 1)
		if flow.meta.nursery.is_ripe(k):
			text += " · " + UiText.t("nursery.ripe")
		row.add_child(_tab(text, k == shown_plot, func(): show_plot(idx), "Plot_%d" % k))


## 这一片地：棋盘（套框）+ 右边【收获】
func _add_field(i: int) -> void:
	var row := UiTheme.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	var g := flow.meta.nursery.field(i)
	field_view = InventoryView.make(g, null)
	field_view.name = "FieldView"
	field_view.cell_px = CELL
	field_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	field_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(field_view)
	BoardFrame.wrap(field_view)     # 所有棋盘都画外框和格线
	_overlay = Control.new()     # 还差几局、熟了的金边、点空格种下
	_overlay.name = "Growth"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_draw_growth)
	_overlay.gui_input.connect(_on_field_input)
	field_view.add_child(_overlay)
	var side := UiTheme.vbox(10)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var ripe := flow.meta.nursery.ripe_units(i).size()
	var b := UiTheme.make_home_button(UiText.t("nursery.harvest"), func(): harvest(i), true, Vector2(150, 44), 20)
	b.name = "Harvest_%d" % i
	b.disabled = ripe == 0
	b.tooltip_text = UiText.t("nursery.ripe_n") % ripe if ripe > 0 else UiText.t("nursery.why_unripe")
	side.add_child(b)
	if picked != &"":
		var hint := UiTheme.make_label(UiText.t("nursery.place_hint") % crop_name(picked), 15, LIGHT)
		hint.name = "PlaceHint"
		hint.set_meta(&"exempt_bare_text", true)
		side.add_child(hint)


## 每株：没熟的压暗、右下角写还差几局；熟了的描金边
func _draw_growth() -> void:
	if field_view == null:
		return
	var n := flow.meta.nursery
	var font := ThemeDB.fallback_font
	for inst in field_view.inventory.items():
		var it := inst as ItemInstance
		var r := field_view.item_rect(it.uid)
		if n.unit_ripe(it.uid):
			_overlay.draw_rect(r.grow(-2.0), RIPE, false, 3.0)
			continue
		_overlay.draw_rect(r.grow(-2.0), Color(0, 0, 0, 0.35), true)
		var t := str(n.left_of(it.uid))
		var at := r.end - Vector2(14, 6)
		_overlay.draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.8))
		_overlay.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, LIGHT)


## 悬停一株：名字、还差几局 / 可收获
func _overlay_tip(at: Vector2) -> String:
	var uid := field_view.uid_at_cell(field_view.cell_at_local(at))
	if uid == GridInventory.EMPTY_UID:
		return ""
	var n := flow.meta.nursery
	var crop := n.crop_of(uid)
	return crop_name(crop) + " · " + (UiText.t("nursery.ripe") if n.unit_ripe(uid) else UiText.t("nursery.left") % n.left_of(uid))


func _on_field_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_overlay.tooltip_text = _overlay_tip((e as InputEventMouseMotion).position)
		return
	if not (e is InputEventMouseButton) or not (e as InputEventMouseButton).pressed or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	if picked == &"":
		return
	var cell := field_view.cell_at_local((e as InputEventMouseButton).position)
	if cell.x < 0 or cell.y < 0:
		return
	sow_at(shown_plot, picked, cell)


## 点了地里的空格：照这个朝向摆得下就摆，不行转个向再试。返回原因（空 = 种上了）
func sow_at(i: int, crop: StringName, cell: Vector2i) -> String:
	var why := ""
	for rot in 4:
		why = flow.sow_crop(i, crop, cell, rot)
		if why != Nursery.WHY_ROOM:
			break
	if why != "":
		said.emit(UiText.t("nursery.why_" + why), true)
	refresh()
	changed.emit()
	return why


## 下面一排栏键 + 这一栏的纸条
func _add_slips(i: int) -> void:
	var gs := groups()
	if gs.size() > 1:
		var tabs := UiTheme.hbox(6)
		tabs.name = "GroupTabs"
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER
		_body.add_child(tabs)
		for g in gs:
			var gg := g
			tabs.add_child(_tab(UiText.t("nursery.group_" + String(g)), g == group, func(): show_group(gg), "Group_" + String(g)))
	var grid := UiTheme.grid(SLIP_COLS, 12)
	grid.name = "Slips"
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(grid)
	for c in Nursery.crops_in(group):
		grid.add_child(_slip(i, c))


## 一张作物纸条：收成图标、名字、种苗 → 收成 ×N、几局、偶尔多收什么、【选中】【种下】
func _slip(i: int, crop: StringName) -> Control:
	var spec: Dictionary = Nursery.CROPS.get(crop, {})
	var p := UiTheme.panel_margins(PanelContainer.new(), UiTheme.PANEL_PARCHMENT, 10, 8, 10, 8)
	UiTheme.set_tone(p, UiTheme.tone_of(UiTheme.PANEL_PARCHMENT))
	p.name = "Slip_" + String(crop)
	p.custom_minimum_size = Vector2(SLIP_W, SLIP_H)
	p.tooltip_text = crop_text(crop)
	var col := UiTheme.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(col)
	var product := StringName(spec.get("product", &""))
	var pic := _item_icon(product, 56)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(pic)
	var title := UiTheme.make_label(crop_name(crop), 17, INK)
	title.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var trade := UiTheme.hbox(4)     # 种苗 ×1 → 收成 ×N
	trade.alignment = BoxContainer.ALIGNMENT_CENTER
	var seed_: Dictionary = spec.get("seed", {})
	if seed_.is_empty():
		trade.add_child(CP.emblem(&"growers", ICON))
	else:
		for id in seed_:
			trade.add_child(_item_icon(StringName(id), ICON))
			trade.add_child(UiTheme.make_label("×%d" % int(seed_[id]), 15, INK))
	trade.add_child(UiTheme.make_label("→", 15, INK_DIM))
	trade.add_child(_item_icon(product, ICON))
	trade.add_child(UiTheme.make_label("×%d" % int(spec.get("yield", 1)), 15, INK))
	col.add_child(trade)
	var runs := UiTheme.hbox(4)
	runs.alignment = BoxContainer.ALIGNMENT_CENTER
	runs.add_child(CP._pic("hourglass", Vector2(14, 18)))
	runs.add_child(UiTheme.make_label(UiText.t("nursery.runs") % int(spec.get("runs", 0)), 15, INK))
	col.add_child(runs)
	var bonus: Dictionary = spec.get("bonus", {})
	if not bonus.is_empty():
		var bd := _def(StringName(bonus.get("id", &"")))
		var bl := UiTheme.make_label(UiText.t("nursery.bonus") % (Names.of(bd) if bd != null else "?"), 13, INK_DIM)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(bl)
	var btns := UiTheme.hbox(4)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	var why := Nursery.why_not_sow(flow.meta, i, crop, flow.items)
	var sel := UiTheme.make_button(UiText.t("nursery.pick"), func(): pick(crop), UiPalette.Tier.SECONDARY, 14)
	sel.name = "Pick_" + String(crop)
	sel.tooltip_text = UiText.t("nursery.pick_tip")
	UiTheme.mark(sel, picked == crop)
	sel.disabled = why != "" and why != Nursery.WHY_ROOM
	btns.add_child(sel)
	var b := UiTheme.make_home_button(UiText.t("nursery.sow"), func(): sow(i, crop), true, Vector2(80, 34), 16)
	b.name = "Sow_%d_%s" % [i, String(crop)]
	b.disabled = why != ""
	if why != "":
		b.tooltip_text = UiText.t("nursery.why_" + why)
	btns.add_child(b)
	return CP._pinned(p, "pin_growers")


## 【种下】：摆进第一个空处
func sow(i: int, crop: StringName) -> String:
	var why := flow.sow_crop(i, crop)
	if why != "":
		said.emit(UiText.t("nursery.why_" + why), true)
	refresh()
	changed.emit()
	return why


func harvest(i: int) -> Dictionary:
	var got := flow.harvest_crop(i)
	if String(got["why"]) != "":
		said.emit(UiText.t("nursery.why_" + String(got["why"])), true)
	refresh()
	changed.emit()
	return got
