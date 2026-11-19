## 基地出征栏：军需和出发主键在上，最近一次出征的角色、地点、难度收在下方记录条。
## 教程未完成时，记录条的位置用于展示下一段教程与跳过入口。
class_name ExpeditionBoard
extends VBoxContainer

const ART := "home/expedition/"
const EMPTY_H := 106.0
const WIDTH := 560.0
const LAST_H := 66.0
const TUTORIAL_H := 200.0
const SUPPLY_H := 206.0
const START := Vector2(360, 96)
const START_FONT := 30
const PORTRAIT := 48
const NAME_FONT := 22
const LINE_FONT := 17
const SLOT := 56.0
const BADGE_FONT := 14
const INK_SLOT := Color("5a4433")
## 挂牌摆法：左边让多少、高出木牌上沿多少（挂牌 46 高，压进木牌 12）
const TAG_X := 18
const TAG_RISE := 34.0
const CHIP_FONT := 15

## 统一教程 D（方案 §8.1 / §8.2）：教程还没全通时点了「跳过剩余教程」（基地弹确认页，[method MetaScreen.show_skip_tutorial]）
signal skip_asked()

var flow: GameFlow = null
var start_btn: Button = null
var last_plate: PanelContainer = null
## 教程木牌（教程还没全通才有，顶替「上回出征」）
var tutorial_plate: PanelContainer = null
var skip_btn: Button = null
var supply_plate: PanelContainer = null
## 「上回出征」三行写的字（测试看）；没出征过是空
var _last_lines: Array[String] = []
## 军需：[[随身技能 id, 个数], …] 与局外加成 id
var _belt: Array = []
var _buffs: Array[StringName] = []


func setup(p_flow: GameFlow) -> ExpeditionBoard:
	flow = p_flow
	add_theme_constant_override("separation", 18)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	supply_plate = _plate(SUPPLY_H, "meta.supplies")
	supply_plate.tooltip_text = UiText.t("meta.supplies_tip")
	supply_plate.mouse_filter = Control.MOUSE_FILTER_PASS
	_fill_supplies(_col(supply_plate))
	if _belt.is_empty() and _buffs.is_empty():
		supply_plate.custom_minimum_size.y = EMPTY_H
	start_btn = UiTheme.make_home_button(UiText.t("meta.new_run"), flow.new_run, true, START, START_FONT)
	_dress_start()
	start_btn.name = "StartButton"
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(start_btn)
	var nxt := flow.tutorial_gate()
	if nxt != null:
		tutorial_plate = _plate(TUTORIAL_H, "meta.tutorial")
		_fill_tutorial(_col(tutorial_plate), nxt)
	else:
		last_plate = UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_CHIP)
		last_plate.custom_minimum_size = Vector2(WIDTH, LAST_H)
		add_child(last_plate)
		var content := UiTheme.vbox(6)
		last_plate.add_child(content)
		_fill_last(content)
		if flow.legacy_tutorial() != null:
			_fill_try(content)
	return self


## 一块大木牌连它的挂牌：挂牌在上（画在木牌上面），木牌往上收 12 压住挂牌下沿；返回木牌，[method _col] 取里面那一列
func _plate(h: float, title_key: String) -> PanelContainer:
	var wrap_ := UiTheme.vbox(-int(HeaderTag.HANG_HEIGHT - TAG_RISE))
	add_child(wrap_)
	var hold := MarginContainer.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold.add_theme_constant_override("margin_left", TAG_X)
	hold.z_index = 1     # 挂牌压在木牌框上
	hold.add_child(HeaderTag.hanging(UiText.t(title_key)))
	wrap_.add_child(hold)
	var p := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_PLAQUE)
	var tex := UiTheme.art_cached(ART + ("stores" if title_key == "meta.supplies" else "order"))
	if tex != null:
		p.add_theme_stylebox_override("panel", UiTheme.nine_box(tex, [36, 20, 44, 20], [30, 20, 28, 20]))
	p.custom_minimum_size = Vector2(WIDTH, h)
	wrap_.add_child(p)
	var body := UiTheme.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(body)
	return p


