## 帝国行军档案。档案页只呈现 SaveSlots 的摘要，切档与删除仍由 GameFlow 处理。
extends GameScreen

const PAPER := Color("#dfd2b5")
const INK := Color("#302d26")
const MUTED_INK := Color("#5c5545")
const RULE := Color("#998866")
const SEAL := Color("#803f32")

var _armed_delete: int = -1
var _folder: PanelContainer
var _rows: Array[BoxContainer] = []
var _primary_keys: Dictionary = {}


func open(payload: Dictionary) -> void:
	_rows.clear()
	_primary_keys.clear()
	_backdrop()
	var page := _painted_screen("menu/bg_map")
	var wash := ColorRect.new()
	wash.color = Color(0.06, 0.08, 0.07, 0.44)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(wash)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_folder = UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_PARCHMENT)
	var cover := _paper_box(PAPER, 30, 23)
	cover.border_color = Color("#766746")
	cover.set_border_width_all(2)
	cover.border_width_left = 8
	cover.shadow_color = Color(0.05, 0.06, 0.05, 0.6)
	cover.shadow_size = 9
	cover.shadow_offset = Vector2(3, 6)
	_folder.add_theme_stylebox_override("panel", cover)
	center.add_child(_folder)
	var col := _vbox(12)
	_folder.add_child(col)
	var heading := _hbox(15)
	col.add_child(heading)
	var compass := Control.new()
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.custom_minimum_size = Vector2(46, 46)
	compass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	compass.draw.connect(_draw_compass.bind(compass))
	heading.add_child(compass)
	var title := UiTheme.make_display(UiText.t("slots.title"), 35)
	title.add_theme_color_override("font_color", INK)
	heading.add_child(title)
	col.add_child(_rule(Color("#6e5740"), 3))
	var notice := flow.backup_notice()
	if notice != "":
		warn(notice)
	elif bool(payload.get("full", false)):
		say(UiText.t("slots.full"))
	var repaired := flow.repair_notice()
	if repaired != "":
		var note := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_SUMMARY_NOTE)
		note.name = "RepairNote"
		col.add_child(note)
		note.add_child(UiTheme.rich_line(repaired, 15, UiTheme.INK_WARN, 1.0))
	for n in range(1, SaveSlots.COUNT + 1):
		col.add_child(_row(n))
	col.add_child(_rule(RULE, 1))
	var back := ScrollKey.make(UiText.t("slots.back"), flow.to_main_menu)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dress_key(back)
	col.add_child(back)
	if not resized.is_connected(_fit):
		resized.connect(_fit)
	_fit()


func _fit() -> void:
	_folder.custom_minimum_size.x = clampf(size.x * 0.77, minf(360, size.x), 1150)
	for row in _rows:
		row.vertical = _folder.custom_minimum_size.x < 720


func _paper_box(color: Color, x: int, y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = x
	box.content_margin_right = x
	box.content_margin_top = y
	box.content_margin_bottom = y
	return box


func _rule(color: Color, height: int) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = color
	rule.custom_minimum_size.y = height
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _draw_compass(mark: Control) -> void:
	var origin := Vector2(23, 23)
	mark.draw_arc(origin, 20, 0, TAU, 64, RULE, 1, true)
	mark.draw_arc(origin, 16, 0, TAU, 64, SEAL, 1, true)
	for i in 8:
		var axis := Vector2.UP.rotated(i * TAU / 8)
		var cross_axis := axis.orthogonal() * 3.4
		var point := origin + axis * (22 if i % 2 == 0 else 13)
		mark.draw_colored_polygon(PackedVector2Array([origin, point, origin + cross_axis]), SEAL)
		mark.draw_polyline(PackedVector2Array([origin, point, origin - cross_axis, origin]), RULE, 1.0, true)
	mark.draw_circle(origin, 2.5, INK)


func _dress_key(key: Button) -> void:
	var main := key is ScrollKey and (key as ScrollKey).primary_key
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var active: bool = state != "normal"
		var base := Color("#294c44") if main else Color("#e6dbc0")
		if active:
			base = Color("#1c3732") if main else Color("#d5c3a0")
		var face := _paper_box(base, 21, 4)
		face.border_color = Color("#8c7855")
		face.set_border_width_all(1)
		face.border_width_bottom = 2
		key.add_theme_stylebox_override(state, face)
		var color_key := "font_color" if state == "normal" else "font_%s_color" % state
		key.add_theme_color_override(color_key, Color("#fff0cc") if main else INK)
	key.add_theme_color_override("font_focus_color", Color("#fff0cc") if main else INK)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = SEAL
	ring.set_border_width_all(3)
	ring.set_expand_margin_all(2)
	key.add_theme_stylebox_override("focus", ring)
	key.focus_mode = Control.FOCUS_ALL


func _row(n: int) -> Control:
	var summary := flow.slots.summary(n, flow.items, flow.meta_rules) if flow.slots != null else {"exists": false}
	var exists := bool(summary.get("exists", false))
	var current := flow.slot == n
	var panel := PanelContainer.new()
	var sheet := _paper_box(Color("#f3e9cd") if exists else Color("#e8dec4"), 17, 11)
	sheet.border_color = SEAL if current else RULE
	sheet.set_border_width_all(1)
	sheet.border_width_left = 5 if current else 2
	panel.add_theme_stylebox_override("panel", sheet)
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_rows.append(row)
	panel.add_child(row)
	var entry := _vbox(3)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(entry)
	var name_ := UiText.t("slots.slot") % n
	if current:
		name_ += UiText.t("slots.current")
	var title := _label(name_, 22, INK)
	title.add_theme_font_override("font", UiPalette.cjk_font_bold())
	title.add_theme_color_override("font_color", SEAL if current else INK)
	entry.add_child(title)
	var text := UiText.t("slots.empty")
	if exists:
		text = UiText.t("slots.summary") % [int(summary.get("runs", 0)) + 1, int(summary.get("extractions", 0)), int(summary.get("deaths", 0)),
			UiText.t("slots.in_run") if bool(summary.get("has_run", false)) else ""]
		if int(summary.get("newer", 0)) > 0:
			text += UiText.t("slots.newer_tag")
	var detail := _wrapped(text, 18, MUTED_INK, 0)
	detail.add_theme_color_override("font_color", MUTED_INK)
	entry.add_child(detail)
	var actions := _hbox(12)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	var primary := ScrollKey.primary(UiText.t("slots.load"), load_slot.bind(n)) if exists else ScrollKey.primary(UiText.t("slots.new_here"), new_game_here.bind(n))
	_dress_key(primary)
	actions.add_child(primary)
	_primary_keys[n] = primary
	if exists:
		var del := ScrollKey.short(UiText.t("slots.delete"), delete_slot.bind(n))
		del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dress_key(del)
		actions.add_child(del)
	return panel


func load_slot(n: int) -> bool:
	return flow.load_slot(n)


func new_game_here(n: int) -> bool:
	return flow.new_game_in(n)


## 点两次才删：第一次只是武装起来、提示一句
func delete_slot(n: int) -> bool:
	if _armed_delete != n:
		_armed_delete = n
		warn(UiText.t("slots.confirm_delete_slot") % (UiText.t("slots.slot") % n))
		return false
	_armed_delete = -1
	flow.delete_slot(n)
	_reopen()
	(_primary_keys[n] as Button).grab_focus()
	return true


func armed_delete() -> int:
	return _armed_delete


## 090：Esc = 回主菜单
func escape() -> bool:
	flow.to_main_menu()
	return true