func _dress_start() -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var pressed: bool = state in ["pressed", "hover_pressed"]
		var tex := UiTheme.art_cached(ART + "march_" + ("pressed" if pressed else state))
		if tex != null:
			start_btn.add_theme_stylebox_override(state, UiTheme.nine_box(tex, [32, 20, 32, 20], [34, 12 if pressed else 8, 34, 4 if pressed else 8]))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		start_btn.add_theme_color_override(state, Color("fff3cd"))
	start_btn.add_theme_color_override("font_outline_color", Color("763128"))
	start_btn.add_theme_constant_override("outline_size", 3)
	start_btn.add_theme_font_override("font", UiPalette.cjk_font_bold())
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(9)
	focus.set_border_width_all(3)
	focus.set_expand_margin_all(2)
	focus.border_color = Color("ffdc75")
	start_btn.add_theme_stylebox_override("focus", focus)
	start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _empty(col: VBoxContainer, art_name: String) -> void:
	var row := UiTheme.hbox(12)
	col.add_child(row)
	var tex := UiTheme.art_cached(ART + art_name)
	if tex != null:
		var pic := UiTheme.picture(tex, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		pic.custom_minimum_size = Vector2(66, 50)
		row.add_child(pic)
	row.add_child(_line(UiText.t("meta.none_yet")))


static func _col(p: PanelContainer) -> VBoxContainer:
	return p.get_child(0)


## 平的浅羊皮小签：一行墨字
func _chip(text: String) -> PanelContainer:
	var chip := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_CHIP)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var label := UiTheme.make_label(text, CHIP_FONT, UiTheme.INK)
	var width := UiPalette.cjk_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.sz(CHIP_FONT)).x
	label.custom_minimum_size.x = minf(ceilf(width) + 2.0, WIDTH - 122.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chip.add_child(label)
	return chip


## 统一教程 D：下一段是哪张图、第几段；右下一个「跳过剩余教程」（点了先弹确认页，不直接跳）
func _fill_tutorial(col: VBoxContainer, nxt: ChapterDef) -> void:
	col.add_child(_line(Names.of(nxt), NAME_FONT))
	col.add_child(_chip(UiText.t("meta.tutorial_step") % [flow.tutorial_number(nxt), flow.tutorial_chapters().size()]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	skip_btn = UiTheme.flat_key(UiText.t("meta.tutorial_skip"), Color(0, 0, 0, 0), UiTheme.INK, SKIP_HOVER, UiTheme.INK, SKIP_SIZE, 15)
	skip_btn.name = "SkipTutorial"
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip_btn.pressed.connect(func(): skip_asked.emit())
	col.add_child(skip_btn)


## 统一教程 F：切片老档在「上回出征」右下多一个「体验统一教程」（[method GameFlow.try_tutorial]）
var try_btn: Button = null


func _fill_try(col: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	try_btn = UiTheme.flat_key(UiText.t("meta.tutorial_try"), Color(0, 0, 0, 0), UiTheme.INK, SKIP_HOVER, UiTheme.INK, SKIP_SIZE, 15)
	try_btn.name = "TryTutorial"
	try_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	try_btn.pressed.connect(func(): flow.try_tutorial())
	col.add_child(try_btn)


const SKIP_SIZE := Vector2(150, 32)
const SKIP_HOVER := Color("8a5a2b")


## 上回出征：开局屏出发时记下的角色（[member MetaState.last_character]）与图 / 规模 / 难度旗标（开局屏照这些预选）
func _fill_last(col: VBoxContainer) -> void:
	var m := flow.meta
	var ch := flow.character_of(m.last_character) if m.last_character != &"" else null
	var chapter := _last_chapter()
	var row := UiTheme.hbox(12)
	col.add_child(row)
	if ch != null:
		row.add_child(PortraitSlot.new(PORTRAIT, Nameplate.character_face(ch.id)))
	var details := UiTheme.vbox(2)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(details)
	var head := UiTheme.hbox(10)
	details.add_child(head)
	head.add_child(UiTheme.make_label(UiText.t("meta.last_expedition"), 15, UiTheme.INK_SOFT))
	if ch == null and chapter == null:
		head.add_child(_line(UiText.t("meta.none_yet"), 15))
		return
	if ch != null:
		var name_ := Names.of(ch)
		head.add_child(_line(name_, LINE_FONT))
		_last_lines.append(name_)
	var route := PackedStringArray()
	if chapter != null:
		var map := Names.of(chapter) if chapter.display_name != "" else String(chapter.id)
		var scale_ := _last_scale(chapter)
		var where := map + (UiText.t("setup.sep") + scale_ if scale_ != "" else "")
		route.append(where)
		_last_lines.append(where)
	var diff := _last_difficulty()
	if diff != null:
		route.append(Names.of(diff))
		_last_lines.append(Names.of(diff))
	if not route.is_empty():
		details.add_child(_line(UiText.t("setup.sep").join(route), CHIP_FONT))


func _last_chapter() -> ChapterDef:
	var at := flow.meta.flag(&"last_map") - 1
	if at < 0:
		return null
	for c in flow.chapters:
		if c.order == at:
			return c
	return null


func _last_scale(c: ChapterDef) -> String:
	var at := flow.meta.flag(&"last_scale") - 1
	var opts: Array[Dictionary] = c.map_source.scale_options() if c.map_source != null else [] as Array[Dictionary]
	return String(opts[at]["display_name"]) if at >= 0 and at < opts.size() else ""


func _last_difficulty() -> DifficultyDef:
	var level := flow.meta.flag(&"last_difficulty")
	for d in flow.difficulties:
		if d.level == level:
			return d
	return null


## 军需：一行随身技能圆槽（科技每局发的，[member MetaState.belt_grants]），一行局外加成小牌（[method GameFlow.meta_buffs]）
func _fill_supplies(col: VBoxContainer) -> void:
	var grants: Dictionary = flow.meta.belt_grants
	var ids := grants.keys()
	ids.sort()
	for id in ids:
		if int(grants[id]) > 0:
			_belt.append([StringName(String(id)), int(grants[id])])
	_buffs = flow.meta_buffs()
	if _belt.is_empty() and _buffs.is_empty():
		_empty(col, "ration_crate")
		return
	var scroll := ScrollContainer.new()
	scroll.name = "SupplyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	col.add_child(scroll)
	var contents := UiTheme.vbox(10)
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contents)
	if not _belt.is_empty():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		row.add_theme_constant_override("v_separation", 8)
		contents.add_child(row)
		for pair in _belt:
			row.add_child(BeltSlot.new(BeltSkillDef.find(pair[0]), int(pair[1])))
	if not _buffs.is_empty():
		var flow_row := HFlowContainer.new()
		flow_row.add_theme_constant_override("h_separation", 8)
		flow_row.add_theme_constant_override("v_separation", 8)
		contents.add_child(flow_row)
		for id in _buffs:
			var def: RunBuffDef = flow.buff_defs.get(id, null)
			var chip := _chip(Names.of(def) if def != null else String(id))
			chip.tooltip_text = Names.description_of(def) if def != null else ""
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			flow_row.add_child(chip)


func _line(text: String, font_size: int = LINE_FONT) -> Label:
	var label := UiTheme.make_label(text, font_size, UiTheme.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func last_lines() -> Array[String]:
	return _last_lines


func belt_supplies() -> Array:
	return _belt


func buff_supplies() -> Array[StringName]:
	return _buffs


## 随身技能圆槽：一圈深色槽、技能图标、右下角数量（字画在槽上，不是散字）；悬停写技能名
class BeltSlot extends Control:
	var def: BeltSkillDef = null
	var count := 0
	var _icon: Texture2D = null

	func _init(p_def: BeltSkillDef, p_count: int) -> void:
		def = p_def
		count = p_count
		_icon = def.icon() if def != null else null     # 留住引用（184）
		custom_minimum_size = Vector2.ONE * SLOT
		tooltip_text = Names.of(def) if def != null else ""
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, INK_SLOT)
		draw_circle(c, r - 3.0, Color("e9dcc0"))
		if _icon != null:
			var s := (r - 6.0) * 2.0
			draw_texture_rect(_icon, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false)
		var font := UiPalette.cjk_font_bold()
		var px := UiTheme.sz(BADGE_FONT)
		var text := "×%d" % count     # 右下角一枚小签：深底浅字
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var tag := Rect2(size.x - w - 8.0, size.y - px - 4.0, w + 8.0, px + 4.0)
		draw_rect(tag, INK_SLOT)
		draw_string(font, Vector2(tag.position.x + 4.0, tag.end.y - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("f1ece2"))
